import Foundation
import UIKit

/// Erreurs possibles lors de l'appel à l'API Claude.
enum ClaudeServiceError: LocalizedError {
    case missingAPIKey
    case imageEncodingFailed
    case invalidResponse
    case api(status: Int, message: String)
    case decoding(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Aucune clé API configurée. Ouvrez les Réglages pour l'ajouter."
        case .imageEncodingFailed:
            return "Impossible de traiter l'image."
        case .invalidResponse:
            return "Réponse invalide du serveur."
        case .api(let status, let message):
            return "Erreur API (\(status)) : \(message)"
        case .decoding(let detail):
            return "Impossible d'interpréter la réponse : \(detail)"
        }
    }
}

/// Service qui envoie une photo d'assiette à l'API Messages d'Anthropic
/// (endpoint vision) et récupère une estimation nutritionnelle structurée.
///
/// Swift n'a pas de SDK Anthropic officiel : on utilise donc des requêtes
/// HTTP brutes via URLSession, l'approche recommandée dans ce cas.
struct ClaudeService {

    // MARK: - Configuration

    /// Modèle utilisé. Claude Opus 5 offre la meilleure précision.
    /// Pour réduire les coûts sur un usage fréquent, vous pouvez le remplacer par
    /// "claude-sonnet-5" (bon compromis) ou "claude-haiku-4-5" (le moins cher).
    static let model = "claude-opus-5"

    private static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private static let anthropicVersion = "2023-06-01"

    /// Instruction système : cadre la tâche pour des estimations cohérentes.
    private static let systemPrompt = """
    Tu es un nutritionniste expert. À partir d'une photo d'assiette, tu identifies \
    chaque aliment visible, tu estimes sa quantité en grammes puis ses calories et \
    macronutriments (protéines, glucides, lipides). Base-toi sur les portions visibles \
    et les repères visuels (taille de l'assiette, des couverts). Sois réaliste : ces \
    valeurs sont des estimations. Réponds en français. Le champ "confidence" reflète \
    ta certitude ; "notes" contient une courte remarque utile (ex. hypothèses de portion).
    """

    // MARK: - Schéma de sortie structurée

    /// Schéma JSON imposé à la réponse du modèle (structured outputs).
    /// Garantit une sortie décodable en `AnalysisResult`.
    private static let outputSchema: [String: Any] = [
        "type": "object",
        "properties": [
            "dish_name": ["type": "string"],
            "items": [
                "type": "array",
                "items": [
                    "type": "object",
                    "properties": [
                        "name": ["type": "string"],
                        "estimated_grams": ["type": "number"],
                        "calories": ["type": "number"],
                        "protein_g": ["type": "number"],
                        "carbs_g": ["type": "number"],
                        "fat_g": ["type": "number"]
                    ],
                    "required": ["name", "estimated_grams", "calories", "protein_g", "carbs_g", "fat_g"],
                    "additionalProperties": false
                ]
            ],
            "total_calories": ["type": "number"],
            "confidence": ["type": "string", "enum": ["low", "medium", "high"]],
            "notes": ["type": "string"]
        ],
        "required": ["dish_name", "items", "total_calories", "confidence", "notes"],
        "additionalProperties": false
    ]

    // MARK: - Appel principal

    /// Analyse une image d'assiette et renvoie l'estimation nutritionnelle.
    /// - Parameter image: la photo prise/choisie par l'utilisateur.
    static func analyze(image: UIImage) async throws -> AnalysisResult {
        guard let apiKey = KeychainHelper.loadAPIKey(), !apiKey.isEmpty else {
            throw ClaudeServiceError.missingAPIKey
        }

        // On réduit l'image pour limiter le coût en tokens (1024 px suffisent
        // largement pour reconnaître des aliments) et on compresse en JPEG.
        guard let jpeg = image.resizedForUpload(maxDimension: 1024).jpegData(compressionQuality: 0.7) else {
            throw ClaudeServiceError.imageEncodingFailed
        }
        let base64 = jpeg.base64EncodedString()

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 2048,
            // Pas de raisonnement étendu : plus rapide et moins cher pour de
            // l'extraction visuelle. Décommentez pour activer le raisonnement adaptatif.
            "thinking": ["type": "disabled"],
            "system": systemPrompt,
            "output_config": [
                "format": [
                    "type": "json_schema",
                    "schema": outputSchema
                ]
            ],
            "messages": [
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "image",
                            "source": [
                                "type": "base64",
                                "media_type": "image/jpeg",
                                "data": base64
                            ]
                        ],
                        [
                            "type": "text",
                            "text": "Analyse cette assiette et estime les calories et macronutriments de chaque aliment, puis le total."
                        ]
                    ]
                ]
            ]
        ]

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(anthropicVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.timeoutInterval = 60
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw ClaudeServiceError.invalidResponse
        }

        guard (200..<300).contains(http.statusCode) else {
            let message = Self.extractAPIErrorMessage(from: data) ?? "Erreur inconnue"
            throw ClaudeServiceError.api(status: http.statusCode, message: message)
        }

        // La réponse Messages contient un tableau `content`. Avec la sortie
        // structurée, le premier bloc de type "text" contient un JSON valide.
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = root["content"] as? [[String: Any]] else {
            throw ClaudeServiceError.invalidResponse
        }

        // Sécurité : un refus renvoie stop_reason == "refusal".
        if let stopReason = root["stop_reason"] as? String, stopReason == "refusal" {
            throw ClaudeServiceError.api(status: 200, message: "La demande a été refusée par le modèle.")
        }

        guard let text = content.first(where: { ($0["type"] as? String) == "text" })?["text"] as? String,
              let jsonData = text.data(using: .utf8) else {
            throw ClaudeServiceError.invalidResponse
        }

        do {
            return try JSONDecoder().decode(AnalysisResult.self, from: jsonData)
        } catch {
            throw ClaudeServiceError.decoding(error.localizedDescription)
        }
    }

    /// Extrait un message d'erreur lisible du corps d'erreur de l'API.
    private static func extractAPIErrorMessage(from data: Data) -> String? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = root["error"] as? [String: Any],
              let message = error["message"] as? String else {
            return nil
        }
        return message
    }
}

// MARK: - Redimensionnement d'image

extension UIImage {
    /// Redimensionne l'image pour que sa plus grande dimension ne dépasse pas
    /// `maxDimension`, en conservant les proportions.
    func resizedForUpload(maxDimension: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > maxDimension else { return self }
        let scale = maxDimension / longest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

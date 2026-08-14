import Foundation
import UIKit

/// Configuration du backend d'analyse (modifiable dans les Réglages).
///
/// Utilise les mêmes clés `UserDefaults` que les `@AppStorage` de `SettingsView`
/// (`serverURL` / `serverPassword`), et l'en-tête `Authorization: Bearer <mot de
/// passe>` comme le projet `menu`.
enum BackendConfig {
    private static let urlKey = "serverURL"
    private static let passwordKey = "serverPassword"

    /// URL de base du backend, ex. https://calories.mon-domaine.eu  (vide = non configuré).
    static var baseURL: String {
        get { UserDefaults.standard.string(forKey: urlKey) ?? "" }
        set { UserDefaults.standard.set(newValue.trimmingCharacters(in: .whitespaces), forKey: urlKey) }
    }

    /// Mot de passe du serveur (`CALORIE_PASSWORD`), envoyé en `Authorization: Bearer`.
    static var password: String {
        get { UserDefaults.standard.string(forKey: passwordKey) ?? "" }
        set { UserDefaults.standard.set(newValue.trimmingCharacters(in: .whitespaces), forKey: passwordKey) }
    }

    static var isConfigured: Bool {
        !baseURL.trimmingCharacters(in: .whitespaces).isEmpty
    }
}

enum RemoteAnalyzerError: LocalizedError {
    case notConfigured
    case imageEncodingFailed
    case server(status: Int, message: String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Backend non configuré. Renseignez son URL dans les Réglages."
        case .imageEncodingFailed:
            return "Impossible de préparer l'image."
        case .server(let status, let message):
            return "Erreur serveur (\(status)) : \(message)"
        case .invalidResponse:
            return "Réponse invalide du serveur."
        }
    }
}

/// Envoie la photo au backend (qui appelle Claude vision) et renvoie l'analyse.
struct RemoteFoodAnalyzer {

    static func analyze(image: UIImage) async throws -> AnalyzedResult {
        guard BackendConfig.isConfigured,
              let url = URL(string: BackendConfig.baseURL.hasSuffix("/")
                            ? BackendConfig.baseURL + "analyze"
                            : BackendConfig.baseURL + "/analyze") else {
            throw RemoteAnalyzerError.notConfigured
        }

        guard let jpeg = image.resizedForUpload(maxDimension: 1024).jpegData(compressionQuality: 0.7) else {
            throw RemoteAnalyzerError.imageEncodingFailed
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        if !BackendConfig.password.isEmpty {
            request.setValue("Bearer \(BackendConfig.password)", forHTTPHeaderField: "Authorization")
        }

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"plate.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(jpeg)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw RemoteAnalyzerError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["detail"] as? String
            throw RemoteAnalyzerError.server(status: http.statusCode, message: message ?? "Erreur inconnue")
        }

        do {
            return try JSONDecoder().decode(AnalyzedResult.self, from: data)
        } catch {
            throw RemoteAnalyzerError.invalidResponse
        }
    }
}

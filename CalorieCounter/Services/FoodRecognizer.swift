import Foundation
import Vision
import UIKit
import CoreML

/// Reconnaissance d'aliments **sur l'appareil**, via le framework Vision d'Apple.
///
/// - Par défaut, utilise le classifieur d'images intégré à iOS
///   (`VNClassifyImageRequest`) : un modèle Core ML embarqué dans le système,
///   sans fichier à fournir, sans réseau, sans clé API.
/// - Si un modèle Core ML dédié aux aliments est ajouté au projet sous le nom
///   `FoodClassifier.mlmodel` (ex. Food-101), il est détecté et utilisé
///   automatiquement pour une meilleure précision.
enum FoodRecognizer {

    /// Modèle Core ML personnalisé optionnel (chargé une seule fois si présent).
    private static let customModel: VNCoreMLModel? = {
        guard let url = Bundle.main.url(forResource: "FoodClassifier", withExtension: "mlmodelc"),
              let mlModel = try? MLModel(contentsOf: url),
              let vnModel = try? VNCoreMLModel(for: mlModel) else {
            return nil
        }
        return vnModel
    }()

    /// Reconnaît les aliments présents sur la photo et renvoie des candidats
    /// associés à la base locale, triés par confiance décroissante.
    static func recognize(_ image: UIImage) async -> [RecognitionCandidate] {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: performRecognition(image))
            }
        }
    }

    // MARK: - Détail

    private static func performRecognition(_ image: UIImage) -> [RecognitionCandidate] {
        guard let cgImage = image.cgImage else { return [] }
        let handler = VNImageRequestHandler(cgImage: cgImage,
                                            orientation: image.cgOrientation,
                                            options: [:])

        var observations: [(label: String, confidence: Double)] = []

        if let model = customModel {
            let request = VNCoreMLRequest(model: model)
            request.imageCropAndScaleOption = .centerCrop
            try? handler.perform([request])
            if let results = request.results as? [VNClassificationObservation] {
                observations = results
                    .filter { $0.confidence > 0.02 }
                    .prefix(15)
                    .map { (label: $0.identifier, confidence: Double($0.confidence)) }
            }
        } else {
            let request = VNClassifyImageRequest()
            try? handler.perform([request])
            if let results = request.results {
                observations = results
                    .filter { $0.confidence > 0.10 }
                    .prefix(20)
                    .map { (label: $0.identifier, confidence: Double($0.confidence)) }
            }
        }

        // On associe chaque libellé à un aliment de la base, en dédupliquant.
        var byFood: [String: RecognitionCandidate] = [:]
        for obs in observations {
            guard let food = FoodDatabase.shared.match(identifier: obs.label) else { continue }
            if let existing = byFood[food.key], existing.confidence >= obs.confidence { continue }
            byFood[food.key] = RecognitionCandidate(food: food, confidence: obs.confidence)
        }

        return byFood.values.sorted { $0.confidence > $1.confidence }
    }
}

private extension UIImage {
    /// Convertit l'orientation UIKit en orientation CoreGraphics pour Vision.
    var cgOrientation: CGImagePropertyOrientation {
        switch imageOrientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}

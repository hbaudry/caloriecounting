import Foundation

/// Résultat brut renvoyé par l'API Claude après analyse d'une photo d'assiette.
/// Le schéma correspond exactement au `json_schema` envoyé dans la requête,
/// ce qui garantit un JSON valide et décodable.
struct AnalysisResult: Codable {
    var dishName: String
    var items: [FoodItem]
    var totalCalories: Double
    var confidence: Confidence
    var notes: String

    enum Confidence: String, Codable {
        case low, medium, high

        /// Libellé affiché en français.
        var label: String {
            switch self {
            case .low: return "Faible"
            case .medium: return "Moyenne"
            case .high: return "Élevée"
            }
        }
    }

    enum CodingKeys: String, CodingKey {
        case dishName = "dish_name"
        case items
        case totalCalories = "total_calories"
        case confidence
        case notes
    }
}

/// Un aliment détecté dans l'assiette, avec son estimation nutritionnelle.
struct FoodItem: Codable, Identifiable {
    var id = UUID()
    var name: String
    var estimatedGrams: Double
    var calories: Double
    var proteinG: Double
    var carbsG: Double
    var fatG: Double

    enum CodingKeys: String, CodingKey {
        case name
        case estimatedGrams = "estimated_grams"
        case calories
        case proteinG = "protein_g"
        case carbsG = "carbs_g"
        case fatG = "fat_g"
    }
}

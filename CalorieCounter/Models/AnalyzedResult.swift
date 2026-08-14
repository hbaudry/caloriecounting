import Foundation

/// Réponse du backend d'analyse (Claude vision) : un plat + ses aliments,
/// avec calories et macros **pour la portion estimée**.
struct AnalyzedResult: Codable {
    var dishName: String
    var items: [AnalyzedItem]
    var totalCalories: Double
    var confidence: String
    var notes: String

    enum CodingKeys: String, CodingKey {
        case dishName = "dish_name"
        case items
        case totalCalories = "total_calories"
        case confidence
        case notes
    }
}

struct AnalyzedItem: Codable {
    var name: String
    var grams: Double
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double

    /// Convertit en `Food` (valeurs ramenées à 100 g) pour réutiliser l'édition
    /// des portions de l'app. Les grammes estimés deviennent la portion par défaut.
    func asFood() -> Food {
        let g = max(grams, 1)
        let factor = 100.0 / g
        return Food(
            key: "ai_" + UUID().uuidString,
            name: name,
            aliases: nil,
            kcal: calories * factor,
            protein: protein * factor,
            carbs: carbs * factor,
            fat: fat * factor,
            defaultGrams: grams
        )
    }
}

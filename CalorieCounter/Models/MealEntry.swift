import Foundation

/// Un repas enregistré dans le journal, avec sa date et son analyse.
/// L'image est stockée en JPEG (miniature) pour réafficher le repas.
struct MealEntry: Codable, Identifiable {
    var id = UUID()
    var date: Date
    var dishName: String
    var items: [FoodItem]
    var totalCalories: Double
    var notes: String
    /// Miniature JPEG encodée pour le journal (optionnelle).
    var imageData: Data?

    init(from result: AnalysisResult, imageData: Data?, date: Date = Date()) {
        self.date = date
        self.dishName = result.dishName
        self.items = result.items
        self.totalCalories = result.totalCalories
        self.notes = result.notes
        self.imageData = imageData
    }

    /// Total des macronutriments pour l'affichage.
    var totalProtein: Double { items.reduce(0) { $0 + $1.proteinG } }
    var totalCarbs: Double { items.reduce(0) { $0 + $1.carbsG } }
    var totalFat: Double { items.reduce(0) { $0 + $1.fatG } }
}

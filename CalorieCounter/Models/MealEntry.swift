import Foundation

/// Un repas enregistré dans le journal.
struct MealEntry: Codable, Identifiable {
    var id = UUID()
    var date: Date
    var dishName: String
    var items: [FoodItem]
    /// Miniature JPEG pour le journal (optionnelle).
    var imageData: Data?

    init(dishName: String, items: [FoodItem], imageData: Data?, date: Date = Date()) {
        self.dishName = dishName
        self.items = items
        self.imageData = imageData
        self.date = date
    }

    var totalCalories: Double { items.reduce(0) { $0 + $1.calories } }
    var totalProtein: Double { items.reduce(0) { $0 + $1.protein } }
    var totalCarbs: Double { items.reduce(0) { $0 + $1.carbs } }
    var totalFat: Double { items.reduce(0) { $0 + $1.fat } }
}

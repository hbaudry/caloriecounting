import Foundation
import Combine

/// Stocke le journal des repas et l'objectif calorique quotidien.
/// Persiste dans un fichier JSON du dossier Documents (hors ligne).
@MainActor
final class MealStore: ObservableObject {
    @Published private(set) var meals: [MealEntry] = []
    @Published var dailyGoal: Int {
        didSet { UserDefaults.standard.set(dailyGoal, forKey: Self.goalKey) }
    }

    private static let goalKey = "daily_calorie_goal"

    private var fileURL: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("meals.json")
    }

    init() {
        let storedGoal = UserDefaults.standard.integer(forKey: Self.goalKey)
        self.dailyGoal = storedGoal == 0 ? 2000 : storedGoal
        load()
    }

    // MARK: - Opérations

    func add(_ meal: MealEntry) {
        meals.insert(meal, at: 0)
        save()
    }

    func delete(at offsets: IndexSet) {
        meals.remove(atOffsets: offsets)
        save()
    }

    func delete(_ meal: MealEntry) {
        meals.removeAll { $0.id == meal.id }
        save()
    }

    // MARK: - Calculs pour aujourd'hui

    var todaysMeals: [MealEntry] {
        meals.filter { Calendar.current.isDateInToday($0.date) }
    }

    var todaysTotalCalories: Double {
        todaysMeals.reduce(0) { $0 + $1.totalCalories }
    }

    var todaysRemaining: Double {
        Double(dailyGoal) - todaysTotalCalories
    }

    /// Regroupe les repas par jour, pour l'historique.
    var mealsByDay: [(date: Date, meals: [MealEntry])] {
        let grouped = Dictionary(grouping: meals) { meal in
            Calendar.current.startOfDay(for: meal.date)
        }
        return grouped
            .map { (date: $0.key, meals: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.date > $1.date }
    }

    // MARK: - Persistance

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        if let decoded = try? JSONDecoder().decode([MealEntry].self, from: data) {
            meals = decoded.sorted { $0.date > $1.date }
        }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(meals) else { return }
        try? data.write(to: fileURL, options: [.atomic])
    }
}

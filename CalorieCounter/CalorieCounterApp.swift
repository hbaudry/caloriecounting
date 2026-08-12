import SwiftUI

@main
struct CalorieCounterApp: App {
    @StateObject private var store = MealStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}

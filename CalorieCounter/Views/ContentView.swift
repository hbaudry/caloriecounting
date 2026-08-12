import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            AnalyzeView()
                .tabItem {
                    Label("Analyser", systemImage: "camera.viewfinder")
                }

            HistoryView()
                .tabItem {
                    Label("Journal", systemImage: "list.bullet.rectangle")
                }

            SettingsView()
                .tabItem {
                    Label("Réglages", systemImage: "gearshape")
                }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(MealStore())
}

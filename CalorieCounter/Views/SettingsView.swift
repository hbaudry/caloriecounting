import SwiftUI

/// Réglages : objectif calorique quotidien et informations sur la reconnaissance
/// locale. Aucune clé API n'est nécessaire : tout fonctionne sur l'appareil.
struct SettingsView: View {
    @EnvironmentObject private var store: MealStore
    @State private var goalText: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Objectif quotidien") {
                    HStack {
                        TextField("2000", text: $goalText)
                            .keyboardType(.numberPad)
                        Text("kcal / jour").foregroundStyle(.secondary)
                    }
                    Button("Mettre à jour l'objectif") {
                        if let value = Int(goalText), value > 0 {
                            store.dailyGoal = value
                        }
                    }
                }

                Section {
                    Label("Reconnaissance sur l'appareil (Vision)", systemImage: "cpu")
                    LabeledContent("Aliments en base", value: "\(FoodDatabase.shared.foods.count)")
                    HStack {
                        Label("Modèle Food-101 dédié", systemImage: FoodRecognizer.hasDedicatedModel ? "checkmark.seal.fill" : "seal")
                        Spacer()
                        Text(FoodRecognizer.hasDedicatedModel ? "Actif" : "Classifieur intégré")
                            .foregroundStyle(FoodRecognizer.hasDedicatedModel ? Color.green : Color.secondary)
                            .font(.subheadline)
                    }
                } header: {
                    Text("Fonctionnement")
                } footer: {
                    Text("L'app reconnaît les aliments hors-ligne avec le framework Vision d'Apple, puis estime les calories à partir d'une base locale. Aucune donnée n'est envoyée sur Internet, aucune clé API n'est requise.")
                }
            }
            .navigationTitle("Réglages")
            .onAppear { goalText = String(store.dailyGoal) }
        }
    }
}

#Preview {
    SettingsView().environmentObject(MealStore())
}

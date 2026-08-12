import SwiftUI

/// Réglages : clé API Anthropic (stockée dans le Trousseau) et objectif calorique.
struct SettingsView: View {
    @EnvironmentObject private var store: MealStore

    @State private var apiKey: String = ""
    @State private var isKeySaved = false
    @State private var goalText: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("sk-ant-…", text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    HStack {
                        Button("Enregistrer la clé") {
                            KeychainHelper.saveAPIKey(apiKey.trimmingCharacters(in: .whitespacesAndNewlines))
                            isKeySaved = true
                        }
                        .disabled(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        Spacer()
                        if isKeySaved {
                            Label("Enregistrée", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.caption)
                        }
                    }
                } header: {
                    Text("Clé API Anthropic")
                } footer: {
                    Text("Obtenez une clé sur console.anthropic.com. Elle est stockée de façon sécurisée dans le Trousseau de l'appareil et n'est envoyée qu'à l'API d'Anthropic.")
                }

                Section("Objectif quotidien") {
                    HStack {
                        TextField("2000", text: $goalText)
                            .keyboardType(.numberPad)
                        Text("kcal / jour")
                            .foregroundStyle(.secondary)
                    }
                    Button("Mettre à jour l'objectif") {
                        if let value = Int(goalText), value > 0 {
                            store.dailyGoal = value
                        }
                    }
                }

                Section("Modèle") {
                    LabeledContent("Modèle utilisé", value: ClaudeService.model)
                    Text("Modifiable dans ClaudeService.swift (ex. claude-sonnet-5 ou claude-haiku-4-5 pour réduire les coûts).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button("Supprimer la clé API", role: .destructive) {
                        KeychainHelper.deleteAPIKey()
                        apiKey = ""
                        isKeySaved = false
                    }
                }
            }
            .navigationTitle("Réglages")
            .onAppear {
                apiKey = KeychainHelper.loadAPIKey() ?? ""
                isKeySaved = !apiKey.isEmpty
                goalText = String(store.dailyGoal)
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(MealStore())
}

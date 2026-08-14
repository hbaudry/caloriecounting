import SwiftUI

/// Réglages : objectif calorique quotidien, backend d'analyse IA optionnel
/// (abonnement Claude via votre serveur), et informations sur la
/// reconnaissance sur l'appareil / les sources de données.
struct SettingsView: View {
    @EnvironmentObject private var store: MealStore
    @State private var goalText: String = ""

    // Mêmes clés que BackendConfig (UserDefaults "serverURL" / "serverPassword").
    @AppStorage("serverURL") private var serverURL = ""
    @AppStorage("serverPassword") private var serverPassword = ""
    @State private var status: HealthStatus = .unknown

    enum HealthStatus {
        case unknown, checking, ok, failed(String)
    }

    /// Vrai si l'URL est en HTTP simple vers une adresse non locale : iOS
    /// bloquera la connexion (App Transport Security).
    private var insecurePublicURL: Bool {
        let url = serverURL.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard url.hasPrefix("http://") else { return false }
        let host = url.replacingOccurrences(of: "http://", with: "")
        let localPrefixes = ["localhost", "127.", "192.168.", "10.", "172.16.", "172.17.", "172.18.",
                             "172.19.", "172.2", "172.30.", "172.31."]
        return !localPrefixes.contains(where: { host.hasPrefix($0) })
    }

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
                    TextField("https://calories.mon-domaine.eu", text: $serverURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    SecureField("Mot de passe du serveur", text: $serverPassword)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Button("Tester la connexion") {
                        testConnection()
                    }

                    switch status {
                    case .unknown:
                        EmptyView()
                    case .checking:
                        HStack { ProgressView(); Text("Test en cours…") }
                    case .ok:
                        Label("Connexion réussie", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(Color.green)
                    case .failed(let message):
                        Label(message, systemImage: "xmark.circle.fill")
                            .foregroundStyle(Color.red)
                    }
                } header: {
                    Text("Analyse par IA (backend)")
                } footer: {
                    if insecurePublicURL {
                        Label(
                            "Adresse en http:// vers un serveur non local : iOS bloquera la connexion. Un serveur exposé sur Internet doit être en https://.",
                            systemImage: "exclamationmark.triangle.fill"
                        )
                        .foregroundStyle(Color.orange)
                    } else {
                        Text("Si renseigné, la photo est envoyée à votre serveur qui appelle Claude en vision (analyse plus précise, décomptée de votre abonnement Claude). La photo transite alors par votre serveur et Anthropic. Sinon, l'app utilise la reconnaissance sur l'appareil.")
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
                    Text("Fonctionnement hors-ligne")
                } footer: {
                    Text("Sans backend configuré, l'app reconnaît les aliments hors-ligne avec le framework Vision d'Apple, puis estime les calories à partir d'une base locale. Aucune donnée n'est envoyée sur Internet, aucune clé n'est requise.")
                }

                Section {
                    Text("Valeurs nutritionnelles : table Ciqual 2020 (ANSES), sous Licence Ouverte / Etalab.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Sources")
                }
            }
            .navigationTitle("Réglages")
            .onAppear {
                goalText = String(store.dailyGoal)
            }
        }
    }

    private func testConnection() {
        status = .checking
        Task {
            do {
                guard let base = URL(string: serverURL.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                    status = .failed("URL invalide")
                    return
                }

                // 1. Joignabilité (endpoint ouvert)
                let (_, healthResponse) = try await URLSession.shared.data(
                    from: base.appending(path: "health")
                )
                guard let health = healthResponse as? HTTPURLResponse, health.statusCode == 200 else {
                    status = .failed("Le serveur a répondu avec une erreur")
                    return
                }

                // 2. Mot de passe (endpoint protégé)
                var authRequest = URLRequest(url: base.appending(path: "api/config"))
                if !serverPassword.isEmpty {
                    authRequest.setValue("Bearer \(serverPassword)", forHTTPHeaderField: "Authorization")
                }
                let (_, authResponse) = try await URLSession.shared.data(for: authRequest)
                switch (authResponse as? HTTPURLResponse)?.statusCode {
                case 200:
                    status = .ok
                case 401:
                    status = .failed(serverPassword.isEmpty
                        ? "Serveur joignable, mais un mot de passe est requis"
                        : "Serveur joignable, mais le mot de passe est incorrect")
                default:
                    status = .failed("Le serveur a répondu avec une erreur")
                }
            } catch {
                status = .failed(error.localizedDescription)
            }
        }
    }
}

#Preview {
    SettingsView().environmentObject(MealStore())
}

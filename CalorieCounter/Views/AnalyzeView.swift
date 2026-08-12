import SwiftUI

/// Écran principal : capture de la photo, lancement de l'analyse, affichage du résultat.
struct AnalyzeView: View {
    @EnvironmentObject private var store: MealStore

    @State private var selectedImage: UIImage?
    @State private var result: AnalysisResult?
    @State private var isAnalyzing = false
    @State private var errorMessage: String?
    @State private var showCamera = false
    @State private var showLibrary = false
    @State private var savedConfirmation = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    dailySummaryCard

                    imageCard

                    captureButtons

                    if isAnalyzing {
                        ProgressView("Analyse en cours…")
                            .padding()
                    }

                    if let error = errorMessage {
                        errorBanner(error)
                    }

                    if let result {
                        ResultCard(result: result)
                        saveButton
                    }
                }
                .padding()
            }
            .navigationTitle("Compteur de Calories")
            .sheet(isPresented: $showCamera) {
                ImagePicker(source: .camera) { image in
                    handlePicked(image)
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showLibrary) {
                ImagePicker(source: .library) { image in
                    handlePicked(image)
                }
                .ignoresSafeArea()
            }
        }
    }

    // MARK: - Sous-vues

    private var dailySummaryCard: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Aujourd'hui")
                    .font(.headline)
                Spacer()
                Text("Objectif : \(store.dailyGoal) kcal")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            HStack(alignment: .firstTextBaseline) {
                Text("\(Int(store.todaysTotalCalories))")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                Text("kcal consommées")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            ProgressView(value: min(store.todaysTotalCalories, Double(store.dailyGoal)),
                         total: Double(max(store.dailyGoal, 1)))
                .tint(store.todaysRemaining >= 0 ? .green : .red)
            Text(store.todaysRemaining >= 0
                 ? "Il reste \(Int(store.todaysRemaining)) kcal"
                 : "Dépassement de \(Int(-store.todaysRemaining)) kcal")
                .font(.caption)
                .foregroundStyle(store.todaysRemaining >= 0 ? .secondary : .red)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var imageCard: some View {
        Group {
            if let selectedImage {
                Image(uiImage: selectedImage)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemBackground))
                    .frame(height: 240)
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: "fork.knife")
                                .font(.system(size: 44))
                                .foregroundStyle(.secondary)
                            Text("Prenez une photo de votre assiette")
                                .foregroundStyle(.secondary)
                        }
                    )
            }
        }
    }

    private var captureButtons: some View {
        HStack(spacing: 12) {
            Button {
                showCamera = true
            } label: {
                Label("Appareil photo", systemImage: "camera.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button {
                showLibrary = true
            } label: {
                Label("Galerie", systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    private var saveButton: some View {
        Button {
            saveMeal()
        } label: {
            Label(savedConfirmation ? "Enregistré ✓" : "Ajouter au journal",
                  systemImage: savedConfirmation ? "checkmark.circle.fill" : "plus.circle.fill")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(savedConfirmation ? .green : .accentColor)
        .disabled(savedConfirmation)
    }

    private func errorBanner(_ message: String) -> some View {
        Text(message)
            .font(.callout)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.red.opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Actions

    private func handlePicked(_ image: UIImage) {
        selectedImage = image
        result = nil
        errorMessage = nil
        savedConfirmation = false
        Task { await analyze(image) }
    }

    private func analyze(_ image: UIImage) async {
        isAnalyzing = true
        errorMessage = nil
        defer { isAnalyzing = false }
        do {
            result = try await ClaudeService.analyze(image: image)
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func saveMeal() {
        guard let result else { return }
        let thumbnail = selectedImage?
            .resizedForUpload(maxDimension: 400)
            .jpegData(compressionQuality: 0.6)
        store.add(MealEntry(from: result, imageData: thumbnail))
        savedConfirmation = true
    }
}

#Preview {
    AnalyzeView()
        .environmentObject(MealStore())
}

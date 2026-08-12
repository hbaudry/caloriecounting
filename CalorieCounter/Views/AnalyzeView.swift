import SwiftUI

/// Écran principal : photo → reconnaissance **sur l'appareil** → sélection des
/// aliments et ajustement des portions → ajout au journal.
struct AnalyzeView: View {
    @EnvironmentObject private var store: MealStore

    @State private var selectedImage: UIImage?
    @State private var candidates: [RecognitionCandidate] = []
    @State private var selected: [SelectedEntry] = []
    @State private var isAnalyzing = false
    @State private var didRecognize = false
    @State private var showCamera = false
    @State private var showLibrary = false
    @State private var searchQuery = ""
    @State private var savedConfirmation = false

    private var totalCalories: Double { selected.reduce(0) { $0 + $1.calories } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    dailySummaryCard
                    imageCard
                    captureButtons

                    if isAnalyzing {
                        ProgressView("Analyse sur l'appareil…").padding()
                    }

                    if !candidates.isEmpty {
                        suggestionsSection
                    } else if didRecognize && !isAnalyzing {
                        Text("Aucun aliment reconnu automatiquement. Ajoutez-le à la main ci-dessous.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    manualAddSection

                    if !selected.isEmpty {
                        selectedSection
                        saveButton
                    }
                }
                .padding()
            }
            .navigationTitle("Compteur de Calories")
            .sheet(isPresented: $showCamera) {
                ImagePicker(source: .camera) { handlePicked($0) }.ignoresSafeArea()
            }
            .sheet(isPresented: $showLibrary) {
                ImagePicker(source: .library) { handlePicked($0) }.ignoresSafeArea()
            }
        }
    }

    // MARK: - Résumé du jour

    private var dailySummaryCard: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Aujourd'hui").font(.headline)
                Spacer()
                Text("Objectif : \(store.dailyGoal) kcal")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            HStack(alignment: .firstTextBaseline) {
                Text("\(Int(store.todaysTotalCalories))")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                Text("kcal consommées").font(.subheadline).foregroundStyle(.secondary)
                Spacer()
            }
            ProgressView(value: min(store.todaysTotalCalories, Double(store.dailyGoal)),
                         total: Double(max(store.dailyGoal, 1)))
                .tint(store.todaysRemaining >= 0 ? Color.green : Color.red)
            Text(store.todaysRemaining >= 0
                 ? "Il reste \(Int(store.todaysRemaining)) kcal"
                 : "Dépassement de \(Int(-store.todaysRemaining)) kcal")
                .font(.caption)
                .foregroundStyle(store.todaysRemaining >= 0 ? Color.secondary : Color.red)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Image + capture

    private var imageCard: some View {
        Group {
            if let selectedImage {
                Image(uiImage: selectedImage)
                    .resizable().scaledToFill()
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.secondarySystemBackground))
                    .frame(height: 220)
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: "fork.knife").font(.system(size: 44))
                                .foregroundStyle(.secondary)
                            Text("Photographiez votre assiette")
                                .foregroundStyle(.secondary)
                        }
                    )
            }
        }
    }

    private var captureButtons: some View {
        HStack(spacing: 12) {
            Button { showCamera = true } label: {
                Label("Appareil photo", systemImage: "camera.fill").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button { showLibrary = true } label: {
                Label("Galerie", systemImage: "photo.on.rectangle").frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Suggestions reconnues

    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Aliments détectés").font(.headline)
            FlowLayout(spacing: 8) {
                ForEach(candidates) { candidate in
                    Button {
                        add(candidate.food)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.circle.fill")
                            Text(candidate.food.name)
                            Text("\(Int(candidate.confidence * 100))%")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Color.accentColor.opacity(0.12))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(selected.contains { $0.food.key == candidate.food.key })
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Ajout manuel

    private var manualAddSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Ajouter un aliment (ex. riz, poulet…)", text: $searchQuery)
                    .autocorrectionDisabled()
            }
            .padding(10)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            if !searchQuery.isEmpty {
                let results = FoodDatabase.shared.search(searchQuery).prefix(8)
                if results.isEmpty {
                    Text("Aucun résultat").font(.caption).foregroundStyle(.secondary)
                } else {
                    ForEach(Array(results)) { food in
                        Button {
                            add(food)
                            searchQuery = ""
                        } label: {
                            HStack {
                                Text(food.name)
                                Spacer()
                                Text("\(Int(food.kcal)) kcal/100g")
                                    .font(.caption).foregroundStyle(.secondary)
                                Image(systemName: "plus.circle")
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(.vertical, 4)
                        Divider()
                    }
                }
            }
        }
    }

    // MARK: - Aliments sélectionnés (portions éditables)

    private var selectedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Votre repas").font(.headline)

            ForEach($selected) { $entry in
                VStack(spacing: 6) {
                    HStack {
                        Text(entry.food.name).font(.subheadline.weight(.medium))
                        Spacer()
                        Text("\(Int(entry.calories)) kcal").font(.subheadline)
                        Button {
                            selected.removeAll { $0.id == entry.id }
                        } label: {
                            Image(systemName: "trash").foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                    HStack {
                        Button { entry.grams = max(10, entry.grams - 25) } label: {
                            Image(systemName: "minus.circle.fill").font(.title3)
                        }
                        .buttonStyle(.plain)
                        Text("\(Int(entry.grams)) g")
                            .frame(minWidth: 60)
                            .font(.subheadline.monospacedDigit())
                        Button { entry.grams += 25 } label: {
                            Image(systemName: "plus.circle.fill").font(.title3)
                        }
                        .buttonStyle(.plain)
                        Spacer()
                    }
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
                Divider()
            }

            HStack {
                Text("Total").font(.headline)
                Spacer()
                Text("\(Int(totalCalories)) kcal")
                    .font(.headline).foregroundStyle(Color.accentColor)
            }

            Text("Valeurs indicatives issues d'une base locale.")
                .font(.caption2).foregroundStyle(.tertiary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var saveButton: some View {
        Button { saveMeal() } label: {
            Label(savedConfirmation ? "Enregistré ✓" : "Ajouter au journal",
                  systemImage: savedConfirmation ? "checkmark.circle.fill" : "plus.circle.fill")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(savedConfirmation ? Color.green : Color.accentColor)
        .disabled(savedConfirmation)
    }

    // MARK: - Actions

    private func handlePicked(_ image: UIImage) {
        selectedImage = image
        candidates = []
        selected = []
        didRecognize = false
        savedConfirmation = false
        Task {
            isAnalyzing = true
            candidates = await FoodRecognizer.recognize(image)
            isAnalyzing = false
            didRecognize = true
        }
    }

    private func add(_ food: Food) {
        guard !selected.contains(where: { $0.food.key == food.key }) else { return }
        selected.append(SelectedEntry(food: food, grams: food.defaultGrams))
        savedConfirmation = false
    }

    private func saveMeal() {
        guard !selected.isEmpty else { return }
        let items = selected.map { $0.food.item(grams: $0.grams) }
        let dishName = selected.count == 1 ? selected[0].food.name : "Repas (\(selected.count) aliments)"
        let thumbnail = selectedImage?
            .resizedForUpload(maxDimension: 400)
            .jpegData(compressionQuality: 0.6)
        store.add(MealEntry(dishName: dishName, items: items, imageData: thumbnail))
        savedConfirmation = true
    }
}

#Preview {
    AnalyzeView().environmentObject(MealStore())
}

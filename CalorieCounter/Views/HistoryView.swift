import SwiftUI

/// Journal des repas, regroupés par jour avec le total quotidien.
struct HistoryView: View {
    @EnvironmentObject private var store: MealStore

    var body: some View {
        NavigationStack {
            Group {
                if store.meals.isEmpty {
                    ContentUnavailableView(
                        "Aucun repas enregistré",
                        systemImage: "list.bullet.rectangle",
                        description: Text("Analysez une assiette puis ajoutez-la au journal.")
                    )
                } else {
                    List {
                        ForEach(store.mealsByDay, id: \.date) { day in
                            Section {
                                ForEach(day.meals) { meal in
                                    MealRow(meal: meal)
                                }
                                .onDelete { offsets in
                                    delete(day: day, offsets: offsets)
                                }
                            } header: {
                                HStack {
                                    Text(day.date, format: .dateTime.weekday(.wide).day().month())
                                    Spacer()
                                    Text("\(Int(day.meals.reduce(0) { $0 + $1.totalCalories })) kcal")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Journal")
        }
    }

    private func delete(day: (date: Date, meals: [MealEntry]), offsets: IndexSet) {
        for index in offsets {
            store.delete(day.meals[index])
        }
    }
}

/// Ligne d'un repas dans le journal.
struct MealRow: View {
    let meal: MealEntry

    var body: some View {
        HStack(spacing: 12) {
            if let data = meal.imageData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.tertiarySystemFill))
                    .frame(width: 52, height: 52)
                    .overlay(Image(systemName: "fork.knife").foregroundStyle(.secondary))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(meal.dishName)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Text(meal.date, format: .dateTime.hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(Int(meal.totalCalories)) kcal")
                .font(.subheadline.weight(.semibold))
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    HistoryView()
        .environmentObject(MealStore())
}

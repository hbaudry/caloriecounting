import SwiftUI

/// Carte affichant le détail d'une analyse : plat, aliments, macros et total.
struct ResultCard: View {
    let result: AnalysisResult

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(result.dishName)
                    .font(.title3.bold())
                Spacer()
                confidenceBadge
            }

            Divider()

            ForEach(result.items) { item in
                foodRow(item)
            }

            Divider()

            HStack {
                Text("Total")
                    .font(.headline)
                Spacer()
                Text("\(Int(result.totalCalories)) kcal")
                    .font(.headline)
                    .foregroundStyle(Color.accentColor)
            }

            macroSummary

            if !result.notes.isEmpty {
                Text(result.notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("Estimations approximatives générées par IA.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var confidenceBadge: some View {
        Text("Confiance : \(result.confidence.label)")
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(badgeColor.opacity(0.2))
            .foregroundStyle(badgeColor)
            .clipShape(Capsule())
    }

    private var badgeColor: Color {
        switch result.confidence {
        case .high: return .green
        case .medium: return .orange
        case .low: return .red
        }
    }

    private func foodRow(_ item: FoodItem) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(item.name)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text("\(Int(item.calories)) kcal")
                    .font(.subheadline)
            }
            Text("~\(Int(item.estimatedGrams)) g · P \(Int(item.proteinG))g · G \(Int(item.carbsG))g · L \(Int(item.fatG))g")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var macroSummary: some View {
        let protein = result.items.reduce(0) { $0 + $1.proteinG }
        let carbs = result.items.reduce(0) { $0 + $1.carbsG }
        let fat = result.items.reduce(0) { $0 + $1.fatG }
        return HStack(spacing: 12) {
            macroPill("Protéines", Int(protein), .blue)
            macroPill("Glucides", Int(carbs), .orange)
            macroPill("Lipides", Int(fat), .purple)
        }
    }

    private func macroPill(_ title: String, _ grams: Int, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text("\(grams) g")
                .font(.subheadline.bold())
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

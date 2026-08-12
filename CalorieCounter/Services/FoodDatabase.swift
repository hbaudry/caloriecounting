import Foundation

/// Base de données locale des aliments (chargée depuis `FoodDatabase.json`
/// embarqué dans l'app). Fonctionne entièrement hors-ligne.
final class FoodDatabase {
    static let shared = FoodDatabase()

    let foods: [Food]

    private init() {
        if let url = Bundle.main.url(forResource: "FoodDatabase", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let decoded = try? JSONDecoder().decode([Food].self, from: data) {
            foods = decoded.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        } else {
            foods = []
        }
    }

    /// Tente d'associer un libellé de reconnaissance (souvent en anglais) à un
    /// aliment de la base, via ses termes clés et alias.
    func match(identifier: String) -> Food? {
        let needle = Self.normalize(identifier)
        guard !needle.isEmpty else { return nil }

        // On privilégie la correspondance la plus « spécifique » (terme le plus long).
        var best: (food: Food, length: Int)?
        for food in foods {
            for term in food.searchTerms {
                let t = Self.normalize(term)
                guard !t.isEmpty else { continue }
                if needle.contains(t) || t.contains(needle) {
                    if best == nil || t.count > best!.length {
                        best = (food, t.count)
                    }
                }
            }
        }
        return best?.food
    }

    /// Recherche textuelle pour l'ajout manuel.
    func search(_ query: String) -> [Food] {
        let q = Self.normalize(query)
        guard !q.isEmpty else { return [] }
        return foods.filter { food in
            food.searchTerms.contains { Self.normalize($0).contains(q) }
        }
    }

    /// Normalise une chaîne : minuscules + suppression des accents.
    static func normalize(_ s: String) -> String {
        s.folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension Food {
    /// Tous les termes utilisables pour la correspondance / recherche.
    var searchTerms: [String] {
        [name, key] + (aliases ?? [])
    }
}

import Foundation

/// Base de données locale des aliments (100 % hors-ligne).
///
/// Deux ensembles :
/// - **`recognitionFoods`** (`FoodDatabase.json`) : aliments alignés sur les
///   classes du modèle de reconnaissance (portions et clés soignées). Utilisé
///   pour associer un résultat de reconnaissance à des calories.
/// - **`libraryFoods`** (`FoodLibrary.json`) : grande base **CIQUAL 2020**
///   (ANSES, licence ouverte), ~2300 aliments français. Utilisée pour la
///   recherche / l'ajout manuel.
final class FoodDatabase {
    static let shared = FoodDatabase()

    let recognitionFoods: [Food]
    let libraryFoods: [Food]
    /// Ensemble complet (reconnaissance + bibliothèque) pour la recherche.
    let foods: [Food]

    private init() {
        let recognition = Self.load("FoodDatabase")
        let library = Self.load("FoodLibrary")
        recognitionFoods = recognition
        libraryFoods = library
        foods = recognition + library
    }

    private static func load(_ resource: String) -> [Food] {
        guard let url = Bundle.main.url(forResource: resource, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([Food].self, from: data) else {
            return []
        }
        return decoded
    }

    /// Associe un libellé de reconnaissance à un aliment — **uniquement** dans le
    /// jeu de reconnaissance, pour rester précis (la bibliothèque CIQUAL, très
    /// vaste, produirait trop de correspondances parasites).
    func match(identifier: String) -> Food? {
        let needle = Self.normalize(identifier)
        guard !needle.isEmpty else { return nil }

        var best: (food: Food, length: Int)?
        for food in recognitionFoods {
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

    /// Recherche textuelle sur tout le catalogue (reconnaissance + CIQUAL).
    /// Classe en tête les préfixes exacts puis les noms les plus courts.
    func search(_ query: String) -> [Food] {
        let q = Self.normalize(query)
        guard !q.isEmpty else { return [] }

        var results: [(food: Food, prefix: Bool, length: Int)] = []
        for food in foods {
            let terms = food.searchTerms.map(Self.normalize)
            guard terms.contains(where: { $0.contains(q) }) else { continue }
            let isPrefix = terms.contains { $0.hasPrefix(q) }
            results.append((food, isPrefix, Self.normalize(food.name).count))
        }
        results.sort {
            if $0.prefix != $1.prefix { return $0.prefix && !$1.prefix }
            if $0.length != $1.length { return $0.length < $1.length }
            return $0.food.name.localizedCaseInsensitiveCompare($1.food.name) == .orderedAscending
        }
        return results.map(\.food)
    }

    /// Normalise une chaîne : minuscules, sans accents, underscores/tirets → espaces.
    static func normalize(_ s: String) -> String {
        s.folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension Food {
    /// Tous les termes utilisables pour la correspondance / recherche.
    var searchTerms: [String] {
        [name, key] + (aliases ?? [])
    }
}

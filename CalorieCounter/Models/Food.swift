import Foundation

/// Un aliment de la base locale, avec ses valeurs nutritionnelles **pour 100 g**.
/// C'est la source « autonome » des calories : aucune requête réseau n'est faite.
struct Food: Codable, Identifiable, Equatable {
    var id: String { key }
    /// Identifiant technique (anglais) servant à la correspondance avec les
    /// libellés renvoyés par la reconnaissance d'image sur l'appareil.
    let key: String
    /// Nom affiché en français.
    let name: String
    /// Termes alternatifs pour améliorer la reconnaissance et la recherche.
    let aliases: [String]?
    let kcal: Double        // pour 100 g
    let protein: Double     // g pour 100 g
    let carbs: Double       // g pour 100 g
    let fat: Double         // g pour 100 g
    /// Portion typique en grammes (valeur de départ ajustable par l'utilisateur).
    let defaultGrams: Double

    /// Construit une portion concrète (aliment + quantité) pour un repas.
    func item(grams: Double) -> FoodItem {
        let factor = grams / 100.0
        return FoodItem(
            name: name,
            grams: grams,
            calories: (kcal * factor).rounded(),
            protein: protein * factor,
            carbs: carbs * factor,
            fat: fat * factor
        )
    }
}

/// Une portion d'aliment enregistrée dans un repas.
struct FoodItem: Codable, Identifiable {
    var id = UUID()
    var name: String
    var grams: Double
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
}

/// Un aliment sélectionné en cours d'édition, avec sa quantité réglable.
struct SelectedEntry: Identifiable {
    let id = UUID()
    let food: Food
    var grams: Double

    var calories: Double { (food.kcal * grams / 100.0).rounded() }
}

/// Un candidat proposé par la reconnaissance d'image on-device.
struct RecognitionCandidate: Identifiable {
    let id = UUID()
    let food: Food
    let confidence: Double
}

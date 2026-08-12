# Compteur de Calories 🍽️ (100 % sur l'appareil)

Application iPhone (SwiftUI) qui **estime les calories d'un repas à partir d'une photo de l'assiette**, **entièrement hors-ligne** : la reconnaissance des aliments se fait **sur l'appareil** (framework Vision / Core ML d'Apple) et les calories proviennent d'une **base locale embarquée**.

> Pas de clé API, pas de connexion Internet, pas de coût par requête. Autonome.

## Fonctionnalités

- 📸 Prise de photo (appareil) ou choix depuis la galerie
- 🧠 Reconnaissance d'aliments **on-device** via le framework Vision d'Apple
- 🍚 Base calorique locale (136 aliments : 101 plats Food-101 + génériques) — calories et macros par 100 g
- ➕ Ajustement des portions (grammes) + ajout manuel par recherche
- 📊 Suivi du total calorique du jour avec objectif personnalisable
- 📖 Journal des repas regroupés par jour (persistance locale)

## Prérequis

- **Xcode 16** ou plus récent
- **iOS 17+** ; l'appareil photo nécessite un iPhone réel (la galerie fonctionne sur simulateur)
- Aucune clé API, aucun compte

## Installation

1. Ouvrez `CalorieCounter.xcodeproj` dans Xcode.
2. Cible **CalorieCounter** → *Signing & Capabilities* → choisissez votre équipe (Team). Ajustez le *Bundle Identifier* si besoin.
3. Lancez (`⌘R`) sur votre iPhone ou un simulateur.
4. Onglet **Analyser** → photographiez votre assiette → les aliments détectés s'affichent → ajoutez-les, réglez les portions → *Ajouter au journal*.

## Architecture

```
CalorieCounter/
├── CalorieCounterApp.swift       # Point d'entrée
├── FoodDatabase.json             # Base calorique locale embarquée
├── Models/                       # Food, FoodItem, MealEntry, RecognitionCandidate
├── Services/
│   ├── FoodRecognizer.swift      # Reconnaissance on-device (Vision / Core ML)
│   ├── FoodDatabase.swift        # Chargement + correspondance / recherche
│   └── UIImage+Resize.swift      # Utilitaire d'image
├── Store/
│   └── MealStore.swift           # Journal des repas (persistance JSON) + objectif
└── Views/                        # Interface SwiftUI (Analyser / Journal / Réglages)
```

## Comment ça marche

1. La photo est passée au framework **Vision** d'Apple.
   - Par défaut : `VNClassifyImageRequest`, le classifieur d'images intégré à iOS
     (un modèle Core ML fourni par le système — rien à installer).
   - Si vous ajoutez un modèle Core ML dédié aux aliments, il est utilisé à la place.
2. Les libellés reconnus sont associés à la **base locale** (`FoodDatabase.json`).
3. Vous confirmez les aliments et réglez les portions ; les calories sont
   calculées localement (valeurs pour 100 g × grammes).

Aucune donnée ne quitte l'appareil.

## Améliorer la précision : créer le modèle de reconnaissance

Le classifieur intégré d'iOS est généraliste. Pour une reconnaissance
spécifiquement alimentaire, le dossier **`Tools/`** contient tout le nécessaire
pour construire un modèle **Food-101** dédié :

```bash
bash Tools/download_food101.sh                                   # jeu de données
swift Tools/TrainFoodClassifier.swift Tools/food-101/images FoodClassifier.mlmodel
```

Glissez ensuite `FoodClassifier.mlmodel` dans le dossier `CalorieCounter` du
projet : `FoodRecognizer` le détecte et l'utilise automatiquement. Les 101
classes correspondent déjà aux clés de `FoodDatabase.json`. Détails complets
dans [`Tools/README.md`](Tools/README.md).

> Un modèle Core ML se construit sur un Mac (framework CreateML). L'app
> fonctionne sans lui grâce au classifieur intégré d'iOS.

## Note importante

Les valeurs nutritionnelles sont des **estimations** basées sur des moyennes par
aliment et sur la portion que vous indiquez. À utiliser comme repère indicatif,
pas comme mesure médicale.

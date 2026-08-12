# Compteur de Calories 🍽️

Application iPhone (SwiftUI) qui **estime les calories d'un repas à partir d'une photo de l'assiette**, grâce à l'API vision de Claude (Anthropic).

## Fonctionnalités

- 📸 Prise de photo (appareil) ou choix depuis la galerie
- 🤖 Analyse par IA : identification des aliments, estimation des grammes, calories et macronutriments (protéines / glucides / lipides)
- 📊 Suivi du total calorique du jour avec objectif personnalisable
- 📖 Journal des repas regroupés par jour (persistance locale hors ligne)
- 🔐 Clé API stockée de façon sécurisée dans le Trousseau (Keychain)

## Prérequis

- **Xcode 16** ou plus récent
- Un iPhone (l'appareil photo nécessite un appareil réel ; la galerie fonctionne sur simulateur) sous **iOS 17+**
- Une **clé API Anthropic** — à obtenir sur [console.anthropic.com](https://console.anthropic.com)

## Installation

1. Ouvrez `CalorieCounter.xcodeproj` dans Xcode.
2. Sélectionnez la cible **CalorieCounter**, onglet *Signing & Capabilities*, et choisissez votre équipe de développement (Team). Changez si besoin le *Bundle Identifier* (`com.example.CalorieCounter`).
3. Branchez votre iPhone (ou choisissez un simulateur) et lancez (`⌘R`).
4. Dans l'app, allez dans **Réglages** et collez votre clé API, puis enregistrez.
5. Onglet **Analyser** → prenez une photo de votre assiette → l'estimation s'affiche → *Ajouter au journal*.

## Architecture

```
CalorieCounter/
├── CalorieCounterApp.swift      # Point d'entrée
├── Models/                      # AnalysisResult, FoodItem, MealEntry
├── Services/
│   ├── ClaudeService.swift      # Appel HTTP à l'API Messages (vision + sortie structurée)
│   └── KeychainHelper.swift     # Stockage sécurisé de la clé API
├── Store/
│   └── MealStore.swift          # Journal des repas (persistance JSON) + objectif
└── Views/                       # Interface SwiftUI (onglets Analyser / Journal / Réglages)
```

## Comment ça marche

L'app envoie la photo (redimensionnée à 1024 px, en JPEG base64) à l'endpoint
`POST https://api.anthropic.com/v1/messages` avec un bloc image. Une **sortie
structurée** (`output_config.format` avec un `json_schema`) garantit une réponse
JSON directement décodable en `AnalysisResult`.

Swift n'ayant pas de SDK Anthropic officiel, l'appel se fait en HTTP brut via
`URLSession` — l'approche recommandée dans ce cas.

## Choix du modèle

Par défaut : **`claude-opus-5`** (meilleure précision). Pour réduire les coûts sur
un usage fréquent, remplacez `ClaudeService.model` dans
`CalorieCounter/Services/ClaudeService.swift` par :

- `claude-sonnet-5` — bon compromis qualité / prix
- `claude-haiku-4-5` — le plus économique

## Note importante

Les valeurs nutritionnelles sont des **estimations générées par IA** à partir
d'une image. Elles peuvent varier sensiblement selon l'angle, la lumière et les
portions réelles. À utiliser comme repère indicatif, pas comme mesure médicale.

## Confidentialité

- La clé API ne quitte l'appareil que pour appeler l'API d'Anthropic.
- Les photos sont envoyées à l'API d'Anthropic pour analyse ; le journal (photos
  miniatures + résultats) reste stocké localement sur l'appareil.

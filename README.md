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
   - Par défaut : le **modèle Food-101 dédié** inclus (`FoodClassifier.mlpackage`).
   - Repli automatique sur `VNClassifyImageRequest` (classifieur intégré à iOS)
     si le modèle dédié est absent.
2. Les libellés reconnus sont associés à la **base locale** (`FoodDatabase.json`).
3. Vous confirmez les aliments et réglez les portions ; les calories sont
   calculées localement (valeurs pour 100 g × grammes).

Aucune donnée ne quitte l'appareil.

## Modèle de reconnaissance dédié (inclus)

Le projet **inclut** un modèle Food-101 dédié :
`CalorieCounter/FoodClassifier.mlpackage`. `FoodRecognizer` le détecte et
l'utilise automatiquement ; les 101 classes correspondent aux clés de
`FoodDatabase.json`. Les Réglages indiquent « Modèle Food-101 dédié : Actif ».

- **Origine** : ViT (`nateraw/vit-base-food101` sur Hugging Face), converti en
  Core ML (script `Tools/convert_vit_to_coreml.py`).
- **Précision FP16 (~165 Mo)** — pour les appareils récents (ex. **iPhone 17
  Pro Max**, puce A19 Pro) : meilleure exactitude, exécution sur le **Neural
  Engine** (`computeUnits = .all`). Versionné via **Git LFS** (fichier > 100 Mo).
- **Repli** : si le modèle est retiré, l'app bascule sur le classifieur d'images
  intégré à iOS (généraliste), donc elle fonctionne dans tous les cas.

> **Git LFS** : ce dépôt stocke le poids du modèle via Git LFS. Installez-le
> avant de cloner (`git lfs install`), sinon vous ne récupérerez qu'un pointeur.

> ⚠️ Vérifiez les conditions de licence du modèle et du jeu de données Food-101
> avant toute distribution commerciale.

### Reconstruire / remplacer le modèle

- **FP16 (défaut, appareils récents)** :
  ```bash
  python3 Tools/convert_vit_to_coreml.py
  ```
- **Quantifié 8 bits (~83 Mo, sans Git LFS)** :
  ```bash
  python3 Tools/convert_vit_to_coreml.py --int8
  ```
- **Entraîner le vôtre** (sur Mac, plus précis) : voir
  [`Tools/README.md`](Tools/README.md) (téléchargement Food-101 + Create ML).

Si vous entraînez un modèle avec d'autres classes, alignez leurs noms sur les
clés `key` de `FoodDatabase.json`.

## Note importante

Les valeurs nutritionnelles sont des **estimations** basées sur des moyennes par
aliment et sur la portion que vous indiquez. À utiliser comme repère indicatif,
pas comme mesure médicale.

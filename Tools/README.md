# Créer le modèle de reconnaissance (`FoodClassifier.mlmodel`)

L'app fonctionne **sans** ce modèle : par défaut, elle utilise le classifieur
d'images généraliste intégré à iOS (Vision). Ce dossier permet de créer un
**modèle dédié aux aliments** (jeu Food-101, 101 plats) pour une bien meilleure
précision. `FoodRecognizer` le détecte et l'utilise automatiquement s'il est
présent dans l'app.

> ⚠️ Un modèle Core ML se construit **sur un Mac** (framework CreateML / Xcode).

## Étapes

### 1. Télécharger le jeu de données (~5 Go)

```bash
cd Tools
bash download_food101.sh
# → crée food-101/images/<classe>/*.jpg (101 classes)
```

### 2. Entraîner et exporter le modèle

```bash
# depuis la racine du dépôt
swift Tools/TrainFoodClassifier.swift Tools/food-101/images FoodClassifier.mlmodel
```

Le script utilise le transfer learning (extracteur « scenePrint » d'Apple) :
l'entraînement est relativement rapide et le `.mlmodel` obtenu reste léger
(quelques Mo). Augmentez `maxIterations` dans le script pour plus de précision.

> Alternative sans ligne de commande : ouvrez l'app **Create ML** (Xcode →
> *Open Developer Tool* → *Create ML*), créez un projet *Image Classification*,
> glissez le dossier `food-101/images`, entraînez, puis exportez le `.mlmodel`.

### 3. Ajouter le modèle au projet

Glissez `FoodClassifier.mlmodel` dans le dossier **`CalorieCounter`** du projet
Xcode (il sera inclus automatiquement dans la cible). Xcode le compile en
`FoodClassifier.mlmodelc` ; l'app le charge au démarrage.

C'est tout — la reconnaissance utilise désormais le modèle Food-101.

## Correspondance avec la base calorique

Les 101 classes de Food-101 (voir `food101_labels.txt`) correspondent aux clés
`key` de `CalorieCounter/FoodDatabase.json`. Chaque plat reconnu est donc
associé à ses calories. Si vous entraînez un modèle avec **d'autres** classes,
ajoutez les entrées correspondantes dans `FoodDatabase.json` (la clé `key` doit
égaler le nom de la classe du modèle).

## Fichiers

- `download_food101.sh` — télécharge et décompresse Food-101
- `TrainFoodClassifier.swift` — entraîne et exporte le modèle (CreateML)
- `food101_labels.txt` — les 101 étiquettes de classes attendues

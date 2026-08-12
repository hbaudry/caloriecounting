#!/usr/bin/env swift
//
//  TrainFoodClassifier.swift
//
//  Entraîne un classifieur d'images d'aliments (transfer learning) à partir d'un
//  dossier d'images organisé par classe, et exporte « FoodClassifier.mlmodel ».
//
//  ⚠️  À exécuter sur un Mac (le framework CreateML est macOS uniquement) :
//
//      swift Tools/TrainFoodClassifier.swift food-101/images FoodClassifier.mlmodel
//
//  Le dossier d'entrée doit contenir un sous-dossier par classe, dont le NOM
//  sert d'étiquette (ex. food-101/images/pizza/*.jpg). Ces noms de classes
//  doivent correspondre aux clés « key » de CalorieCounter/FoodDatabase.json
//  (c'est le cas pour Food-101 : voir Tools/food101_labels.txt).
//
//  Le modèle utilise l'extracteur de caractéristiques « scenePrint » d'Apple :
//  le fichier .mlmodel exporté reste léger (quelques Mo) et tourne sur l'appareil.

#if canImport(CreateML)
import CreateML
import Foundation

let args = CommandLine.arguments
let datasetPath = args.count > 1 ? args[1] : "food-101/images"
let outputPath  = args.count > 2 ? args[2] : "FoodClassifier.mlmodel"

let dataURL = URL(fileURLWithPath: datasetPath)
guard FileManager.default.fileExists(atPath: dataURL.path) else {
    FileHandle.standardError.write(Data("Dossier introuvable : \(datasetPath)\n".utf8))
    exit(1)
}

print("Chargement des images depuis \(datasetPath)…")
let source = MLImageClassifier.DataSource.labeledDirectories(at: dataURL)

// Augmentation légère pour améliorer la robustesse. Augmentez maxIterations
// pour une meilleure précision (au prix d'un temps d'entraînement plus long).
let params = MLImageClassifier.ModelParameters(
    validation: .split(strategy: .automatic),
    maxIterations: 25,
    augmentation: [.flip, .rotation],
    algorithm: .transferLearning(featureExtractor: .scenePrint(revision: 2),
                                 classifier: .logisticRegressor)
)

print("Entraînement en cours (cela peut prendre du temps)…")
let classifier = try MLImageClassifier(trainingData: source, parameters: params)

if let validation = classifier.validationMetrics.classificationError as Double? {
    print(String(format: "Erreur de validation : %.1f %%", validation * 100))
}

let metadata = MLModelMetadata(
    author: "Compteur de Calories",
    shortDescription: "Classifieur d'aliments (Food-101) pour l'estimation des calories.",
    version: "1.0"
)

try classifier.write(to: URL(fileURLWithPath: outputPath), metadata: metadata)
print("Modèle exporté : \(outputPath)")
print("Glissez ce fichier dans le dossier « CalorieCounter » du projet Xcode.")

#else
import Foundation
FileHandle.standardError.write(Data("CreateML n'est disponible que sur macOS.\n".utf8))
exit(1)
#endif

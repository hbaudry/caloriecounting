"""
Convertit un modèle Hugging Face ViT affiné sur Food-101 en Core ML.

    python3 Tools/convert_vit_to_coreml.py            # FP16 (défaut, meilleure exactitude)
    python3 Tools/convert_vit_to_coreml.py --int8     # quantifié 8 bits (~2x plus petit)

Le FP16 (~165 Mo) est recommandé pour les appareils récents (ex. iPhone 17 Pro Max)
qui disposent d'un Neural Engine puissant et de stockage confortable ; nécessite
Git LFS pour le versionner. Le 8 bits (~83 Mo) tient sous la limite GitHub de 100 Mo.

Nécessite : torch, transformers, coremltools, pillow, numpy.
"""
import sys, torch, torch.nn as nn
from transformers import ViTForImageClassification
import coremltools as ct
import coremltools.optimize.coreml as cto

MODEL_ID = "nateraw/vit-base-food101"
OUT = "CalorieCounter/FoodClassifier.mlpackage"
INT8 = "--int8" in sys.argv

print("Chargement du modèle…")
model = ViTForImageClassification.from_pretrained(MODEL_ID).eval()
id2label = model.config.id2label
labels = [id2label[i] for i in range(len(id2label))]
print("labels:", len(labels), labels[:4])

class Wrapper(nn.Module):
    def __init__(self, m):
        super().__init__()
        self.m = m
    def forward(self, x):
        return torch.softmax(self.m(x).logits, dim=1)

traced = torch.jit.trace(Wrapper(model).eval(), torch.rand(1, 3, 224, 224), strict=False)

# ViT normalise avec mean=std=0.5 : (x/255 - 0.5)/0.5 = x/127.5 - 1
scale, bias = 1.0 / 127.5, [-1.0, -1.0, -1.0]

print("Conversion Core ML (FP16)…")
mlmodel = ct.convert(
    traced,
    inputs=[ct.ImageType(name="image", shape=(1, 3, 224, 224),
                         scale=scale, bias=bias, color_layout=ct.colorlayout.RGB)],
    classifier_config=ct.ClassifierConfig(labels),
    minimum_deployment_target=ct.target.iOS16,
    compute_precision=ct.precision.FLOAT16,
    convert_to="mlprogram",
)
mlmodel.short_description = "Classifieur d'aliments Food-101 (ViT) pour l'estimation des calories."
mlmodel.author = "Compteur de Calories"
mlmodel.version = "1.0"

if INT8:
    print("Quantification 8-bit…")
    cfg = cto.OptimizationConfig(
        global_config=cto.OpLinearQuantizerConfig(mode="linear_symmetric", dtype="int8"))
    mlmodel = cto.linear_quantize_weights(mlmodel, cfg)

mlmodel.save(OUT)
print("Enregistré:", OUT, "(int8)" if INT8 else "(FP16)")

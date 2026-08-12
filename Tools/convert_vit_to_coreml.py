import json, torch, torch.nn as nn
from transformers import ViTForImageClassification
import coremltools as ct
import coremltools.optimize.coreml as cto

MODEL_ID = "nateraw/vit-base-food101"
OUT = "CalorieCounter/FoodClassifier.mlpackage"

print("Chargement du modèle…")
model = ViTForImageClassification.from_pretrained(MODEL_ID)
model.eval()

id2label = model.config.id2label
labels = [id2label[i] for i in range(len(id2label))]
print("labels:", len(labels), labels[:4])

class Wrapper(nn.Module):
    def __init__(self, m):
        super().__init__()
        self.m = m
    def forward(self, x):
        return torch.softmax(self.m(x).logits, dim=1)

wrapped = Wrapper(model).eval()
example = torch.rand(1, 3, 224, 224)
print("Traçage…")
traced = torch.jit.trace(wrapped, example, strict=False)

# ViT normalise avec mean=std=0.5 : (x/255 - 0.5)/0.5 = x/127.5 - 1
scale = 1.0 / 127.5
bias = [-1.0, -1.0, -1.0]

print("Conversion Core ML…")
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

print("Quantification 8-bit…")
op_config = cto.OpLinearQuantizerConfig(mode="linear_symmetric", dtype="int8")
config = cto.OptimizationConfig(global_config=op_config)
compressed = cto.linear_quantize_weights(mlmodel, config)

compressed.save(OUT)
print("Enregistré:", OUT)

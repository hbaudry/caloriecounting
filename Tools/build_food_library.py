"""
Construit CalorieCounter/FoodLibrary.json à partir de la table Ciqual 2020
(ANSES, Licence Ouverte / Etalab). ~2300 aliments français, valeurs pour 100 g.

    # 1. Télécharger la table Ciqual au format XML (zip)
    curl -sSL -o ciqual.zip \
      "https://ciqual.anses.fr/cms/sites/default/files/inline-files/XML_2020_07_07.zip"
    # 2. Générer la bibliothèque
    python3 Tools/build_food_library.py ciqual.zip

Codes des constituants Ciqual : 328 = énergie (kcal/100 g), 25000 = protéines,
31000 = glucides, 40000 = lipides.
"""
import zipfile, re, json, sys, os

ZIP = sys.argv[1] if len(sys.argv) > 1 else "ciqual.zip"
OUT = "CalorieCounter/FoodLibrary.json"
KCAL, PROT, CARB, FAT = "328", "25000", "31000", "40000"

z = zipfile.ZipFile(ZIP)
def load(prefix):
    return z.read([x for x in z.namelist() if x.startswith(prefix)][0]).decode("latin-1", errors="replace")

names = {}
for b in re.findall(r"<ALIM>(.*?)</ALIM>", load("alim_"), re.S):
    code = re.search(r"<alim_code>\s*(\d+)\s*</alim_code>", b)
    nom = re.search(r"<alim_nom_fr>(.*?)</alim_nom_fr>", b)
    if code and nom:
        names[code.group(1)] = re.sub(r"\s+", " ", nom.group(1)).strip()

data = {}
for b in re.findall(r"<COMPO>(.*?)</COMPO>", load("compo_"), re.S):
    a = re.search(r"<alim_code>\s*(\d+)\s*</alim_code>", b)
    cst = re.search(r"<const_code>\s*(\d+)\s*</const_code>", b)
    t = re.search(r"<teneur>(.*?)</teneur>", b)
    if a and cst and t:
        data.setdefault(a.group(1), {})[cst.group(1)] = t.group(1)

def val(s):
    if s is None:
        return None
    s = s.strip()
    if s in ("-", "", "NC"):
        return None
    if s.lower() == "traces":
        return 0.0
    if s.startswith("<"):
        s = s[1:].strip()
    try:
        return round(float(s.replace(",", ".")), 1)
    except ValueError:
        return None

lib = []
for code, comps in data.items():
    kcal = val(comps.get(KCAL))
    name = names.get(code)
    if kcal is None or not name:
        continue
    lib.append({
        "key": "ciqual_" + code,
        "name": name,
        "aliases": None,
        "kcal": kcal,
        "protein": val(comps.get(PROT)) or 0.0,
        "carbs": val(comps.get(CARB)) or 0.0,
        "fat": val(comps.get(FAT)) or 0.0,
        "defaultGrams": 100,
    })

lib.sort(key=lambda x: x["name"].lower())
with open(OUT, "w", encoding="utf-8") as f:
    json.dump(lib, f, ensure_ascii=False, separators=(",", ":"))
print(f"{OUT} : {len(lib)} aliments ({round(os.path.getsize(OUT)/1024)} Ko)")

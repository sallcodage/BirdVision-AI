from ultralytics import RTDETR
from pathlib import Path

# ==========================
# CHEMINS DU PROJET
# ==========================

BASE_DIR = Path(__file__).resolve().parent.parent

MODEL_PATH = BASE_DIR / "models" / "rtdetr-x.pt"
IMAGE_PATH = BASE_DIR / "test_images" / "oiseau.jpg"
RESULTS_DIR = BASE_DIR / "results"


# ==========================
# CHARGEMENT DU MODÈLE
# ==========================

print("Chargement de RT-DETR...")

model = RTDETR(str(MODEL_PATH))

print("RT-DETR chargé avec succès !")


# ==========================
# DÉTECTION
# ==========================

print("Analyse de l'image...")

results = model.predict(
    source=str(IMAGE_PATH),
    conf=0.25,
    save=True,
    project=str(RESULTS_DIR),
    name="detection"
)


# ==========================
# RÉSULTATS
# ==========================

for result in results:

    nombre_objets = len(result.boxes)

    print(f"Nombre d'objets détectés : {nombre_objets}")

    for box in result.boxes:

        classe_id = int(box.cls[0])
        confiance = float(box.conf[0])

        nom_classe = model.names[classe_id]

        print(
            f"Objet : {nom_classe} | "
            f"Confiance : {confiance:.2%}"
        )


print("Détection terminée !")
print(f"Résultat enregistré dans : {RESULTS_DIR}")

from pathlib import Path
from rfdetr import RFDETRSmall
from PIL import Image

# Image à analyser
image_path = Path("../test_images/oiseau.jpg")

if not image_path.exists():
    raise FileNotFoundError(f"Image introuvable : {image_path.resolve()}")

print(f"Image utilisée : {image_path.resolve()}")

# Charger le modèle préentraîné
model = RFDETRSmall()

print("Modèle chargé. Détection en cours...")

# Effectuer la détection
detections = model.predict(str(image_path), threshold=0.5)

# Afficher les résultats
print("\nRésultats de la détection :")
print(detections)

print("\nTest terminé.")

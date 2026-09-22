
from pathlib import Path
import uuid

import cv2

from django.conf import settings
from rest_framework.decorators import api_view
from rest_framework.response import Response
from rest_framework import status

from ultralytics import RTDETR


# ============================================
# MODÈLE RT-DETR
# ============================================

PROJECT_ROOT = Path(settings.BASE_DIR).parent

MODEL_PATH = PROJECT_ROOT / "models" / "rtdetr-x.pt"

print("Chargement de RT-DETR-X...")

model = RTDETR(str(MODEL_PATH))

print("RT-DETR-X chargé avec succès !")


# ============================================
# API DE DÉTECTION
# ============================================

@api_view(["POST"])
def detect_birds(request):

    image = request.FILES.get("image")

    if image is None:
        return Response(
            {"error": "Aucune image fournie."},
            status=status.HTTP_400_BAD_REQUEST
        )

    # Seuil choisi par l'utilisateur
    # Par défaut : 70 %
    try:
        confidence = float(request.data.get("confidence", 0.70))
    except (TypeError, ValueError):
        return Response(
            {"error": "Seuil de confiance invalide."},
            status=status.HTTP_400_BAD_REQUEST
        )

    # BirdVision accepte uniquement 50 %, 60 % ou 70 %
    allowed_confidences = [0.50, 0.60, 0.70]

    if confidence not in allowed_confidences:
        return Response(
            {
                "error": "Le seuil doit être 0.50, 0.60 ou 0.70."
            },
            status=status.HTTP_400_BAD_REQUEST
        )

    # ============================================
    # CRÉER LES DOSSIERS
    # ============================================

    upload_directory = Path(settings.MEDIA_ROOT) / "uploads"
    result_directory = Path(settings.MEDIA_ROOT) / "results"

    upload_directory.mkdir(parents=True, exist_ok=True)
    result_directory.mkdir(parents=True, exist_ok=True)

    # ============================================
    # VÉRIFICATION DU FORMAT
    # ============================================

    extension = Path(image.name).suffix.lower()

    if extension not in [".jpg", ".jpeg", ".png"]:
        return Response(
            {"error": "Format accepté : JPG, JPEG ou PNG."},
            status=status.HTTP_400_BAD_REQUEST
        )

    # ============================================
    # NOM UNIQUE
    # ============================================

    filename = f"{uuid.uuid4()}{extension}"

    input_path = upload_directory / filename

    # ============================================
    # ENREGISTRER L'IMAGE REÇUE
    # ============================================

    with open(input_path, "wb+") as destination:
        for chunk in image.chunks():
            destination.write(chunk)

    # ============================================
    # DÉTECTION RT-DETR
    # ============================================

    results = model.predict(
        source=str(input_path),
        conf=confidence,
        verbose=False
    )

    result = results[0]

    # ============================================
    # FILTRER ET DESSINER UNIQUEMENT LES OISEAUX
    # ============================================

    detections = []

    # Charger l'image originale
    annotated_image = cv2.imread(str(input_path))

    for box in result.boxes:
        class_id = int(box.cls[0])
        class_name = model.names[class_id]

        # Ignorer toutes les classes sauf "bird"
        if class_name.lower() != "bird":
            continue

        confidence_score = float(box.conf[0])
        coordinates = box.xyxy[0].tolist()

        x1, y1, x2, y2 = map(int, coordinates)

        # Dessiner uniquement la bounding box de l'oiseau
        cv2.rectangle(
            annotated_image,
            (x1, y1),
            (x2, y2),
            (0, 255, 0),
            2
        )

        # Texte affiché sur la boîte
        label = f"Bird {confidence_score * 100:.1f}%"

        cv2.putText(
            annotated_image,
            label,
            (x1, max(y1 - 10, 20)),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.6,
            (0, 255, 0),
            2
        )

        # Ajouter la détection dans le JSON
        detections.append({
            "class": "bird",
            "confidence": round(confidence_score, 4),
            "box": {
                "x1": round(coordinates[0], 2),
                "y1": round(coordinates[1], 2),
                "x2": round(coordinates[2], 2),
                "y2": round(coordinates[3], 2),
            }
        })

    # ============================================
    # ENREGISTRER L'IMAGE RÉSULTAT
    # ============================================

    output_path = result_directory / filename

    cv2.imwrite(
        str(output_path),
        annotated_image
    )

    # ============================================
    # URL DE L'IMAGE RÉSULTAT
    # ============================================

    result_url = request.build_absolute_uri(
        settings.MEDIA_URL + "results/" + filename
    )

    # ============================================
    # RÉPONSE API
    # ============================================

    return Response({
        "success": True,
        "bird_count": len(detections),
        "confidence_threshold": confidence,
        "detections": detections,
        "result_image": result_url
    })


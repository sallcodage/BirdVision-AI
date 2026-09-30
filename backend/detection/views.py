from pathlib import Path
import uuid

import cv2

from django.conf import settings
from rest_framework.decorators import api_view
from rest_framework.response import Response
from rest_framework import status

from ultralytics import RTDETR, YOLO
from .dfine_model import DfineModel


# ============================================
# CONFIGURATION DES MODÈLES
# ============================================

PROJECT_ROOT = Path(settings.BASE_DIR).parent

MODEL_CONFIG = {
    "rtdetr-x": {
        "path": PROJECT_ROOT / "models" / "rtdetr-x.pt",
        "type": "rtdetr",
    },
    "yolo26s": {
        "path": PROJECT_ROOT / "models" / "yolo26s.pt",
        "type": "yolo",
    },
    "dfine-x": {
        "path": PROJECT_ROOT / "models" / "dfine_x_coco.pth",
        "type": "dfine",
    },
}


# ============================================
# VÉRIFICATION DES FICHIERS DE MODÈLES
# ============================================

for model_name, config in MODEL_CONFIG.items():
    if not config["path"].exists():
        raise FileNotFoundError(
            f"Le fichier du modèle {model_name} est introuvable : "
            f"{config['path']}"
        )


# ============================================
# CHARGEMENT DES MODÈLES
# ============================================

print("Chargement des modèles BirdVision AI...")

models = {}

print("Chargement de RT-DETR-X...")
models["rtdetr-x"] = RTDETR(
    str(MODEL_CONFIG["rtdetr-x"]["path"])
)
print("RT-DETR-X chargé avec succès !")

print("Chargement de YOLO26s...")
models["yolo26s"] = YOLO(
    str(MODEL_CONFIG["yolo26s"]["path"])
)
print("YOLO26s chargé avec succès !")

print("Chargement de D-FINE-X...")
models["dfine-x"] = DfineModel()
print("D-FINE-X chargé avec succès !")


# ============================================
# API DE DÉTECTION
# ============================================

@api_view(["POST"])
def detect_birds(request):

    # ========================================
    # RÉCUPÉRER L'IMAGE
    # ========================================

    image = request.FILES.get("image")

    if image is None:
        return Response(
            {"error": "Aucune image fournie."},
            status=status.HTTP_400_BAD_REQUEST
        )

    # ========================================
    # MODÈLE CHOISI
    # ========================================

    model_name = request.data.get(
        "model",
        "rtdetr-x"
    ).lower()

    if model_name not in MODEL_CONFIG:
        return Response(
            {
                "error": "Modèle invalide.",
                "available_models": [
                    "rtdetr-x",
                    "yolo26s",
                    "dfine-x"
                ]
            },
            status=status.HTTP_400_BAD_REQUEST
        )

    model = models[model_name]

    # ========================================
    # SEUIL DE CONFIANCE
    # ========================================

    try:
        confidence = float(
            request.data.get(
                "confidence",
                0.25
            )
        )
    except (TypeError, ValueError):
        return Response(
            {
                "error": (
                    "Seuil de confiance invalide."
                )
            },
            status=status.HTTP_400_BAD_REQUEST
        )

    # BirdVision accepte un seuil
    # compris entre 10 % et 90 %

    if confidence < 0.10 or confidence > 0.90:
        return Response(
            {
                "error": (
                    "Le seuil de confiance doit être "
                    "compris entre 0.10 et 0.90."
                )
            },
            status=status.HTTP_400_BAD_REQUEST
        )

    # ========================================
    # DOSSIERS
    # ========================================

    upload_directory = (
        Path(settings.MEDIA_ROOT)
        / "uploads"
    )

    result_directory = (
        Path(settings.MEDIA_ROOT)
        / "results"
    )

    upload_directory.mkdir(
        parents=True,
        exist_ok=True
    )

    result_directory.mkdir(
        parents=True,
        exist_ok=True
    )

    # ========================================
    # FORMAT DE L'IMAGE
    # ========================================

    extension = Path(
        image.name
    ).suffix.lower()

    if extension not in [
        ".jpg",
        ".jpeg",
        ".png"
    ]:
        return Response(
            {
                "error": (
                    "Format accepté : "
                    "JPG, JPEG ou PNG."
                )
            },
            status=status.HTTP_400_BAD_REQUEST
        )

    # ========================================
    # NOM UNIQUE
    # ========================================

    filename = (
        f"{uuid.uuid4()}{extension}"
    )

    input_path = (
        upload_directory
        / filename
    )

    # ========================================
    # ENREGISTRER L'IMAGE
    # ========================================

    with open(
        input_path,
        "wb+"
    ) as destination:

        for chunk in image.chunks():
            destination.write(chunk)

    # ========================================
    # D-FINE-X
    # ========================================

    if model_name == "dfine-x":

        output_path = (
            result_directory
            / filename
        )

        try:
            dfine_result = model.predict(
                image_path=str(input_path),
                confidence=confidence,
                save_path=str(output_path)
            )

        except Exception as error:
            return Response(
                {
                    "error": (
                        "Erreur pendant la "
                        "détection D-FINE-X."
                    ),
                    "details": str(error)
                },
                status=(
                    status.HTTP_500_INTERNAL_SERVER_ERROR
                )
            )

        result_url = (
            request.build_absolute_uri(
                settings.MEDIA_URL
                + "results/"
                + filename
            )
        )

        return Response(
            {
                "success": True,
                "model": model_name,
                "bird_count": (
                    dfine_result[
                        "bird_count"
                    ]
                ),
                "confidence_threshold": (
                    confidence
                ),
                "detections": (
                    dfine_result[
                        "detections"
                    ]
                ),
                "result_image": (
                    result_url
                )
            }
        )

    # ========================================
    # RT-DETR-X / YOLO26s
    # ========================================

    try:
        results = model.predict(
            source=str(input_path),

            # IMPORTANT :
            # utiliser le seuil choisi
            # dans le frontend
            conf=confidence,

            imgsz=1280,
            verbose=False
        )

    except Exception as error:
        return Response(
            {
                "error": (
                    "Erreur pendant "
                    "la détection."
                ),
                "details": str(error)
            },
            status=(
                status.HTTP_500_INTERNAL_SERVER_ERROR
            )
        )

    result = results[0]

    # ========================================
    # DÉTECTIONS
    # ========================================

    detections = []

    annotated_image = cv2.imread(
        str(input_path)
    )

    if annotated_image is None:
        return Response(
            {
                "error": (
                    "Impossible de lire "
                    "l'image envoyée."
                )
            },
            status=(
                status.HTTP_400_BAD_REQUEST
            )
        )

    # ========================================
    # PARCOURIR LES BOUNDING BOXES
    # ========================================

    for box in result.boxes:

        class_id = int(
            box.cls[0]
        )

        # Récupérer le nom
        # de la classe

        class_name = (
            model.names[
                class_id
            ]
        )

        # Garder uniquement
        # les oiseaux

        if (
            class_name.lower()
            != "bird"
        ):
            continue

        confidence_score = float(
            box.conf[0]
        )

        # Respecter le seuil
        # choisi par l'utilisateur

        if (
            confidence_score
            < confidence
        ):
            continue

        coordinates = (
            box.xyxy[0]
            .tolist()
        )

        x1, y1, x2, y2 = map(
            int,
            coordinates
        )

        # ====================================
        # DESSINER LA BOUNDING BOX
        # ====================================

        cv2.rectangle(
            annotated_image,
            (x1, y1),
            (x2, y2),
            (0, 255, 0),
            2
        )

        label = (
            f"Bird "
            f"{confidence_score * 100:.1f}%"
        )

        cv2.putText(
            annotated_image,
            label,
            (
                x1,
                max(
                    y1 - 10,
                    20
                )
            ),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.6,
            (0, 255, 0),
            2
        )

        # ====================================
        # AJOUTER AU JSON
        # ====================================

        detections.append(
            {
                "class": "bird",

                "confidence": round(
                    confidence_score,
                    4
                ),

                "box": {
                    "x1": round(
                        coordinates[0],
                        2
                    ),
                    "y1": round(
                        coordinates[1],
                        2
                    ),
                    "x2": round(
                        coordinates[2],
                        2
                    ),
                    "y2": round(
                        coordinates[3],
                        2
                    ),
                }
            }
        )

    # ========================================
    # ENREGISTRER L'IMAGE RÉSULTAT
    # ========================================

    output_path = (
        result_directory
        / filename
    )

    success = cv2.imwrite(
        str(output_path),
        annotated_image
    )

    if not success:
        return Response(
            {
                "error": (
                    "Impossible d'enregistrer "
                    "l'image résultat."
                )
            },
            status=(
                status.HTTP_500_INTERNAL_SERVER_ERROR
            )
        )

    # ========================================
    # URL DE L'IMAGE RÉSULTAT
    # ========================================

    result_url = (
        request.build_absolute_uri(
            settings.MEDIA_URL
            + "results/"
            + filename
        )
    )

    # ========================================
    # RÉPONSE API
    # ========================================

    return Response(
        {
            "success": True,
            "model": model_name,
            "bird_count": len(
                detections
            ),
            "confidence_threshold": (
                confidence
            ),
            "detections": detections,
            "result_image": (
                result_url
            )
        }
    )
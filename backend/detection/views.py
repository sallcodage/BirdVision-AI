import os
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

    image = request.FILES.get("image")

    if image is None:
        return Response(
            {"error": "Aucune image fournie."},
            status=status.HTTP_400_BAD_REQUEST
        )

    # ========================================
    # MODÈLE CHOISI
    # ========================================

    model_name = request.data.get("model", "rtdetr-x").lower()

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
            request.data.get("confidence", 0.70)
        )
    except (TypeError, ValueError):
        return Response(
            {"error": "Seuil de confiance invalide."},
            status=status.HTTP_400_BAD_REQUEST
        )

    # Le frontend permet un seuil de 10 % à 90 %.
    if confidence < 0.10 or confidence > 0.90:
        return Response(
            {
                "error": "Le seuil doit être compris entre 0,10 et 0,90."
            },
            status=status.HTTP_400_BAD_REQUEST
        )

    # ========================================
    # DOSSIERS
    # ========================================

    upload_directory = (
        Path(settings.MEDIA_ROOT) / "uploads"
    )

    result_directory = (
        Path(settings.MEDIA_ROOT) / "results"
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

    extension = Path(image.name).suffix.lower()

    # Les photos prises depuis la caméra (web / mobile) arrivent
    # parfois sans extension : on les traite comme du JPEG.
    if extension == "" and (
        image.content_type or ""
    ).startswith("image/"):
        extension = ".jpg"

    if extension not in [".jpg", ".jpeg", ".png", ".webp", ".bmp"]:
        return Response(
            {
                "error": (
                    "Format accepté : "
                    "JPG, JPEG, PNG, WEBP ou BMP."
                )
            },
            status=status.HTTP_400_BAD_REQUEST
        )

    # ========================================
    # NOM UNIQUE
    # ========================================

    filename = f"{uuid.uuid4()}{extension}"

    input_path = upload_directory / filename

    # ========================================
    # ENREGISTRER L'IMAGE
    # ========================================

    with open(input_path, "wb+") as destination:
        for chunk in image.chunks():
            destination.write(chunk)

    # ========================================
    # D-FINE-X
    # ========================================

    if model_name == "dfine-x":
        output_path = result_directory / filename

        try:
            dfine_result = model.predict(
                image_path=str(input_path),
                confidence=confidence,
                save_path=str(output_path)
            )
        except Exception as error:
            return Response(
                {
                    "error": "Erreur pendant la détection D-FINE-X.",
                    "details": str(error)
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

        result_url = request.build_absolute_uri(
            settings.MEDIA_URL + "results/" + filename
        )

        return Response(
            {
                "success": True,
                "model": model_name,
                "bird_count": dfine_result["bird_count"],
                "confidence_threshold": confidence,
                "detections": dfine_result["detections"],
                "result_image": result_url
            }
        )

    # ========================================
    # DÉTECTION
    # ========================================

    try:
        results = model.predict(
            source=str(input_path),
            conf=0.10,
            imgsz=1280,
            verbose=False
        )
    except Exception as error:
        return Response(
            {
                "error": "Erreur pendant la détection.",
                "details": str(error)
            },
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
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
            {"error": "Image illisible ou corrompue."},
            status=status.HTTP_400_BAD_REQUEST
        )

    # ========================================
    # PARCOURIR LES BOUNDING BOXES
    # ========================================

    for box in result.boxes:

        class_id = int(box.cls[0])

        # Récupérer le nom de la classe
        class_name = model.names[class_id]

        # Garder uniquement les oiseaux
        if class_name.lower() != "bird":
            continue

        confidence_score = float(
            box.conf[0]
        )

        # Respecter le seuil choisi
        if confidence_score < confidence:
            continue

        coordinates = box.xyxy[0].tolist()

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
            (x1, max(y1 - 10, 20)),
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
        result_directory / filename
    )

    cv2.imwrite(
        str(output_path),
        annotated_image
    )

    # ========================================
    # URL DE L'IMAGE RÉSULTAT
    # ========================================

    result_url = request.build_absolute_uri(
        settings.MEDIA_URL
        + "results/"
        + filename
    )

    # ========================================
    # RÉPONSE API
    # ========================================

    return Response(
        {
            "success": True,
            "model": model_name,
            "bird_count": len(detections),
            "confidence_threshold": confidence,
            "detections": detections,
            "result_image": result_url
        }
    )
    
# ============================================
# API DE DÉTECTION VIDÉO
# ============================================

VIDEO_EXTENSIONS = [".mp4", ".mov", ".avi", ".mkv", ".webm", ".3gp", ".m4v"]


def _detect_frame(model_name, model, frame, confidence, temp_dir, video_id):
    """
    Détecte les oiseaux sur une frame (BGR).
    Retourne une liste de (x1, y1, x2, y2, score).
    """

    boxes = []

    if model_name == "dfine-x":
        # D-FINE-X travaille sur un fichier image.
        temp_frame = os.path.join(temp_dir, f"{video_id}_frame.jpg")
        cv2.imwrite(temp_frame, frame)

        try:
            dfine_result = model.predict(
                image_path=temp_frame,
                confidence=confidence,
            )
        finally:
            if os.path.exists(temp_frame):
                os.remove(temp_frame)

        for detection in dfine_result["detections"]:
            box = detection["box"]
            boxes.append(
                (
                    int(box["x1"]),
                    int(box["y1"]),
                    int(box["x2"]),
                    int(box["y2"]),
                    float(detection["confidence"]),
                )
            )

        return boxes

    # RT-DETR-X / YOLO26s
    results = model.predict(
        source=frame,
        conf=0.10,
        imgsz=640,
        verbose=False
    )

    for result in results:
        if result.boxes is None:
            continue

        for box in result.boxes:
            class_name = model.names[int(box.cls[0])]

            if class_name.lower() != "bird":
                continue

            score = float(box.conf[0])

            if score < confidence:
                continue

            x1, y1, x2, y2 = map(int, box.xyxy[0].tolist())
            boxes.append((x1, y1, x2, y2, score))

    return boxes


def _draw_boxes(frame, boxes):
    for x1, y1, x2, y2, score in boxes:
        cv2.rectangle(frame, (x1, y1), (x2, y2), (0, 255, 0), 2)
        cv2.putText(
            frame,
            f"bird {score * 100:.1f}%",
            (x1, max(y1 - 10, 20)),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.6,
            (0, 255, 0),
            2
        )


def _open_video_writer(output_path, fps, width, height):
    """
    H.264 (avc1) est lisible par les navigateurs, Android et iOS.
    mp4v sert de secours si H.264 n'est pas disponible.
    """

    for codec in ["avc1", "mp4v"]:
        writer = cv2.VideoWriter(
            output_path,
            cv2.VideoWriter_fourcc(*codec),
            fps,
            (width, height)
        )

        if writer.isOpened():
            return writer

        writer.release()

    return None


@api_view(["POST"])
def detect_video(request):
    """
    Analyse une vidéo et détecte les oiseaux.

    Paramètres :
    - video : fichier vidéo
    - model : rtdetr-x | yolo26s | dfine-x
    - confidence : 0.10 à 0.90
    - frame_step : analyser 1 image sur N (1 = toutes). Les images
      intermédiaires réutilisent les dernières boîtes détectées.
    """

    video_file = request.FILES.get("video")

    if not video_file:
        return Response(
            {"error": "Aucune vidéo fournie."},
            status=status.HTTP_400_BAD_REQUEST
        )

    model_name = request.data.get("model", "rtdetr-x").lower()

    if model_name not in MODEL_CONFIG:
        return Response(
            {
                "error": "Modèle invalide.",
                "available_models": list(MODEL_CONFIG.keys())
            },
            status=status.HTTP_400_BAD_REQUEST
        )

    try:
        confidence = float(request.data.get("confidence", 0.70))
        frame_step = int(request.data.get("frame_step", 1))
    except (TypeError, ValueError):
        return Response(
            {"error": "Paramètres invalides."},
            status=status.HTTP_400_BAD_REQUEST
        )

    if confidence < 0.10 or confidence > 0.90:
        return Response(
            {
                "error": "Le seuil doit être compris entre 0,10 et 0,90."
            },
            status=status.HTTP_400_BAD_REQUEST
        )

    frame_step = min(max(frame_step, 1), 30)

    extension = Path(video_file.name).suffix.lower() or ".mp4"

    if extension not in VIDEO_EXTENSIONS:
        return Response(
            {
                "error": (
                    "Format vidéo accepté : "
                    + ", ".join(e[1:].upper() for e in VIDEO_EXTENSIONS)
                )
            },
            status=status.HTTP_400_BAD_REQUEST
        )

    video_dir = os.path.join(settings.MEDIA_ROOT, "videos")
    result_dir = os.path.join(video_dir, "results")

    os.makedirs(result_dir, exist_ok=True)

    video_id = uuid.uuid4().hex

    input_path = os.path.join(video_dir, f"{video_id}_input{extension}")
    output_path = os.path.join(result_dir, f"{video_id}_result.mp4")

    with open(input_path, "wb+") as destination:
        for chunk in video_file.chunks():
            destination.write(chunk)

    cap = cv2.VideoCapture(input_path)

    if not cap.isOpened():
        cap.release()
        os.remove(input_path)

        return Response(
            {"error": "Impossible d'ouvrir la vidéo."},
            status=status.HTTP_400_BAD_REQUEST
        )

    fps = cap.get(cv2.CAP_PROP_FPS)

    if not fps or fps <= 0 or fps > 240:
        fps = 25.0

    width = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    height = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))

    writer = _open_video_writer(output_path, fps, width, height)

    if writer is None:
        cap.release()
        os.remove(input_path)

        return Response(
            {"error": "Impossible de créer la vidéo de résultat."},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )

    model = models[model_name]

    frame_count = 0
    analyzed_frames = 0
    total_birds = 0
    max_birds_in_frame = 0
    last_boxes = []

    try:
        while True:
            success, frame = cap.read()

            if not success:
                break

            if frame_count % frame_step == 0:
                last_boxes = _detect_frame(
                    model_name,
                    model,
                    frame,
                    confidence,
                    video_dir,
                    video_id
                )

                analyzed_frames += 1
                total_birds += len(last_boxes)
                max_birds_in_frame = max(
                    max_birds_in_frame,
                    len(last_boxes)
                )

            frame_count += 1

            _draw_boxes(frame, last_boxes)
            writer.write(frame)

    except Exception as error:
        return Response(
            {
                "error": "Erreur pendant l'analyse de la vidéo.",
                "details": str(error)
            },
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )

    finally:
        cap.release()
        writer.release()

        if os.path.exists(input_path):
            os.remove(input_path)

    result_url = request.build_absolute_uri(
        settings.MEDIA_URL
        + f"videos/results/{os.path.basename(output_path)}"
    )

    return Response(
        {
            "success": True,
            "model": model_name,
            "confidence_threshold": confidence,
            "frame_step": frame_step,
            "frames_total": frame_count,
            "frames_analyzed": analyzed_frames,
            "duration_seconds": round(frame_count / fps, 2),
            "total_bird_detections": total_birds,
            "max_birds_in_frame": max_birds_in_frame,
            "result_video": result_url
        },
        status=status.HTTP_200_OK
    )

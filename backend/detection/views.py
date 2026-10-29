import io
import os
from pathlib import Path
import subprocess
import threading
import time
import uuid

import cv2
import imageio_ffmpeg
import numpy as np
from PIL import Image, ImageOps

from django.conf import settings
from rest_framework.decorators import api_view
from rest_framework.response import Response
from rest_framework import status

from ultralytics import RTDETR, YOLO
from rfdetr import RFDETRSmall

from .dfine_model import DfineModel
from .fasterrcnn_model import FasterRcnnModel


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
    "rfdetr-s": {
        "path": None,
        "type": "rfdetr",
    },
    "dfine-x": {
        "path": PROJECT_ROOT / "models" / "dfine_x_coco.pth",
        "type": "dfine",
    },
    "dfine-s": {
        "path": PROJECT_ROOT / "models" / "dfine_s_coco.pth",
        "type": "dfine",
    },
    # Poids torchvision téléchargés automatiquement (cache torch)
    "faster-rcnn": {
        "path": None,
        "type": "fasterrcnn",
    },
}

# Modèles qui utilisent une classe wrapper personnalisée.
WRAPPED_MODEL_TYPES = ("dfine", "fasterrcnn")


def _confidence_validation_error(model_name, confidence):
    minimum = 0.09 if model_name == "rfdetr-s" else 0.10

    if minimum <= confidence <= 0.90:
        return None

    minimum_text = "0,09" if model_name == "rfdetr-s" else "0,10"

    return (
        f"Le seuil doit être compris entre "
        f"{minimum_text} et 0,90."
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

print("Chargement de RF-DETR-S...")
models["rfdetr-s"] = RFDETRSmall()
print("RF-DETR-S chargé avec succès !")

print("Chargement de D-FINE-X...")
models["dfine-x"] = DfineModel()
print("D-FINE-X chargé avec succès !")

print("Chargement de D-FINE-S...")
models["dfine-s"] = DfineModel(size="s")
print("D-FINE-S chargé avec succès !")

print("Chargement de Faster R-CNN...")
models["faster-rcnn"] = FasterRcnnModel()
print("Faster R-CNN chargé avec succès !")


# ============================================
# API DE DÉTECTION D'IMAGES
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
                "available_models": list(MODEL_CONFIG.keys())
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

    confidence_error = _confidence_validation_error(
        model_name,
        confidence
    )

    if confidence_error:
        return Response(
            {"error": confidence_error},
            status=status.HTTP_400_BAD_REQUEST
        )

    # ========================================
    # DOSSIERS
    # ========================================

    upload_directory = Path(settings.MEDIA_ROOT) / "uploads"
    result_directory = Path(settings.MEDIA_ROOT) / "results"

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
    # RF-DETR-S : DÉTECTION D'IMAGE
    # ========================================

    if MODEL_CONFIG[model_name]["type"] == "rfdetr":

        try:
            with Image.open(input_path) as source_image:
                pil_image = source_image.convert("RGB")

                predictions = model.predict(
                    pil_image,
                    threshold=confidence
                )

            annotated_image = cv2.imread(str(input_path))

            if annotated_image is None:
                raise ValueError(
                    "Image illisible ou corrompue."
                )

            detections = []
            class_names = predictions.data.get("class_name", [])
            # COCO bird : 14 (0-indexed 80 classes) ou 16 (1-indexed 90 classes)
            BIRD_CLASS_IDS = {14, 16}
            cids = getattr(predictions, "class_id", None)

            for i, coordinates in enumerate(predictions.xyxy):

                # Priorité : nom de classe (insensible à la casse)
                if len(class_names) > i:
                    raw = class_names[i]
                    class_name = (
                        raw.decode("utf-8").lower()
                        if isinstance(raw, (bytes, bytearray))
                        else str(raw).lower()
                    )
                    is_bird = class_name == "bird"
                elif cids is not None and len(cids) > i:
                    # Fallback class_id : 14 (COCO 80) ou 16 (COCO 90)
                    is_bird = int(cids[i]) in BIRD_CLASS_IDS
                else:
                    # Aucune info de classe : on inclut (modèle fine-tuné bird only)
                    is_bird = True

                # Garder uniquement les oiseaux.
                if not is_bird:
                    continue

                score = float(predictions.confidence[i])

                if score < confidence:
                    continue

                x1, y1, x2, y2 = map(
                    int,
                    coordinates.tolist()
                )

                # Dessiner la boîte de détection.
                cv2.rectangle(
                    annotated_image,
                    (x1, y1),
                    (x2, y2),
                    (0, 255, 0),
                    2
                )

                label = f"Bird {score * 100:.1f}%"

                cv2.putText(
                    annotated_image,
                    label,
                    (x1, max(y1 - 10, 20)),
                    cv2.FONT_HERSHEY_SIMPLEX,
                    0.6,
                    (0, 255, 0),
                    2
                )

                detections.append(
                    {
                        "class": "bird",
                        "confidence": round(score, 4),
                        "box": {
                            "x1": round(float(coordinates[0]), 2),
                            "y1": round(float(coordinates[1]), 2),
                            "x2": round(float(coordinates[2]), 2),
                            "y2": round(float(coordinates[3]), 2),
                        }
                    }
                )

            output_path = result_directory / filename

            if not cv2.imwrite(
                str(output_path),
                annotated_image
            ):
                raise RuntimeError(
                    "Impossible d'enregistrer l'image résultat."
                )

            result_url = request.build_absolute_uri(
                settings.MEDIA_URL + "results/" + filename
            )

            return Response(
                {
                    "success": True,
                    "model": model_name,
                    "bird_count": len(detections),
                    "confidence_threshold": confidence,
                    "detections": detections,
                    "result_image": result_url
                },
                status=status.HTTP_200_OK
            )

        except Exception as error:
            return Response(
                {
                    "error": "Erreur pendant la détection RF-DETR-S.",
                    "details": str(error)
                },
                status=status.HTTP_500_INTERNAL_SERVER_ERROR
            )

    # ========================================
    # D-FINE / FASTER R-CNN
    # ========================================

    if MODEL_CONFIG[model_name]["type"] in WRAPPED_MODEL_TYPES:

        output_path = result_directory / filename

        try:
            model_result = model.predict(
                image_path=str(input_path),
                confidence=confidence,
                save_path=str(output_path)
            )

        except Exception as error:
            return Response(
                {
                    "error": f"Erreur pendant la détection {model_name}.",
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
                "bird_count": model_result["bird_count"],
                "confidence_threshold": confidence,
                "detections": model_result["detections"],
                "result_image": result_url
            },
            status=status.HTTP_200_OK
        )

    # ========================================
    # RT-DETR-X / YOLO26s
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
    # PRÉPARER L'IMAGE RÉSULTAT
    # ========================================

    detections = []

    annotated_image = cv2.imread(str(input_path))

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
        class_name = model.names[class_id]

        if class_name.lower() != "bird":
            continue

        confidence_score = float(box.conf[0])

        if confidence_score < confidence:
            continue

        coordinates = box.xyxy[0].tolist()

        x1, y1, x2, y2 = map(
            int,
            coordinates
        )

        # Dessiner la boîte.
        cv2.rectangle(
            annotated_image,
            (x1, y1),
            (x2, y2),
            (0, 255, 0),
            2
        )

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

        detections.append(
            {
                "class": "bird",
                "confidence": round(confidence_score, 4),
                "box": {
                    "x1": round(coordinates[0], 2),
                    "y1": round(coordinates[1], 2),
                    "x2": round(coordinates[2], 2),
                    "y2": round(coordinates[3], 2),
                }
            }
        )

    # ========================================
    # ENREGISTRER L'IMAGE RÉSULTAT
    # ========================================

    output_path = result_directory / filename

    if not cv2.imwrite(
        str(output_path),
        annotated_image
    ):
        return Response(
            {"error": "Impossible d'enregistrer l'image résultat."},
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )

    # ========================================
    # URL DE L'IMAGE RÉSULTAT
    # ========================================

    result_url = request.build_absolute_uri(
        settings.MEDIA_URL + "results/" + filename
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
        },
        status=status.HTTP_200_OK
    )


# ============================================
# API DE DÉTECTION VIDÉO
# ============================================

VIDEO_EXTENSIONS = [
    ".mp4", ".mov", ".avi", ".mkv", ".webm", ".3gp", ".m4v"
]


def _detect_frame(
    model_name,
    model,
    frame,
    confidence,
    temp_dir,
    video_id
):
    """
    Détecte les oiseaux sur une frame BGR.

    Retourne une liste de tuples :
    (x1, y1, x2, y2, score).
    """

    boxes = []

    # ========================================
    # RF-DETR-S
    # Utilisé pour la caméra et la vidéo.
    # ========================================

    if MODEL_CONFIG[model_name]["type"] == "rfdetr":

        rgb_frame = cv2.cvtColor(
            frame,
            cv2.COLOR_BGR2RGB
        )

        pil_image = Image.fromarray(rgb_frame)

        predictions = model.predict(
            pil_image,
            threshold=confidence
        )

        class_names = predictions.data.get("class_name", [])
        BIRD_CLASS_IDS = {14, 16}
        cids = getattr(predictions, "class_id", None)

        for i, coordinates in enumerate(predictions.xyxy):

            if len(class_names) > i:
                raw = class_names[i]
                class_name = (
                    raw.decode("utf-8").lower()
                    if isinstance(raw, (bytes, bytearray))
                    else str(raw).lower()
                )
                is_bird = class_name == "bird"
            elif cids is not None and len(cids) > i:
                is_bird = int(cids[i]) in BIRD_CLASS_IDS
            else:
                is_bird = True

            if not is_bird:
                continue

            score = float(predictions.confidence[i])

            if score < confidence:
                continue

            x1, y1, x2, y2 = map(
                int,
                coordinates.tolist()
            )

            boxes.append(
                (x1, y1, x2, y2, score)
            )

        return boxes

    # ========================================
    # D-FINE / FASTER R-CNN
    # ========================================

    if MODEL_CONFIG[model_name]["type"] in WRAPPED_MODEL_TYPES:

        encoded, buffer = cv2.imencode(".jpg", frame)

        if not encoded:
            raise RuntimeError(
                "Impossible d'encoder l'image."
            )

        model_result = model.predict(
            image_path=io.BytesIO(buffer.tobytes()),
            confidence=confidence,
        )

        for detection in model_result["detections"]:

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

    # ========================================
    # RT-DETR-X / YOLO26s
    # ========================================

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

            x1, y1, x2, y2 = map(
                int,
                box.xyxy[0].tolist()
            )

            boxes.append(
                (x1, y1, x2, y2, score)
            )

    return boxes


# ============================================
# DESSINER LES BOÎTES SUR UNE IMAGE
# ============================================

def _draw_boxes(frame, boxes):

    for x1, y1, x2, y2, score in boxes:

        cv2.rectangle(
            frame,
            (x1, y1),
            (x2, y2),
            (0, 255, 0),
            2
        )

        cv2.putText(
            frame,
            f"bird {score * 100:.1f}%",
            (x1, max(y1 - 10, 20)),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.6,
            (0, 255, 0),
            2
        )


# ============================================
# NORMALISER LES COORDONNÉES
# ============================================

def _normalize_boxes(boxes, width, height):
    """
    Convertit les coordonnées entre 0 et 1.
    L'application peut ainsi placer les boîtes
    sur un aperçu quelle que soit sa taille.
    """

    return [
        {
            "x1": round(x1 / width, 4),
            "y1": round(y1 / height, 4),
            "x2": round(x2 / width, 4),
            "y2": round(y2 / height, 4),
            "confidence": round(score, 4),
        }
        for x1, y1, x2, y2, score in boxes
    ]


# ============================================
# VERROUS POUR LA CAMÉRA
# ============================================

frame_locks = {
    name: threading.Lock()
    for name in MODEL_CONFIG
}


# ============================================
# API DE DÉTECTION EN DIRECT
# ============================================

@api_view(["POST"])
def detect_frame(request):
    """
    Détection en direct sur une image de la caméra.

    Paramètres :
    - image : image JPEG
    - model : modèle à utiliser
    - confidence : seuil entre 0.10 et 0.90 (0.09 pour RF-DETR-S)

    Ne sauvegarde pas l'image : renvoie les boîtes normalisées.
    """

    image_file = request.FILES.get("image")

    if not image_file:
        return Response(
            {"error": "Aucune image fournie."},
            status=status.HTTP_400_BAD_REQUEST
        )

    model_name = request.data.get("model", "dfine-s").lower()

    if model_name not in MODEL_CONFIG:
        return Response(
            {
                "error": "Modèle invalide.",
                "available_models": list(MODEL_CONFIG.keys())
            },
            status=status.HTTP_400_BAD_REQUEST
        )

    try:
        confidence = float(
            request.data.get("confidence", 0.40)
        )
    except (TypeError, ValueError):
        return Response(
            {"error": "Paramètres invalides."},
            status=status.HTTP_400_BAD_REQUEST
        )

    confidence_error = _confidence_validation_error(
        model_name,
        confidence
    )

    if confidence_error:
        return Response(
            {"error": confidence_error},
            status=status.HTTP_400_BAD_REQUEST
        )

    try:
        # Corriger l'orientation EXIF des photos de téléphone.
        image = ImageOps.exif_transpose(
            Image.open(image_file)
        )

        frame = cv2.cvtColor(
            np.asarray(image.convert("RGB")),
            cv2.COLOR_RGB2BGR
        )

    except Exception:
        return Response(
            {"error": "Image illisible."},
            status=status.HTTP_400_BAD_REQUEST
        )

    height, width = frame.shape[:2]

    temp_dir = os.path.join(
        settings.MEDIA_ROOT,
        "frames"
    )

    os.makedirs(
        temp_dir,
        exist_ok=True
    )

    started = time.perf_counter()

    try:
        with frame_locks[model_name]:

            boxes = _detect_frame(
                model_name,
                models[model_name],
                frame,
                confidence,
                temp_dir,
                uuid.uuid4().hex
            )

    except Exception as error:
        return Response(
            {
                "error": f"Erreur pendant la détection {model_name}.",
                "details": str(error)
            },
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )

    return Response(
        {
            "success": True,
            "model": model_name,
            "width": width,
            "height": height,
            "boxes": _normalize_boxes(
                boxes,
                width,
                height
            ),
            "time_ms": round(
                (time.perf_counter() - started) * 1000
            ),
        },
        status=status.HTTP_200_OK
    )


# ============================================
# CONVERSION VIDÉO EN H.264
# ============================================

def _to_h264(raw_path, output_path):
    """
    Réencode la vidéo OpenCV en H.264 + faststart.
    Retourne False si ffmpeg échoue.
    """

    command = [
        imageio_ffmpeg.get_ffmpeg_exe(),
        "-y",
        "-loglevel", "error",
        "-i", raw_path,
        "-c:v", "libx264",
        "-preset", "veryfast",
        "-crf", "23",
        "-pix_fmt", "yuv420p",
        "-movflags", "+faststart",
        "-an",
        output_path,
    ]

    try:
        subprocess.run(
            command,
            check=True,
            capture_output=True,
            timeout=600
        )

        return True

    except (subprocess.SubprocessError, OSError) as error:
        print(f"Réencodage H.264 impossible : {error}")
        return False


# ============================================
# GESTION DES TÂCHES VIDÉO
# ============================================

video_jobs = {}
video_jobs_lock = threading.Lock()

# Une seule analyse vidéo à la fois.
video_inference_lock = threading.Lock()


def _update_job(job_id, **fields):

    with video_jobs_lock:
        video_jobs[job_id].update(fields)


# ============================================
# ANALYSE D'UNE VIDÉO
# ============================================

def _run_video_job(
    job_id,
    model_name,
    confidence,
    frame_step,
    max_frames,
    input_path,
    video_dir,
    result_dir
):

    raw_path = os.path.join(
        result_dir,
        f"{job_id}_raw.mp4"
    )

    output_path = os.path.join(
        result_dir,
        f"{job_id}_result.mp4"
    )

    cap = cv2.VideoCapture(input_path)
    writer = None

    try:
        if not cap.isOpened():
            raise RuntimeError(
                "Impossible d'ouvrir la vidéo."
            )

        fps = cap.get(cv2.CAP_PROP_FPS)

        if not fps or fps <= 0 or fps > 240:
            fps = 25.0

        width = int(
            cap.get(cv2.CAP_PROP_FRAME_WIDTH)
        )

        height = int(
            cap.get(cv2.CAP_PROP_FRAME_HEIGHT)
        )

        frames_expected = int(
            cap.get(cv2.CAP_PROP_FRAME_COUNT)
        ) or 0

        if max_frames and frames_expected:
            frame_step = max(
                frame_step,
                -(-frames_expected // max_frames)
            )

        writer = cv2.VideoWriter(
            raw_path,
            cv2.VideoWriter_fourcc(*"mp4v"),
            fps,
            (width, height)
        )

        if not writer.isOpened():
            raise RuntimeError(
                "Impossible de créer la vidéo de résultat."
            )

        model = models[model_name]

        frame_count = 0
        analyzed_frames = 0
        total_birds = 0
        max_birds_in_frame = 0
        last_boxes = []

        with video_inference_lock:

            _update_job(
                job_id,
                status="processing"
            )

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
                        job_id
                    )

                    # Enregistrer les détections pour l'application.
                    with video_jobs_lock:

                        video_jobs[job_id]["detections"].append(
                            {
                                "t": round(
                                    frame_count / fps,
                                    3
                                ),
                                "boxes": _normalize_boxes(
                                    last_boxes,
                                    frame.shape[1],
                                    frame.shape[0]
                                ),
                            }
                        )

                    analyzed_frames += 1
                    total_birds += len(last_boxes)

                    max_birds_in_frame = max(
                        max_birds_in_frame,
                        len(last_boxes)
                    )

                frame_count += 1

                _draw_boxes(
                    frame,
                    last_boxes
                )

                writer.write(frame)

                if frames_expected and frame_count % 5 == 0:

                    _update_job(
                        job_id,
                        progress=min(
                            frame_count / frames_expected,
                            0.99
                        )
                    )

        cap.release()
        writer.release()

        _update_job(
            job_id,
            status="encoding",
            progress=0.99
        )

        if _to_h264(raw_path, output_path):
            os.remove(raw_path)
        else:
            os.replace(
                raw_path,
                output_path
            )

        _update_job(
            job_id,
            status="done",
            progress=1.0,
            result={
                "model": model_name,
                "confidence_threshold": confidence,
                "frame_step": frame_step,
                "frames_total": frame_count,
                "frames_analyzed": analyzed_frames,
                "duration_seconds": round(
                    frame_count / fps,
                    2
                ),
                "total_bird_detections": total_birds,
                "max_birds_in_frame": max_birds_in_frame,
                "result_path": (
                    settings.MEDIA_URL
                    + "videos/results/"
                    + os.path.basename(output_path)
                ),
            }
        )

    except Exception as error:

        _update_job(
            job_id,
            status="error",
            error=str(error)
        )

        if os.path.exists(raw_path):
            os.remove(raw_path)

    finally:

        cap.release()

        if writer is not None:
            writer.release()

        if os.path.exists(input_path):
            os.remove(input_path)


# ============================================
# API DE DÉTECTION VIDÉO
# ============================================

@api_view(["POST"])
def detect_video(request):
    """
    Lance l'analyse d'une vidéo.

    Paramètres :
    - video : fichier vidéo
    - model : modèle à utiliser
    - confidence : seuil entre 0.10 et 0.90 (0.09 pour RF-DETR-S)
    - frame_step : analyser une image sur N
    - max_frames : nombre maximal d'images analysées
    - async : "1" pour lancer l'analyse en arrière-plan
    """

    video_file = request.FILES.get("video")

    if not video_file:
        return Response(
            {"error": "Aucune vidéo fournie."},
            status=status.HTTP_400_BAD_REQUEST
        )

    model_name = request.data.get(
        "model",
        "rtdetr-x"
    ).lower()

    if model_name not in MODEL_CONFIG:
        return Response(
            {
                "error": "Modèle invalide.",
                "available_models": list(MODEL_CONFIG.keys())
            },
            status=status.HTTP_400_BAD_REQUEST
        )

    try:
        confidence = float(
            request.data.get("confidence", 0.70)
        )

        frame_step = int(
            request.data.get("frame_step", 1)
        )

        max_frames = max(
            int(request.data.get("max_frames", 0)),
            0
        )

    except (TypeError, ValueError):
        return Response(
            {"error": "Paramètres invalides."},
            status=status.HTTP_400_BAD_REQUEST
        )

    confidence_error = _confidence_validation_error(
        model_name,
        confidence
    )

    if confidence_error:
        return Response(
            {"error": confidence_error},
            status=status.HTTP_400_BAD_REQUEST
        )

    frame_step = min(
        max(frame_step, 1),
        30
    )

    extension = Path(
        video_file.name
    ).suffix.lower() or ".mp4"

    if extension not in VIDEO_EXTENSIONS:
        return Response(
            {
                "error": (
                    "Format vidéo accepté : "
                    + ", ".join(
                        ext[1:].upper()
                        for ext in VIDEO_EXTENSIONS
                    )
                )
            },
            status=status.HTTP_400_BAD_REQUEST
        )

    video_dir = os.path.join(
        settings.MEDIA_ROOT,
        "videos"
    )

    result_dir = os.path.join(
        video_dir,
        "results"
    )

    os.makedirs(
        result_dir,
        exist_ok=True
    )

    job_id = uuid.uuid4().hex

    input_path = os.path.join(
        video_dir,
        f"{job_id}_input{extension}"
    )

    try:
        os.makedirs(
            video_dir,
            exist_ok=True
        )

        with open(input_path, "wb+") as destination:
            for chunk in video_file.chunks():
                destination.write(chunk)

    except OSError as error:

        if os.path.exists(input_path):
            os.remove(input_path)

        return Response(
            {
                "error": (
                    "Le disque du PC serveur est plein : "
                    "libérez de la place sur C:."
                ),
                "details": str(error),
            },
            status=status.HTTP_507_INSUFFICIENT_STORAGE
        )

    with video_jobs_lock:

        video_jobs[job_id] = {
            "status": "queued",
            "progress": 0.0,
            "detections": [],
        }

    # Ancien fonctionnement : attendre la fin de l'analyse.
    if request.data.get("async") != "1":

        _run_video_job(
            job_id,
            model_name,
            confidence,
            frame_step,
            max_frames,
            input_path,
            video_dir,
            result_dir
        )

        return _job_response(
            request,
            job_id
        )

    # Nouveau fonctionnement : lancer l'analyse en arrière-plan.
    threading.Thread(
        target=_run_video_job,
        args=(
            job_id,
            model_name,
            confidence,
            frame_step,
            max_frames,
            input_path,
            video_dir,
            result_dir
        ),
        daemon=True
    ).start()

    return Response(
        {
            "success": True,
            "job_id": job_id,
            "status": "queued"
        },
        status=status.HTTP_202_ACCEPTED
    )


# ============================================
# ÉTAT D'UNE ANALYSE VIDÉO
# ============================================

@api_view(["GET"])
def video_job_status(request, job_id):
    """
    État d'une analyse :
    queued | processing | encoding | done | error.
    """

    return _job_response(
        request,
        job_id
    )


def _job_response(request, job_id):

    with video_jobs_lock:

        job = video_jobs.get(job_id)

        if job:
            job = dict(
                job,
                detections=list(job["detections"])
            )

    if not job:
        return Response(
            {
                "error": (
                    "Analyse introuvable "
                    "(serveur redémarré ?)."
                )
            },
            status=status.HTTP_404_NOT_FOUND
        )

    body = {
        "success": job["status"] != "error",
        "job_id": job_id,
        "status": job["status"],
        "progress": round(
            job.get("progress", 0.0),
            3
        ),
        "detections": job["detections"],
    }

    if job["status"] == "error":

        body["error"] = (
            "Erreur pendant l'analyse de la vidéo."
        )

        body["details"] = job.get("error")

    if job["status"] == "done":

        result = dict(
            job["result"]
        )

        result["result_video"] = request.build_absolute_uri(
            result.pop("result_path")
        )

        body.update(result)

    return Response(
        body,
        status=status.HTTP_200_OK
    )
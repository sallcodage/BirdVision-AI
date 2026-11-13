"""
Tester d'autres modèles de détection (hors backend) sur les oiseaux, depuis le cmd.

Tous les modèles Ultralytics sont acceptés : ils sont téléchargés
automatiquement dans models/autres/ la première fois.

Exemples (depuis la racine du projet) :
    python src/test_models.py --list
    python src/test_models.py test_images/oiseau.jpg
    python src/test_models.py test_images --models yolo11s yolov8m rtdetr-l --conf 0.4
    python src/test_models.py test_images --models yolov8s-worldv2 --save
    python src/test_models.py test_images --models chemin/vers/mon_modele.pt
    python src/test_models.py test_images --models fasterrcnn retinanet ssd grounding-dino-tiny --save
"""

import argparse
import gc
import sys
import time
from pathlib import Path

import cv2
from ultralytics import RTDETR, YOLO, YOLOWorld

from other_detectors import OTHER_MODELS, load_other_model


# ==========================
# CONFIGURATION
# ==========================

BASE_DIR = Path(__file__).resolve().parent.parent

WEIGHTS_DIR = BASE_DIR / "models" / "autres"

RESULTS_DIR = BASE_DIR / "runs" / "test_models"

IMAGE_EXTENSIONS = [".jpg", ".jpeg", ".png", ".webp", ".bmp"]

# Modèles testés par défaut (différents de ceux du backend)
DEFAULT_MODELS = ["yolo11s", "yolov8s", "yolov10s", "rtdetr-l"]

# Modèles proposés avec --list
SUGGESTED_MODELS = {
    "YOLO11": ["yolo11n", "yolo11s", "yolo11m", "yolo11l", "yolo11x"],
    "YOLOv8": ["yolov8n", "yolov8s", "yolov8m", "yolov8l", "yolov8x"],
    "YOLOv10": ["yolov10n", "yolov10s", "yolov10m", "yolov10l", "yolov10x"],
    "YOLOv9": ["yolov9t", "yolov9s", "yolov9m", "yolov9c", "yolov9e"],
    "RT-DETR": ["rtdetr-l"],
    "YOLO-World (vocabulaire libre)": ["yolov8s-worldv2", "yolov8m-worldv2", "yolov8l-worldv2"],
    "Faster R-CNN (torchvision)": ["fasterrcnn", "fasterrcnn-v1", "fasterrcnn-mobile"],
    "RetinaNet (torchvision)": ["retinanet", "retinanet-v1"],
    "SSD (torchvision)": ["ssd", "ssdlite"],
    "FCOS (torchvision)": ["fcos"],
    "Grounding DINO (Hugging Face)": ["grounding-dino-tiny", "grounding-dino-base"],
}


# ==========================
# OUTILS
# ==========================

def collect_images(source):
    """Retourne la liste des images (fichier unique ou dossier)."""

    path = Path(source)

    if path.is_dir():
        return sorted(
            p for p in path.iterdir()
            if p.suffix.lower() in IMAGE_EXTENSIONS
        )

    if path.is_file():
        return [path]

    return []


def load_model(name):
    """Charge un modèle par nom (téléchargé si besoin) ou par chemin."""

    path = Path(name)

    # Chemin vers un fichier existant (ex : modèle fine-tuné)
    if path.suffix == ".pt" and path.exists():
        weights = path
    else:
        WEIGHTS_DIR.mkdir(parents=True, exist_ok=True)
        weights = WEIGHTS_DIR / f"{path.stem}.pt"

    stem = weights.stem.lower()

    if stem.startswith("rtdetr"):
        model = RTDETR(str(weights))
    elif "world" in stem:
        model = YOLOWorld(str(weights))
        model.set_classes(["bird"])
    else:
        model = YOLO(str(weights))

    return model, weights.stem


def bird_class_ids(model):
    """Identifiants de la classe 'bird' dans le modèle (None = toutes)."""

    ids = [i for i, n in model.names.items() if n.lower() == "bird"]

    return ids or None


class UltralyticsDetector:
    """Même interface que les détecteurs de other_detectors.py."""

    def __init__(self, model, imgsz):
        self.model = model
        self.imgsz = imgsz
        self.classes = bird_class_ids(model)

    def predict(self, image_path, conf):
        result = self.model.predict(
            str(image_path),
            classes=self.classes,
            conf=conf,
            imgsz=self.imgsz,
            verbose=False,
        )[0]

        return [float(c) for c in result.boxes.conf], result.boxes.xyxy.tolist()


def draw_detections(image_path, scores, boxes, output_path):
    """Dessine les boîtes comme le backend et enregistre l'image."""

    image = cv2.imread(str(image_path))

    for score, (x1, y1, x2, y2) in zip(scores, boxes):
        x1, y1, x2, y2 = map(int, (x1, y1, x2, y2))
        cv2.rectangle(image, (x1, y1), (x2, y2), (0, 255, 0), 2)
        cv2.putText(image, f"Bird {score * 100:.1f}%", (x1, max(y1 - 10, 20)),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 0), 2)

    cv2.imwrite(str(output_path), image)


# ==========================
# PROGRAMME PRINCIPAL
# ==========================

def main():

    parser = argparse.ArgumentParser(
        description="Tester d'autres modèles de détection d'oiseaux."
    )
    parser.add_argument(
        "source",
        nargs="?",
        default=str(BASE_DIR / "test_images"),
        help="Image ou dossier d'images (défaut : test_images)",
    )
    parser.add_argument(
        "-m", "--models",
        nargs="+",
        default=DEFAULT_MODELS,
        help=f"Noms ou chemins .pt (défaut : {' '.join(DEFAULT_MODELS)})",
    )
    parser.add_argument(
        "-c", "--conf",
        type=float,
        default=0.50,
        help="Seuil de confiance (défaut : 0.50)",
    )
    parser.add_argument(
        "--imgsz",
        type=int,
        default=1280,
        help="Taille d'entrée (défaut : 1280, comme le backend)",
    )
    parser.add_argument(
        "-s", "--save",
        action="store_true",
        help=f"Enregistrer les images annotées dans {RESULTS_DIR}",
    )
    parser.add_argument(
        "-v", "--verbose",
        action="store_true",
        help="Afficher chaque détection (confiance + boîte)",
    )
    parser.add_argument(
        "--list",
        action="store_true",
        help="Afficher les modèles disponibles et quitter",
    )
    args = parser.parse_args()

    if args.list:
        for family, names in SUGGESTED_MODELS.items():
            print(f"{family:<32} {' '.join(names)}")
        print("\nOu tout fichier .pt local (ex : modèle fine-tuné).")
        return

    images = collect_images(args.source)

    if not images:
        print(f"Aucune image trouvée : {args.source}")
        sys.exit(1)

    print(f"Modèles   : {', '.join(args.models)}")
    print(f"Confiance : {args.conf:.2f} | imgsz : {args.imgsz}")
    print(f"Images    : {len(images)}")
    print()

    summary = []

    header = f"{'Image':<28} {'Modèle':<18} {'Oiseaux':>7} {'Conf max':>9} {'Temps':>8}"

    for model_input in args.models:

        # ==========================
        # CHARGEMENT
        # ==========================

        try:
            if model_input.lower() in OTHER_MODELS:
                model_name = model_input.lower()
                model = load_other_model(model_name)
            else:
                model, model_name = load_model(model_input)
                model = UltralyticsDetector(model, args.imgsz)
        except Exception as error:
            print(f"=== {model_input} : ERREUR de chargement : {error}\n")
            summary.append((model_input, 0, 0.0, "chargement impossible"))
            continue

        print(f"=== {model_name} ===")
        print(header)
        print("-" * len(header))

        # Échauffement (la 1re inférence est toujours plus lente)
        model.predict(images[0], args.conf)

        # ==========================
        # DÉTECTION
        # ==========================

        total_birds = 0
        timings = []

        for image_path in images:

            start = time.perf_counter()
            scores, boxes = model.predict(image_path, args.conf)
            elapsed = time.perf_counter() - start

            timings.append(elapsed)

            total_birds += len(scores)

            print(
                f"{image_path.name[:27]:<28} {model_name[:17]:<18} {len(scores):>7} "
                f"{max(scores, default=0.0):>8.1%} {elapsed:>7.2f}s"
            )

            if args.verbose:
                for score, (x1, y1, x2, y2) in zip(scores, boxes):
                    print(f"{'':<30}- bird {score:.1%} [{x1:.0f}, {y1:.0f}, {x2:.0f}, {y2:.0f}]")

            if args.save:
                output_dir = RESULTS_DIR / model_name
                output_dir.mkdir(parents=True, exist_ok=True)
                draw_detections(image_path, scores, boxes, output_dir / image_path.name)

        average = sum(timings) / len(timings)
        summary.append((model_name, total_birds, average, ""))
        print()

        # Libérer la mémoire avant le modèle suivant
        del model
        gc.collect()

    # ==========================
    # RÉSUMÉ
    # ==========================

    print("Résumé")
    print("-" * 60)
    for model_name, birds, average, error in summary:
        if error:
            print(f"{model_name:<18} {error}")
        else:
            print(f"{model_name:<18} oiseaux : {birds:>4}  temps moyen : {average:.2f}s")

    if args.save:
        print()
        print(f"Images annotées enregistrées dans : {RESULTS_DIR}")


if __name__ == "__main__":
    main()

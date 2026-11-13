"""
Tester les modèles de détection BirdVision AI via l'API backend, depuis le cmd.

Prérequis : le backend Django doit tourner
    cd backend
    python manage.py runserver

Exemples :
    python src/test_api.py test_images/oiseau.jpg
    python src/test_api.py test_images/oiseau.jpg --model yolo26s --conf 0.5
    python src/test_api.py test_images/oiseau.jpg --model all
    python src/test_api.py test_images --model all --save
"""

import argparse
import sys
import time
from pathlib import Path

import requests


# ==========================
# CONFIGURATION
# ==========================

BASE_DIR = Path(__file__).resolve().parent.parent

DEFAULT_URL = "http://127.0.0.1:8000"

AVAILABLE_MODELS = ["rtdetr-x", "yolo26s", "dfine-x", "dfine-s", "faster-rcnn"]

IMAGE_EXTENSIONS = [".jpg", ".jpeg", ".png", ".webp", ".bmp"]

RESULTS_DIR = BASE_DIR / "runs" / "api_test"


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


def detect(api_url, image_path, model_name, confidence):
    """Envoie une image à /api/detect/ et retourne (json, durée)."""

    start = time.perf_counter()

    with open(image_path, "rb") as image_file:
        response = requests.post(
            f"{api_url}/api/detect/",
            files={"image": (image_path.name, image_file)},
            data={"model": model_name, "confidence": confidence},
            timeout=300,
        )

    elapsed = time.perf_counter() - start

    try:
        data = response.json()
    except ValueError:
        data = {"error": f"Réponse non JSON (HTTP {response.status_code})"}

    if not response.ok and "error" not in data:
        data["error"] = f"HTTP {response.status_code}"

    return data, elapsed


def save_result_image(url, image_path, model_name):
    """Télécharge l'image annotée renvoyée par l'API."""

    output_dir = RESULTS_DIR / model_name
    output_dir.mkdir(parents=True, exist_ok=True)

    output_path = output_dir / image_path.name

    response = requests.get(url, timeout=60)
    response.raise_for_status()
    output_path.write_bytes(response.content)

    return output_path


# ==========================
# PROGRAMME PRINCIPAL
# ==========================

def main():

    parser = argparse.ArgumentParser(
        description="Tester les modèles de détection via l'API BirdVision AI."
    )
    parser.add_argument(
        "source",
        help="Image ou dossier d'images à analyser",
    )
    parser.add_argument(
        "-m", "--model",
        default="rtdetr-x",
        help=f"Modèle : {', '.join(AVAILABLE_MODELS)} ou 'all' (défaut : rtdetr-x)",
    )
    parser.add_argument(
        "-c", "--conf",
        type=float,
        default=0.70,
        help="Seuil de confiance entre 0.10 et 0.90 (défaut : 0.70)",
    )
    parser.add_argument(
        "--url",
        default=DEFAULT_URL,
        help=f"Adresse du backend (défaut : {DEFAULT_URL})",
    )
    parser.add_argument(
        "-s", "--save",
        action="store_true",
        help=f"Télécharger les images annotées dans {RESULTS_DIR}",
    )
    parser.add_argument(
        "-v", "--verbose",
        action="store_true",
        help="Afficher chaque détection (confiance + boîte)",
    )
    args = parser.parse_args()

    api_url = args.url.rstrip("/")

    # Modèles à tester
    if args.model.lower() == "all":
        model_names = AVAILABLE_MODELS
    elif args.model.lower() in AVAILABLE_MODELS:
        model_names = [args.model.lower()]
    else:
        print(f"Modèle inconnu : {args.model}")
        print(f"Modèles disponibles : {', '.join(AVAILABLE_MODELS)}, all")
        sys.exit(1)

    if not 0.10 <= args.conf <= 0.90:
        print("Le seuil doit être compris entre 0.10 et 0.90.")
        sys.exit(1)

    images = collect_images(args.source)

    if not images:
        print(f"Aucune image trouvée : {args.source}")
        sys.exit(1)

    # Vérifier que le backend répond
    try:
        requests.get(api_url, timeout=5)
    except requests.ConnectionError:
        print(f"Impossible de joindre le backend sur {api_url}")
        print("Lancez-le avec : cd backend && python manage.py runserver")
        sys.exit(1)

    print(f"Backend   : {api_url}")
    print(f"Modèles   : {', '.join(model_names)}")
    print(f"Confiance : {args.conf:.2f}")
    print(f"Images    : {len(images)}")
    print()

    # ==========================
    # DÉTECTION
    # ==========================

    summary = {name: {"birds": 0, "time": 0.0, "errors": 0} for name in model_names}

    header = f"{'Image':<28} {'Modèle':<10} {'Oiseaux':>7} {'Conf max':>9} {'Temps':>8}"
    print(header)
    print("-" * len(header))

    for image_path in images:
        for model_name in model_names:

            try:
                data, elapsed = detect(api_url, image_path, model_name, args.conf)
            except requests.RequestException as error:
                data, elapsed = {"error": str(error)}, 0.0

            name = image_path.name[:27]

            if "error" in data:
                summary[model_name]["errors"] += 1
                details = data.get("details", "")
                print(f"{name:<28} {model_name:<10} ERREUR : {data['error']} {details}")
                continue

            detections = data.get("detections", [])
            best = max((d["confidence"] for d in detections), default=0.0)

            summary[model_name]["birds"] += data["bird_count"]
            summary[model_name]["time"] += elapsed

            print(
                f"{name:<28} {model_name:<10} {data['bird_count']:>7} "
                f"{best:>8.1%} {elapsed:>7.2f}s"
            )

            if args.verbose:
                for d in detections:
                    box = d["box"]
                    print(
                        f"{'':<30}- bird {d['confidence']:.1%} "
                        f"[{box['x1']:.0f}, {box['y1']:.0f}, {box['x2']:.0f}, {box['y2']:.0f}]"
                    )

            if args.save and data.get("result_image"):
                try:
                    saved = save_result_image(data["result_image"], image_path, model_name)
                    if args.verbose:
                        print(f"{'':<30}  -> {saved}")
                except requests.RequestException as error:
                    print(f"{'':<30}  Échec du téléchargement : {error}")

    # ==========================
    # RÉSUMÉ
    # ==========================

    if len(model_names) > 1 or len(images) > 1:
        print()
        print("Résumé")
        print("-" * 50)
        for model_name, stats in summary.items():
            ok = len(images) - stats["errors"]
            average = stats["time"] / ok if ok else 0.0
            print(
                f"{model_name:<10} oiseaux : {stats['birds']:>4}  "
                f"temps moyen : {average:.2f}s  erreurs : {stats['errors']}"
            )

    if args.save:
        print()
        print(f"Images annotées enregistrées dans : {RESULTS_DIR}")


if __name__ == "__main__":
    main()

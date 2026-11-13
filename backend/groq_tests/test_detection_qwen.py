"""Détection d'oiseaux 100 % Groq avec qwen/qwen3.8-27b (vision).

Le modèle renvoie chaque oiseau avec une boîte et une confiance (auto-déclarée).
Les images annotées sont enregistrées dans runs/groq_detection/.

Usage (depuis backend/) :
    ..\\venv\\Scripts\\python.exe groq_tests\\test_detection_qwen.py
    ..\\venv\\Scripts\\python.exe groq_tests\\test_detection_qwen.py ..\\test_images\\oiseau.jpg
"""
import argparse
import base64
import io
import json
import os
import statistics
import sys
import time
from pathlib import Path

from dotenv import load_dotenv
from groq import Groq, GroqError
from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
PROJECT_ROOT = HERE.parents[1]
load_dotenv(HERE.parent / ".env")

IMAGES_DIR = PROJECT_ROOT / "test_images"
OUTPUT_DIR = PROJECT_ROOT / "runs" / "groq_detection"
MODEL = "qwen/qwen3.8-27b"

# Nombre réel d'oiseaux (compté à la main)
VERITE = {"oiseau.jpg": 10, "oiseau3.jpg": 9}

PROMPT = (
    "Détecte TOUS les oiseaux visibles sur cette image, un par un. "
    "Réponds UNIQUEMENT avec un objet JSON de la forme : "
    '{"oiseaux": [{"box": [x1, y1, x2, y2], "confiance": 0.0, "espece": "..."}]} '
    "où box est en coordonnées normalisées de 0 à 1000 (coin haut-gauche, coin bas-droit), "
    "confiance est un nombre entre 0 et 1 qui reflète honnêtement ta certitude que c'est un oiseau, "
    "et espece est le nom commun en français (ou null si inconnu). "
    "Ne compte pas deux fois le même oiseau. Si aucun oiseau, renvoie une liste vide."
)

parser = argparse.ArgumentParser()
parser.add_argument("images", nargs="*")
args = parser.parse_args()

if not os.getenv("GROQ_API_KEY"):
    sys.exit("GROQ_API_KEY manquante : ajoute-la dans backend/.env")

images = [Path(p) for p in args.images] or sorted(
    p for p in IMAGES_DIR.iterdir()
    if p.suffix.lower() in {".jpg", ".jpeg", ".png"} and not p.name.startswith("dfine_result")
)
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
client = Groq()


def detect(path):
    img = Image.open(path).convert("RGB")
    img.thumbnail((1280, 1280))
    buffer = io.BytesIO()
    img.save(buffer, format="JPEG", quality=85)
    image_b64 = base64.b64encode(buffer.getvalue()).decode()

    completion = client.chat.completions.create(
        model=MODEL,
        messages=[{
            "role": "user",
            "content": [
                {"type": "text", "text": PROMPT},
                {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{image_b64}"}},
            ],
        }],
        temperature=0.1,
        max_tokens=800,
        response_format={"type": "json_object"},
    )
    return img, json.loads(completion.choices[0].message.content).get("oiseaux", [])


def draw(img, birds, out_path):
    w, h = img.size
    d = ImageDraw.Draw(img)
    for b in birds:
        try:
            x1, y1, x2, y2 = (float(v) for v in b["box"])
        except (KeyError, TypeError, ValueError):
            continue
        box = [x1 * w / 1000, y1 * h / 1000, x2 * w / 1000, y2 * h / 1000]
        d.rectangle(box, outline="red", width=3)
        d.text((box[0], max(box[1] - 12, 0)), f"{b.get('espece') or 'oiseau'} {float(b.get('confiance', 0)):.0%}", fill="red")
    img.save(out_path)


results = []
for path in images:
    print(f"=== {path.name} ===")
    start = time.time()
    try:
        img, birds = detect(path)
    except (GroqError, json.JSONDecodeError) as e:
        print(f"  ERREUR : {e}\n")
        continue
    elapsed = time.time() - start

    confs = [float(b.get("confiance", 0)) for b in birds]
    especes = sorted({b.get("espece") or "?" for b in birds})
    draw(img, birds, OUTPUT_DIR / path.name)

    print(f"  {len(birds)} oiseaux | {elapsed:.2f}s | espèces : {', '.join(especes)}")
    if confs:
        print(f"  confiance : moy {statistics.mean(confs):.2f} | min {min(confs):.2f} | max {max(confs):.2f}")
    print()
    results.append((path.name, len(birds), confs, elapsed, especes))

# ============================================
# RÉSUMÉ
# ============================================

print("=" * 86)
print(f"{'Image':<20}{'Réel':>6}{'Qwen':>6}{'Conf moy':>10}{'Min':>7}{'Max':>7}{'Temps':>8}  Espèces")
print("-" * 86)
for name, n, confs, t, especes in results:
    reel = VERITE.get(name, "?")
    mean = f"{statistics.mean(confs):.2f}" if confs else "-"
    print(f"{name[:19]:<20}{reel:>6}{n:>6}{mean:>10}{min(confs, default=0):>7.2f}{max(confs, default=0):>7.2f}"
          f"{t:>7.1f}s  {', '.join(especes)[:30]}")
print(f"\nImages annotées : {OUTPUT_DIR}")

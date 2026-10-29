"""Comparatif des modèles YOLO26 (n, s, m, l, x) sur la détection d'oiseaux.

Usage (depuis la racine du projet) :
    venv\\Scripts\\python.exe src\\benchmark_yolo.py
    venv\\Scripts\\python.exe src\\benchmark_yolo.py --sizes n s --conf 0.3
"""
import argparse
import gc
import statistics
import time
from pathlib import Path

from ultralytics import YOLO

PROJECT_ROOT = Path(__file__).resolve().parent.parent
WEIGHTS_DIR = PROJECT_ROOT / "models" / "yolo26"
IMAGES_DIR = PROJECT_ROOT / "test_images"
OUTPUT_DIR = PROJECT_ROOT / "runs" / "benchmark_yolo"
BIRD_CLASS = 14  # COCO

parser = argparse.ArgumentParser()
parser.add_argument("--sizes", nargs="+", default=["n", "s", "m", "l", "x"])
parser.add_argument("--conf", type=float, default=0.25)
parser.add_argument("--repeats", type=int, default=3)
args = parser.parse_args()

images = sorted(p for p in IMAGES_DIR.iterdir() if p.suffix.lower() in {".jpg", ".jpeg", ".png"})
if not images:
    raise SystemExit(f"Aucune image dans {IMAGES_DIR}")

WEIGHTS_DIR.mkdir(parents=True, exist_ok=True)
print(f"{len(images)} images | conf={args.conf} | {args.repeats} passages | CPU\n")

results = []
for size in args.sizes:
    name = f"yolo26{size}"
    weights = WEIGHTS_DIR / f"{name}.pt"
    print(f"=== {name} ===")
    model = YOLO(str(weights))  # téléchargé automatiquement s'il manque

    # Échauffement (la 1re inférence est toujours plus lente)
    model.predict(str(images[0]), classes=[BIRD_CLASS], conf=args.conf, verbose=False)

    timings = []
    for _ in range(args.repeats):
        for img in images:
            start = time.perf_counter()
            model.predict(str(img), classes=[BIRD_CLASS], conf=args.conf, verbose=False)
            timings.append((time.perf_counter() - start) * 1000)

    # Passage final : détections + images annotées
    per_image = {}
    confidences = []
    for img in images:
        r = model.predict(
            str(img), classes=[BIRD_CLASS], conf=args.conf, verbose=False,
            save=True, project=str(OUTPUT_DIR), name=name, exist_ok=True,
        )[0]
        confs = r.boxes.conf.tolist()
        per_image[img.name] = len(confs)
        confidences.extend(confs)

    results.append({
        "model": name,
        "size_mb": weights.stat().st_size / 1e6,
        "ms": statistics.mean(timings),
        "fps": 1000 / statistics.mean(timings),
        "birds": sum(per_image.values()),
        "images_with_bird": sum(1 for n in per_image.values() if n),
        "conf_mean": statistics.mean(confidences) if confidences else 0.0,
        "per_image": per_image,
    })
    print(f"  {results[-1]['ms']:.0f} ms/image | {results[-1]['birds']} oiseaux\n")

    del model
    gc.collect()

# ============================================
# RÉSUMÉ
# ============================================

print("\n" + "=" * 78)
print(f"{'Modèle':<10}{'Taille':>9}{'ms/img':>9}{'FPS':>7}{'Oiseaux':>9}{'Img OK':>9}{'Conf moy':>10}")
print("-" * 78)
for r in results:
    print(
        f"{r['model']:<10}{r['size_mb']:>7.1f}Mo{r['ms']:>9.0f}{r['fps']:>7.1f}"
        f"{r['birds']:>9}{r['images_with_bird']:>6}/{len(images):<2}{r['conf_mean']:>10.2f}"
    )

print("\nOiseaux détectés par image :")
print(f"{'Image':<30}" + "".join(f"{r['model']:>10}" for r in results))
for img in images:
    print(f"{img.name[:29]:<30}" + "".join(f"{r['per_image'][img.name]:>10}" for r in results))

print(f"\nImages annotées : {OUTPUT_DIR}")

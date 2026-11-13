"""Comparatif de la confiance des détections d'oiseaux pour tous les modèles.

Usage (depuis la racine du projet) :
    venv\\Scripts\\python.exe src\\benchmark_confiance.py
"""
import gc
import statistics
import sys
import time
from pathlib import Path

from ultralytics import RTDETR, YOLO

PROJECT_ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(PROJECT_ROOT / "backend"))

IMAGES_DIR = PROJECT_ROOT / "test_images"
BIRD_CLASS = 14  # COCO
MIN_CONF = 0.25

# Nombre réel d'oiseaux (compté à la main)
VERITE = {"oiseau.jpg": 10, "oiseau3.jpg": 9}

images = sorted(
    p for p in IMAGES_DIR.iterdir()
    if p.suffix.lower() in {".jpg", ".jpeg", ".png"} and not p.name.startswith("dfine_result")
)


def ultralytics_runner(cls, weights, imgsz):
    model = cls(str(weights))

    def run(img):
        r = model.predict(str(img), classes=[BIRD_CLASS], conf=MIN_CONF, imgsz=imgsz, verbose=False)[0]
        return r.boxes.conf.tolist()
    return run


def dfine_runner(size):
    from detection.dfine_model import DfineModel
    model = DfineModel(size=size)

    def run(img):
        return [d["confidence"] for d in model.predict(str(img), confidence=MIN_CONF)["detections"]]
    return run


CANDIDATS = [
    ("yolo26s (640)", lambda: ultralytics_runner(YOLO, PROJECT_ROOT / "models" / "yolo26s.pt", 640)),
    ("yolo26s (1280)", lambda: ultralytics_runner(YOLO, PROJECT_ROOT / "models" / "yolo26s.pt", 1280)),
    ("yolo26l (640)", lambda: ultralytics_runner(YOLO, PROJECT_ROOT / "models" / "yolo26" / "yolo26l.pt", 640)),
    ("yolo26l (1280)", lambda: ultralytics_runner(YOLO, PROJECT_ROOT / "models" / "yolo26" / "yolo26l.pt", 1280)),
    ("rtdetr-x", lambda: ultralytics_runner(RTDETR, PROJECT_ROOT / "models" / "rtdetr-x.pt", 640)),
    # D-FINE-X avant D-FINE-S : la config D-FINE garde un état global (use_lab)
    ("dfine-x", lambda: dfine_runner("x")),
    ("dfine-s", lambda: dfine_runner("s")),
]

print(f"{len(images)} images : {', '.join(p.name for p in images)}\n")

results = []
for name, factory in CANDIDATS:
    print(f"=== {name} ===")
    run = factory()
    run(images[0])  # échauffement

    confs, per_image, timings = [], {}, []
    for img in images:
        start = time.perf_counter()
        c = run(img)
        timings.append((time.perf_counter() - start) * 1000)
        confs.extend(c)
        per_image[img.name] = c

    results.append({
        "name": name,
        "ms": statistics.mean(timings),
        "n": len(confs),
        "mean": statistics.mean(confs) if confs else 0,
        "min": min(confs) if confs else 0,
        "max": max(confs) if confs else 0,
        "ge50": sum(c >= 0.5 for c in confs) / len(confs) if confs else 0,
        "per_image": per_image,
    })
    del run
    gc.collect()

# ============================================
# RÉSUMÉ
# ============================================

print("\n" + "=" * 96)
print(f"{'Modèle':<16}{'ms/img':>8}{'Détect.':>9}{'Conf moy':>10}{'Min':>7}{'Max':>7}{'>=50%':>8}"
      + "".join(f"{k[:-4] + ' (' + str(v) + ')':>15}" for k, v in VERITE.items()))
print("-" * 96)
for r in results:
    verite = ""
    for img, attendu in VERITE.items():
        c = r["per_image"].get(img, [])
        n50 = sum(x >= 0.5 for x in c)
        verite += f"{len(c):>8} / {n50:>2}≥50"
    print(f"{r['name']:<16}{r['ms']:>8.0f}{r['n']:>9}{r['mean']:>10.2f}{r['min']:>7.2f}{r['max']:>7.2f}"
          f"{r['ge50']:>7.0%} {verite}")
print("\nColonnes oiseau/oiseau3 : nombre détecté (seuil 25%) / dont confiance ≥ 50%")

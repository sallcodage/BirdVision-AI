"""BirdVision-AI : fine-tuning de YOLO26s sur les oiseaux (exécuté sur Kaggle, GPU).

Lancé à distance par : kaggle kernels push -p notebooks\\kaggle
Résultat : /kaggle/working/yolo26s_birds.pt (récupéré automatiquement).
"""
import shutil
import subprocess
import sys

subprocess.run(
    [sys.executable, "-m", "pip", "install", "-q", "ultralytics==8.4.158", "fiftyone"],
    check=True,
)

import fiftyone as fo  # noqa: E402
import fiftyone.zoo as foz  # noqa: E402
from fiftyone import ViewField as F  # noqa: E402
from ultralytics import YOLO  # noqa: E402

N_TRAIN = 4000
N_VAL = 600
EXPORT_DIR = "/kaggle/temp/birds_yolo"
WORK = "/kaggle/working"

# ============================================
# 1. JEU DE DONNÉES : Open Images V7, classe "Bird"
# ============================================

for split, n in [("train", N_TRAIN), ("validation", N_VAL)]:
    ds = foz.load_zoo_dataset(
        "open-images-v7",
        split=split,
        label_types=["detections"],
        classes=["Bird"],
        max_samples=n,
        shuffle=True,
        seed=42,
        dataset_name=f"birds-{split}",
        dataset_dir="/kaggle/temp/fiftyone",
    )
    view = ds.filter_labels("ground_truth", F("label") == "Bird")
    view.export(
        export_dir=EXPORT_DIR,
        dataset_type=fo.types.YOLOv5Dataset,
        label_field="ground_truth",
        split="train" if split == "train" else "val",
        classes=["Bird"],
    )

# Nom de classe en minuscules : le backend BirdVision filtre sur "bird"
yaml_path = f"{EXPORT_DIR}/dataset.yaml"
text = open(yaml_path).read().replace("Bird", "bird")
open(yaml_path, "w").write(text)
print(text, flush=True)

# ============================================
# 2. ENTRAÎNEMENT
# ============================================

model = YOLO("yolo26s.pt")
model.train(
    data=yaml_path,
    epochs=40,
    patience=10,
    imgsz=1280,
    batch=8,
    project=f"{WORK}/runs",
    name="yolo26s_birds",
    exist_ok=True,
    plots=True,
    workers=4,
)

# ============================================
# 3. ÉVALUATION + EXPORT
# ============================================

best_path = f"{WORK}/runs/yolo26s_birds/weights/best.pt"
best = YOLO(best_path)
metrics = best.val(data=yaml_path, imgsz=1280)
print(f"mAP50     : {metrics.box.map50:.3f}")
print(f"mAP50-95  : {metrics.box.map:.3f}")
print(f"Précision : {metrics.box.mp:.3f}")
print(f"Rappel    : {metrics.box.mr:.3f}")

shutil.copy(best_path, f"{WORK}/yolo26s_birds.pt")
# Ne garder que l'essentiel dans les sorties (poids intermédiaires inutiles)
shutil.rmtree(f"{WORK}/runs/yolo26s_birds/weights", ignore_errors=True)
print("Terminé : yolo26s_birds.pt", flush=True)

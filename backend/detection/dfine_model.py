import os
import sys
from pathlib import Path

import torch
import torch.nn as nn
import torchvision.transforms as T
from PIL import Image, ImageDraw

# Chemin vers le dossier D-FINE
PROJECT_ROOT = Path(__file__).resolve().parents[2]
DFINE_ROOT = PROJECT_ROOT / "D-FINE"

# Ajouter D-FINE au PYTHONPATH
if str(DFINE_ROOT) not in sys.path:
    sys.path.insert(0, str(DFINE_ROOT))

from src.core import YAMLConfig


class DfineModel:
    """
    Wrapper BirdVision AI pour D-FINE-X.
    """

    def __init__(self):
        self.project_root = PROJECT_ROOT

        self.config_path = (
            DFINE_ROOT
            / "configs"
            / "dfine"
            / "dfine_hgnetv2_x_coco.yml"
        )

        self.model_path = (
            PROJECT_ROOT
            / "models"
            / "dfine_x_coco.pth"
        )

        self.device = torch.device("cpu")

        print("Chargement de D-FINE-X...")

        if not self.config_path.exists():
            raise FileNotFoundError(
                f"Configuration D-FINE introuvable : {self.config_path}"
            )

        if not self.model_path.exists():
            raise FileNotFoundError(
                f"Modèle D-FINE introuvable : {self.model_path}"
            )

        # Charger la configuration
        cfg = YAMLConfig(
            str(self.config_path),
            resume=str(self.model_path)
        )

        # Le checkpoint D-FINE-X contient le modèle entraîné.
        checkpoint = torch.load(
            str(self.model_path),
            map_location="cpu"
        )

        if "ema" in checkpoint:
            state = checkpoint["ema"]["module"]
        else:
            state = checkpoint["model"]

        # Charger les poids
        cfg.model.load_state_dict(state)

        # Passage en mode déploiement
        class Model(nn.Module):
            def __init__(self):
                super().__init__()

                self.model = cfg.model.deploy()
                self.postprocessor = cfg.postprocessor.deploy()

            def forward(self, images, orig_target_sizes):
                outputs = self.model(images)
                outputs = self.postprocessor(
                    outputs,
                    orig_target_sizes
                )

                return outputs

        self.model = Model().to(self.device)
        self.model.eval()

        self.transforms = T.Compose(
            [
                T.Resize((640, 640)),
                T.ToTensor(),
            ]
        )

        print("D-FINE-X chargé avec succès !")

    def predict(
        self,
        image_path,
        confidence=0.70,
        save_path=None
    ):
        """
        Détecte uniquement les oiseaux.

        Retourne :
        - bird_count
        - detections
        - image annotée
        """

        image = Image.open(
            image_path
        ).convert("RGB")

        width, height = image.size

        orig_size = torch.tensor(
            [[width, height]],
            device=self.device
        )

        image_tensor = self.transforms(
            image
        ).unsqueeze(0).to(self.device)

        with torch.no_grad():
            labels, boxes, scores = self.model(
                image_tensor,
                orig_size
            )

        labels = labels[0]
        boxes = boxes[0]
        scores = scores[0]

        detections = []

        draw = ImageDraw.Draw(image)

        for label, box, score in zip(
            labels,
            boxes,
            scores
        ):
            label_id = int(label.item())
            confidence_score = float(score.item())

            # D-FINE utilise les labels COCO remappés.
            # Le label interne 14 correspond à "bird".
            if label_id != 14:
                continue

            if confidence_score < confidence:
                continue

            coordinates = [
                float(value)
                for value in box.tolist()
            ]

            x1, y1, x2, y2 = coordinates

            # Dessiner la bounding box
            draw.rectangle(
                [x1, y1, x2, y2],
                outline="red",
                width=3
            )

            draw.text(
                (x1, max(y1 - 15, 0)),
                f"bird {confidence_score * 100:.1f}%",
                fill="red"
            )

            detections.append(
                {
                    "class": "bird",
                    "confidence": round(
                        confidence_score,
                        4
                    ),
                    "box": {
                        "x1": round(x1, 2),
                        "y1": round(y1, 2),
                        "x2": round(x2, 2),
                        "y2": round(y2, 2),
                    }
                }
            )

        if save_path:
            image.save(save_path)

        return {
            "bird_count": len(detections),
            "detections": detections
        }
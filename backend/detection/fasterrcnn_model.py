import torch
from PIL import Image, ImageDraw
from torchvision.models.detection import (
    FasterRCNN_ResNet50_FPN_V2_Weights,
    fasterrcnn_resnet50_fpn_v2,
)
from torchvision.transforms.functional import to_tensor

# Utiliser tous les cœurs CPU disponibles
torch.set_num_threads(torch.get_num_threads())

_MAX_SIDE = 800  # redimensionnement avant inférence pour accélérer


class FasterRcnnModel:
    """
    Wrapper BirdVision AI pour Faster R-CNN (torchvision, ResNet50-FPN v2, COCO).

    Même interface que DfineModel : predict(image_path, confidence, save_path).
    Les poids (~170 Mo) sont téléchargés automatiquement au premier lancement
    dans le cache torch (~/.cache/torch/hub/checkpoints).
    """

    def __init__(self):
        self.device = torch.device("cpu")

        weights = FasterRCNN_ResNet50_FPN_V2_Weights.DEFAULT

        # Seuil interne bas : le filtrage se fait dans predict()
        self.model = fasterrcnn_resnet50_fpn_v2(
            weights=weights,
            box_score_thresh=0.05
        ).to(self.device)
        self.model.eval()

        # Identifiant COCO de la classe "bird" pour torchvision
        self.bird_id = weights.meta["categories"].index("bird")

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

        original_image = Image.open(
            image_path
        ).convert("RGB")

        # Redimensionner pour l'inférence (accélère sur CPU)
        w, h = original_image.size
        scale = _MAX_SIDE / max(w, h)
        if scale < 1.0:
            infer_image = original_image.resize(
                (int(w * scale), int(h * scale)),
                Image.BILINEAR
            )
        else:
            scale = 1.0
            infer_image = original_image

        image_tensor = to_tensor(infer_image).to(self.device)

        with torch.no_grad():
            output = self.model([image_tensor])[0]

        detections = []

        # Annoter l'image originale (pleine résolution)
        draw = ImageDraw.Draw(original_image)

        for label, box, score in zip(
            output["labels"],
            output["boxes"],
            output["scores"]
        ):
            confidence_score = float(score.item())

            if int(label.item()) != self.bird_id:
                continue

            if confidence_score < confidence:
                continue

            x1, y1, x2, y2 = [
                float(value) / scale
                for value in box.tolist()
            ]

            # Dessiner la bounding box
            draw.rectangle(
                [x1, y1, x2, y2],
                outline="lime",
                width=3
            )

            draw.text(
                (x1, max(y1 - 15, 0)),
                f"bird {confidence_score * 100:.1f}%",
                fill="lime"
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
            original_image.save(save_path)

        return {
            "bird_count": len(detections),
            "detections": detections
        }

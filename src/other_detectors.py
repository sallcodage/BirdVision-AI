"""
Détecteurs hors Ultralytics, utilisés par test_models.py :
    - torchvision : Faster R-CNN, RetinaNet, SSD, SSDlite, FCOS (pré-entraînés COCO)
    - Hugging Face : Grounding DINO (vocabulaire libre, texte "a bird.")

Chaque détecteur expose predict(image_path, conf) -> (scores, boxes)
avec boxes au format [x1, y1, x2, y2] en pixels.
"""

import torch
from PIL import Image
from torchvision.models import detection
from torchvision.transforms.functional import to_tensor


# ==========================
# MODÈLES DISPONIBLES
# ==========================

TORCHVISION_MODELS = {
    "fasterrcnn": ("fasterrcnn_resnet50_fpn_v2", "FasterRCNN_ResNet50_FPN_V2_Weights"),
    "fasterrcnn-v1": ("fasterrcnn_resnet50_fpn", "FasterRCNN_ResNet50_FPN_Weights"),
    "fasterrcnn-mobile": ("fasterrcnn_mobilenet_v3_large_fpn", "FasterRCNN_MobileNet_V3_Large_FPN_Weights"),
    "retinanet": ("retinanet_resnet50_fpn_v2", "RetinaNet_ResNet50_FPN_V2_Weights"),
    "retinanet-v1": ("retinanet_resnet50_fpn", "RetinaNet_ResNet50_FPN_Weights"),
    "ssd": ("ssd300_vgg16", "SSD300_VGG16_Weights"),
    "ssdlite": ("ssdlite320_mobilenet_v3_large", "SSDLite320_MobileNet_V3_Large_Weights"),
    "fcos": ("fcos_resnet50_fpn", "FCOS_ResNet50_FPN_Weights"),
}

GROUNDING_DINO_MODELS = {
    "grounding-dino-tiny": "IDEA-Research/grounding-dino-tiny",
    "grounding-dino-base": "IDEA-Research/grounding-dino-base",
}

OTHER_MODELS = list(TORCHVISION_MODELS) + list(GROUNDING_DINO_MODELS)


# ==========================
# TORCHVISION
# ==========================

class TorchvisionDetector:

    def __init__(self, name):
        builder_name, weights_name = TORCHVISION_MODELS[name]

        weights = getattr(detection, weights_name).DEFAULT

        # Seuil interne très bas : le filtrage se fait dans predict()
        kwargs = {"box_score_thresh": 0.05} if "rcnn" in builder_name else {}
        self.model = getattr(detection, builder_name)(weights=weights, **kwargs)
        self.model.eval()

        categories = weights.meta["categories"]
        self.bird_id = categories.index("bird")

    @torch.inference_mode()
    def predict(self, image_path, conf):
        image = to_tensor(Image.open(image_path).convert("RGB"))
        output = self.model([image])[0]

        keep = (output["labels"] == self.bird_id) & (output["scores"] >= conf)

        return output["scores"][keep].tolist(), output["boxes"][keep].tolist()


# ==========================
# GROUNDING DINO
# ==========================

class GroundingDinoDetector:

    def __init__(self, name, prompt="a bird."):
        from transformers import AutoModelForZeroShotObjectDetection, AutoProcessor

        model_id = GROUNDING_DINO_MODELS[name]

        self.processor = AutoProcessor.from_pretrained(model_id)
        self.model = AutoModelForZeroShotObjectDetection.from_pretrained(model_id)
        self.model.eval()
        self.prompt = prompt

    @torch.inference_mode()
    def predict(self, image_path, conf):
        image = Image.open(image_path).convert("RGB")

        inputs = self.processor(images=image, text=self.prompt, return_tensors="pt")
        outputs = self.model(**inputs)

        result = self.processor.post_process_grounded_object_detection(
            outputs,
            inputs.input_ids,
            threshold=conf,
            text_threshold=0.25,
            target_sizes=[image.size[::-1]],
        )[0]

        return result["scores"].tolist(), result["boxes"].tolist()


def load_other_model(name):
    """Charge un détecteur torchvision ou Grounding DINO par son nom."""

    if name in TORCHVISION_MODELS:
        return TorchvisionDetector(name)

    return GroundingDinoDetector(name)

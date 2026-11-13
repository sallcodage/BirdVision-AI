"""
Détection d'oiseaux via Groq API (qwen/qwen3.8-27b vision).
Utilisé comme modèle cloud dans l'API Django BirdVision.
"""
import base64
import io
import json
import os

from PIL import Image, ImageDraw


def _encode_image(image_path):
    with Image.open(image_path) as img:
        img = img.convert("RGB")
        img.thumbnail((1280, 1280))
        w, h = img.size
        buf = io.BytesIO()
        img.save(buf, format="JPEG", quality=85)
        b64 = base64.b64encode(buf.getvalue()).decode()
    return b64, w, h


def _encode_bytes(jpeg_bytes):
    with Image.open(io.BytesIO(jpeg_bytes)) as img:
        img = img.convert("RGB")
        img.thumbnail((1280, 1280))
        w, h = img.size
        buf = io.BytesIO()
        img.save(buf, format="JPEG", quality=85)
        b64 = base64.b64encode(buf.getvalue()).decode()
    return b64, w, h


_PROMPT = (
    "Détecte TOUS les oiseaux visibles sur cette image, un par un. "
    "Réponds UNIQUEMENT avec un objet JSON : "
    '{"oiseaux": [{"box": [x1, y1, x2, y2], "confiance": 0.0, "espece": "..."}]} '
    "où box est en coordonnées normalisées de 0 à 1000 (coin haut-gauche, coin bas-droit), "
    "confiance est entre 0 et 1, espece est le nom en français (ou null). "
    "Si aucun oiseau, renvoie une liste vide."
)


def _call_groq(b64_image):
    from groq import Groq
    api_key = os.getenv("GROQ_API_KEY")
    if not api_key:
        raise ValueError("GROQ_API_KEY manquante dans backend/.env")
    client = Groq(api_key=api_key)
    completion = client.chat.completions.create(
        model="qwen/qwen3.8-27b",
        messages=[{
            "role": "user",
            "content": [
                {"type": "text", "text": _PROMPT},
                {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{b64_image}"}},
            ],
        }],
        temperature=0.1,
        max_tokens=800,
        response_format={"type": "json_object"},
    )
    return json.loads(completion.choices[0].message.content).get("oiseaux", [])


def detect_from_path(image_path, confidence=0.4):
    """
    Détecte les oiseaux dans une image (chemin fichier).
    Retourne (detections, img_width, img_height).
    detections = [{"box": {"x1","y1","x2","y2"} normalisé 0-1, "confidence", "class_name"}]
    """
    b64, w, h = _encode_image(image_path)
    birds = _call_groq(b64)
    return _parse(birds, confidence), w, h


def detect_from_bytes(jpeg_bytes, confidence=0.4):
    """
    Détecte les oiseaux dans des bytes JPEG (caméra live / vidéo).
    Retourne liste de dicts {x1, y1, x2, y2} normalisés 0-1.
    """
    b64, w, h = _encode_bytes(jpeg_bytes)
    birds = _call_groq(b64)
    return _parse(birds, confidence)


def _parse(birds, confidence):
    detections = []
    for b in birds:
        conf = float(b.get("confiance", 0))
        if conf < confidence:
            continue
        try:
            x1, y1, x2, y2 = (float(v) / 1000.0 for v in b["box"])
        except (KeyError, TypeError, ValueError):
            continue
        detections.append({
            "box": {"x1": x1, "y1": y1, "x2": x2, "y2": y2},
            "confidence": conf,
            "class_name": b.get("espece") or "oiseau",
        })
    return detections


def annotate_image(image_path, detections, output_path):
    """Dessine les boîtes sur l'image et sauvegarde."""
    with Image.open(image_path) as img:
        img = img.convert("RGB")
        w, h = img.size
        draw = ImageDraw.Draw(img)
        for d in detections:
            box = d["box"]
            x1, y1 = int(box["x1"] * w), int(box["y1"] * h)
            x2, y2 = int(box["x2"] * w), int(box["y2"] * h)
            draw.rectangle([x1, y1, x2, y2], outline="red", width=3)
            label = f"{d['class_name']} {d['confidence']:.0%}"
            draw.text((x1, max(y1 - 14, 0)), label, fill="red")
        img.save(output_path)

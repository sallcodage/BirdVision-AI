"""Test de la vision Groq sur une photo d'oiseau.

Usage :
    ..\\venv\\Scripts\\python.exe groq_tests\\deja_testes\\test_groq_vision.py ..\\test_images\\oiseau.jpg
"""
import argparse
import base64
import io
import os
import sys
import time
from pathlib import Path

from dotenv import load_dotenv
from groq import Groq
from PIL import Image

load_dotenv(Path(__file__).resolve().parents[2] / ".env")

parser = argparse.ArgumentParser()
parser.add_argument("image")
parser.add_argument("--model", default="qwen/qwen3.8-27b")
parser.add_argument(
    "--question",
    default="Combien d'oiseaux vois-tu sur cette photo ? De quelle(s) espèce(s) s'agit-il ? "
            "Donne ton niveau de certitude. Réponds en français, brièvement.",
)
args = parser.parse_args()

if not os.getenv("GROQ_API_KEY"):
    sys.exit("GROQ_API_KEY manquante : ajoute-la dans backend/.env")

# Réduction de l'image pour rester sous la limite d'envoi
img = Image.open(args.image).convert("RGB")
img.thumbnail((1280, 1280))
buffer = io.BytesIO()
img.save(buffer, format="JPEG", quality=85)
image_b64 = base64.b64encode(buffer.getvalue()).decode()

client = Groq()

print(f"Modèle : {args.model}")
print(f"Image : {args.image}\n")

start = time.time()
completion = client.chat.completions.create(
    model=args.model,
    messages=[{
        "role": "user",
        "content": [
            {"type": "text", "text": args.question},
            {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{image_b64}"}},
        ],
    }],
    temperature=0.2,
    max_tokens=2048,
)
elapsed = time.time() - start

print(completion.choices[0].message.content)
print(f"\n--- {elapsed:.2f}s | tokens : {completion.usage.total_tokens}")

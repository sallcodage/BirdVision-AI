"""Test rapide de l'API Groq.

Usage :
    ..\\venv\\Scripts\\python.exe groq_tests\\deja_testes\\test_groq.py
    ..\\venv\\Scripts\\python.exe groq_tests\\deja_testes\\test_groq.py "Ta question" --model="openai/gpt-oss-120b",
"""
import argparse
import os
import sys
import time
from pathlib import Path

from dotenv import load_dotenv
from groq import Groq

load_dotenv(Path(__file__).resolve().parents[2] / ".env")

parser = argparse.ArgumentParser()
parser.add_argument(
    "question",
    nargs="?",
    default="Décris en 3 phrases l'aigle royal (Aquila chrysaetos) : habitat, taille et alimentation.",
)
parser.add_argument("--model", default=os.getenv("GROQ_MODEL", "openai/gpt-oss-120b"))
args = parser.parse_args()

api_key = os.getenv("GROQ_API_KEY")
if not api_key:
    sys.exit("GROQ_API_KEY manquante : ajoute-la dans backend/.env")

client = Groq(api_key=api_key)

print(f"Modèle : {args.model}")
print(f"Question : {args.question}\n")

start = time.time()
completion = client.chat.completions.create(
    model=args.model,
    messages=[
        {"role": "system", "content": "Tu es un expert en ornithologie. Réponds en français."},
        {"role": "user", "content": args.question},
    ],
    temperature=0.5,
    max_tokens=2048,
)
elapsed = time.time() - start

print(completion.choices[0].message.content)
print(f"\n--- {elapsed:.2f}s | tokens : {completion.usage.total_tokens}")

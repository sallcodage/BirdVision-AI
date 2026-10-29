import json
import os
from pathlib import Path

from django.conf import settings
from dotenv import load_dotenv
from groq import Groq, GroqError
from rest_framework.decorators import api_view
from rest_framework.response import Response
from rest_framework import status


# ============================================
# CONFIGURATION GROQ
# ============================================

load_dotenv(Path(settings.BASE_DIR) / ".env")

GROQ_MODEL = os.getenv("GROQ_MODEL", "openai/gpt-oss-120b")

SYSTEM_PROMPT = (
    "Tu es un ornithologue rigoureux. On te donne le nom d'une espèce d'oiseau. "
    "Réponds UNIQUEMENT avec un objet JSON valide, en français, avec ces clés : "
    '"nom_commun", "nom_scientifique", "description" (2 phrases maximum), '
    '"habitat", "taille", "alimentation", "statut_conservation" (catégorie UICN), '
    '"present_au_senegal" (true, false ou null), "fiable" (true ou false). '
    "Si tu ne reconnais pas l'espèce ou n'es pas sûr d'une information, "
    'mets "fiable" à false et la valeur concernée à null. N\'invente jamais.'
)

_client = None


def _get_client():
    global _client
    if _client is None:
        api_key = os.getenv("GROQ_API_KEY")
        if not api_key:
            return None
        _client = Groq(api_key=api_key)
    return _client


# ============================================
# ROUTE : INFORMATIONS SUR UNE ESPÈCE
# ============================================

@api_view(["GET", "POST"])
def bird_info(request):
    species = (
        request.data.get("species")
        if request.method == "POST"
        else request.query_params.get("species")
    )
    species = (species or "").strip()

    if not species:
        return Response(
            {"error": "Paramètre 'species' requis (ex : 'Pélican blanc')."},
            status=status.HTTP_400_BAD_REQUEST,
        )
    if len(species) > 100:
        return Response(
            {"error": "Nom d'espèce trop long (100 caractères maximum)."},
            status=status.HTTP_400_BAD_REQUEST,
        )

    client = _get_client()
    if client is None:
        return Response(
            {"error": "GROQ_API_KEY manquante dans backend/.env."},
            status=status.HTTP_503_SERVICE_UNAVAILABLE,
        )

    try:
        completion = client.chat.completions.create(
            model=GROQ_MODEL,
            messages=[
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": f"Espèce : {species}"},
            ],
            temperature=0.2,
            max_tokens=2048,
            response_format={"type": "json_object"},
        )
        info = json.loads(completion.choices[0].message.content)
    except (GroqError, json.JSONDecodeError) as e:
        return Response(
            {"error": f"Erreur Groq : {e}"},
            status=status.HTTP_502_BAD_GATEWAY,
        )

    return Response({
        "species": species,
        "model": GROQ_MODEL,
        "info": info,
    })

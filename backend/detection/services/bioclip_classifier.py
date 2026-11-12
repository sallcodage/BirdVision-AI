
import csv
import threading
from pathlib import Path

import open_clip
import torch
from django.conf import settings
from PIL import Image


# =====================================================
# CONFIGURATION
# =====================================================

PROJECT_ROOT = Path(settings.BASE_DIR).parent

SPECIES_CSV = (
    PROJECT_ROOT
    / "datasets"
    / "species_senegal"
    / "species.csv"
)

MODEL_NAME = "hf-hub:imageomics/bioclip"
DEVICE = "cpu"

DEFAULT_TOP_K = 3


# =====================================================
# DESCRIPTIONS COMPLEMENTAIRES
# =====================================================

# Descriptions spécifiques pour certaines espèces.
# Les autres espèces utilisent automatiquement
# les descriptions génériques.

SPECIES_EXTRA_PROMPTS = {
    "Poicephalus senegalus": [
        "A photograph of a Senegal parrot.",
        "A close-up photo of a Senegal parrot, Poicephalus senegalus.",
        "A green parrot with a grey head and an orange yellow belly.",
        "A Senegal parrot with green wings and a grey head.",
        "A wildlife photograph of Poicephalus senegalus."
    ]
}


def build_species_prompts(item):
    """
    Construit plusieurs descriptions textuelles
    pour une même espèce.
    """

    common_name = item["common_name"].strip()
    scientific_name = item["scientific_name"].strip()

    prompts = [
        (
            f"A photograph of a bird named "
            f"{common_name} ({scientific_name})."
        ),
        (
            f"A wildlife photograph of "
            f"{scientific_name}, commonly called "
            f"{common_name}."
        ),
        (
            f"A close-up photograph of the bird species "
            f"{scientific_name}."
        ),
        (
            f"A natural photograph showing "
            f"{common_name}, a bird."
        )
    ]

    prompts.extend(
        SPECIES_EXTRA_PROMPTS.get(scientific_name, [])
    )

    return prompts


# =====================================================
# VARIABLES GLOBALES
# =====================================================

_model = None
_preprocess = None
_tokenizer = None
_species = None
_text_features = None

_model_lock = threading.RLock()


# =====================================================
# CHARGEMENT DU CATALOGUE
# =====================================================

def load_species():
    """
    Charge les espèces candidates depuis le CSV.
    """

    global _species

    with _model_lock:

        if _species is not None:
            return _species

        if not SPECIES_CSV.is_file():
            raise FileNotFoundError(
                f"Catalogue introuvable : {SPECIES_CSV}"
            )

        with open(
            SPECIES_CSV,
            "r",
            encoding="utf-8-sig",
            newline=""
        ) as file:

            reader = csv.DictReader(file)

            required_columns = {
                "species_id",
                "common_name",
                "scientific_name",
                "category"
            }

            if not required_columns.issubset(
                reader.fieldnames or []
            ):
                raise ValueError(
                    "Colonnes manquantes dans le catalogue CSV."
                )

            species = list(reader)

        if not species:
            raise ValueError(
                "Le catalogue des espèces est vide."
            )

        for item in species:

            for column in required_columns:
                if not item.get(column) or not item[column].strip():
                    raise ValueError(
                        f"Valeur vide dans la colonne {column}."
                    )

        scientific_names = [
            item["scientific_name"].strip()
            for item in species
        ]

        if len(scientific_names) != len(set(scientific_names)):
            raise ValueError(
                "Le catalogue contient des espèces en double."
            )

        _species = species

        return _species


# =====================================================
# CHARGEMENT UNIQUE DE BIOCLIP
# =====================================================

def get_bioclip():
    """
    Charge BioCLIP une seule fois.
    """

    global _model, _preprocess, _tokenizer

    with _model_lock:

        if _model is None:

            _model, _, _preprocess = (
                open_clip.create_model_and_transforms(
                    MODEL_NAME,
                    device=DEVICE
                )
            )

            _model.eval()

            _tokenizer = open_clip.get_tokenizer(
                MODEL_NAME
            )

        return _model, _preprocess, _tokenizer


# =====================================================
# ENCODAGE DES DESCRIPTIONS
# =====================================================

def get_species_features():
    """
    Encode plusieurs descriptions par espèce.

    Les caractéristiques textuelles sont calculées
    une seule fois et conservées en mémoire.
    """

    global _text_features

    with _model_lock:

        if _text_features is not None:
            return _text_features

        model, _, tokenizer = get_bioclip()

        species = load_species()

        all_prompts = []
        prompt_counts = []

        for item in species:

            prompts = build_species_prompts(item)

            all_prompts.extend(prompts)
            prompt_counts.append(len(prompts))

        tokens = tokenizer(all_prompts).to(DEVICE)

        with torch.inference_mode():

            features = model.encode_text(tokens)

            features = features / features.norm(
                dim=-1,
                keepdim=True
            ).clamp(min=1e-12)

        # Regroupe les descriptions de chaque espèce.
        grouped_features = []

        start = 0

        for count in prompt_counts:

            end = start + count

            species_features = features[start:end]

            grouped_features.append(species_features)

            start = end

        _text_features = grouped_features

        return _text_features


# =====================================================
# IDENTIFICATION D'UN OISEAU
# =====================================================

def identify_species(image, top_k=DEFAULT_TOP_K):
    """
    Identifie les espèces candidates dans une image.

    Plusieurs descriptions sont comparées pour chaque
    espèce. Leurs similarités sont ensuite moyennées.

    Args:
        image: image PIL représentant un oiseau.
        top_k: nombre de propositions à retourner.

    Returns:
        Liste des espèces classées par similarité.
    """

    if not isinstance(image, Image.Image):
        raise TypeError(
            "L'image doit être un objet PIL.Image."
        )

    if image.width < 10 or image.height < 10:
        raise ValueError(
            "Image trop petite pour l'identification."
        )

    if not isinstance(top_k, int) or top_k < 1:
        raise ValueError(
            "top_k doit être un entier positif."
        )

    species = load_species()

    model, preprocess, _ = get_bioclip()

    text_features = get_species_features()

    image = image.convert("RGB")

    image_tensor = (
        preprocess(image)
        .unsqueeze(0)
        .to(DEVICE)
    )

    with torch.inference_mode():

        image_features = model.encode_image(image_tensor)

        image_features = image_features / image_features.norm(
            dim=-1,
            keepdim=True
        ).clamp(min=1e-12)

        # Calcule la similarité pour chaque description,
        # puis moyenne les scores par espèce.

        species_scores = []

        for features in text_features:

            similarities = (
                image_features @ features.T
            )[0]

            mean_score = similarities.mean()

            species_scores.append(mean_score)

        scores = torch.stack(species_scores)

        number_results = min(top_k, len(species))

        top_scores, indices = torch.topk(
            scores,
            k=number_results
        )

    results = []

    for score, index in zip(
        top_scores.tolist(),
        indices.tolist()
    ):

        item = species[index]

        results.append({
            "species_id": item["species_id"],
            "common_name": item["common_name"],
            "scientific_name": item["scientific_name"],
            "category": item["category"],
            "similarity": round(float(score), 4)
        })

    return results

def get_image_embedding(image):
    """
    Transforme une image en vecteur numérique BioCLIP.
    Ce vecteur servira à retrouver les espèces mémorisées.
    """

    if not isinstance(image, Image.Image):
        raise TypeError("L'image doit être un objet PIL.Image.")

    model, preprocess, _ = get_bioclip()

    image = image.convert("RGB")
    image_tensor = preprocess(image).unsqueeze(0).to(DEVICE)

    with torch.inference_mode():
        features = model.encode_image(image_tensor)

        features = features / features.norm(
            dim=-1,
            keepdim=True
        ).clamp(min=1e-12)

    return features.squeeze(0).cpu().tolist()

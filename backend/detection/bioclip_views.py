import numpy as np
from PIL import Image, ImageOps
from django.core.files.base import ContentFile
from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework.decorators import api_view, parser_classes
from rest_framework.parsers import MultiPartParser, FormParser
from rest_framework.response import Response
from rest_framework import status
from .models import BirdObservation, BirdSpecies, BirdReferenceImage



@api_view(["POST"])
@parser_classes([MultiPartParser, FormParser])

def identify_bird_species(request):
    """
    Recherche d'abord une espèce dans la mémoire BirdVision.
    Si aucune correspondance fiable n'est trouvée,
    utilise BioCLIP pour proposer les 3 meilleures espèces.
    """

    image_file = request.FILES.get("image")

    if image_file is None:
        return Response(
            {
                "success": False,
                "error": "Aucune image fournie."
            },
            status=status.HTTP_400_BAD_REQUEST
        )

    try:
        from .services.bioclip_classifier import (
            identify_species,
            get_image_embedding
        )

        # Seuil expérimental à calibrer avec des images de test.
        MEMORY_THRESHOLD = 0.90

        # Préparation de l'image
        image_file.seek(0)
        original_bytes = image_file.read()
        image_file.seek(0)

        with Image.open(image_file) as uploaded_image:
            image = ImageOps.exif_transpose(
                uploaded_image
            ).convert("RGB")

        # Extraction de l'embedding BioCLIP
        embedding = get_image_embedding(image)
        new_vector = np.asarray(embedding, dtype=np.float32)

        predictions = []
        recognition_source = "bioclip"
        memory_similarity = None

        # Recherche dans la mémoire
        references = (
            BirdReferenceImage.objects
            .select_related("species")
            .all()
        )

        species_scores = {}

        for reference in references:
            if not reference.embedding:
                continue

            reference_vector = np.asarray(
                reference.embedding,
                dtype=np.float32
            )

            if reference_vector.shape != new_vector.shape:
                continue

            if not np.all(np.isfinite(reference_vector)):
                continue

            similarity = float(
                np.dot(new_vector, reference_vector)
                / (
                    np.linalg.norm(new_vector)
                    * np.linalg.norm(reference_vector)
                    + 1e-12
                )
            )

            species_id = reference.species_id

            # On conserve le meilleur score par espèce.
            if (
                species_id not in species_scores
                or similarity > species_scores[species_id]["similarity"]
            ):
                species_scores[species_id] = {
                    "species": reference.species,
                    "similarity": similarity
                }

        # Recherche de la meilleure espèce mémorisée
        if species_scores:
            best_match = max(
                species_scores.values(),
                key=lambda item: item["similarity"]
            )

            if best_match["similarity"] >= MEMORY_THRESHOLD:
                species = best_match["species"]
                memory_similarity = round(
                    best_match["similarity"], 4
                )

                predictions = [{
                    "species_id": str(species.id),
                    "common_name": species.common_name,
                    "scientific_name": species.scientific_name or "",
                    "similarity": memory_similarity,
                    "source": "memory"
                }]

                recognition_source = "memory"

        # Aucun résultat suffisamment fiable :
        # BioCLIP propose les trois meilleurs candidats.
        if recognition_source == "bioclip":
            predictions = identify_species(
                image,
                top_k=3
            )

        # Enregistrement de l'observation en attente
        observation = BirdObservation(
            predicted_species=(
                predictions[0]["common_name"]
                if predictions else ""
            ),
            predicted_scientific_name=(
                predictions[0]["scientific_name"]
                if predictions else ""
            ),
            alternatives=predictions,
            embedding=embedding,
            status="pending"
        )

        filename = (
            image_file.name.replace("\\", "/").split("/")[-1]
            or "bird_observation.jpg"
        )

        observation.image.save(
            filename,
            ContentFile(original_bytes),
            save=False
        )

        observation.save()

        return Response(
            {
                "success": True,
                "model": "BioCLIP ViT-B/16",
                "device": "cpu",
                "observation_id": observation.id,
                "status": observation.status,
                "recognition_source": recognition_source,
                "memory_match": recognition_source == "memory",
                "memory_similarity": memory_similarity,
                "message": (
                    "Espèce retrouvée dans la mémoire BirdVision."
                    if recognition_source == "memory"
                    else "Identification proposée par BioCLIP."
                ),
                "predictions": predictions
            },
            status=status.HTTP_200_OK
        )

    except Exception as error:
        return Response(
            {
                "success": False,
                "error": str(error)
            },
            status=status.HTTP_500_INTERNAL_SERVER_ERROR
        )


@api_view(["POST"])
def validate_bird_observation(request):
    """
    Confirme, corrige ou classe une observation.

    Actions possibles :
    - confirm : confirme une proposition BioCLIP.
    - manual : enregistre un nom donné par l'utilisateur.
    - unclassified : conserve l'oiseau sans identification.
    """

    observation_id = request.data.get("observation_id")
    action = request.data.get("action")

    if not observation_id or not action:
        return Response(
            {
                "success": False,
                "error": "observation_id et action sont obligatoires."
            },
            status=status.HTTP_400_BAD_REQUEST
        )

    observation = get_object_or_404(
        BirdObservation,
        id=observation_id
    )

    if observation.status != "pending":
        return Response(
            {
                "success": False,
                "error": "Cette observation a déjà été traitée."
            },
            status=status.HTTP_400_BAD_REQUEST
        )

    # ==========================================
    # CAS 1 : CONFIRMER UNE PROPOSITION BIOCLIP
    # ==========================================

    if action == "confirm":

        try:
            selected_index = int(
                request.data.get("selected_index", 0)
            )

            predictions = observation.alternatives

            if selected_index < 0 or selected_index >= len(predictions):
                raise ValueError()

            selected = predictions[selected_index]

        except (ValueError, TypeError, IndexError):
            return Response(
                {
                    "success": False,
                    "error": "Proposition sélectionnée invalide."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

        common_name = selected.get("common_name", "").strip()
        scientific_name = selected.get("scientific_name", "").strip()

    # ==========================================
    # CAS 2 : NOM DONNE MANUELLEMENT
    # ==========================================

    elif action == "manual":

        common_name = str(
            request.data.get("common_name", "")
        ).strip()

        scientific_name = str(
            request.data.get("scientific_name", "")
        ).strip()

        if not common_name:
            return Response(
                {
                    "success": False,
                    "error": "Le nom de l'espèce est obligatoire."
                },
                status=status.HTTP_400_BAD_REQUEST
            )

    # ==========================================
    # CAS 3 : ESPECE NON CLASSEE
    # ==========================================

    elif action == "unclassified":

        observation.status = "unclassified"
        observation.confirmed_species = None
        observation.validated_at = timezone.now()
        observation.save()

        return Response(
            {
                "success": True,
                "message": "Observation enregistrée dans les espèces non classées.",
                "observation_id": observation.id,
                "status": observation.status
            },
            status=status.HTTP_200_OK
        )

    else:
        return Response(
            {
                "success": False,
                "error": "Action non reconnue."
            },
            status=status.HTTP_400_BAD_REQUEST
        )

    # ==========================================
    # ENREGISTREMENT DE L'ESPECE VALIDEE
    # ==========================================

    species, created = BirdSpecies.objects.get_or_create(
        common_name=common_name,
        scientific_name=scientific_name
    )

    observation.confirmed_species = species
    observation.status = "confirmed"
    observation.validated_at = timezone.now()
    observation.save()

    # ==========================================
    # ENREGISTREMENT DE LA PHOTO DE REFERENCE
    # ==========================================

    BirdReferenceImage.objects.create(
        species=species,
        image=observation.image.name,
        embedding=observation.embedding
    )

    return Response(
        {
            "success": True,
            "message": "Espèce confirmée et mémorisée avec succès.",
            "observation_id": observation.id,
            "species": {
                "id": species.id,
                "common_name": species.common_name,
                "scientific_name": species.scientific_name
            },
            "status": observation.status,
            "new_species": created
        },
        status=status.HTTP_200_OK
    )

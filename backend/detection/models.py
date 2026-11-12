from django.db import models


class Detection(models.Model):
    MODEL_CHOICES = [
        ("rtdetr-x", "RT-DETR-X"),
        ("yolo26s", "YOLO26s"),
        ("dfine-x", "D-FINE-X"),
    ]

    image = models.ImageField(upload_to="detections/")
    model = models.CharField(max_length=20, choices=MODEL_CHOICES)
    confidence_threshold = models.FloatField()
    bird_count = models.PositiveIntegerField(default=0)
    detections = models.JSONField(default=list)
    result_image = models.ImageField(
        upload_to="detections/results/",
        blank=True,
        null=True,
    )
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return (
            f"{self.model} - "
            f"{self.bird_count} oiseau(x) - "
            f"{self.created_at:%d/%m/%Y %H:%M}"
        )


# =====================================================
# MEMOIRE INTELLIGENTE BIRDVISION AI
# =====================================================

class BirdSpecies(models.Model):
    """
    Espèce validée et mémorisée par BirdVision AI.
    """

    common_name = models.CharField(
        max_length=150,
    )

    scientific_name = models.CharField(
        max_length=200,
        blank=True,
        null=True,
    )

    description = models.TextField(
        blank=True,
    )

    created_at = models.DateTimeField(
        auto_now_add=True,
    )

    updated_at = models.DateTimeField(
        auto_now=True,
    )

    def __str__(self):
        return self.common_name


class BirdReferenceImage(models.Model):
    """
    Image de référence associée à une espèce validée.
    """

    species = models.ForeignKey(
        BirdSpecies,
        on_delete=models.CASCADE,
        related_name="reference_images",
    )

    image = models.ImageField(
        upload_to="bird_memory/references/",
    )

    # Embedding visuel BioCLIP stocké sous forme de liste.
    embedding = models.JSONField(
        default=list,
    )

    validated_at = models.DateTimeField(
        auto_now_add=True,
    )

    def __str__(self):
        return f"Référence - {self.species.common_name}"


class BirdObservation(models.Model):
    """
    Historique des identifications et corrections humaines.
    """

    STATUS_CHOICES = [
        ("pending", "En attente de validation"),
        ("confirmed", "Espèce confirmée"),
        ("unclassified", "Espèce non classée"),
    ]

    image = models.ImageField(
        upload_to="bird_memory/observations/",
    )

    predicted_species = models.CharField(
        max_length=200,
        blank=True,
    )

    predicted_scientific_name = models.CharField(
        max_length=200,
        blank=True,
    )

    alternatives = models.JSONField(
        default=list,
        blank=True,
    )

    confirmed_species = models.ForeignKey(
        BirdSpecies,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="observations",
    )

    status = models.CharField(
        max_length=20,
        choices=STATUS_CHOICES,
        default="pending",
    )

    # Embedding de l'image observée.
    embedding = models.JSONField(
        default=list,
        blank=True,
    )

    created_at = models.DateTimeField(
        auto_now_add=True,
    )

    validated_at = models.DateTimeField(
        null=True,
        blank=True,
    )

    def __str__(self):
        return (
            f"Observation {self.id} - "
            f"{self.get_status_display()}"
        )

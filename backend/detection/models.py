
from django.conf import settings
from django.db import models


MODEL_CHOICES = [
    ("rtdetr-x", "RT-DETR-X"),
    ("yolo26s", "YOLO26s"),
    ("dfine-x", "D-FINE-X"),
    ("dfine-s", "D-FINE-S"),
    ("rfdetr-s", "RF-DETR-S"),
    ("faster-rcnn", "Faster R-CNN"),
]


class Detection(models.Model):
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="detections",
    )

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
# MÉMOIRE INTELLIGENTE BIRDVISION AI - BIOCLIP
# =====================================================

class BirdSpecies(models.Model):
    common_name = models.CharField(max_length=150)
    scientific_name = models.CharField(
        max_length=200,
        blank=True,
        null=True,
    )
    description = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self):
        return self.common_name


class BirdReferenceImage(models.Model):
    species = models.ForeignKey(
        BirdSpecies,
        on_delete=models.CASCADE,
        related_name="reference_images",
    )
    image = models.ImageField(
        upload_to="bird_memory/references/",
    )
    embedding = models.JSONField(default=list)
    validated_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"Référence - {self.species.common_name}"


class BirdObservation(models.Model):
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
    embedding = models.JSONField(
        default=list,
        blank=True,
    )
    created_at = models.DateTimeField(auto_now_add=True)
    validated_at = models.DateTimeField(
        null=True,
        blank=True,
    )

    def __str__(self):
        return (
            f"Observation {self.id} - "
            f"{self.get_status_display()}"
        )


# =====================================================
# SUIVI DES OISEAUX - TRACKING
# =====================================================

class TrackingSession(models.Model):
    SOURCE_CHOICES = [
        ("live", "Caméra live"),
        ("video", "Vidéo importée"),
    ]
    STATUS_CHOICES = [
        ("active", "Active"),
        ("done", "Terminée"),
        ("error", "Erreur"),
    ]

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="tracking_sessions",
    )
    session_id = models.CharField(
        max_length=64,
        unique=True,
        db_index=True,
    )
    source = models.CharField(
        max_length=10,
        choices=SOURCE_CHOICES,
    )
    model = models.CharField(
        max_length=20,
        choices=MODEL_CHOICES,
    )
    confidence_threshold = models.FloatField()

    unique_bird_count = models.PositiveIntegerField(default=0)
    total_detections = models.PositiveIntegerField(default=0)
    duration_seconds = models.FloatField(null=True, blank=True)
    fps = models.FloatField(null=True, blank=True)

    result_video = models.CharField(max_length=500, blank=True)

    status = models.CharField(
        max_length=10,
        choices=STATUS_CHOICES,
        default="active",
    )
    created_at = models.DateTimeField(auto_now_add=True)
    ended_at = models.DateTimeField(null=True, blank=True)

    def __str__(self):
        return (
            f"{self.source} | {self.model} | "
            f"{self.unique_bird_count} oiseaux uniques | "
            f"{self.created_at:%d/%m/%Y %H:%M}"
        )


class TrackedBird(models.Model):
    STATUS_CHOICES = [
        ("tracking", "En cours"),
        ("lost", "Perdu"),
        ("done", "Terminé"),
    ]

    session = models.ForeignKey(
        TrackingSession,
        on_delete=models.CASCADE,
        related_name="birds",
    )
    tracker_id = models.PositiveIntegerField()

    frame_count = models.PositiveIntegerField(default=0)
    total_confidence = models.FloatField(default=0.0)
    avg_confidence = models.FloatField(default=0.0)
    max_confidence = models.FloatField(default=0.0)

    last_x1 = models.FloatField(default=0.0)
    last_y1 = models.FloatField(default=0.0)
    last_x2 = models.FloatField(default=0.0)
    last_y2 = models.FloatField(default=0.0)

    first_seen = models.DateTimeField(auto_now_add=True)
    last_seen = models.DateTimeField(auto_now=True)
    status = models.CharField(
        max_length=10,
        choices=STATUS_CHOICES,
        default="tracking",
    )

    class Meta:
        unique_together = ("session", "tracker_id")

    def __str__(self):
        return (
            f"Bird #{self.tracker_id:03d} | "
            f"session {self.session.session_id[:8]} | "
            f"{self.frame_count} frames"
        )

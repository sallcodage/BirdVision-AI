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

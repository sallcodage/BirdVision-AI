from django.contrib import admin
from .models import Detection


@admin.register(Detection)
class DetectionAdmin(admin.ModelAdmin):
    list_display = (
        "id",
        "model",
        "bird_count",
        "confidence_threshold",
        "created_at",
    )

    list_filter = (
        "model",
        "created_at",
    )

    search_fields = (
        "model",
    )

    ordering = ("-created_at",)

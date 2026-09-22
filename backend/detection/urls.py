from django.urls import path
from .views import detect_birds

urlpatterns = [
    path("detect/", detect_birds, name="detect-birds"),
]
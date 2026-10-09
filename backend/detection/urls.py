from django.urls import path
from .views import detect_birds, detect_video

urlpatterns = [
    path("detect/", detect_birds, name="detect-birds"),
    path("detect-video/", detect_video, name="detect-video"),
]
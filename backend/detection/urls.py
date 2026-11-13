
from django.urls import path

from .views import (
    detect_birds,
    detect_frame,
    detect_video,
    video_job_status,
    detection_history,
    close_live_session,
    tracking_sessions,
    tracking_session_detail,
)

from .bioclip_views import (
    identify_bird_species,
    validate_bird_observation,
)

from .bird_info import bird_info



urlpatterns = [
    # Informations sur les oiseaux
    path("bird-info/", bird_info, name="bird-info"),

    # Détection classique
    path("detect/", detect_birds, name="detect-birds"),

    # Détection en direct
    path("detect-frame/", detect_frame, name="detect-frame"),

    # Détection vidéo
    path("detect-video/", detect_video, name="detect-video"),
    path(
        "detect-video/<str:job_id>/",
        video_job_status,
        name="video-job-status",
    ),

    # Historique des détections
    path("history/", detection_history, name="detection-history"),

    # Suivi des oiseaux
    path("sessions/", tracking_sessions, name="tracking-sessions"),
    path(
        "sessions/close/",
        close_live_session,
        name="close-live-session",
    ),
    path(
        "sessions/<str:session_id>/",
        tracking_session_detail,
        name="tracking-session-detail",
    ),

    # Identification intelligente BioCLIP
    path(
        "identify-species/",
        identify_bird_species,
        name="identify-species",
    ),
    path(
        "validate-observation/",
        validate_bird_observation,
        name="validate-bird-observation",
    ),
]

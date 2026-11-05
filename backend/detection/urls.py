
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
from .bird_info import bird_info
from .auth_views import register, login

urlpatterns = [
    path("bird-info/", bird_info, name="bird-info"),
    path("detect/", detect_birds, name="detect-birds"),
    path("detect-frame/", detect_frame, name="detect-frame"),
    path("detect-video/", detect_video, name="detect-video"),
    path("detect-video/<str:job_id>/", video_job_status, name="video-job-status"),
    path("history/", detection_history, name="detection-history"),
    path("sessions/", tracking_sessions, name="tracking-sessions"),
    path("sessions/close/", close_live_session, name="close-live-session"),
    path("sessions/<str:session_id>/", tracking_session_detail, name="tracking-session-detail"),
    path("auth/register/", register, name="register"),
    path("auth/login/", login, name="login"),
]

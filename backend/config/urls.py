
from pathlib import Path

from django.contrib import admin
from django.urls import path, include, re_path
from django.conf import settings
from django.conf.urls.static import static
from django.views.static import serve

from .views import home

FRONTEND_DIST = Path(settings.BASE_DIR).parent / "frontend" / "dist"

urlpatterns = [
    # Administration Django
    path("admin/", admin.site.urls),

    # API de détection
    path("api/", include("detection.urls")),

    # API d'authentification
    path("api/auth/", include("accounts.urls")),

    # Fichiers statiques React
    re_path(
        r"^assets/(?P<path>.*)$",
        serve,
        {"document_root": FRONTEND_DIST / "assets"},
    ),
]

# Fichiers médias : AVANT la route React
if settings.DEBUG:
    urlpatterns += static(
        settings.MEDIA_URL,
        document_root=settings.MEDIA_ROOT,
    )

# Application React : toujours en dernier
urlpatterns += [
    re_path(r"^.*$", home, name="home"),
]

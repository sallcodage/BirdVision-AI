
from django.contrib import admin
from django.urls import path, include
from django.conf import settings
from django.conf.urls.static import static

urlpatterns = [
    # Administration Django
    path("admin/", admin.site.urls),

    # API de détection des oiseaux
    path("api/", include("detection.urls")),

    # API d'inscription et de connexion
    path("api/auth/", include("accounts.urls")),
]

if settings.DEBUG:
    urlpatterns += static(
        settings.MEDIA_URL,
        document_root=settings.MEDIA_ROOT
    )

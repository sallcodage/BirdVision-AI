from django.urls import path
from .views import detect_birds
from .bioclip_views import identify_bird_species, validate_bird_observation

urlpatterns = [
    path("detect/", detect_birds, name="detect-birds"),
    path("identify-species/", identify_bird_species, name="identify-species"),
    path("validate-observation/", validate_bird_observation, name="validate-bird-observation"),
]
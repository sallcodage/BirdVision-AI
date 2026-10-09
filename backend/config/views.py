from django.http import JsonResponse


def home(request):
    return JsonResponse(
        {
            "message": "BirdVision AI API",
            "status": "online",
            "endpoint": "/api/detect/",
        }
    )

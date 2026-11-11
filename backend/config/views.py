from pathlib import Path
from django.http import JsonResponse, FileResponse, Http404
from django.conf import settings


def home(request):
    index_path = Path(settings.BASE_DIR).parent / "frontend" / "dist" / "index.html"
    if index_path.exists():
        return FileResponse(open(index_path, "rb"), content_type="text/html")
    return JsonResponse({"message": "BirdVision AI API", "status": "online"})

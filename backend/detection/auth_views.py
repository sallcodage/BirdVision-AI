
import json
import secrets

from django.contrib.auth import authenticate, get_user_model
from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.views.decorators.http import require_POST


User = get_user_model()


@csrf_exempt
@require_POST
def register(request):
    try:
        data = json.loads(request.body)
    except (json.JSONDecodeError, UnicodeDecodeError):
        return JsonResponse({"error": "JSON invalide."}, status=400)

    username = str(data.get("username") or "").strip()
    email = str(data.get("email") or "").strip().lower()
    password = data.get("password") or ""

    if not username or not email or not password:
        return JsonResponse(
            {"error": "Nom d'utilisateur, email et mot de passe obligatoires."},
            status=400,
        )

    if User.objects.filter(username__iexact=username).exists():
        return JsonResponse(
            {"error": "Ce nom d'utilisateur existe déjà."},
            status=400,
        )

    if User.objects.filter(email__iexact=email).exists():
        return JsonResponse(
            {"error": "Cette adresse email est déjà utilisée."},
            status=400,
        )

    try:
        validate_password(password)
    except ValidationError as exc:
        return JsonResponse({"error": list(exc.messages)}, status=400)

    user = User.objects.create_user(
        username=username,
        email=email,
        password=password,
    )

    return JsonResponse(
        {
            "message": "Inscription réussie.",
            "user": {
                "id": user.pk,
                "username": user.username,
                "email": user.email,
            },
        },
        status=201,
    )


@csrf_exempt
@require_POST
def login(request):
    try:
        data = json.loads(request.body)
    except (json.JSONDecodeError, UnicodeDecodeError):
        return JsonResponse({"error": "JSON invalide."}, status=400)

    email = str(data.get("email") or "").strip().lower()
    username = str(data.get("username") or "").strip()
    password = data.get("password") or ""

    if (not email and not username) or not password:
        return JsonResponse(
            {"error": "Email ou nom d'utilisateur et mot de passe obligatoires."},
            status=400,
        )

    # Accepter une adresse email ou un nom d'utilisateur.
    if email:
        user_obj = User.objects.filter(email__iexact=email).first()

        if user_obj is None:
            return JsonResponse(
                {"error": "Identifiants incorrects."},
                status=401,
            )

        username = user_obj.get_username()

    user = authenticate(
        request,
        username=username,
        password=password,
    )

    if user is None:
        return JsonResponse(
            {"error": "Identifiants incorrects."},
            status=401,
        )

    # Jeton temporaire compatible avec le format attendu par Login.jsx.
    # Pour une authentification sécurisée, remplacer par un vrai système de tokens.
    token = secrets.token_urlsafe(32)

    return JsonResponse(
        {
            "message": "Connexion réussie.",
            "token": token,
            "user": {
                "id": user.pk,
                "username": user.username,
                "email": user.email,
            },
        }
    )

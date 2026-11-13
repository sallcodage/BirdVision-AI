
from django.contrib.auth import authenticate
from django.contrib.auth.models import User

from rest_framework.decorators import (
    api_view,
    permission_classes,
)
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework import status
from rest_framework.authtoken.models import Token

from .serializers import RegisterSerializer


@api_view(["POST"])
@permission_classes([AllowAny])
def register(request):
    serializer = RegisterSerializer(data=request.data)

    if not serializer.is_valid():
        return Response(
            serializer.errors,
            status=status.HTTP_400_BAD_REQUEST
        )

    user = serializer.save()

    token, _ = Token.objects.get_or_create(user=user)

    return Response(
        {
            "message": "Compte créé avec succès.",
            "token": token.key,
            "user": {
                "id": user.id,
                "name": user.first_name,
                "email": user.email,
            },
        },
        status=status.HTTP_201_CREATED
    )


@api_view(["POST"])
@permission_classes([AllowAny])
def login(request):
    email = str(request.data.get("email", "")).strip().lower()
    password = request.data.get("password", "")

    if not email or not password:
        return Response(
            {"error": "Email et mot de passe obligatoires."},
            status=status.HTTP_400_BAD_REQUEST
        )

    user = authenticate(
        request,
        username=email,
        password=password
    )

    if user is None:
        return Response(
            {"error": "Email ou mot de passe incorrect."},
            status=status.HTTP_400_BAD_REQUEST
        )

    token, _ = Token.objects.get_or_create(user=user)

    return Response({
        "message": "Connexion réussie.",
        "token": token.key,
        "user": {
            "id": user.id,
            "name": user.first_name,
            "email": user.email,
        },
    })


from django.contrib.auth.models import User
from django.contrib.auth.password_validation import validate_password
from rest_framework import serializers


class RegisterSerializer(serializers.ModelSerializer):
    name = serializers.CharField(
        write_only=True,
        max_length=150
    )
    password = serializers.CharField(
        write_only=True,
        validators=[validate_password]
    )
    confirm_password = serializers.CharField(
        write_only=True
    )

    class Meta:
        model = User
        fields = [
            "name",
            "email",
            "password",
            "confirm_password",
        ]

    def validate_email(self, value):
        email = value.strip().lower()

        if User.objects.filter(email__iexact=email).exists():
            raise serializers.ValidationError(
                "Cette adresse e-mail est déjà utilisée."
            )

        return email

    def validate(self, attrs):
        if attrs["password"] != attrs["confirm_password"]:
            raise serializers.ValidationError({
                "confirm_password": "Les mots de passe ne correspondent pas."
            })

        return attrs

    def create(self, validated_data):
        validated_data.pop("confirm_password")

        name = validated_data.pop("name").strip()
        email = validated_data.pop("email")
        password = validated_data.pop("password")

        user = User(
            username=email,
            email=email,
            first_name=name,
        )
        user.set_password(password)
        user.save()

        return user

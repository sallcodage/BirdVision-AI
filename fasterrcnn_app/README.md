# BirdVision Flutter

Application Flutter BirdVision pour détecter les oiseaux avec le backend Django
du dossier `backend`. **RF-DETR-S** est sélectionné par défaut ; le modèle peut
être changé dans les réglages. L'application envoie les images et vidéos à l'API :
les poids restent sur le serveur.

Les modèles disponibles dans les réglages sont RF-DETR-S, Faster R-CNN,
D-FINE-S, D-FINE-X, YOLO26s et RT-DETR-X.

## Lancer le backend Django (sur le PC)

```cmd
cd C:\Users\PC\OneDrive\Desktop\BirdVision-AI\backend
python manage.py runserver 0.0.0.0:8000
```

Le backend expose notamment :

- `POST /api/detect/` avec un champ multipart `image`, `model=rfdetr-s` et `confidence`.
- `POST /api/detect-frame/` avec un champ multipart `image` pour la caméra.
- `POST /api/detect-video/` avec un champ multipart `video` pour l'analyse vidéo.

Le téléphone et le PC doivent être sur le même réseau Wi-Fi. Dans les réglages
de l'application, remplacez l'adresse du serveur par l'adresse IPv4 locale du PC
(par exemple `http://192.168.1.9:8000`). Lancez le serveur Django avec
`0.0.0.0:8000`, puis utilisez le bouton **Tester** dans l'application.
L'adresse `127.0.0.1` ne fonctionne pas sur un téléphone : elle désigne le
téléphone lui-même. HTTP non chiffré est prévu ici pour le réseau local de
développement ; utilisez HTTPS pour un serveur accessible publiquement.

## Compiler l'APK

Gradle demande Java 17 :

```cmd
set JAVA_HOME=C:\Users\PC\.jdks\jdk-17.0.20.1+1
cd C:\Users\PC\OneDrive\Desktop\BirdVision-AI\fasterrcnn_app
flutter build apk --release
```

L'APK généré se trouve dans
`build\app\outputs\flutter-apk\app-release.apk`. Le temps de détection dépend
du matériel qui exécute Django et du modèle choisi.

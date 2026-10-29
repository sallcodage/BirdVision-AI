import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart' show XFile;

/// Cadre d'un oiseau, coordonnées entre 0 et 1.
class BirdBox {
  const BirdBox(this.x1, this.y1, this.x2, this.y2, this.confidence);

  factory BirdBox.fromJson(Map<String, dynamic> j) => BirdBox(
    (j['x1'] as num).toDouble(),
    (j['y1'] as num).toDouble(),
    (j['x2'] as num).toDouble(),
    (j['y2'] as num).toDouble(),
    (j['confidence'] as num).toDouble(),
  );

  final double x1, y1, x2, y2, confidence;
}

/// Cadres trouvés sur l'image de la vidéo à l'instant [t] (secondes).
class TimedBoxes {
  const TimedBoxes(this.t, this.boxes);

  factory TimedBoxes.fromJson(Map<String, dynamic> j) =>
      TimedBoxes((j['t'] as num).toDouble(), [
        for (final b in j['boxes'] as List)
          BirdBox.fromJson(b as Map<String, dynamic>),
      ]);

  final double t;
  final List<BirdBox> boxes;
}

/// Client de l'API Django BirdVision (RF-DETR-S par défaut).
class BirdVisionApi {
  BirdVisionApi(this.baseUrl);

  /// Exemple : http://192.168.1.12:8000
  final String baseUrl;

  static const model = 'rfdetr-s';

  /// Modèle rapide proposé pour la caméra en direct.
  static const fastModel = 'yolo26s';

  /// Modèles du backend Django : identifiant -> nom affiché.
  static const models = {
    'rfdetr-s': 'RF-DETR-S',
    'faster-rcnn': 'Faster R-CNN',
    'dfine-s': 'D-FINE-S',
    'dfine-x': 'D-FINE-X',
    'yolo26s': 'YOLO26s',
    'rtdetr-x': 'RT-DETR-X',
  };

  /// Temps approximatif par image sur le CPU du PC, si mesuré.
  static const seconds = {
    'faster-rcnn': 20,
    'dfine-s': 5,
    'dfine-x': 8,
    'yolo26s': 3,
    'rtdetr-x': 22,
  };

  static String nameOf(String model) => models[model] ?? model;

  Uri _uri(String path) =>
      Uri.parse('${baseUrl.trim().replaceAll(RegExp(r'/+$'), '')}$path');

  /// Vérifie que le serveur répond.
  Future<bool> ping() async {
    try {
      final r = await http.get(_uri('/')).timeout(const Duration(seconds: 5));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// POST /api/detect/
  Future<Map<String, dynamic>> detectImage(
    XFile file, {
    required double confidence,
    String model = model,
  }) async {
    final request = http.MultipartRequest('POST', _uri('/api/detect/'))
      ..fields['model'] = model
      ..fields['confidence'] = confidence.toStringAsFixed(2)
      ..files.add(await _multipart('image', file));

    // Sur CPU : environ 20 s par image avec Faster R-CNN.
    return _send(request, const Duration(minutes: 3));
  }

  /// POST /api/detect-frame/ : une image de la caméra, sans sauvegarde.
  Future<List<BirdBox>> detectFrame(
    List<int> jpeg, {
    required double confidence,
    String model = model,
  }) async {
    final request = http.MultipartRequest('POST', _uri('/api/detect-frame/'))
      ..fields['model'] = model
      ..fields['confidence'] = confidence.toStringAsFixed(2)
      ..files.add(
        http.MultipartFile.fromBytes('image', jpeg, filename: 'frame.jpg'),
      );

    // Faster R-CNN peut dépasser 20 s par image.
    final body = await _send(request, const Duration(seconds: 60));
    return [
      for (final b in body['boxes'] as List)
        BirdBox.fromJson(b as Map<String, dynamic>),
    ];
  }

  /// POST /api/detect-video/ puis GET /api/detect-video/{job_id}/
  ///
  /// L'analyse tourne en arrière-plan sur le serveur : une requête qui
  /// reste ouverte plusieurs minutes est coupée par Android.
  /// [onUpdate] reçoit l'avancement et les cadres déjà trouvés, pour les
  /// dessiner pendant la lecture.
  Future<Map<String, dynamic>> detectVideo(
    XFile file, {
    required double confidence,
    required int frameStep,
    String model = model,
    void Function(double progress, List<TimedBoxes> detections)? onUpdate,
  }) async {
    final request = http.MultipartRequest('POST', _uri('/api/detect-video/'))
      ..fields['model'] = model
      ..fields['confidence'] = confidence.toStringAsFixed(2)
      ..fields['frame_step'] = '$frameStep'
      // Au plus 7 images analysées, quelle que soit la durée de la vidéo :
      // ≈ 30 s avec D-FINE-S, ≈ 2 min 30 avec Faster R-CNN.
      ..fields['max_frames'] = '7'
      ..fields['async'] = '1'
      ..files.add(await _multipart('video', file));

    // Seul l'envoi du fichier se fait dans cette requête.
    final job = await _send(request, const Duration(minutes: 5));
    final jobUri = _uri('/api/detect-video/${job['job_id']}/');
    final deadline = DateTime.now().add(const Duration(minutes: 30));
    var failures = 0;

    while (DateTime.now().isBefore(deadline)) {
      await Future.delayed(const Duration(seconds: 1));

      final Map<String, dynamic> body;
      try {
        final r = await http.get(jobUri).timeout(const Duration(seconds: 15));
        body = _decode(r);
        failures = 0;
      } on http.ClientException {
        // Wi-Fi instable : on réessaie quelques fois avant d'abandonner.
        if (++failures >= 5) rethrow;
        continue;
      } on TimeoutException {
        if (++failures >= 5) rethrow;
        continue;
      }

      onUpdate?.call((body['progress'] as num?)?.toDouble() ?? 0, [
        for (final d in body['detections'] as List? ?? const [])
          TimedBoxes.fromJson(d as Map<String, dynamic>),
      ]);
      if (body['status'] == 'done') return body;
    }

    throw Exception('L\'analyse prend trop de temps (plus de 30 min).');
  }

  /// On envoie les octets : sur le web il n'y a pas de chemin de fichier, et
  /// une vidéo déjà lue en mémoire ne dépend plus du cache Android.
  Future<http.MultipartFile> _multipart(String field, XFile file) async {
    return http.MultipartFile.fromBytes(
      field,
      await file.readAsBytes(),
      filename: file.name,
    );
  }

  Future<Map<String, dynamic>> _send(
    http.MultipartRequest request,
    Duration timeout,
  ) async {
    final streamed = await request.send().timeout(timeout);
    return _decode(await http.Response.fromStream(streamed));
  }

  Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> body;
    try {
      body =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Réponse invalide du serveur (${response.statusCode}).');
    }

    final ok = response.statusCode == 200 || response.statusCode == 202;
    if (!ok || body['success'] != true) {
      final details = body['details'] != null ? '\n${body['details']}' : '';
      throw Exception('${body['error'] ?? 'Erreur inconnue'}$details');
    }

    return body;
  }
}

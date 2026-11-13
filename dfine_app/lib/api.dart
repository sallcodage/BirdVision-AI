import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart' show XFile;

/// Cadre d'un oiseau, coordonnées entre 0 et 1.
class BirdBox {
  const BirdBox(this.x1, this.y1, this.x2, this.y2, this.confidence,
      {this.trackerId});

  factory BirdBox.fromJson(Map<String, dynamic> j) => BirdBox(
        (j['x1'] as num).toDouble(),
        (j['y1'] as num).toDouble(),
        (j['x2'] as num).toDouble(),
        (j['y2'] as num).toDouble(),
        (j['confidence'] as num).toDouble(),
        trackerId: j['tracker_id'] as int?,
      );

  final double x1, y1, x2, y2, confidence;
  final int? trackerId;
}

/// Cadres trouvés sur l'image de la vidéo à l'instant [t] (secondes).
class TimedBoxes {
  const TimedBoxes(this.t, this.boxes);

  factory TimedBoxes.fromJson(Map<String, dynamic> j) => TimedBoxes(
        (j['t'] as num).toDouble(),
        [
          for (final b in j['boxes'] as List)
            BirdBox.fromJson(b as Map<String, dynamic>),
        ],
      );

  final double t;
  final List<BirdBox> boxes;
}

/// Stats d'un oiseau tracké dans une session.
class TrackedBirdSummary {
  const TrackedBirdSummary({
    required this.trackerId,
    required this.label,
    required this.frameCount,
    required this.avgConfidence,
    required this.maxConfidence,
  });

  factory TrackedBirdSummary.fromJson(Map<String, dynamic> j) =>
      TrackedBirdSummary(
        trackerId: j['tracker_id'] as int,
        label: j['label'] as String,
        frameCount: j['frame_count'] as int,
        avgConfidence: (j['avg_confidence'] as num).toDouble(),
        maxConfidence: (j['max_confidence'] as num).toDouble(),
      );

  final int trackerId;
  final String label;
  final int frameCount;
  final double avgConfidence;
  final double maxConfidence;
}

/// Résumé d'une session de tracking (live ou vidéo).
class TrackingSession {
  const TrackingSession({
    required this.id,
    required this.sessionId,
    required this.source,
    required this.model,
    required this.uniqueBirdCount,
    required this.totalDetections,
    required this.durationSeconds,
    required this.status,
    required this.createdAt,
    this.resultVideo,
  });

  factory TrackingSession.fromJson(Map<String, dynamic> j) => TrackingSession(
        id: j['id'] as int,
        sessionId: j['session_id'] as String,
        source: j['source'] as String,
        model: j['model'] as String,
        uniqueBirdCount: j['unique_bird_count'] as int,
        totalDetections: j['total_detections'] as int,
        durationSeconds: (j['duration_seconds'] as num?)?.toDouble(),
        status: j['status'] as String,
        resultVideo: j['result_video'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
      );

  final int id;
  final String sessionId;
  final String source;
  final String model;
  final int uniqueBirdCount;
  final int totalDetections;
  final double? durationSeconds;
  final String status;
  final String? resultVideo;
  final DateTime createdAt;
}

/// Une entrée de l'historique des analyses image.
class HistoryEntry {
  const HistoryEntry({
    required this.id,
    required this.model,
    required this.confidenceThreshold,
    required this.birdCount,
    required this.resultImage,
    required this.createdAt,
  });

  factory HistoryEntry.fromJson(Map<String, dynamic> j) => HistoryEntry(
        id: (j['id'] as num).toInt(),
        model: j['model'] as String,
        confidenceThreshold: (j['confidence_threshold'] as num).toDouble(),
        birdCount: (j['bird_count'] as num).toInt(),
        resultImage: j['result_image'] as String?,
        createdAt: DateTime.parse(j['created_at'] as String).toLocal(),
      );

  final int id;
  final String model;
  final double confidenceThreshold;
  final int birdCount;
  final String? resultImage;
  final DateTime createdAt;
}

/// Résultat d'un appel detectFrame avec le compteur unique.
class FrameResult {
  const FrameResult({required this.boxes, required this.uniqueBirdCount});
  final List<BirdBox> boxes;
  final int uniqueBirdCount;
}

/// Client de l'API Django BirdVision.
class BirdVisionApi {
  BirdVisionApi(this.baseUrl);

  final String baseUrl;

  static const rfdetrModel = 'rfdetr-s';
  static const dfineXModel = 'dfine-x';
  static const fasterRcnnModel = 'faster-rcnn';
  static const groqQwenModel = 'groq-qwen';

  static const models = <(String, String)>[
    (rfdetrModel, 'RF-DETR-S'),
    (dfineXModel, 'D-FINE-X'),
    (fasterRcnnModel, 'Faster R-CNN'),
    (groqQwenModel, 'Groq Qwen (Cloud)'),
  ];

  Uri _uri(String path) =>
      Uri.parse('${baseUrl.trim().replaceAll(RegExp(r'/+$'), '')}$path');

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
    required String model,
  }) async {
    final request = http.MultipartRequest('POST', _uri('/api/detect/'))
      ..fields['model'] = model
      ..fields['confidence'] = confidence.toStringAsFixed(2)
      ..files.add(await _multipart('image', file));

    return _send(request, const Duration(minutes: 3));
  }

  /// POST /api/detect-frame/ — retourne boxes + compteur d'oiseaux uniques.
  Future<FrameResult> detectFrame(
    List<int> jpeg, {
    required double confidence,
    required String model,
    String? sessionId,
  }) async {
    final request = http.MultipartRequest('POST', _uri('/api/detect-frame/'))
      ..fields['model'] = model
      ..fields['confidence'] = confidence.toStringAsFixed(2)
      ..files.add(
        http.MultipartFile.fromBytes('image', jpeg, filename: 'frame.jpg'),
      );
    if (sessionId != null) request.fields['session_id'] = sessionId;

    final body = await _send(request, const Duration(seconds: 30));
    return FrameResult(
      boxes: [
        for (final b in body['boxes'] as List)
          BirdBox.fromJson(b as Map<String, dynamic>),
      ],
      uniqueBirdCount: (body['unique_bird_count'] as int?) ?? 0,
    );
  }

  /// POST /api/sessions/close/ — ferme une session live et sauvegarde en DB.
  Future<void> closeLiveSession(
    String sessionId, {
    required String model,
    required double confidence,
  }) async {
    try {
      await http.post(
        _uri('/api/sessions/close/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'session_id': sessionId,
          'model': model,
          'confidence': confidence,
        }),
      ).timeout(const Duration(seconds: 10));
    } catch (_) {
      // Ne pas bloquer si la fermeture échoue
    }
  }

  /// POST /api/detect-video/ puis polling GET /api/detect-video/{job_id}/
  Future<Map<String, dynamic>> detectVideo(
    XFile file, {
    required double confidence,
    required int frameStep,
    required String model,
    void Function(double progress, List<TimedBoxes> detections)? onUpdate,
  }) async {
    final request = http.MultipartRequest('POST', _uri('/api/detect-video/'))
      ..fields['model'] = model
      ..fields['confidence'] = confidence.toStringAsFixed(2)
      ..fields['frame_step'] = '$frameStep'
      ..fields['max_frames'] = '7'
      ..fields['async'] = '1'
      ..files.add(await _multipart('video', file));

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
        if (++failures >= 5) rethrow;
        continue;
      } on TimeoutException {
        if (++failures >= 5) rethrow;
        continue;
      }

      onUpdate?.call(
        (body['progress'] as num?)?.toDouble() ?? 0,
        [
          for (final d in body['detections'] as List? ?? const [])
            TimedBoxes.fromJson(d as Map<String, dynamic>),
        ],
      );
      if (body['status'] == 'done') return body;
    }

    throw Exception('L\'analyse prend trop de temps (plus de 30 min).');
  }

  /// POST /api/auth/login/ — retourne le token.
  Future<Map<String, dynamic>> login(String email, String password) async {
    final r = await http.post(
      _uri('/api/auth/login/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    ).timeout(const Duration(seconds: 15));
    final body = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    if (r.statusCode != 200) throw Exception(body['error'] ?? 'Erreur connexion.');
    return body;
  }

  /// POST /api/auth/register/ — crée un compte et retourne le token.
  Future<Map<String, dynamic>> register(String username, String email, String password) async {
    final r = await http.post(
      _uri('/api/auth/register/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'email': email, 'password': password}),
    ).timeout(const Duration(seconds: 15));
    final body = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    if (r.statusCode != 201) throw Exception(body['error'] ?? 'Erreur inscription.');
    return body;
  }

  /// GET /api/history/ — 50 dernières analyses image.
  Future<List<HistoryEntry>> fetchHistory(String token) async {
    final headers = token.isNotEmpty ? {'Authorization': 'Token $token'} : <String, String>{};
    final r = await http.get(
      _uri('/api/history/'),
      headers: headers,
    ).timeout(const Duration(seconds: 15));

    if (r.statusCode == 401) throw Exception('Token invalide.');
    if (r.statusCode != 200) throw Exception('Erreur serveur (${r.statusCode}).');

    final body = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    return [
      for (final e in body['history'] as List)
        HistoryEntry.fromJson(e as Map<String, dynamic>),
    ];
  }

  /// GET /api/sessions/ — 50 dernières sessions de tracking.
  Future<List<TrackingSession>> fetchSessions() async {
    final r = await http.get(_uri('/api/sessions/')).timeout(const Duration(seconds: 15));
    if (r.statusCode != 200) throw Exception('Erreur serveur (${r.statusCode}).');
    final body = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    return [
      for (final s in body['sessions'] as List)
        TrackingSession.fromJson(s as Map<String, dynamic>),
    ];
  }

  /// GET /api/sessions/<session_id>/ — détail + liste des oiseaux.
  Future<Map<String, dynamic>> fetchSessionDetail(String sessionId) async {
    final r = await http
        .get(_uri('/api/sessions/$sessionId/'))
        .timeout(const Duration(seconds: 15));
    if (r.statusCode == 404) throw Exception('Session introuvable.');
    if (r.statusCode != 200) throw Exception('Erreur serveur (${r.statusCode}).');
    return jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
  }

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
      body = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
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

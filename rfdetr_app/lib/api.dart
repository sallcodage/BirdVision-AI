import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart' show XFile;

class BirdBox {
  const BirdBox(this.x1, this.y1, this.x2, this.y2, this.confidence, {this.trackerId});

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
    id: j['id'] as int,
    model: j['model'] as String,
    confidenceThreshold: (j['confidence_threshold'] as num).toDouble(),
    birdCount: j['bird_count'] as int,
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

class RfDetrApi {
  RfDetrApi(this.baseUrl);

  final String baseUrl;

  static const modelId = 'rfdetr-s';
  static const modelName = 'RF-DETR-S';

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

  Future<List<BirdBox>> detectFrame(
    List<int> jpeg, {
    required double confidence,
    String? sessionId,
  }) async {
    final request = http.MultipartRequest('POST', _uri('/api/detect-frame/'))
      ..fields['model'] = modelId
      ..fields['confidence'] = confidence.toStringAsFixed(2)
      ..files.add(
        http.MultipartFile.fromBytes('image', jpeg, filename: 'frame.jpg'),
      );
    if (sessionId != null) request.fields['session_id'] = sessionId;

    final body = await _send(request, const Duration(seconds: 30));
    return [
      for (final b in body['boxes'] as List)
        BirdBox.fromJson(b as Map<String, dynamic>),
    ];
  }

  Future<List<HistoryEntry>> fetchHistory(String token) async {
    final r = await http.get(
      _uri('/api/history/'),
      headers: {'Authorization': 'Token $token'},
    ).timeout(const Duration(seconds: 15));

    if (r.statusCode == 401) throw Exception('Token invalide. Vérifiez vos réglages.');
    if (r.statusCode != 200) throw Exception('Erreur serveur (${r.statusCode}).');

    final body = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    return [
      for (final e in body['history'] as List)
        HistoryEntry.fromJson(e as Map<String, dynamic>),
    ];
  }

  Future<Map<String, dynamic>> detectImage(
    XFile file, {
    required double confidence,
  }) async {
    final request = http.MultipartRequest('POST', _uri('/api/detect/'))
      ..fields['model'] = modelId
      ..fields['confidence'] = confidence.toStringAsFixed(2)
      ..files.add(await _multipart('image', file));

    return _send(request, const Duration(minutes: 2));
  }

  Future<Map<String, dynamic>> detectVideo(
    XFile file, {
    required double confidence,
    required int frameStep,
    void Function(double progress, List<TimedBoxes> detections)? onUpdate,
  }) async {
    final request = http.MultipartRequest('POST', _uri('/api/detect-video/'))
      ..fields['model'] = modelId
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

      onUpdate?.call((body['progress'] as num?)?.toDouble() ?? 0, [
        for (final d in body['detections'] as List? ?? const [])
          TimedBoxes.fromJson(d as Map<String, dynamic>),
      ]);
      if (body['status'] == 'done') return body;
    }

    throw Exception('L\'analyse prend trop de temps (plus de 30 min).');
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

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart' show XFile;

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

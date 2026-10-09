import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart' show XFile;

/// Client de l'API Django BirdVision, utilisé uniquement avec D-FINE-X.
class DfineApi {
  DfineApi(this.baseUrl);

  /// Exemple : http://192.168.1.12:8000
  final String baseUrl;

  static const model = 'dfine-x';

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
  }) async {
    final request = http.MultipartRequest('POST', _uri('/api/detect/'))
      ..fields['model'] = model
      ..fields['confidence'] = confidence.toStringAsFixed(2)
      ..files.add(await _multipart('image', file));

    // D-FINE-X tourne sur CPU : environ 10 s par image.
    return _send(request, const Duration(minutes: 3));
  }

  /// POST /api/detect-video/
  Future<Map<String, dynamic>> detectVideo(
    XFile file, {
    required double confidence,
    required int frameStep,
  }) async {
    final request = http.MultipartRequest('POST', _uri('/api/detect-video/'))
      ..fields['model'] = model
      ..fields['confidence'] = confidence.toStringAsFixed(2)
      ..fields['frame_step'] = '$frameStep'
      ..files.add(await _multipart('video', file));

    // Une vidéo peut prendre plusieurs minutes sur CPU.
    return _send(request, const Duration(minutes: 30));
  }

  /// Sur le web il n'y a pas de chemin de fichier : on envoie les octets.
  Future<http.MultipartFile> _multipart(String field, XFile file) async {
    if (kIsWeb) {
      return http.MultipartFile.fromBytes(
        field,
        await file.readAsBytes(),
        filename: file.name,
      );
    }
    return http.MultipartFile.fromPath(field, file.path);
  }

  Future<Map<String, dynamic>> _send(
    http.MultipartRequest request,
    Duration timeout,
  ) async {
    final streamed = await request.send().timeout(timeout);
    final response = await http.Response.fromStream(streamed);

    Map<String, dynamic> body;
    try {
      body = jsonDecode(utf8.decode(response.bodyBytes))
          as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Réponse invalide du serveur (${response.statusCode}).');
    }

    if (response.statusCode != 200 || body['success'] != true) {
      final details = body['details'] != null ? '\n${body['details']}' : '';
      throw Exception('${body['error'] ?? 'Erreur inconnue'}$details');
    }

    return body;
  }
}

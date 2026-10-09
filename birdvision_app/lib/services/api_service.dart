import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../models/detection_models.dart';
import 'server_config.dart';

class ApiException implements Exception {
  final String message;
  const ApiException(this.message);

  @override
  String toString() => message;
}

class ApiService {
  ApiService._();

  static String get _base => ServerConfig.baseUrl.value;

  /// Vérifie que le serveur Django répond.
  static Future<bool> ping() async {
    try {
      final response = await http
          .get(Uri.parse('$_base/'))
          .timeout(const Duration(seconds: 4));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<ImageDetectionResult> detectImage({
    required XFile image,
    required String model,
    required double confidence,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_base/api/detect/'),
    )
      ..fields['model'] = model
      ..fields['confidence'] = confidence.toStringAsFixed(2)
      ..files.add(
        await _multipartFile('image', image, defaultExtension: '.jpg'),
      );

    final json = await _send(request, const Duration(minutes: 3));
    return ImageDetectionResult.fromJson(
      _rebaseUrls(json, ['result_image']),
    );
  }

  static Future<VideoDetectionResult> detectVideo({
    required XFile video,
    required String model,
    required double confidence,
    required int frameStep,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$_base/api/detect-video/'),
    )
      ..fields['model'] = model
      ..fields['confidence'] = confidence.toStringAsFixed(2)
      ..fields['frame_step'] = frameStep.toString()
      ..files.add(
        await _multipartFile('video', video, defaultExtension: '.mp4'),
      );

    final json = await _send(request, const Duration(minutes: 30));
    return VideoDetectionResult.fromJson(
      _rebaseUrls(json, ['result_video']),
    );
  }

  // ------------------------------------------------------------------

  static Future<http.MultipartFile> _multipartFile(
    String field,
    XFile file, {
    required String defaultExtension,
  }) async {
    // Les photos/vidéos de la caméra n'ont pas toujours d'extension.
    var filename = file.name.isEmpty ? 'media' : file.name;
    if (!filename.contains('.')) filename += defaultExtension;

    if (kIsWeb) {
      return http.MultipartFile.fromBytes(
        field,
        await file.readAsBytes(),
        filename: filename,
      );
    }

    // Sur mobile/desktop on envoie le fichier en flux
    // (évite de charger une grosse vidéo en mémoire).
    return http.MultipartFile.fromPath(field, file.path, filename: filename);
  }

  static Future<Map<String, dynamic>> _send(
    http.MultipartRequest request,
    Duration timeout,
  ) async {
    final http.Response response;

    try {
      final streamed = await request.send().timeout(timeout);
      response = await http.Response.fromStream(streamed).timeout(timeout);
    } on TimeoutException {
      throw const ApiException(
        'Le serveur met trop de temps à répondre. '
        'Essayez une vidéo plus courte ou le mode « Rapide ».',
      );
    } catch (_) {
      throw ApiException(
        'Serveur injoignable ($_base).\n'
        'Vérifiez que Django est lancé avec :\n'
        'python manage.py runserver 0.0.0.0:8000\n'
        'et l’adresse dans les réglages du serveur.',
      );
    }

    Map<String, dynamic>? json;
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) json = decoded;
    } catch (_) {}

    if (response.statusCode != 200 || json == null) {
      final error = json?['error']?.toString();
      final details = json?['details']?.toString();
      throw ApiException(
        [
          error ?? 'Erreur serveur (${response.statusCode}).',
          ?details,
        ].join('\n'),
      );
    }

    return json;
  }

  /// Django construit les URLs avec l'hôte de la requête. On les réécrit
  /// sur l'adresse configurée pour qu'elles restent valides partout.
  static Map<String, dynamic> _rebaseUrls(
    Map<String, dynamic> json,
    List<String> keys,
  ) {
    final copy = Map<String, dynamic>.from(json);
    for (final key in keys) {
      final value = copy[key]?.toString();
      if (value == null || value.isEmpty) continue;
      final uri = Uri.tryParse(value);
      if (uri == null) continue;
      copy[key] = '$_base${uri.path}';
    }
    return copy;
  }
}

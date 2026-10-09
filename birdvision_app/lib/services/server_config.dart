import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Adresse du serveur Django.
///
/// Ordre de priorité :
/// 1. adresse enregistrée dans l'application (Réglages serveur) ;
/// 2. `--dart-define=API_URL=http://192.168.1.20:8000` ;
/// 3. valeur par défaut selon la plateforme.
class ServerConfig {
  ServerConfig._();

  static const _prefsKey = 'server_url';
  static const _dartDefine = String.fromEnvironment('API_URL');

  static final ValueNotifier<String> baseUrl =
      ValueNotifier<String>(defaultUrl);

  /// - Émulateur Android : 10.0.2.2 pointe vers le PC hôte.
  /// - Web, iOS simulateur, desktop : 127.0.0.1.
  /// - Téléphone réel : à régler dans l'app (IP du PC sur le Wi-Fi).
  static String get defaultUrl {
    if (_dartDefine.isNotEmpty) return _normalize(_dartDefine);
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://127.0.0.1:8000';
  }

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      if (saved != null && saved.isNotEmpty) {
        baseUrl.value = _normalize(saved);
      }
    } catch (_) {
      // Pas de stockage disponible : on garde la valeur par défaut.
    }
  }

  static Future<void> save(String url) async {
    final normalized = _normalize(url);
    baseUrl.value = normalized;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, normalized);
    } catch (_) {}
  }

  static Future<void> reset() async {
    baseUrl.value = defaultUrl;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
    } catch (_) {}
  }

  static String _normalize(String url) {
    var value = url.trim();
    if (!value.startsWith('http://') && !value.startsWith('https://')) {
      value = 'http://$value';
    }
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    return value;
  }
}

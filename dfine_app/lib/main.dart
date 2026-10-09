import 'package:flutter/material.dart';

import 'api.dart';
import 'image_page.dart';
import 'video_page.dart';

void main() => runApp(const DfineApp());

const _seed = Color(0xFF2E7D32);

ThemeData _theme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: brightness == Brightness.light
        ? const Color(0xFFF4F7F2)
        : scheme.surface,
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surfaceContainer,
      indicatorColor: scheme.primaryContainer,
      labelTextStyle: WidgetStatePropertyAll(
        const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
      ),
    ),
  );
}

class DfineApp extends StatelessWidget {
  const DfineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BirdVision · D-FINE-X',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      home: const HomePage(),
    );
  }
}

/// Réglages partagés entre les pages Image et Vidéo.
class Settings {
  // Adresse Wi-Fi du PC qui fait tourner Django.
  String serverUrl = 'http://192.168.1.12:8000';

  // 0.40 donne le meilleur équilibre pour D-FINE-X (voir tests).
  double confidence = 0.40;

  // Vidéo : analyser 1 image sur N.
  int frameStep = 15;

  DfineApi get api => DfineApi(serverUrl);
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final settings = Settings();
  int _tab = 0;

  /// null = vérification en cours.
  bool? _online;

  @override
  void initState() {
    super.initState();
    _checkServer();
  }

  Future<void> _checkServer() async {
    setState(() => _online = null);
    final ok = await settings.api.ping();
    if (mounted) setState(() => _online = ok);
  }

  Future<void> _openSettings() async {
    final urlController = TextEditingController(text: settings.serverUrl);
    double confidence = settings.confidence;
    int frameStep = settings.frameStep;
    String? pingResult;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            0,
            24,
            24 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Réglages',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: urlController,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: 'Adresse du serveur Django',
                  hintText: 'http://192.168.1.12:8000',
                  prefixIcon: const Icon(Icons.dns_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.wifi_tethering),
                    label: const Text('Tester'),
                    onPressed: () async {
                      setSheet(() => pingResult = 'Test en cours…');
                      final ok = await DfineApi(urlController.text).ping();
                      setSheet(() => pingResult =
                          ok ? '✅ Serveur en ligne' : '❌ Serveur injoignable');
                    },
                  ),
                  const SizedBox(width: 12),
                  if (pingResult != null) Expanded(child: Text(pingResult!)),
                ],
              ),
              const SizedBox(height: 24),
              _SliderHeader(
                icon: Icons.tune,
                title: 'Seuil de confiance',
                value: '${(confidence * 100).round()} %',
              ),
              Slider(
                value: confidence,
                min: 0.10,
                max: 0.90,
                divisions: 16,
                label: '${(confidence * 100).round()} %',
                onChanged: (v) => setSheet(() => confidence = v),
              ),
              const _Hint('Conseillé pour D-FINE-X : 30 à 40 %'),
              const SizedBox(height: 16),
              _SliderHeader(
                icon: Icons.movie_filter_outlined,
                title: 'Vidéo : 1 image analysée sur',
                value: '$frameStep',
              ),
              Slider(
                value: frameStep.toDouble(),
                min: 1,
                max: 30,
                divisions: 29,
                label: '$frameStep',
                onChanged: (v) => setSheet(() => frameStep = v.round()),
              ),
              const _Hint('Plus le nombre est grand, plus l\'analyse est rapide'),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () {
                    setState(() {
                      settings.serverUrl = urlController.text.trim();
                      settings.confidence = confidence;
                      settings.frameStep = frameStep;
                    });
                    Navigator.pop(context);
                    _checkServer();
                  },
                  child: const Text('Enregistrer'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _Header(
            online: _online,
            onSettings: _openSettings,
            onRetry: _checkServer,
          ),
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: [
                ImagePage(settings: settings),
                VideoPage(settings: settings),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.photo_outlined),
            selectedIcon: Icon(Icons.photo),
            label: 'Image',
          ),
          NavigationDestination(
            icon: Icon(Icons.videocam_outlined),
            selectedIcon: Icon(Icons.videocam),
            label: 'Vidéo',
          ),
        ],
      ),
    );
  }
}

/// En-tête vert avec le titre, l'état du serveur et les réglages.
class _Header extends StatelessWidget {
  const _Header({
    required this.online,
    required this.onSettings,
    required this.onRetry,
  });

  final bool? online;
  final VoidCallback onSettings;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final (dot, text) = switch (online) {
      null => (Colors.amber, 'Connexion…'),
      true => (const Color(0xFF69F0AE), 'Serveur en ligne'),
      false => (const Color(0xFFFF8A80), 'Serveur hors ligne'),
    };

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF00897B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 8, 20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.flutter_dash,
                  color: Colors.white,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'BirdVision',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: onRetry,
                      borderRadius: BorderRadius.circular(20),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: dot,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'D-FINE-X · $text',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.tune, color: Colors.white),
                tooltip: 'Réglages',
                onPressed: onSettings,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SliderHeader extends StatelessWidget {
  const _SliderHeader({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Icon(icon, size: 20, color: scheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: scheme.onPrimaryContainer,
            ),
          ),
        ),
      ],
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

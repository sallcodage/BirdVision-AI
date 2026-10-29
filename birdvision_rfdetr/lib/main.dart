import 'package:flutter/material.dart';

import 'api.dart';
import 'brand.dart';
import 'image_page.dart';
import 'video_page.dart';

void main() => runApp(const BirdVisionRfDetrApp());

ThemeData _theme(Brightness brightness) {
  const seed = BrandColors.blue;
  final scheme = ColorScheme.fromSeed(
    seedColor: seed,
    primary: brightness == Brightness.light ? seed : null,
    brightness: brightness,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: brightness == Brightness.light
        ? BrandColors.background
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

class BirdVisionRfDetrApp extends StatelessWidget {
  const BirdVisionRfDetrApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BirdVision RF-DETR-S',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      home: const _HomePage(),
    );
  }
}

class _HomePage extends StatefulWidget {
  const _HomePage();

  @override
  State<_HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<_HomePage> {
  String _serverUrl = 'http://127.0.0.1:8000';
  double _confidence = 0.25;
  int _frameStep = 15;
  int _tab = 0;
  bool? _online;

  RfDetrApi get _api => RfDetrApi(_serverUrl);

  @override
  void initState() {
    super.initState();
    _checkServer();
  }

  Future<void> _checkServer() async {
    setState(() => _online = null);
    final ok = await _api.ping();
    if (mounted) setState(() => _online = ok);
  }

  Future<void> _openSettings() async {
    final urlController = TextEditingController(text: _serverUrl);
    double confidence = _confidence;
    int frameStep = _frameStep;
    String? pingResult;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(
            24, 0, 24,
            24 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Réglages',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
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
                      final ok = await RfDetrApi(urlController.text).ping();
                      setSheet(
                        () => pingResult = ok
                            ? '✅ Serveur en ligne'
                            : '❌ Serveur injoignable',
                      );
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
                min: 0.09,
                max: 0.90,
                divisions: 81,
                label: '${(confidence * 100).round()} %',
                onChanged: (v) => setSheet(() => confidence = v),
              ),
              _Hint('Seuil minimum RF-DETR-S : 9 %'),
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
              _Hint('Plus le nombre est grand, plus l\'analyse est rapide'),
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
                      _serverUrl = urlController.text.trim();
                      _confidence = confidence;
                      _frameStep = frameStep;
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
    final (dot, statusText) = switch (_online) {
      null => (Colors.amber, 'Connexion…'),
      true => (BrandColors.cyan, 'Serveur en ligne'),
      false => (const Color(0xFFFF8A80), 'Serveur hors ligne'),
    };

    return Scaffold(
      body: Column(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: BrandColors.headerGradient,
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 8, 20),
                child: Row(
                  children: [
                    const BrandLogo(size: 50),
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
                            onTap: _checkServer,
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
                                  'RF-DETR-S · $statusText',
                                  style: const TextStyle(
                                    color: BrandColors.softText,
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
                      onPressed: _openSettings,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _tab,
              children: [
                ImagePage(api: _api, confidence: _confidence),
                VideoPage(
                  api: _api,
                  confidence: _confidence,
                  frameStep: _frameStep,
                ),
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

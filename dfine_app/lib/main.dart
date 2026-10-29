import 'package:flutter/material.dart';

import 'api.dart';
import 'brand.dart';
import 'image_page.dart';
import 'video_page.dart';

void main() => runApp(const BirdVisionApp());

const _seed = BrandColors.blue;

ThemeData _theme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: _seed,
    primary: brightness == Brightness.light ? _seed : null,
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

class BirdVisionApp extends StatelessWidget {
  const BirdVisionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BirdVision',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      home: const HomePage(),
    );
  }
}

/// Réglages partagés entre les pages Image et Vidéo.
class Settings {
  String serverUrl = 'http://192.168.1.12:8000/';
  double confidence = 0.40;
  int frameStep = 15;
  String model = BirdVisionApi.rfdetrModel;

  BirdVisionApi get api => BirdVisionApi(serverUrl);

  String get modelDisplayName {
    for (final (id, name) in BirdVisionApi.models) {
      if (id == model) return name;
    }
    return model.toUpperCase();
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final settings = Settings();
  int _tab = 0;

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
    String model = settings.model;
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
          child: SingleChildScrollView(
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

                // ---------- Serveur ----------
                TextField(
                  controller: urlController,
                  keyboardType: TextInputType.url,
                  decoration: InputDecoration(
                    labelText: 'Adresse du serveur Django',
                    hintText: 'http://192.168.1.12:8000/',
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
                        final ok =
                            await BirdVisionApi(urlController.text).ping();
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

                // ---------- Modèle de détection ----------
                _SectionLabel(
                  icon: Icons.model_training,
                  title: 'Modèle de détection',
                ),
                const SizedBox(height: 8),
                _ModelDropdown(
                  value: model,
                  onChanged: (v) => setSheet(() => model = v),
                ),

                const SizedBox(height: 24),

                // ---------- Seuil de confiance ----------
                _SliderHeader(
                  icon: Icons.tune,
                  title: 'Seuil de confiance',
                  value: '${(confidence * 100).round()} %',
                ),
                Slider(
                  value: confidence,
                  min: 0.09,
                  max: 0.90,
                  divisions: 27,
                  label: '${(confidence * 100).round()} %',
                  onChanged: (v) => setSheet(() => confidence = v),
                ),
                const _Hint('Conseillé : 30 à 50 %'),

                const SizedBox(height: 16),

                // ---------- Pas d'image vidéo ----------
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
                        settings.model = model;
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
            modelName: settings.modelDisplayName,
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

/// En-tête avec le logo, le titre, l'état du serveur et les réglages.
class _Header extends StatelessWidget {
  const _Header({
    required this.online,
    required this.modelName,
    required this.onSettings,
    required this.onRetry,
  });

  final bool? online;
  final String modelName;
  final VoidCallback onSettings;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final (dot, statusText) = switch (online) {
      null => (Colors.amber, 'Connexion…'),
      true => (BrandColors.cyan, 'Serveur en ligne'),
      false => (const Color(0xFFFF8A80), 'Serveur hors ligne'),
    };

    return Container(
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
                            '$modelName · $statusText',
                            style: TextStyle(
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
                onPressed: onSettings,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dropdown stylisé pour choisir le modèle.
class _ModelDropdown extends StatelessWidget {
  const _ModelDropdown({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outline),
        borderRadius: BorderRadius.circular(14),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          borderRadius: BorderRadius.circular(14),
          items: BirdVisionApi.models
              .map(
                (m) => DropdownMenuItem(
                  value: m.$1,
                  child: Row(
                    children: [
                      Icon(_modelIcon(m.$1), size: 20, color: scheme.primary),
                      const SizedBox(width: 12),
                      Text(
                        m.$2,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
          selectedItemBuilder: (context) => BirdVisionApi.models
              .map(
                (m) => Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    m.$2,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  IconData _modelIcon(String id) => switch (id) {
    BirdVisionApi.rfdetrModel => Icons.radar,
    BirdVisionApi.dfineXModel => Icons.auto_awesome,
    BirdVisionApi.fasterRcnnModel => Icons.center_focus_strong,
    _ => Icons.model_training,
  };
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: scheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ],
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

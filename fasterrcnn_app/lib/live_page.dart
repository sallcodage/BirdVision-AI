import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'api.dart';
import 'main.dart';
import 'widgets.dart';

/// Caméra en direct : chaque image est envoyée au serveur et les cadres
/// des oiseaux sont dessinés sur l'aperçu dès la réponse.
class LivePage extends StatefulWidget {
  const LivePage({super.key, required this.settings});

  final Settings settings;

  @override
  State<LivePage> createState() => _LivePageState();
}

class _LivePageState extends State<LivePage> with WidgetsBindingObserver {
  CameraController? _camera;
  String? _error;

  /// La boucle d'envoi tourne tant que la page est ouverte et visible.
  bool _running = false;

  List<BirdBox> _boxes = const [];
  // La caméra utilise d'abord le modèle choisi dans les réglages.
  late String _model;
  Duration? _lastTime;

  @override
  void initState() {
    super.initState();
    _model = widget.settings.model;
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _running = false;
    _camera?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Android libère la caméra quand l'app passe en arrière-plan.
    if (state == AppLifecycleState.inactive) {
      _running = false;
      final camera = _camera;
      setState(() => _camera = null);
      camera?.dispose();
    } else if (state == AppLifecycleState.resumed && _camera == null) {
      _start();
    }
  }

  Future<void> _start() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw CameraException('none', 'Aucune caméra.');

      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      // Résolution moyenne : image légère à envoyer, assez nette pour
      // le modèle qui la réduit de toute façon en 640 x 640.
      final camera = CameraController(
        back,
        ResolutionPreset.medium,
        enableAudio: false,
      );
      await camera.initialize();

      if (!mounted) {
        await camera.dispose();
        return;
      }

      setState(() {
        _camera = camera;
        _error = null;
      });
      _loop(camera);
    } on CameraException catch (e) {
      if (mounted) {
        setState(() => _error = 'Caméra indisponible : ${e.description}');
      }
    }
  }

  Future<void> _loop(CameraController camera) async {
    _running = true;

    while (_running && mounted && _camera == camera) {
      final started = DateTime.now();
      try {
        final picture = await camera.takePicture();
        final boxes = await widget.settings.api.detectFrame(
          await picture.readAsBytes(),
          confidence: widget.settings.confidence,
          model: _model,
        );

        if (!mounted || _camera != camera) return;
        setState(() {
          _boxes = boxes;
          _lastTime = DateTime.now().difference(started);
          _error = null;
        });
      } catch (e) {
        if (!mounted || _camera != camera) return;
        setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
        // Serveur injoignable : on attend avant de réessayer.
        await Future.delayed(const Duration(seconds: 2));
      }
    }
  }

  void _toggleModel() {
    setState(() {
      final alternate = widget.settings.model == BirdVisionApi.fastModel
          ? BirdVisionApi.model
          : BirdVisionApi.fastModel;
      _model = _model == widget.settings.model
          ? alternate
          : widget.settings.model;
      _boxes = const [];
      _lastTime = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final camera = _camera;
    final modelName = BirdVisionApi.nameOf(_model);

    Widget preview;
    if (camera != null && camera.value.isInitialized) {
      // Sur téléphone tenu droit, l'aperçu est en portrait.
      final portrait =
          !kIsWeb && MediaQuery.of(context).orientation == Orientation.portrait;
      final ratio = camera.value.aspectRatio;

      preview = AspectRatio(
        aspectRatio: portrait ? 1 / ratio : ratio,
        child: Stack(
          fit: StackFit.expand,
          children: [CameraPreview(camera), BoxOverlay(_boxes)],
        ),
      );
    } else if (_error != null) {
      preview = Padding(
        padding: const EdgeInsets.all(24),
        child: ErrorBanner(_error!),
      );
    } else {
      preview = const CircularProgressIndicator(color: Colors.white);
    }

    final count = _boxes.length;
    final status = _lastTime == null
        ? 'Détection en cours…'
        : '${count == 0 ? 'Aucun oiseau' : '$count oiseau${count > 1 ? 'x' : ''}'}'
              ' · ${(_lastTime!.inMilliseconds / 1000).toStringAsFixed(1)} s par image';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Détection en direct'),
        actions: [
          TextButton.icon(
            onPressed: _toggleModel,
            icon: const Icon(Icons.swap_horiz, color: Colors.white),
            label: Text(modelName, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: Center(child: preview)),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            color: Colors.black,
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  Text(
                    status,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (camera != null && _error != null) ...[
                    const SizedBox(height: 10),
                    ErrorBanner(_error!),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    _model == BirdVisionApi.fastModel
                        ? 'YOLO26s : modèle rapide pour la détection en direct'
                        : '${BirdVisionApi.nameOf(_model)} : détection exécutée par le serveur',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

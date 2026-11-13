import 'dart:math';

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

  bool _running = false;

  List<BirdBox> _boxes = const [];
  int _uniqueBirdCount = 0;

  /// Live : RF-DETR-S ou D-FINE-X (Faster R-CNN trop lent pour le direct).
  static const _liveModels = [
    BirdVisionApi.rfdetrModel,
    BirdVisionApi.dfineXModel,
  ];

  String _model = BirdVisionApi.rfdetrModel;
  Duration? _lastTime;

  // ID de session unique pour le tracker persistant côté serveur
  String _sessionId = _newSessionId();

  static String _newSessionId() {
    final rng = Random();
    return List.generate(16, (_) => rng.nextInt(16).toRadixString(16)).join();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _running = false;
    _camera?.dispose();
    widget.settings.api.closeLiveSession(
      _sessionId,
      model: _model,
      confidence: widget.settings.confidence,
    );
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
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
        final result = await widget.settings.api.detectFrame(
          await picture.readAsBytes(),
          confidence: widget.settings.confidence,
          model: _model,
          sessionId: _sessionId,
        );

        if (!mounted || _camera != camera) return;
        setState(() {
          _boxes = result.boxes;
          _uniqueBirdCount = result.uniqueBirdCount;
          _lastTime = DateTime.now().difference(started);
          _error = null;
        });
      } catch (e) {
        if (!mounted || _camera != camera) return;
        setState(
          () => _error = e.toString().replaceFirst('Exception: ', ''),
        );
        await Future.delayed(const Duration(seconds: 2));
      }
    }
  }

  void _toggleModel() {
    // Ferme la session courante avant d'en créer une nouvelle
    widget.settings.api.closeLiveSession(
      _sessionId,
      model: _model,
      confidence: widget.settings.confidence,
    );
    final next = (_liveModels.indexOf(_model) + 1) % _liveModels.length;
    setState(() {
      _model = _liveModels[next];
      _boxes = const [];
      _uniqueBirdCount = 0;
      _lastTime = null;
      _sessionId = _newSessionId();
    });
  }

  String get _modelLabel => switch (_model) {
    BirdVisionApi.dfineXModel => 'D-FINE-X',
    _ => 'RF-DETR-S',
  };

  String get _modelHint => switch (_model) {
    BirdVisionApi.dfineXModel => 'D-FINE-X : précis, environ 5 s par image',
    _ => 'RF-DETR-S : bon équilibre vitesse / précision',
  };

  @override
  Widget build(BuildContext context) {
    final camera = _camera;
    final modelName = _modelLabel;

    Widget preview;
    if (camera != null && camera.value.isInitialized) {
      final portrait =
          !kIsWeb &&
          MediaQuery.of(context).orientation == Orientation.portrait;
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
              ' · ${(_lastTime!.inMilliseconds / 1000).toStringAsFixed(1)} s/image';

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
                  if (_lastTime != null && _uniqueBirdCount > 0) ...[
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.flutter_dash, color: Colors.amber, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          '$_uniqueBirdCount oiseau${_uniqueBirdCount > 1 ? 'x' : ''} unique${_uniqueBirdCount > 1 ? 's' : ''} détecté${_uniqueBirdCount > 1 ? 's' : ''}',
                          style: const TextStyle(color: Colors.amber, fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                  if (camera != null && _error != null) ...[
                    const SizedBox(height: 10),
                    ErrorBanner(_error!),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    _modelHint,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ID session : $_sessionId',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white38, fontSize: 10, fontFamily: 'monospace'),
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

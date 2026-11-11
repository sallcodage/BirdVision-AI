import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'api.dart';
import 'widgets.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({super.key, required this.api, required this.confidence});

  final RfDetrApi api;
  final double confidence;

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> with WidgetsBindingObserver {
  List<CameraDescription> _cameras = [];
  CameraController? _controller;
  String? _initError;

  bool _running = false;
  bool _busy = false;

  List<BirdBox> _boxes = [];
  int _uniqueCount = 0;
  int _fps = 0;
  String? _sessionId;

  int _frameCount = 0;
  DateTime _fpsTimer = DateTime.now();

  static const _intervalMs = 300;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _controller?.dispose();
    final sid = _sessionId;
    if (sid != null) {
      widget.api.closeLiveSession(sid, confidence: widget.confidence);
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    if (state == AppLifecycleState.inactive) {
      _stopDetection();
      ctrl.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (!mounted) return;
      if (_cameras.isEmpty) {
        setState(() => _initError = 'Aucune caméra disponible sur cet appareil.');
        return;
      }
      await _startCamera(_cameras.first);
    } catch (e) {
      if (!mounted) return;
      setState(() => _initError = 'Impossible d\'accéder à la caméra : $e');
    }
  }

  Future<void> _startCamera(CameraDescription cam) async {
    final ctrl = CameraController(
      cam,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    try {
      await ctrl.initialize();
      if (!mounted) {
        ctrl.dispose();
        return;
      }
      setState(() {
        _controller = ctrl;
        _initError = null;
      });
    } catch (e) {
      ctrl.dispose();
      if (!mounted) return;
      setState(() => _initError = 'Erreur caméra : $e');
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    _stopDetection();
    final old = _controller;
    final oldLens = old?.description.lensDirection;
    setState(() => _controller = null);
    await old?.dispose();
    final idx = _cameras.indexWhere(
      (c) => c.lensDirection == (oldLens ?? CameraLensDirection.back),
    );
    final next = _cameras[(idx + 1) % _cameras.length];
    await _startCamera(next);
  }

  void _startDetection() {
    if (_running) return;
    final sid = DateTime.now().millisecondsSinceEpoch.toRadixString(16);
    _sessionId = sid;
    setState(() {
      _running = true;
      _boxes = [];
      _uniqueCount = 0;
      _fps = 0;
      _frameCount = 0;
      _fpsTimer = DateTime.now();
    });
    _timer = Timer.periodic(const Duration(milliseconds: _intervalMs), (_) => _sendFrame());
  }

  void _stopDetection() {
    _timer?.cancel();
    _timer = null;
    final sid = _sessionId;
    if (sid != null) {
      widget.api.closeLiveSession(sid, confidence: widget.confidence);
      _sessionId = null;
    }
    if (mounted) setState(() => _running = false);
  }

  Future<void> _sendFrame() async {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized || _busy) return;
    _busy = true;
    try {
      final XFile pic = await ctrl.takePicture();
      final Uint8List bytes = await pic.readAsBytes();

      final result = await widget.api.detectFrame(
        bytes,
        confidence: widget.confidence,
        sessionId: _sessionId,
      );

      if (!mounted || !_running) return;

      _frameCount++;
      final now = DateTime.now();
      final elapsed = now.difference(_fpsTimer).inSeconds;
      if (elapsed >= 1) {
        setState(() {
          _fps = (_frameCount / elapsed).round();
          _frameCount = 0;
          _fpsTimer = now;
          _boxes = result.boxes;
          _uniqueCount = result.uniqueBirdCount;
        });
      } else {
        setState(() {
          _boxes = result.boxes;
          _uniqueCount = result.uniqueBirdCount;
        });
      }
    } catch (_) {
      // Ignore frame errors
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (_initError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.videocam_off_outlined, size: 56, color: scheme.onSurfaceVariant),
              const SizedBox(height: 16),
              Text(_initError!, textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant)),
              const SizedBox(height: 20),
              FilledButton.tonalIcon(
                icon: const Icon(Icons.refresh),
                label: const Text('Réessayer'),
                onPressed: _initCamera,
              ),
            ],
          ),
        ),
      );
    }

    if (kIsWeb) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'La caméra live n\'est pas disponible sur navigateur.\n'
            'Utilisez l\'application Android.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        Positioned.fill(
          child: CameraPreview(
            ctrl,
            child: LayoutBuilder(
              builder: (context, constraints) => BoxOverlay(_boxes),
            ),
          ),
        ),

        // Compteurs en haut
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black.withValues(alpha: 0.7), Colors.transparent],
              ),
            ),
            child: Row(
              children: [
                _Chip(icon: Icons.fingerprint, label: '$_uniqueCount uniques', highlight: true),
                const SizedBox(width: 8),
                _Chip(icon: Icons.flutter_dash, label: '${_boxes.length} visibles'),
                const Spacer(),
                if (_running) _Chip(icon: Icons.speed, label: '$_fps fps'),
              ],
            ),
          ),
        ),

        // Boutons en bas
        Positioned(
          bottom: 24,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_cameras.length > 1)
                _RoundButton(icon: Icons.flip_camera_android, onTap: _switchCamera, small: true),
              const SizedBox(width: 24),
              _RoundButton(
                icon: _running ? Icons.stop : Icons.play_arrow,
                onTap: _running ? _stopDetection : _startDetection,
                color: _running ? Colors.red.shade400 : scheme.primary,
                large: true,
              ),
              const SizedBox(width: 24),
              const SizedBox(width: 48),
            ],
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label, this.highlight = false});

  final IconData icon;
  final String label;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: highlight
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.85)
            : Colors.black54,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 5),
          Text(label,
              style: const TextStyle(
                  color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.onTap,
    this.color,
    this.small = false,
    this.large = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  final bool small;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final size = large ? 72.0 : small ? 48.0 : 56.0;
    final bg = color ?? Colors.white24;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white, size: large ? 36 : 24),
      ),
    );
  }
}

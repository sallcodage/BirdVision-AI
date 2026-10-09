import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../models/detection_models.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../utils/video_controller.dart';
import '../widgets/common.dart';
import '../widgets/server_settings.dart';
import '../widgets/video_player_view.dart';

/// Vitesse d'analyse : on n'analyse qu'une image sur [step], les images
/// intermédiaires réutilisent les dernières boîtes détectées.
enum _Speed {
  fast(5, 'Rapide', Icons.bolt_rounded),
  balanced(2, 'Équilibré', Icons.balance_rounded),
  precise(1, 'Précis', Icons.center_focus_strong_rounded);

  final int step;
  final String label;
  final IconData icon;

  const _Speed(this.step, this.label, this.icon);
}

class VideoDetectionPage extends StatefulWidget {
  /// Si renseigné, ouvre directement la galerie ou la caméra.
  final ImageSource? initialSource;

  const VideoDetectionPage({super.key, this.initialSource});

  @override
  State<VideoDetectionPage> createState() => _VideoDetectionPageState();
}

class _VideoDetectionPageState extends State<VideoDetectionPage> {
  final ImagePicker _picker = ImagePicker();

  XFile? _video;
  VideoPlayerController? _sourceController;
  VideoPlayerController? _resultController;

  String _model = 'yolo26s';
  double _confidence = 0.30;
  _Speed _speed = _Speed.balanced;

  bool _loading = false;
  String? _error;
  VideoDetectionResult? _result;
  bool _showResult = true;

  final Stopwatch _stopwatch = Stopwatch();
  Timer? _ticker;

  late final bool _cameraAvailable =
      _picker.supportsImageSource(ImageSource.camera);

  @override
  void initState() {
    super.initState();
    final source = widget.initialSource;
    if (source != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _pick(source));
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _sourceController?.dispose();
    _resultController?.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    final XFile? video;
    try {
      video = await _picker.pickVideo(
        source: source,
        maxDuration: const Duration(minutes: 2),
        preferredCameraDevice: CameraDevice.rear,
      );
    } catch (e) {
      setState(() {
        _error = source == ImageSource.camera
            ? 'Impossible d’ouvrir la caméra.\n'
                'Vérifiez les autorisations caméra et micro.\n($e)'
            : 'Impossible de sélectionner la vidéo.\n($e)';
      });
      return;
    }
    if (video == null) return;

    final old = _sourceController;
    final oldResult = _resultController;
    final controller = controllerForPickedVideo(video);

    setState(() {
      _video = video;
      _sourceController = controller;
      _resultController = null;
      _result = null;
      _error = null;
    });
    await old?.dispose();
    await oldResult?.dispose();

    try {
      await controller.initialize();
      await controller.setLooping(true);
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'La vidéo a été sélectionnée mais ne peut pas être '
              'prévisualisée sur cet appareil. Vous pouvez quand même '
              'lancer l’analyse.\n($e)';
        });
      }
    }
  }

  Future<void> _analyze() async {
    final video = _video;
    if (video == null) {
      setState(() => _error = 'Choisissez d’abord une vidéo.');
      return;
    }

    _sourceController?.pause();
    _stopwatch
      ..reset()
      ..start();
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() {}),
    );

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await ApiService.detectVideo(
        video: video,
        model: _model,
        confidence: _confidence,
        frameStep: _speed.step,
      );

      final controller = VideoPlayerController.networkUrl(
        Uri.parse(result.resultVideoUrl),
      );
      final previous = _resultController;

      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _result = result;
        _resultController = controller;
        _showResult = true;
      });
      await previous?.dispose();
      if (!mounted) return;

      showInfoSnack(
        context,
        'Analyse terminée : jusqu’à ${result.maxBirdsInFrame} '
        'oiseau${result.maxBirdsInFrame > 1 ? 'x' : ''} à l’écran.',
      );

      await controller.initialize();
      await controller.setLooping(true);
      if (mounted) {
        setState(() {});
        controller.play();
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      _ticker?.cancel();
      _stopwatch.stop();
      if (mounted) setState(() => _loading = false);
    }
  }

  void _selectView(bool showResult) {
    setState(() => _showResult = showResult);
    if (showResult) {
      _sourceController?.pause();
    } else {
      _resultController?.pause();
    }
  }

  String get _elapsed {
    final s = _stopwatch.elapsed.inSeconds;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analyse vidéo'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: ServerStatusChip(),
          ),
        ],
      ),
      body: PageBody(
        children: [
          _buildPlayer(),
          if (_video != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.movie_outlined,
                    size: 16, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _video!.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textMuted),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 14),
          SourceButtons(
            galleryIcon: Icons.video_library_outlined,
            galleryLabel: 'Galerie',
            onGallery: _loading ? null : () => _pick(ImageSource.gallery),
            cameraIcon: Icons.videocam_outlined,
            cameraLabel: 'Filmer',
            showCamera: _cameraAvailable,
            onCamera: _loading ? null : () => _pick(ImageSource.camera),
          ),
          const SizedBox(height: 20),
          SectionCard(
            title: 'Modèle de détection',
            icon: Icons.memory_rounded,
            child: ModelSelector(
              value: _model,
              onChanged: _loading ? null : (v) => setState(() => _model = v),
            ),
          ),
          const SizedBox(height: 14),
          SectionCard(
            title: 'Seuil de confiance',
            icon: Icons.tune_rounded,
            child: ConfidenceSlider(
              value: _confidence,
              onChanged:
                  _loading ? null : (v) => setState(() => _confidence = v),
            ),
          ),
          const SizedBox(height: 14),
          SectionCard(
            title: 'Vitesse d’analyse',
            icon: Icons.speed_rounded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<_Speed>(
                  showSelectedIcon: false,
                  segments: [
                    for (final speed in _Speed.values)
                      ButtonSegment(
                        value: speed,
                        icon: Icon(speed.icon),
                        label: Text(speed.label),
                      ),
                  ],
                  selected: {_speed},
                  onSelectionChanged: _loading
                      ? null
                      : (s) => setState(() => _speed = s.first),
                ),
                const SizedBox(height: 10),
                Text(
                  _speed.step == 1
                      ? 'Chaque image est analysée (le plus lent).'
                      : 'Une image sur ${_speed.step} est analysée, les '
                          'autres réutilisent les dernières détections.',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            ErrorBanner(
              message: _error!,
              onClose: () => setState(() => _error = null),
            ),
          ],
          const SizedBox(height: 20),
          AnalyzeButton(
            loading: _loading,
            label: _result == null
                ? 'Analyser la vidéo'
                : 'Relancer l’analyse',
            loadingLabel: 'Analyse en cours… $_elapsed',
            onPressed: _video == null ? null : _analyze,
          ),
          if (_loading) ...[
            const SizedBox(height: 10),
            const Text(
              'L’analyse vidéo peut prendre plusieurs minutes selon la '
              'durée et le modèle. Gardez l’application ouverte.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textMuted, fontSize: 13),
            ),
          ],
          if (_result != null) ...[
            const SizedBox(height: 24),
            _VideoResultSection(result: _result!),
          ],
        ],
      ),
    );
  }

  Widget _buildPlayer() {
    final source = _sourceController;
    if (source == null) {
      return MediaPlaceholder(
        dark: true,
        icon: Icons.video_library_outlined,
        title: 'Ajoutez une vidéo d’oiseaux',
        subtitle: 'Touchez pour ouvrir la galerie',
        onTap: _loading ? null : () => _pick(ImageSource.gallery),
      );
    }

    final resultController = _resultController;
    final showResult = _showResult && resultController != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (resultController != null) ...[
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: false,
                icon: Icon(Icons.movie_outlined),
                label: Text('Originale'),
              ),
              ButtonSegment(
                value: true,
                icon: Icon(Icons.crop_free_rounded),
                label: Text('Détections'),
              ),
            ],
            selected: {showResult},
            onSelectionChanged: (s) => _selectView(s.first),
          ),
          const SizedBox(height: 12),
        ],
        Stack(
          children: [
            VideoPlayerView(
              key: ValueKey(showResult),
              controller: showResult ? resultController : source,
            ),
            if (_loading)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(color: Colors.white),
                      const SizedBox(height: 14),
                      Text(
                        'Analyse image par image… $_elapsed',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _VideoResultSection extends StatelessWidget {
  final VideoDetectionResult result;

  const _VideoResultSection({required this.result});

  @override
  Widget build(BuildContext context) {
    final duration = result.durationSeconds;

    return SectionCard(
      title: 'Résultats',
      icon: Icons.insights_rounded,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          StatGrid(
            tiles: [
              StatTile(
                icon: Icons.flutter_dash,
                value: '${result.maxBirdsInFrame}',
                label: 'oiseaux max. sur une image',
              ),
              StatTile(
                icon: Icons.crop_free_rounded,
                value: '${result.totalBirdDetections}',
                label: 'détections au total',
                color: const Color(0xFFB8741A),
              ),
              StatTile(
                icon: Icons.burst_mode_outlined,
                value: '${result.framesAnalyzed}',
                label: 'images analysées'
                    '${result.framesTotal != result.framesAnalyzed ? ' / ${result.framesTotal}' : ''}',
                color: const Color(0xFF1F4E79),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoChip(
                icon: Icons.memory_rounded,
                text: DetectorModel.nameOf(result.model),
              ),
              _InfoChip(
                icon: Icons.tune_rounded,
                text: 'Seuil ${(result.confidenceThreshold * 100).round()} %',
              ),
              if (duration != null)
                _InfoChip(
                  icon: Icons.timer_outlined,
                  text: '${duration.toStringAsFixed(1)} s de vidéo',
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.textMuted),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontSize: 13)),
        ],
      ),
    );
  }
}

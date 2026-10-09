import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import 'main.dart';
import 'widgets.dart';

class VideoPage extends StatefulWidget {
  const VideoPage({super.key, required this.settings});

  final Settings settings;

  @override
  State<VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<VideoPage> {
  final _picker = ImagePicker();

  XFile? _video;
  Map<String, dynamic>? _result;
  String? _error;
  bool _loading = false;

  /// Lecteur : vidéo choisie avant l'analyse, vidéo annotée après.
  VideoPlayerController? _player;
  Timer? _timer;
  int _elapsed = 0;

  @override
  void dispose() {
    _timer?.cancel();
    _player?.dispose();
    super.dispose();
  }

  Future<void> _setPlayer(VideoPlayerController? player) async {
    final old = _player;
    setState(() => _player = player);
    await old?.dispose();

    if (player == null) return;
    try {
      await player.initialize();
      await player.setLooping(true);
      await player.play();
      if (mounted) setState(() {});
    } catch (_) {
      // Aperçu impossible : on garde l'écran sans lecteur.
      if (mounted && _player == player) setState(() => _player = null);
    }
  }

  Future<void> _pick(ImageSource source) async {
    final file = await _picker.pickVideo(
      source: source,
      maxDuration: const Duration(seconds: 30),
    );
    if (file == null) return;

    setState(() {
      _video = file;
      _result = null;
      _error = null;
    });

    await _setPlayer(
      kIsWeb
          ? VideoPlayerController.networkUrl(Uri.parse(file.path))
          : VideoPlayerController.file(File(file.path)),
    );
    await _player?.setVolume(0);
  }

  Future<void> _detect() async {
    if (_video == null) return;

    await _player?.pause();
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
      _elapsed = 0;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed++);
    });

    try {
      final result = await widget.settings.api.detectVideo(
        _video!,
        confidence: widget.settings.confidence,
        frameStep: widget.settings.frameStep,
      );

      setState(() => _result = result);
      await _setPlayer(
        VideoPlayerController.networkUrl(
          Uri.parse(result['result_video'] as String),
        ),
      );
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      _timer?.cancel();
      if (mounted) setState(() => _loading = false);
    }
  }

  String get _elapsedText =>
      '${_elapsed ~/ 60}:${(_elapsed % 60).toString().padLeft(2, '0')}';

  Widget _preview() {
    final player = _player;

    if (_video == null) {
      return const EmptyPreview(
        icon: Icons.video_call_outlined,
        title: 'Aucune vidéo',
        subtitle: 'Choisissez une vidéo ou filmez des oiseaux (30 s max)',
      );
    }

    final Widget content;
    if (player != null && player.value.isInitialized) {
      content = GestureDetector(
        onTap: () => setState(() {
          player.value.isPlaying ? player.pause() : player.play();
        }),
        child: Stack(
          alignment: Alignment.center,
          children: [
            AspectRatio(
              aspectRatio: player.value.aspectRatio,
              child: VideoPlayer(player),
            ),
            if (!player.value.isPlaying && !_loading)
              const CircleAvatar(
                radius: 30,
                backgroundColor: Colors.black45,
                child: Icon(Icons.play_arrow, color: Colors.white, size: 36),
              ),
          ],
        ),
      );
    } else {
      content = SizedBox(
        height: 220,
        child: Center(
          child: Text(
            _video!.name,
            style: const TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    return PreviewFrame(
      loading: _loading,
      loadingText: 'D-FINE-X analyse la vidéo… $_elapsedText\n'
          'Cela peut prendre plusieurs minutes',
      child: Container(
        color: Colors.black,
        width: double.infinity,
        constraints: const BoxConstraints(maxHeight: 460),
        child: Center(child: content),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      children: [
        _preview(),

        if (_video != null && !_loading) ...[
          const SizedBox(height: 10),
          Center(
            child: Chip(
              avatar: Icon(
                _result != null ? Icons.crop_free : Icons.movie_outlined,
                size: 18,
              ),
              label: Text(
                _result != null ? 'Vidéo annotée' : 'Vidéo originale',
              ),
            ),
          ),
        ],

        const SizedBox(height: 16),

        Row(
          children: [
            ActionTile(
              icon: Icons.video_library_outlined,
              label: 'Galerie',
              onTap: _loading ? null : () => _pick(ImageSource.gallery),
            ),
            const SizedBox(width: 12),
            ActionTile(
              icon: Icons.videocam_outlined,
              label: 'Filmer',
              onTap: _loading ? null : () => _pick(ImageSource.camera),
            ),
          ],
        ),
        const SizedBox(height: 12),
        PrimaryButton(
          icon: Icons.search,
          label: _loading
              ? 'Analyse en cours… $_elapsedText'
              : 'Détecter les oiseaux',
          onPressed: _video == null || _loading ? null : _detect,
        ),
        const SizedBox(height: 8),
        Text(
          'Seuil ${(widget.settings.confidence * 100).round()} % · '
          '1 image analysée sur ${widget.settings.frameStep}',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
        ),

        if (_error != null) ...[
          const SizedBox(height: 16),
          ErrorBanner(_error!),
        ],

        if (_result != null) ...[
          const SizedBox(height: 20),
          Row(
            children: [
              StatTile(
                highlight: true,
                icon: Icons.flutter_dash,
                value: '${_result!['max_birds_in_frame']}',
                label: 'oiseaux max\nsur une image',
              ),
              const SizedBox(width: 10),
              StatTile(
                icon: Icons.timer_outlined,
                value: '${_result!['duration_seconds']} s',
                label: 'durée\nde la vidéo',
              ),
              const SizedBox(width: 10),
              StatTile(
                icon: Icons.hourglass_bottom,
                value: _elapsedText,
                label: 'temps\nd\'analyse',
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _row('Images totales', '${_result!['frames_total']}'),
                _row('Images analysées', '${_result!['frames_analyzed']}'),
                _row(
                  'Détections cumulées',
                  '${_result!['total_bird_detections']}',
                ),
                _row(
                  'Seuil',
                  '${((_result!['confidence_threshold'] as num) * 100).round()} %',
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(child: Text(label)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

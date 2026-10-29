import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import 'api.dart';
import 'widgets.dart';

class VideoPage extends StatefulWidget {
  const VideoPage({
    super.key,
    required this.api,
    required this.confidence,
    required this.frameStep,
  });

  final RfDetrApi api;
  final double confidence;
  final int frameStep;

  @override
  State<VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<VideoPage> {
  final _picker = ImagePicker();

  XFile? _video;
  Map<String, dynamic>? _result;
  String? _error;
  bool _loading = false;

  VideoPlayerController? _player;
  Timer? _timer;
  int _elapsed = 0;
  double _progress = 0;

  List<TimedBoxes> _detections = const [];
  int _run = 0;
  bool _waiting = false;

  double get _analyzedUntil {
    if (_result != null) return double.infinity;
    if (_detections.isEmpty) return -1;
    final last = _detections.last.t;
    final step = _detections.length > 1
        ? last - _detections[_detections.length - 2].t
        : 0.5;
    return last + step;
  }

  void _gate() {
    final player = _player;
    if (player == null || !player.value.isInitialized || !_loading) return;
    final t = player.value.position.inMilliseconds / 1000;
    if (player.value.isPlaying && t >= _analyzedUntil) {
      player.pause();
      setState(() => _waiting = true);
    }
  }

  void _resumeIfReady() {
    final player = _player;
    if (!_waiting || player == null || !player.value.isInitialized) return;
    final t = player.value.position.inMilliseconds / 1000;
    if (_analyzedUntil > t + 0.3) {
      _waiting = false;
      player.play();
    }
  }

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
      await player.setVolume(0);
      player.addListener(_gate);
      if (mounted) setState(() => _waiting = true);
    } catch (_) {
      if (mounted && _player == player) setState(() => _player = null);
    }
  }

  Future<void> _pick() async {
    final file = await _picker.pickVideo(
      source: ImageSource.gallery,
      maxDuration: const Duration(seconds: 30),
    );
    if (file == null) return;

    final XFile video;
    try {
      video = XFile.fromData(
        await file.readAsBytes(),
        name: file.name,
        path: file.path,
      );
    } catch (_) {
      setState(() => _error = 'Impossible de lire la vidéo.');
      return;
    }

    setState(() {
      _video = video;
      _result = null;
      _error = null;
      _detections = const [];
    });

    await _setPlayer(
      kIsWeb
          ? VideoPlayerController.networkUrl(Uri.parse(file.path))
          : VideoPlayerController.file(File(file.path)),
    );

    await _detect();
  }

  Future<void> _detect() async {
    if (_video == null) return;

    final run = ++_run;
    _timer?.cancel();

    final player = _player;
    if (player != null && player.value.isInitialized) {
      await player.pause();
      await player.seekTo(Duration.zero);
    }
    _waiting = true;

    setState(() {
      _loading = true;
      _error = null;
      _result = null;
      _elapsed = 0;
      _progress = 0;
      _detections = const [];
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed++);
    });

    try {
      final result = await widget.api.detectVideo(
        _video!,
        confidence: widget.confidence,
        frameStep: widget.frameStep,
        onUpdate: (progress, detections) {
          if (!mounted || run != _run) return;
          setState(() {
            _progress = progress;
            _detections = detections;
          });
          _resumeIfReady();
        },
      );

      if (!mounted || run != _run) return;
      setState(() => _result = result);
      _resumeIfReady();
    } catch (e) {
      if (!mounted || run != _run) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      _waiting = false;
      await _player?.play();
    } finally {
      if (run == _run) {
        _timer?.cancel();
        if (mounted) setState(() => _loading = false);
      }
    }
  }

  List<BirdBox> _boxesAt(Duration position) {
    final t = position.inMilliseconds / 1000;
    if (_detections.isEmpty) return const [];

    final step = _detections.length > 1
        ? _detections[1].t - _detections[0].t
        : 0.5;
    final maxGap = step * 1.5 < 1.0 ? 1.0 : step * 1.5;

    var i = -1;
    while (i + 1 < _detections.length && _detections[i + 1].t <= t) {
      i++;
    }
    if (i < 0) return const [];

    final before = _detections[i];
    if (t - before.t > maxGap) return const [];
    if (i + 1 >= _detections.length) return before.boxes;

    final after = _detections[i + 1];
    if (after.boxes.length != before.boxes.length) return before.boxes;

    final k = (t - before.t) / (after.t - before.t);
    double lerp(double a, double b) => a + (b - a) * k;

    return [
      for (var j = 0; j < before.boxes.length; j++)
        BirdBox(
          lerp(before.boxes[j].x1, after.boxes[j].x1),
          lerp(before.boxes[j].y1, after.boxes[j].y1),
          lerp(before.boxes[j].x2, after.boxes[j].x2),
          lerp(before.boxes[j].y2, after.boxes[j].y2),
          before.boxes[j].confidence,
        ),
    ];
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
        child: AspectRatio(
          aspectRatio: player.value.aspectRatio,
          child: Stack(
            fit: StackFit.expand,
            children: [
              VideoPlayer(player),
              ValueListenableBuilder(
                valueListenable: player,
                builder: (context, value, _) =>
                    BoxOverlay(_boxesAt(value.position)),
              ),
              if (_waiting && _loading)
                const Center(
                  child: CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.black45,
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    ),
                  ),
                )
              else if (!player.value.isPlaying)
                const Center(
                  child: CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.black45,
                    child: Icon(Icons.play_arrow, color: Colors.white, size: 36),
                  ),
                ),
            ],
          ),
        ),
      );
    } else {
      content = SizedBox(
        height: 220,
        child: Center(
          child: Text(_video!.name, style: const TextStyle(color: Colors.white70)),
        ),
      );
    }

    return PreviewFrame(
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

        if (_loading) ...[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: _progress > 0 ? _progress : null,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'RF-DETR-S analyse la vidéo… ${(_progress * 100).round()} % · $_elapsedText\n'
            'La lecture suit l\'analyse en temps réel',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ] else if (_video != null) ...[
          const SizedBox(height: 10),
          Center(
            child: Chip(
              avatar: Icon(
                _result != null ? Icons.crop_free : Icons.movie_outlined,
                size: 18,
              ),
              label: Text(_result != null ? 'Vidéo analysée' : 'Vidéo originale'),
            ),
          ),
        ],

        const SizedBox(height: 16),

        Row(
          children: [
            ActionTile(
              icon: Icons.video_library_outlined,
              label: 'Galerie',
              onTap: _loading ? null : _pick,
            ),
            const SizedBox(width: 12),
            ActionTile(
              icon: Icons.videocam_outlined,
              label: 'Filmer',
              onTap: _loading
                  ? null
                  : () async {
                      final file = await ImagePicker().pickVideo(
                        source: ImageSource.camera,
                        maxDuration: const Duration(seconds: 30),
                      );
                      if (file == null) return;
                      setState(() {
                        _video = file;
                        _result = null;
                        _error = null;
                        _detections = const [];
                      });
                      await _detect();
                    },
            ),
          ],
        ),

        const SizedBox(height: 12),
        PrimaryButton(
          icon: Icons.search,
          label: _loading ? 'Analyse en cours…' : 'Détecter les oiseaux',
          onPressed: _video == null || _loading ? null : _detect,
        ),
        const SizedBox(height: 8),
        Text(
          'Seuil ${(widget.confidence * 100).round()} % · 1 image analysée sur ${widget.frameStep}',
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
                _row('Détections cumulées', '${_result!['total_bird_detections']}'),
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

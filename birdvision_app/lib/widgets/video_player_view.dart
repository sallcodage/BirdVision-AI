import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../theme.dart';

/// Lecteur vidéo avec lecture/pause, barre de progression, durée et son.
class VideoPlayerView extends StatefulWidget {
  final VideoPlayerController controller;

  const VideoPlayerView({super.key, required this.controller});

  @override
  State<VideoPlayerView> createState() => _VideoPlayerViewState();
}

class _VideoPlayerViewState extends State<VideoPlayerView> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onUpdate);
  }

  @override
  void didUpdateWidget(VideoPlayerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onUpdate);
      widget.controller.addListener(_onUpdate);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onUpdate);
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  void _togglePlay() {
    final c = widget.controller;
    if (c.value.isPlaying) {
      c.pause();
    } else {
      if (c.value.position >= c.value.duration) c.seekTo(Duration.zero);
      c.play();
    }
  }

  void _toggleMute() {
    final c = widget.controller;
    c.setVolume(c.value.volume > 0 ? 0 : 1);
  }

  static String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final value = c.value;

    if (value.hasError) {
      return _frame(
        const AspectRatio(
          aspectRatio: 16 / 9,
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'Impossible de lire cette vidéo.',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ),
        ),
      );
    }

    if (!value.isInitialized) {
      return _frame(
        const AspectRatio(
          aspectRatio: 16 / 9,
          child: Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        ),
      );
    }

    // Limite la hauteur des vidéos verticales (téléphone).
    final maxHeight = MediaQuery.sizeOf(context).height * 0.55;

    return _frame(
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: AspectRatio(
              aspectRatio: value.aspectRatio,
              child: GestureDetector(
                onTap: _togglePlay,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    VideoPlayer(c),
                    AnimatedOpacity(
                      opacity: value.isPlaying ? 0 : 1,
                      duration: const Duration(milliseconds: 200),
                      child: Container(
                        color: Colors.black26,
                        alignment: Alignment.center,
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            size: 40,
                            color: AppColors.primaryDeep,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 12, 6),
            child: Row(
              children: [
                IconButton(
                  onPressed: _togglePlay,
                  color: Colors.white,
                  icon: Icon(
                    value.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                  ),
                ),
                Expanded(
                  child: VideoProgressIndicator(
                    c,
                    allowScrubbing: true,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    colors: const VideoProgressColors(
                      playedColor: AppColors.accent,
                      bufferedColor: Colors.white38,
                      backgroundColor: Colors.white12,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${_format(value.position)} / ${_format(value.duration)}',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                IconButton(
                  onPressed: _toggleMute,
                  color: Colors.white70,
                  iconSize: 20,
                  icon: Icon(
                    value.volume > 0
                        ? Icons.volume_up_rounded
                        : Icons.volume_off_rounded,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _frame(Widget child) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(24),
      ),
      clipBehavior: Clip.antiAlias,
      child: Center(child: child),
    );
  }
}

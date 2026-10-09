import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/detection_models.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/server_settings.dart';

class ImageDetectionPage extends StatefulWidget {
  /// Si renseigné, ouvre directement la galerie ou la caméra.
  final ImageSource? initialSource;

  const ImageDetectionPage({super.key, this.initialSource});

  @override
  State<ImageDetectionPage> createState() => _ImageDetectionPageState();
}

class _ImageDetectionPageState extends State<ImageDetectionPage> {
  final ImagePicker _picker = ImagePicker();

  XFile? _image;
  Uint8List? _imageBytes;

  String _model = 'rtdetr-x';
  double _confidence = 0.30;

  bool _loading = false;
  String? _error;
  ImageDetectionResult? _result;
  bool _showResult = true;

  late final bool _cameraAvailable =
      _picker.supportsImageSource(ImageSource.camera);

  @override
  void initState() {
    super.initState();
    _recoverLostPhoto();
    final source = widget.initialSource;
    if (source != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _pick(source));
    }
  }

  /// Android peut fermer l'app pendant que la caméra est ouverte :
  /// on récupère alors la photo au redémarrage.
  Future<void> _recoverLostPhoto() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final lost = await _picker.retrieveLostData();
      if (lost.isEmpty || lost.file == null) return;
      await _setImage(lost.file!);
    } catch (_) {}
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final image = await _picker.pickImage(
        source: source,
        imageQuality: 90,
        maxWidth: 2560,
        maxHeight: 2560,
        preferredCameraDevice: CameraDevice.rear,
      );
      if (image == null) return;
      await _setImage(image);
    } catch (e) {
      setState(() {
        _error = source == ImageSource.camera
            ? 'Impossible d’ouvrir la caméra.\n'
                'Vérifiez l’autorisation d’accès à l’appareil photo.\n($e)'
            : 'Impossible de sélectionner l’image.\n($e)';
      });
    }
  }

  Future<void> _setImage(XFile image) async {
    final bytes = await image.readAsBytes();
    if (!mounted) return;
    setState(() {
      _image = image;
      _imageBytes = bytes;
      _error = null;
      _result = null;
    });
  }

  Future<void> _analyze() async {
    final image = _image;
    if (image == null) {
      setState(() => _error = 'Choisissez d’abord une image.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await ApiService.detectImage(
        image: image,
        model: _model,
        confidence: _confidence,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _showResult = true;
      });
      showInfoSnack(
        context,
        result.birdCount == 0
            ? 'Aucun oiseau détecté. Essayez un seuil plus bas.'
            : '${result.birdCount} oiseau${result.birdCount > 1 ? 'x' : ''} '
                'détecté${result.birdCount > 1 ? 's' : ''} !',
      );
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openFullscreen() {
    final result = _result;
    final showNetwork = _showResult && result?.resultImageUrl != null;
    final Widget image = showNetwork
        ? Image.network(result!.resultImageUrl!)
        : Image.memory(_imageBytes!);

    Navigator.push(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => _FullscreenImage(child: image),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analyse d’image'),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: ServerStatusChip(),
          ),
        ],
      ),
      body: PageBody(
        children: [
          _buildPreview(),
          const SizedBox(height: 14),
          SourceButtons(
            galleryIcon: Icons.photo_library_outlined,
            galleryLabel: 'Galerie',
            onGallery: _loading ? null : () => _pick(ImageSource.gallery),
            cameraIcon: Icons.camera_alt_outlined,
            cameraLabel: 'Prendre une photo',
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
            label: _result == null ? 'Analyser l’image' : 'Relancer l’analyse',
            loadingLabel: 'Analyse en cours…',
            onPressed: _image == null ? null : _analyze,
          ),
          if (_result != null) ...[
            const SizedBox(height: 24),
            _ResultSection(result: _result!),
          ],
        ],
      ),
    );
  }

  Widget _buildPreview() {
    final bytes = _imageBytes;
    if (bytes == null) {
      return MediaPlaceholder(
        icon: Icons.add_photo_alternate_outlined,
        title: 'Ajoutez une photo d’oiseau',
        subtitle: 'Touchez pour ouvrir la galerie',
        onTap: _loading ? null : () => _pick(ImageSource.gallery),
      );
    }

    final result = _result;
    final hasResultImage = result?.resultImageUrl != null;
    final showResult = _showResult && hasResultImage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasResultImage) ...[
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: false,
                icon: Icon(Icons.image_outlined),
                label: Text('Originale'),
              ),
              ButtonSegment(
                value: true,
                icon: Icon(Icons.crop_free_rounded),
                label: Text('Détections'),
              ),
            ],
            selected: {showResult},
            onSelectionChanged: (s) => setState(() => _showResult = s.first),
          ),
          const SizedBox(height: 12),
        ],
        GestureDetector(
          onTap: _openFullscreen,
          child: Container(
            constraints: const BoxConstraints(minHeight: 200, maxHeight: 420),
            decoration: BoxDecoration(
              color: const Color(0xFF14211C),
              borderRadius: BorderRadius.circular(24),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: showResult
                      ? Image.network(
                          result!.resultImageUrl!,
                          key: const ValueKey('result'),
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, progress) =>
                              progress == null
                                  ? child
                                  : const SizedBox(
                                      height: 260,
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                          errorBuilder: (context, error, stack) =>
                              const SizedBox(
                            height: 200,
                            child: Center(
                              child: Text(
                                'Impossible de charger l’image résultat.',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ),
                          ),
                        )
                      : Image.memory(
                          bytes,
                          key: const ValueKey('original'),
                          fit: BoxFit.contain,
                        ),
                ),
                if (_loading)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black45,
                      alignment: Alignment.center,
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: Colors.white),
                          SizedBox(height: 14),
                          Text(
                            'Recherche des oiseaux…',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.fullscreen_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ResultSection extends StatelessWidget {
  final ImageDetectionResult result;

  const _ResultSection({required this.result});

  @override
  Widget build(BuildContext context) {
    final average = result.averageConfidence;

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
                value: '${result.birdCount}',
                label: result.birdCount > 1
                    ? 'oiseaux détectés'
                    : 'oiseau détecté',
              ),
              StatTile(
                icon: Icons.verified_outlined,
                value: average == null ? '—' : '${(average * 100).round()} %',
                label: 'confiance moyenne',
                color: const Color(0xFFB8741A),
              ),
              StatTile(
                icon: Icons.memory_rounded,
                value: DetectorModel.nameOf(result.model),
                label: 'seuil ${(result.confidenceThreshold * 100).round()} %',
                color: const Color(0xFF1F4E79),
              ),
            ],
          ),
          if (result.detections.isNotEmpty) ...[
            const SizedBox(height: 18),
            const Text(
              'Détail des détections',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < result.detections.length; i++)
              _DetectionRow(index: i + 1, detection: result.detections[i]),
          ] else ...[
            const SizedBox(height: 14),
            const Text(
              'Aucun oiseau au-dessus du seuil choisi. '
              'Baissez le seuil ou essayez un autre modèle.',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetectionRow extends StatelessWidget {
  final int index;
  final BirdDetection detection;

  const _DetectionRow({required this.index, required this.detection});

  @override
  Widget build(BuildContext context) {
    final percent = (detection.confidence * 100).round();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 74,
            child: Text(
              'Oiseau $index',
              style: const TextStyle(color: AppColors.textMuted),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: detection.confidence,
                minHeight: 10,
                backgroundColor: AppColors.border,
                color: percent >= 70
                    ? AppColors.primary
                    : percent >= 45
                        ? AppColors.accent
                        : AppColors.error,
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 44,
            child: Text(
              '$percent %',
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _FullscreenImage extends StatelessWidget {
  final Widget child;

  const _FullscreenImage({required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text(
          'Pincez pour zoomer',
          style: TextStyle(color: Colors.white70, fontSize: 15),
        ),
      ),
      body: InteractiveViewer(
        minScale: 1,
        maxScale: 6,
        child: Center(child: child),
      ),
    );
  }
}

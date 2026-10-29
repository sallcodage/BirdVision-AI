import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'main.dart';
import 'widgets.dart';

class ImagePage extends StatefulWidget {
  const ImagePage({super.key, required this.settings});

  final Settings settings;

  @override
  State<ImagePage> createState() => _ImagePageState();
}

class _ImagePageState extends State<ImagePage> {
  final _picker = ImagePicker();

  XFile? _image;
  Map<String, dynamic>? _result;
  String? _error;
  bool _loading = false;

  bool _showResult = true;

  Future<void> _pick(ImageSource source) async {
    final file = await _picker.pickImage(
      source: source,
      maxWidth: 1920,
      imageQuality: 90,
    );
    if (file == null) return;

    setState(() {
      _image = file;
      _result = null;
      _error = null;
    });
  }

  Future<void> _detect() async {
    if (_image == null) return;

    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });

    try {
      final result = await widget.settings.api.detectImage(
        _image!,
        confidence: widget.settings.confidence,
        model: widget.settings.model,
      );
      setState(() {
        _result = result;
        _showResult = true;
      });
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      setState(() => _loading = false);
    }
  }

  Widget _original() => kIsWeb
      ? Image.network(_image!.path, fit: BoxFit.contain)
      : Image.file(File(_image!.path), fit: BoxFit.contain);

  Widget _annotated() => Image.network(
        _result!['result_image'] as String,
        fit: BoxFit.contain,
        loadingBuilder: (c, child, p) => p == null
            ? child
            : const SizedBox(
                height: 240,
                child: Center(child: CircularProgressIndicator()),
              ),
        errorBuilder: (c, e, s) => const SizedBox(
          height: 120,
          child: Center(child: Text('Impossible de charger l\'image résultat.')),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final detections = (_result?['detections'] as List?) ?? const [];

    final avg = detections.isEmpty
        ? 0.0
        : detections
                .map((d) => (d['confidence'] as num).toDouble())
                .reduce((a, b) => a + b) /
            detections.length;

    final modelName = widget.settings.modelDisplayName;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      children: [
        // ---------- Aperçu ----------
        if (_image == null)
          const EmptyPreview(
            icon: Icons.add_a_photo_outlined,
            title: 'Aucune photo',
            subtitle: 'Choisissez une image ou prenez une photo d\'oiseaux',
          )
        else
          PreviewFrame(
            loading: _loading,
            loadingText: '$modelName analyse l\'image…',
            child: Container(
              color: Colors.black,
              constraints: const BoxConstraints(minHeight: 200),
              width: double.infinity,
              child: _result != null && _showResult
                  ? _annotated()
                  : _original(),
            ),
          ),

        if (_result != null) ...[
          const SizedBox(height: 12),
          Center(
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: false,
                  icon: Icon(Icons.image_outlined),
                  label: Text('Original'),
                ),
                ButtonSegment(
                  value: true,
                  icon: Icon(Icons.crop_free),
                  label: Text('Détections'),
                ),
              ],
              selected: {_showResult},
              onSelectionChanged: (s) => setState(() => _showResult = s.first),
            ),
          ),
        ],

        const SizedBox(height: 16),

        // ---------- Actions ----------
        Row(
          children: [
            ActionTile(
              icon: Icons.photo_library_outlined,
              label: 'Galerie',
              onTap: _loading ? null : () => _pick(ImageSource.gallery),
            ),
            const SizedBox(width: 12),
            ActionTile(
              icon: Icons.photo_camera_outlined,
              label: 'Caméra',
              onTap: _loading ? null : () => _pick(ImageSource.camera),
            ),
          ],
        ),
        const SizedBox(height: 12),
        PrimaryButton(
          icon: Icons.search,
          label: _loading ? 'Analyse en cours…' : 'Détecter les oiseaux',
          onPressed: _image == null || _loading ? null : _detect,
        ),
        const SizedBox(height: 6),
        Text(
          'Modèle : $modelName · Seuil ${(widget.settings.confidence * 100).round()} %',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),

        if (_error != null) ...[
          const SizedBox(height: 16),
          ErrorBanner(_error!),
        ],

        // ---------- Résultats ----------
        if (_result != null) ...[
          const SizedBox(height: 20),
          Row(
            children: [
              StatTile(
                highlight: true,
                icon: Icons.flutter_dash,
                value: '${_result!['bird_count']}',
                label: 'oiseau(x)',
              ),
              const SizedBox(width: 10),
              StatTile(
                icon: Icons.verified_outlined,
                value: detections.isEmpty ? '–' : '${(avg * 100).round()} %',
                label: 'confiance moy.',
              ),
              const SizedBox(width: 10),
              StatTile(
                icon: Icons.tune,
                value:
                    '${((_result!['confidence_threshold'] as num) * 100).round()} %',
                label: 'seuil',
              ),
            ],
          ),
          if (detections.isNotEmpty) ...[
            const SizedBox(height: 12),
            const SectionTitle('Oiseaux détectés'),
            for (var i = 0; i < detections.length; i++)
              _DetectionCard(index: i + 1, detection: detections[i]),
          ] else ...[
            const SizedBox(height: 16),
            const Center(
              child: Text(
                'Aucun oiseau au-dessus du seuil.\n'
                'Essayez de baisser le seuil dans les réglages.',
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class _DetectionCard extends StatelessWidget {
  const _DetectionCard({required this.index, required this.detection});

  final int index;
  final dynamic detection;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final box = detection['box'];
    final conf = (detection['confidence'] as num).toDouble();
    final color = confidenceColor(conf);
    final w = ((box['x2'] as num) - (box['x1'] as num)).round();
    final h = ((box['y2'] as num) - (box['y1'] as num)).round();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withValues(alpha: 0.15),
            child: Text(
              '$index',
              style: TextStyle(color: color, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Oiseau',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    Text(
                      '${(conf * 100).toStringAsFixed(1)} %',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: conf,
                    minHeight: 6,
                    color: color,
                    backgroundColor: color.withValues(alpha: 0.15),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Position (${(box['x1'] as num).round()}, '
                  '${(box['y1'] as num).round()}) · taille $w × $h px',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

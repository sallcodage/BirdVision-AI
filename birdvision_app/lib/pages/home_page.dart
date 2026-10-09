import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/detection_models.dart';
import '../theme.dart';
import '../widgets/server_settings.dart';
import 'image_detection_page.dart';
import 'video_detection_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  void _openImage(BuildContext context, [ImageSource? source]) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ImageDetectionPage(initialSource: source),
      ),
    );
  }

  void _openVideo(BuildContext context, [ImageSource? source]) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VideoDetectionPage(initialSource: source),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cameraAvailable = ImagePicker().supportsImageSource(
      ImageSource.camera,
    );

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            const _Hero(),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Transform.translate(
                        offset: const Offset(0, -36),
                        child: Row(
                          children: [
                            Expanded(
                              child: _ActionCard(
                                gradient: AppColors.imageGradient,
                                icon: Icons.photo_camera_back_outlined,
                                title: 'Image',
                                subtitle: 'Photo ou galerie',
                                onTap: () => _openImage(context),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: _ActionCard(
                                gradient: AppColors.videoGradient,
                                icon: Icons.movie_creation_outlined,
                                title: 'Vidéo',
                                subtitle: 'Analyse image par image',
                                onTap: () => _openVideo(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (cameraAvailable) ...[
                        const _SectionTitle('Accès rapide'),
                        const SizedBox(height: 10),
                        _QuickAction(
                          icon: Icons.camera_alt_rounded,
                          title: 'Prendre une photo',
                          subtitle: 'Ouvre directement l’appareil photo',
                          onTap: () =>
                              _openImage(context, ImageSource.camera),
                        ),
                        const SizedBox(height: 10),
                        _QuickAction(
                          icon: Icons.videocam_rounded,
                          title: 'Filmer une vidéo',
                          subtitle: 'Enregistrez puis analysez',
                          onTap: () =>
                              _openVideo(context, ImageSource.camera),
                        ),
                        const SizedBox(height: 28),
                      ],
                      const _SectionTitle('Comment ça marche'),
                      const SizedBox(height: 12),
                      const _Steps(),
                      const SizedBox(height: 28),
                      const _SectionTitle('Modèles disponibles'),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final model in DetectorModel.all)
                            Chip(
                              avatar: const Icon(
                                Icons.memory_rounded,
                                size: 18,
                                color: AppColors.primary,
                              ),
                              label: Text(
                                '${model.name} · ${model.description}',
                              ),
                              backgroundColor: AppColors.surface,
                              side: const BorderSide(color: AppColors.border),
                              shape: const StadiumBorder(),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            // Grand oiseau décoratif en filigrane.
            Positioned(
              right: -30,
              bottom: 10,
              child: Icon(
                Icons.flutter_dash,
                size: 190,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 64),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.flutter_dash,
                              color: AppColors.accent,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'BirdVision AI',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const ServerStatusChip(onDark: true),
                        ],
                      ),
                      const SizedBox(height: 34),
                      const Text(
                        'Repérez chaque oiseau,\nen un instant.',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          height: 1.15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Détection intelligente sur vos photos et vidéos '
                        'grâce à trois modèles de vision par ordinateur.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.78),
                          fontSize: 15,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final Gradient gradient;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.gradient,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: Colors.white, size: 26),
                ),
                const SizedBox(height: 26),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFFB8741A)),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;

  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: AppColors.primaryDeep,
      ),
    );
  }
}

class _Steps extends StatelessWidget {
  const _Steps();

  @override
  Widget build(BuildContext context) {
    const steps = [
      (Icons.add_photo_alternate_outlined, 'Choisissez',
          'une photo, une vidéo ou utilisez la caméra'),
      (Icons.tune_rounded, 'Réglez',
          'le modèle d’IA et le seuil de confiance'),
      (Icons.insights_rounded, 'Découvrez',
          'les oiseaux encadrés et les statistiques'),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            for (var i = 0; i < steps.length; i++)
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                title: Text(
                  steps[i].$2,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(steps[i].$3),
                trailing: Icon(steps[i].$1, color: AppColors.textMuted),
              ),
          ],
        ),
      ),
    );
  }
}

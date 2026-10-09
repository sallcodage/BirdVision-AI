import 'package:flutter/material.dart';

import '../models/detection_models.dart';
import '../theme.dart';

/// Contenu centré, largeur limitée (lisible sur web/tablette).
class PageBody extends StatelessWidget {
  final List<Widget> children;

  const PageBody({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
  }
}

class SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  const SectionCard({
    super.key,
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDeep,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

class ModelSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String>? onChanged;

  const ModelSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final model in DetectorModel.all) ...[
          _ModelTile(
            model: model,
            selected: model.id == value,
            onTap: onChanged == null ? null : () => onChanged!(model.id),
          ),
          if (model != DetectorModel.all.last) const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _ModelTile extends StatelessWidget {
  final DetectorModel model;
  final bool selected;
  final VoidCallback? onTap;

  const _ModelTile({
    required this.model,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.primary.withValues(alpha: 0.08)
          : AppColors.background,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.primary : Colors.transparent,
              width: 1.6,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: selected ? AppColors.primary : AppColors.textMuted,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  model.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              Flexible(
                child: Text(
                  model.description,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ConfidenceSlider extends StatelessWidget {
  final double value;
  final ValueChanged<double>? onChanged;

  const ConfidenceSlider({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Ne garder que les détections au-dessus de :',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${(value * 100).round()} %',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: 0.10,
          max: 0.90,
          divisions: 16,
          onChanged: onChanged,
        ),
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Plus d’oiseaux',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
            Text('Plus sûr',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
          ],
        ),
      ],
    );
  }
}

class ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback? onClose;

  const ErrorBanner({super.key, required this.message, this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFFDECEA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF5C6C0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: AppColors.error),
          const SizedBox(width: 12),
          Expanded(
            child: SelectableText(
              message,
              style: const TextStyle(color: Color(0xFF8E2A1F), height: 1.35),
            ),
          ),
          if (onClose != null)
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: onClose,
              icon: const Icon(Icons.close, size: 18),
            ),
        ],
      ),
    );
  }
}

class AnalyzeButton extends StatelessWidget {
  final bool loading;
  final String label;
  final String loadingLabel;
  final VoidCallback? onPressed;

  const AnalyzeButton({
    super.key,
    required this.loading,
    required this.label,
    required this.loadingLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: loading ? null : onPressed,
      style: FilledButton.styleFrom(
        disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.55),
        disabledForegroundColor: Colors.white,
      ),
      icon: loading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.auto_awesome),
      label: Text(loading ? loadingLabel : label),
    );
  }
}

class StatTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const StatTile({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 2,
            style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

/// Grille de StatTile qui passe de 3 à 2 colonnes sur petit écran.
class StatGrid extends StatelessWidget {
  final List<Widget> tiles;

  const StatGrid({super.key, required this.tiles});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 360 ? 2 : 3;
        const gap = 10.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final tile in tiles) SizedBox(width: width, child: tile),
          ],
        );
      },
    );
  }
}

/// Deux boutons « source » côte à côte (galerie / caméra).
class SourceButtons extends StatelessWidget {
  final IconData galleryIcon;
  final String galleryLabel;
  final VoidCallback? onGallery;
  final IconData cameraIcon;
  final String cameraLabel;
  final VoidCallback? onCamera;
  final bool showCamera;

  const SourceButtons({
    super.key,
    required this.galleryIcon,
    required this.galleryLabel,
    required this.onGallery,
    required this.cameraIcon,
    required this.cameraLabel,
    required this.onCamera,
    this.showCamera = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: onGallery,
            icon: Icon(galleryIcon),
            label: Text(galleryLabel),
          ),
        ),
        if (showCamera) ...[
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onCamera,
              icon: Icon(cameraIcon),
              label: Text(cameraLabel),
            ),
          ),
        ],
      ],
    );
  }
}

/// Zone vide cliquable avant la sélection d'un média.
class MediaPlaceholder extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool dark;

  const MediaPlaceholder({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.dark = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = dark ? Colors.white70 : AppColors.textMuted;
    return Material(
      color: dark ? const Color(0xFF14211C) : AppColors.surface,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          height: 260,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: dark ? Colors.white12 : AppColors.border,
              width: 1.5,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: dark ? 0.25 : 0.1),
                ),
                child: Icon(icon,
                    size: 38,
                    color: dark ? Colors.white : AppColors.primary),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: dark ? Colors.white : AppColors.primaryDeep,
                ),
              ),
              const SizedBox(height: 4),
              Text(subtitle, style: TextStyle(color: fg, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

void showInfoSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

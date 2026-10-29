import 'package:flutter/material.dart';

import 'api.dart';

/// Cadres des oiseaux dessinés par-dessus une image ou une vidéo.
/// À placer dans un Stack de même taille que l'aperçu.
class BoxOverlay extends StatelessWidget {
  const BoxOverlay(this.boxes, {super.key});

  final List<BirdBox> boxes;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(painter: _BoxPainter(boxes), size: Size.infinite),
    );
  }
}

class _BoxPainter extends CustomPainter {
  _BoxPainter(this.boxes);

  final List<BirdBox> boxes;

  @override
  void paint(Canvas canvas, Size size) {
    for (final b in boxes) {
      final color = confidenceColor(b.confidence);
      final rect = Rect.fromLTRB(
        b.x1 * size.width,
        b.y1 * size.height,
        b.x2 * size.width,
        b.y2 * size.height,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(6)),
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );

      final label = TextPainter(
        text: TextSpan(
          text: ' oiseau ${(b.confidence * 100).round()} % ',
          style: TextStyle(
            color: Colors.white,
            backgroundColor: color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final top = rect.top - label.height < 0 ? rect.top : rect.top - label.height;
      label.paint(canvas, Offset(rect.left, top));
    }
  }

  @override
  bool shouldRepaint(_BoxPainter old) => old.boxes != boxes;
}

/// Grande tuile d'action (Galerie, Caméra…).
class ActionTile extends StatelessWidget {
  const ActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onTap != null;

    return Expanded(
      child: Material(
        color: scheme.secondaryContainer.withValues(alpha: enabled ? 1 : 0.5),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Column(
              children: [
                Icon(icon, size: 30, color: scheme.onSecondaryContainer),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSecondaryContainer,
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

/// Cadre arrondi de l'aperçu, avec un voile pendant l'analyse.
class PreviewFrame extends StatelessWidget {
  const PreviewFrame({
    super.key,
    required this.child,
    this.loading = false,
    this.loadingText = 'Analyse en cours…',
  });

  final Widget child;
  final bool loading;
  final String loadingText;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Stack(
        alignment: Alignment.center,
        children: [
          child,
          if (loading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.55),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 44,
                      height: 44,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      loadingText,
                      textAlign: TextAlign.center,
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
    );
  }
}

/// Zone vide affichée avant de choisir un fichier.
class EmptyPreview extends StatelessWidget {
  const EmptyPreview({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      height: 240,
      width: double.infinity,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outlineVariant, width: 1.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 34,
            backgroundColor: scheme.primaryContainer,
            child: Icon(icon, size: 34, color: scheme.onPrimaryContainer),
          ),
          const SizedBox(height: 14),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

/// Chiffre clé (nombre d'oiseaux, confiance moyenne…).
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
    this.highlight = false,
  });

  final String value;
  final String label;
  final IconData icon;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = highlight ? scheme.primary : scheme.surfaceContainerHigh;
    final fg = highlight ? scheme.onPrimary : scheme.onSurface;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: fg.withValues(alpha: 0.85)),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: fg,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: fg.withValues(alpha: 0.8)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Grand bouton principal « Détecter ».
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      icon: Icon(icon),
      label: Text(label),
      onPressed: onPressed,
    );
  }
}

class ErrorBanner extends StatelessWidget {
  const ErrorBanner(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: scheme.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

/// Couleur de confiance : vert (sûr) → orange → rouge (incertain).
Color confidenceColor(double value) {
  if (value >= 0.7) return const Color(0xFF1268E8);
  if (value >= 0.45) return const Color(0xFFEF8F00);
  return const Color(0xFFD84315);
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 10),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

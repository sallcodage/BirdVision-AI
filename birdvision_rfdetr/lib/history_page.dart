import 'package:flutter/material.dart';

import 'api.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key, required this.api, required this.token});

  final RfDetrApi api;
  final String token;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<HistoryEntry>? _entries;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(HistoryPage old) {
    super.didUpdateWidget(old);
    if (old.token != widget.token) _load();
  }

  Future<void> _load() async {
    if (_loading) return;
    setState(() { _loading = true; _error = null; });

    try {
      final entries = await widget.api.fetchHistory(widget.token.trim());
      if (mounted) setState(() { _entries = entries; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Historique',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                  if (!_loading)
                    IconButton(icon: const Icon(Icons.refresh), tooltip: 'Actualiser', onPressed: _load),
                ],
              ),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            SliverFillRemaining(child: _ErrorState(message: _error!, onRetry: _load))
          else if (_entries == null || _entries!.isEmpty)
            const SliverFillRemaining(child: _EmptyState())
          else ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 4),
              sliver: SliverToBoxAdapter(
                child: Text(
                  '${_entries!.length} analyse${_entries!.length > 1 ? 's' : ''}',
                  style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              sliver: SliverList.separated(
                itemCount: _entries!.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) => _HistoryCard(_entries![i]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard(this.entry);
  final HistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: _Thumbnail(url: entry.resultImage),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          _modelLabel(entry.model),
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _BirdBadge(count: entry.birdCount, scheme: scheme),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _InfoRow(icon: Icons.calendar_today_outlined, label: _formatDate(entry.createdAt)),
                  const SizedBox(height: 3),
                  _InfoRow(
                    icon: Icons.tune_outlined,
                    label: 'Confiance : ${(entry.confidenceThreshold * 100).round()} %',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _modelLabel(String id) => switch (id) {
    'rtdetr-x'    => 'RT-DETR-X',
    'yolo26s'     => 'YOLO26s',
    'dfine-x'     => 'D-FINE-X',
    'dfine-s'     => 'D-FINE-S',
    'rfdetr-s'    => 'RF-DETR-S',
    'faster-rcnn' => 'Faster R-CNN',
    _             => id.toUpperCase(),
  };

  String _formatDate(DateTime dt) {
    String p(int n) => n.toString().padLeft(2, '0');
    return '${p(dt.day)}/${p(dt.month)}/${dt.year}  ${p(dt.hour)}:${p(dt.minute)}';
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (url == null) return _placeholder(scheme);
    return Image.network(
      url!, width: 80, height: 80, fit: BoxFit.cover,
      loadingBuilder: (_, child, progress) => progress == null
          ? child
          : const SizedBox(width: 80, height: 80, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
      errorBuilder: (context, error, stackTrace) =>
    _placeholder(scheme),
    );
  }

  Widget _placeholder(ColorScheme scheme) => Container(
    width: 80, height: 80,
    color: scheme.surfaceContainerHigh,
    child: Icon(Icons.image_not_supported_outlined, color: scheme.onSurfaceVariant),
  );
}

class _BirdBadge extends StatelessWidget {
  const _BirdBadge({required this.count, required this.scheme});
  final int count;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final hasBirds = count > 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: hasBirds ? scheme.primaryContainer : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.flutter_dash, size: 14,
              color: hasBirds ? scheme.onPrimaryContainer : scheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Text('$count', style: TextStyle(
            fontWeight: FontWeight.w800, fontSize: 13,
            color: hasBirds ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
          )),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Row(
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Expanded(child: Text(label, style: TextStyle(fontSize: 12, color: color))),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 38,
              backgroundColor: scheme.primaryContainer,
              child: Icon(Icons.history, size: 38, color: scheme.onPrimaryContainer),
            ),
            const SizedBox(height: 16),
            Text('Aucune analyse',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('Vos prochaines analyses apparaîtront ici.',
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 38,
              backgroundColor: scheme.errorContainer,
              child: Icon(Icons.error_outline, size: 38, color: scheme.onErrorContainer),
            ),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 20),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.refresh),
              label: const Text('Réessayer'),
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

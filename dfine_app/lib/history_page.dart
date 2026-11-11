import 'dart:async';

import 'package:flutter/material.dart';

import 'api.dart';
import 'main.dart';
import 'widgets.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key, required this.settings});

  final Settings settings;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);

  List<HistoryEntry>? _entries;
  bool _loadingEntries = false;
  String? _errorEntries;

  List<TrackingSession>? _sessions;
  bool _loadingSessions = false;
  String? _errorSessions;

  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadEntries();
    _loadSessions();
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      if (_tab.index == 0) _silentRefreshEntries();
      else _silentRefreshSessions();
    });
    _tab.addListener(() {
      if (!_tab.indexIsChanging) return;
      if (_tab.index == 0 && _entries == null && !_loadingEntries) {
        _loadEntries();
      } else if (_tab.index == 1 && _sessions == null && !_loadingSessions) {
        _loadSessions();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _tab.dispose();
    super.dispose();
  }

  Future<void> _silentRefreshEntries() async {
    if (_loadingEntries) return;
    try {
      final token = widget.settings.token.trim();
      final entries = await widget.settings.api.fetchHistory(token);
      if (mounted) setState(() => _entries = entries);
    } catch (_) {}
  }

  Future<void> _silentRefreshSessions() async {
    if (_loadingSessions) return;
    try {
      final sessions = await widget.settings.api.fetchSessions();
      if (mounted) setState(() => _sessions = sessions);
    } catch (_) {}
  }

  Future<void> _loadEntries() async {
    if (_loadingEntries) return;
    setState(() {
      _loadingEntries = true;
      _errorEntries = null;
    });

    try {
      final token = widget.settings.token.trim();
      final entries = await widget.settings.api.fetchHistory(token);
      if (mounted) {
        setState(() {
          _entries = entries;
          _loadingEntries = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorEntries = e.toString().replaceFirst('Exception: ', '');
          _loadingEntries = false;
        });
      }
    }
  }

  Future<void> _loadSessions() async {
    if (_loadingSessions) return;
    setState(() {
      _loadingSessions = true;
      _errorSessions = null;
    });

    try {
      final sessions = await widget.settings.api.fetchSessions();
      if (mounted) {
        setState(() {
          _sessions = sessions;
          _loadingSessions = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorSessions = e.toString().replaceFirst('Exception: ', '');
          _loadingSessions = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── En-tête + onglets ───────────────────────────────────
        Container(
          color: Theme.of(context).colorScheme.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Historique',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Actualiser',
                      onPressed: () {
                        if (_tab.index == 0) {
                          _loadEntries();
                        } else {
                          _loadSessions();
                        }
                      },
                    ),
                  ],
                ),
              ),
              TabBar(
                controller: _tab,
                tabs: const [
                  Tab(text: 'Analyses image'),
                  Tab(text: 'Sessions de suivi'),
                ],
              ),
            ],
          ),
        ),

        // ── Contenu des onglets ─────────────────────────────────
        Expanded(
          child: TabBarView(
            controller: _tab,
            children: [
              _EntriesTab(
                entries: _entries,
                loading: _loadingEntries,
                error: _errorEntries,
                onRetry: _loadEntries,
              ),
              _SessionsTab(
                sessions: _sessions,
                loading: _loadingSessions,
                error: _errorSessions,
                onRetry: _loadSessions,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Onglet analyses image ────────────────────────────────────────

class _EntriesTab extends StatelessWidget {
  const _EntriesTab({
    required this.entries,
    required this.loading,
    required this.error,
    required this.onRetry,
  });

  final List<HistoryEntry>? entries;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null) {
      return _ErrorState(message: error!, onRetry: onRetry);
    }
    if (entries == null || entries!.isEmpty) {
      return const _EmptyState(message: 'Vos prochaines analyses apparaîtront ici.');
    }

    return RefreshIndicator(
      onRefresh: () async => onRetry(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        itemCount: entries!.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _HistoryCard(entries![i]),
      ),
    );
  }
}

// ── Onglet sessions de suivi ─────────────────────────────────────

class _SessionsTab extends StatelessWidget {
  const _SessionsTab({
    required this.sessions,
    required this.loading,
    required this.error,
    required this.onRetry,
  });

  final List<TrackingSession>? sessions;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null) {
      return _ErrorState(message: error!, onRetry: onRetry);
    }
    if (sessions == null || sessions!.isEmpty) {
      return const _EmptyState(
        message: 'Lancez une détection vidéo ou caméra live\npour créer une session.',
      );
    }

    return RefreshIndicator(
      onRefresh: () async => onRetry(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        itemCount: sessions!.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _SessionCard(sessions![i]),
      ),
    );
  }
}

// ── Carte session de tracking ────────────────────────────────────

class _SessionCard extends StatelessWidget {
  const _SessionCard(this.session);

  final TrackingSession session;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isLive = session.source == 'live';
    final dur = session.durationSeconds;
    final durText = dur != null
        ? dur >= 60
            ? '${(dur / 60).floor()} min ${(dur % 60).round()} s'
            : '${dur.round()} s'
        : '—';

    return Card(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isLive ? Icons.videocam_outlined : Icons.movie_outlined,
                  size: 18,
                  color: scheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_modelLabel(session.model)} · ${isLive ? 'Caméra live' : 'Vidéo'}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                _BirdBadge(count: session.uniqueBirdCount, scheme: scheme),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _InfoRow(
                    icon: Icons.calendar_today_outlined,
                    label: _formatDate(session.createdAt),
                  ),
                ),
                _InfoRow(icon: Icons.timer_outlined, label: durText),
              ],
            ),
            const SizedBox(height: 4),
            _InfoRow(
              icon: Icons.bar_chart_outlined,
              label: '${session.totalDetections} détection${session.totalDetections > 1 ? 's' : ''}',
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

// ── Carte d'une analyse image ────────────────────────────────────

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
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _BirdBadge(count: entry.birdCount, scheme: scheme),
                    ],
                  ),
                  const SizedBox(height: 6),
                  _InfoRow(
                    icon: Icons.calendar_today_outlined,
                    label: _formatDate(entry.createdAt),
                  ),
                  const SizedBox(height: 3),
                  _InfoRow(
                    icon: Icons.tune_outlined,
                    label:
                        'Confiance : ${(entry.confidenceThreshold * 100).round()} %',
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

// ── Miniature ────────────────────────────────────────────────────

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (url == null) return _placeholder(scheme);

    return Image.network(
      url!,
      width: 80,
      height: 80,
      fit: BoxFit.cover,
      loadingBuilder: (_, child, progress) => progress == null
          ? child
          : SizedBox(
              width: 80,
              height: 80,
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  value: progress.expectedTotalBytes != null
                      ? progress.cumulativeBytesLoaded /
                          progress.expectedTotalBytes!
                      : null,
                ),
              ),
            ),
      errorBuilder: (_, __, ___) => _placeholder(scheme),
    );
  }

  Widget _placeholder(ColorScheme scheme) => Container(
    width: 80,
    height: 80,
    color: scheme.surfaceContainerHigh,
    child: Icon(
      Icons.image_not_supported_outlined,
      color: scheme.onSurfaceVariant,
    ),
  );
}

// ── Badge oiseaux ────────────────────────────────────────────────

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
          Icon(
            Icons.flutter_dash,
            size: 14,
            color: hasBirds
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: hasBirds
                  ? scheme.onPrimaryContainer
                  : scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Ligne d'info (icône + texte) ─────────────────────────────────

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
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: color),
          ),
        ),
      ],
    );
  }
}

// ── État vide ────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

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
              child: Icon(
                Icons.history,
                size: 38,
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Aucun résultat',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

// ── État erreur ──────────────────────────────────────────────────

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
              child: Icon(
                Icons.error_outline,
                size: 38,
                color: scheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
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

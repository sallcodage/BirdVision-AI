import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/server_config.dart';
import '../theme.dart';

/// Pastille « Serveur connecté / hors ligne ». Toucher = réglages.
class ServerStatusChip extends StatefulWidget {
  final bool onDark;

  const ServerStatusChip({super.key, this.onDark = false});

  @override
  State<ServerStatusChip> createState() => _ServerStatusChipState();
}

class _ServerStatusChipState extends State<ServerStatusChip> {
  bool? _online;

  @override
  void initState() {
    super.initState();
    ServerConfig.baseUrl.addListener(_check);
    _check();
  }

  @override
  void dispose() {
    ServerConfig.baseUrl.removeListener(_check);
    super.dispose();
  }

  Future<void> _check() async {
    setState(() => _online = null);
    final ok = await ApiService.ping();
    if (mounted) setState(() => _online = ok);
  }

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (_online) {
      null => (Colors.amber, 'Connexion…'),
      true => (const Color(0xFF3DDC97), 'Serveur connecté'),
      false => (const Color(0xFFFF6B6B), 'Serveur hors ligne'),
    };

    return Material(
      color: widget.onDark
          ? Colors.white.withValues(alpha: 0.12)
          : AppColors.surface,
      shape: StadiumBorder(
        side: BorderSide(
          color: widget.onDark ? Colors.white24 : AppColors.border,
        ),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () async {
          await showServerSettings(context);
          _check();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: widget.onDark ? Colors.white : AppColors.primaryDeep,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.settings_outlined,
                size: 14,
                color: widget.onDark ? Colors.white70 : AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showServerSettings(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppColors.surface,
    builder: (_) => const _ServerSettingsSheet(),
  );
}

class _ServerSettingsSheet extends StatefulWidget {
  const _ServerSettingsSheet();

  @override
  State<_ServerSettingsSheet> createState() => _ServerSettingsSheetState();
}

class _ServerSettingsSheetState extends State<_ServerSettingsSheet> {
  late final TextEditingController _controller =
      TextEditingController(text: ServerConfig.baseUrl.value);
  bool _testing = false;
  bool? _result;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveAndTest() async {
    setState(() {
      _testing = true;
      _result = null;
    });
    await ServerConfig.save(_controller.text);
    _controller.text = ServerConfig.baseUrl.value;
    final ok = await ApiService.ping();
    if (mounted) {
      setState(() {
        _testing = false;
        _result = ok;
      });
    }
  }

  Future<void> _reset() async {
    await ServerConfig.reset();
    _controller.text = ServerConfig.baseUrl.value;
    setState(() => _result = null);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Serveur Django',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Émulateur Android : http://10.0.2.2:8000\n'
            'Web / iOS simulateur : http://127.0.0.1:8000\n'
            'Téléphone réel : http://IP-DU-PC:8000 (même Wi-Fi)',
            style: TextStyle(color: AppColors.textMuted, height: 1.5),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.dns_outlined),
              hintText: 'http://192.168.1.20:8000',
            ),
            onSubmitted: (_) => _saveAndTest(),
          ),
          if (_result != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  _result! ? Icons.check_circle : Icons.cancel,
                  color: _result! ? AppColors.primary : AppColors.error,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _result!
                        ? 'Connexion réussie.'
                        : 'Pas de réponse. Lancez Django avec '
                            '« runserver 0.0.0.0:8000 ».',
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _testing ? null : _reset,
                  child: const Text('Par défaut'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: _testing ? null : _saveAndTest,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: _testing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Enregistrer et tester'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

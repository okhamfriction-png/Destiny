import 'package:flutter/material.dart';

import '../../application/state/spectacle_controller.dart';
import '../visuals/entity_visuals.dart';

/// Historique des parties de Mode Spectacle terminées.
class SpectacleArchivesScreen extends StatefulWidget {
  const SpectacleArchivesScreen({required this.controller, super.key});

  final SpectacleController controller;

  @override
  State<SpectacleArchivesScreen> createState() =>
      _SpectacleArchivesScreenState();
}

class _SpectacleArchivesScreenState extends State<SpectacleArchivesScreen> {
  List<Map<String, dynamic>> _records = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await widget.controller.loadHistory();
    if (!mounted) return;
    setState(() {
      _records = r;
      _loading = false;
    });
  }

  Future<void> _clearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Vider l\'historique ?'),
        content: const Text('Toutes les parties archivées seront supprimées.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Vider')),
        ],
      ),
    );
    if (ok != true) return;
    await widget.controller.clearHistory();
    await _load();
  }

  String _date(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Parties archivées'),
        actions: [
          if (_records.isNotEmpty)
            IconButton(
                tooltip: 'Vider',
                icon: const Icon(Icons.delete_sweep),
                onPressed: _clearAll),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF141029), Color(0xFF0A0818)],
          ),
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _records.isEmpty
                ? Center(
                    child: Text('Aucune partie terminée pour l\'instant.',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: Colors.white54)),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _records.length,
                    itemBuilder: (context, i) {
                      final r = _records[i];
                      final arch = r['archetype'] as String? ?? '';
                      final emoji = arch.isEmpty
                          ? null
                          : EntityVisuals.emojiForArchetypeName(arch);
                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          leading: Text(emoji ?? '🎭',
                              style: const TextStyle(fontSize: 24)),
                          title: Text(
                              '${r['lieu'] ?? ''} · ${r['danger'] ?? ''}'),
                          subtitle: Text(
                            '${arch.isEmpty ? '' : '$arch · '}'
                            '${(r['mode'] as String? ?? '')} · '
                            '${_date((r['createdAt'] as num?)?.toInt() ?? 0)}',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => _ArchiveDetailScreen(record: r)),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}

class _ArchiveDetailScreen extends StatelessWidget {
  const _ArchiveDetailScreen({required this.record});

  final Map<String, dynamic> record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final log = (record['log'] as List<dynamic>? ?? const [])
        .map((e) => (e as Map).cast<String, dynamic>())
        .toList();
    return Scaffold(
      appBar: AppBar(title: Text(record['lieu'] as String? ?? 'Partie')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF141029), Color(0xFF0A0818)],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Text('${record['lieu'] ?? ''} · ${record['danger'] ?? ''}',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            // Transcript.
            for (final item in log) _ArchiveBubble(item: item),
            // Score.
            if (record['score'] != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFC24B).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: const Color(0xFFFFC24B).withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Score',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(color: const Color(0xFFFFC24B))),
                    const SizedBox(height: 8),
                    _renderDynamic(theme, record['score']),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ArchiveBubble extends StatelessWidget {
  const _ArchiveBubble({required this.item});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPlayer = item['isPlayer'] as bool? ?? false;
    final arch = item['archetype'] as String? ?? '';
    final emoji =
        arch.isEmpty ? null : EntityVisuals.emojiForArchetypeName(arch);
    final personnage = item['personnage'] as String? ?? '';
    final texte = item['texte'] as String? ?? '';
    final didascalie = item['didascalie'] as String? ?? '';
    final success = item['success'] as bool?;

    Color bg;
    if (success == true) {
      bg = Colors.green.withValues(alpha: 0.16);
    } else if (success == false) {
      bg = Colors.red.withValues(alpha: 0.14);
    } else {
      bg = isPlayer
          ? theme.colorScheme.primary.withValues(alpha: 0.14)
          : Colors.white.withValues(alpha: 0.05);
    }

    return Align(
      alignment: isPlayer ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment:
              isPlayer ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isPlayer && didascalie.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(didascalie,
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white54,
                        fontStyle: FontStyle.italic)),
              ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (emoji != null) ...[
                  Text(emoji, style: const TextStyle(fontSize: 16)),
                  const SizedBox(width: 4),
                ],
                Text(
                  isPlayer
                      ? (personnage.isEmpty ? 'Toi' : 'Toi — $personnage')
                      : personnage,
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: theme.colorScheme.primary),
                ),
              ],
            ),
            Text(texte, style: theme.textTheme.bodyMedium?.copyWith(height: 1.35)),
          ],
        ),
      ),
    );
  }
}

/// Rendu générique d'une valeur JSON (dupliqué léger pour l'écran d'archive).
Widget _renderDynamic(ThemeData theme, Object? value) {
  if (value == null) return const SizedBox.shrink();
  if (value is String) {
    return Text(value, style: theme.textTheme.bodyMedium?.copyWith(height: 1.35));
  }
  if (value is num || value is bool) {
    return Text('$value', style: theme.textTheme.bodyMedium);
  }
  if (value is List) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final e in value)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('•  '),
                Expanded(child: _renderDynamic(theme, e)),
              ],
            ),
          ),
      ],
    );
  }
  if (value is Map) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in value.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.key.toString(),
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: theme.colorScheme.primary)),
                const SizedBox(height: 2),
                _renderDynamic(theme, entry.value),
              ],
            ),
          ),
      ],
    );
  }
  return Text('$value', style: theme.textTheme.bodyMedium);
}

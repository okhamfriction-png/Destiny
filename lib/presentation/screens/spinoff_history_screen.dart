import 'package:flutter/material.dart';

import '../../application/state/spinoff_history.dart';
import '../visuals/entity_visuals.dart';

/// Historique des spin-off générés. Vider l'historique réautorise les films.
class SpinoffHistoryScreen extends StatefulWidget {
  const SpinoffHistoryScreen({required this.history, super.key});

  final SpinoffHistory history;

  @override
  State<SpinoffHistoryScreen> createState() => _SpinoffHistoryScreenState();
}

class _SpinoffHistoryScreenState extends State<SpinoffHistoryScreen> {
  @override
  void initState() {
    super.initState();
    widget.history.addListener(_onChange);
  }

  @override
  void dispose() {
    widget.history.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Vider l\'historique des spin-off ?'),
        content: const Text(
            'Les films déjà tirés pourront de nouveau ressortir.'),
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
    if (ok == true) await widget.history.clear();
  }

  String _date(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final records = widget.history.records;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Spin-off tirés'),
        actions: [
          if (records.isNotEmpty)
            IconButton(
                tooltip: 'Vider',
                icon: const Icon(Icons.delete_sweep),
                onPressed: _clear),
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
        child: records.isEmpty
            ? Center(
                child: Text('Aucun spin-off pour l\'instant.',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: Colors.white54)),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: records.length,
                itemBuilder: (context, i) {
                  final r = records[i];
                  final ctx = (r['context'] as Map?)?.cast<String, dynamic>() ??
                      const {};
                  final film = ctx['film']?.toString() ?? '';
                  final annee = ctx['annee']?.toString() ?? '';
                  final protos =
                      (ctx['protagonistes'] as List<dynamic>? ?? const []);
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ExpansionTile(
                      leading: const Icon(Icons.movie, color: Color(0xFFFFC24B)),
                      title: Text(annee.isEmpty ? film : '$film ($annee)'),
                      subtitle: Text(
                        '${r['genre'] ?? ''} · ${r['decade'] ?? ''} · '
                        '${_date((r['createdAt'] as num?)?.toInt() ?? 0)}',
                      ),
                      childrenPadding:
                          const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      children: [
                        if ((ctx['lieu'] ?? '').toString().isNotEmpty)
                          _line(theme, 'Lieu : ${ctx['lieu']}'),
                        if ((ctx['danger'] ?? '').toString().isNotEmpty)
                          _line(theme, 'Danger : ${ctx['danger']}'),
                        const SizedBox(height: 6),
                        for (final p in protos)
                          _proto(theme, (p as Map).cast<String, dynamic>()),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _line(ThemeData theme, String text) => Align(
        alignment: Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Text(text, style: theme.textTheme.bodySmall),
        ),
      );

  Widget _proto(ThemeData theme, Map<String, dynamic> p) {
    final anta = p['antagoniste'] as bool? ?? false;
    final color = anta ? const Color(0xFFFF5252) : Colors.white;
    final arch = p['archetype']?.toString() ?? '';
    final emoji = EntityVisuals.emojiForArchetypeName(arch) ?? '🎭';
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 15)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '${p['prenom'] ?? ''}  ·  $arch',
              style: theme.textTheme.bodySmall?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

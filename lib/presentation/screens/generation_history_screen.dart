import 'package:flutter/material.dart';

import '../../application/state/generation_history.dart';

/// Historique des scènes générées dans le Générateur.
class GenerationHistoryScreen extends StatefulWidget {
  const GenerationHistoryScreen({required this.history, super.key});

  final GenerationHistory history;

  @override
  State<GenerationHistoryScreen> createState() =>
      _GenerationHistoryScreenState();
}

class _GenerationHistoryScreenState extends State<GenerationHistoryScreen> {
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

  String _date(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)} ${two(d.hour)}:${two(d.minute)}';
  }

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tout effacer ?'),
        content: const Text('Vider l\'historique des scènes générées ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Effacer')),
        ],
      ),
    );
    if (ok == true) await widget.history.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final records = widget.history.records;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historique'),
        actions: [
          if (records.isNotEmpty)
            IconButton(
              tooltip: 'Tout effacer',
              icon: const Icon(Icons.delete_sweep),
              onPressed: _confirmClear,
            ),
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
            ? const Center(
                child: Text('Aucune scène générée pour l\'instant.',
                    style: TextStyle(color: Colors.white54)),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: records.length,
                itemBuilder: (context, i) {
                  final r = records[i];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ExpansionTile(
                      leading: Icon(
                          r.rue ? Icons.directions_walk : Icons.menu_book,
                          color: theme.colorScheme.primary),
                      title: Text('${r.location} · ${r.danger}',
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                          '${_date(r.createdAt)}'
                          '${r.rue ? ' · Rue' : ''}'
                          '${r.dangerStyle.isNotEmpty ? ' · ${r.dangerStyle}' : ''}',
                          style: const TextStyle(color: Colors.white54)),
                      childrenPadding:
                          const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      children: [
                        if (r.archetypes.isNotEmpty)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Héros : ${[
                                for (var k = 0; k < r.archetypes.length; k++)
                                  '${r.archetypes[k]}'
                                      '${k < r.roles.length ? ' (${r.roles[k]})' : ''}'
                              ].join(', ')}',
                              style:
                                  theme.textTheme.bodySmall?.copyWith(
                                      color: Colors.white70),
                            ),
                          ),
                        if (r.paliers.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          for (var k = 0; k < r.paliers.length; k++)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 3),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text('${k + 1}. ${r.paliers[k]}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                        color: Colors.white54, height: 1.3)),
                              ),
                            ),
                        ],
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.icon(
                            onPressed: () => Navigator.pop(context, r),
                            icon: const Icon(Icons.open_in_new, size: 18),
                            label: const Text('Réafficher'),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

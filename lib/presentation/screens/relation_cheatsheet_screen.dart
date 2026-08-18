import 'package:flutter/material.dart';

import '../../application/state/relation_cheatsheet.dart';

const Color _gold = Color(0xFFFFC24B);

/// Vue lecture seule de l'antisèche : liens groupés par registre. Embarquable
/// (ex. dans un panneau dépliable de l'Acte 1).
class RelationCheatsheetView extends StatelessWidget {
  const RelationCheatsheetView({required this.cheatsheet, super.key});
  final RelationCheatsheet cheatsheet;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: cheatsheet,
      builder: (context, _) {
        final theme = Theme.of(context);
        final links = cheatsheet.links;
        // Regroupe par registre (ordre défini + registres inconnus à la fin).
        final byReg = <String, List<String>>{};
        for (final l in links) {
          byReg.putIfAbsent(l.registre, () => []).add(l.texte);
        }
        final ordered = [
          ...RelationCheatsheet.registres.where(byReg.containsKey),
          ...byReg.keys.where((r) => !RelationCheatsheet.registres.contains(r)),
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Des points de départ, jamais imposés : un écart de statut avec '
              'une amorce d\'histoire.',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.white54),
            ),
            const SizedBox(height: 8),
            for (final reg in ordered) ...[
              Text(reg.toUpperCase(),
                  style: const TextStyle(
                      color: _gold,
                      fontSize: 12,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              for (final t in byReg[reg]!)
                Padding(
                  padding: const EdgeInsets.only(bottom: 5, left: 2),
                  child: Text('• $t',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: Colors.white, height: 1.3)),
                ),
              const SizedBox(height: 8),
            ],
          ],
        );
      },
    );
  }
}

/// Éditeur de l'antisèche de relations (ajouter / modifier / supprimer).
class RelationCheatsheetScreen extends StatefulWidget {
  const RelationCheatsheetScreen({required this.cheatsheet, super.key});
  final RelationCheatsheet cheatsheet;

  @override
  State<RelationCheatsheetScreen> createState() =>
      _RelationCheatsheetScreenState();
}

class _RelationCheatsheetScreenState extends State<RelationCheatsheetScreen> {
  @override
  void initState() {
    super.initState();
    widget.cheatsheet.addListener(_onChange);
  }

  @override
  void dispose() {
    widget.cheatsheet.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  Future<void> _editDialog({int? index}) async {
    final existing = index != null ? widget.cheatsheet.links[index] : null;
    var registre = existing?.registre ?? RelationCheatsheet.registres.first;
    final ctrl = TextEditingController(text: existing?.texte ?? '');
    final result = await showDialog<RelationLink>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(index == null ? 'Nouveau lien' : 'Modifier le lien'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<String>(
                isExpanded: true,
                value: RelationCheatsheet.registres.contains(registre)
                    ? registre
                    : RelationCheatsheet.registres.first,
                items: [
                  for (final r in RelationCheatsheet.registres)
                    DropdownMenuItem(value: r, child: Text(r)),
                ],
                onChanged: (v) => setLocal(() => registre = v ?? registre),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: ctrl,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Lien (écart de statut + amorce)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler')),
            FilledButton(
              onPressed: () {
                final t = ctrl.text.trim();
                if (t.isEmpty) return;
                Navigator.pop(
                    context, RelationLink(registre: registre, texte: t));
              },
              child: const Text('Valider'),
            ),
          ],
        ),
      ),
    );
    if (result == null) return;
    if (index == null) {
      await widget.cheatsheet.add(result);
    } else {
      await widget.cheatsheet.update(index, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final links = widget.cheatsheet.links;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Antisèche de relations'),
        actions: [
          IconButton(
            tooltip: 'Restaurer les liens d\'origine',
            icon: const Icon(Icons.restore),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Restaurer ?'),
                  content: const Text(
                      'Remplacer tous les liens par la liste d\'origine ?'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Annuler')),
                    FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Restaurer')),
                  ],
                ),
              );
              if (ok == true) await widget.cheatsheet.resetToDefault();
            },
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
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            for (var i = 0; i < links.length; i++)
              Card(
                margin: const EdgeInsets.symmetric(vertical: 3),
                child: ListTile(
                  title: Text(links[i].texte),
                  subtitle: Text(links[i].registre,
                      style: const TextStyle(color: _gold, fontSize: 12)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, size: 20),
                        onPressed: () => _editDialog(index: i),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 20),
                        onPressed: () => widget.cheatsheet.removeAt(i),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
    );
  }
}

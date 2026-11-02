import 'package:flutter/material.dart';

import '../../application/state/relation_cheatsheet.dart';
import '../destiny/donnees.dart';
import '../destiny/page.dart';
import '../theme/destiny_theme.dart';

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
        final c = context.destiny;
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
              context.textes.t('relations.intro'),
              style: TextStyle(fontFamily: kPoliceTexte, fontSize: 14, height: 1.35, color: c.texteSecondaire),
            ),
            const SizedBox(height: 8),
            for (final reg in ordered) ...[
              Text(
                reg.toUpperCase(),
                style: TextStyle(
                  fontFamily: kPoliceTexte,
                  color: c.titre,
                  fontSize: 13.5,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              for (final texte in byReg[reg]!) Puce(texte),
              const SizedBox(height: 6),
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
  State<RelationCheatsheetScreen> createState() => _RelationCheatsheetScreenState();
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

  String k(String x, [Map<String, String> v = const {}]) => context.textes.t('relations.$x', v);

  Future<void> _editDialog({int? index}) async {
    final existing = index != null ? widget.cheatsheet.links[index] : null;
    var registre = existing?.registre ?? RelationCheatsheet.registres.first;
    final ctrl = TextEditingController(text: existing?.texte ?? '');
    final result = await showDialog<RelationLink>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(index == null ? k('nouveau') : k('modifier')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: RelationCheatsheet.registres.contains(registre)
                    ? registre
                    : RelationCheatsheet.registres.first,
                decoration: InputDecoration(labelText: k('registre'), border: const OutlineInputBorder()),
                items: [
                  for (final r in RelationCheatsheet.registres) DropdownMenuItem(value: r, child: Text(r)),
                ],
                onChanged: (v) => setLocal(() => registre = v ?? registre),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                minLines: 2,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: k('champ'),
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(k('annuler'))),
            FilledButton(
              onPressed: () {
                final texte = ctrl.text.trim();
                if (texte.isEmpty) return;
                Navigator.pop(context, RelationLink(registre: registre, texte: texte));
              },
              child: Text(k('valider')),
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

  Future<void> _restaurer() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(k('restaurer_titre')),
        content: Text(k('restaurer_texte')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(k('annuler'))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(k('restaurer_ok'))),
        ],
      ),
    );
    if (ok == true) await widget.cheatsheet.resetToDefault();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.textes;
    final c = context.destiny;
    final links = widget.cheatsheet.links;
    Widget centre(Widget enfant) =>
        Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 760), child: enfant));
    return Scaffold(
      appBar: AppBar(
        title: Text(k('titre')),
        actions: [
          IconButton(
            tooltip: k('restaurer'),
            icon: const Icon(Icons.restore_rounded),
            onPressed: _restaurer,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editDialog(),
        icon: const Icon(Icons.add_rounded),
        label: Text(k('ajouter')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          centre(Paragraphe(k('intro'), italique: true)),
          if (links.isEmpty) centre(Paragraphe(k('vide'))),
          for (var i = 0; i < links.length; i++)
            centre(CadreLisere(
              couleur: c.or,
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      links[i].registre.toUpperCase(),
                      style: TextStyle(
                        fontFamily: kPoliceTexte,
                        fontSize: 12.5,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700,
                        color: c.titre,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      links[i].texte,
                      style: TextStyle(fontFamily: kPoliceTexte, fontSize: 14.5, height: 1.35, color: c.texte),
                    ),
                  ]),
                ),
                IconButton(
                  tooltip: t.t('accessibilite.modifier'),
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  color: c.texteSecondaire,
                  onPressed: () => _editDialog(index: i),
                ),
                IconButton(
                  tooltip: t.t('accessibilite.supprimer'),
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  color: c.texteSecondaire,
                  onPressed: () => widget.cheatsheet.removeAt(i),
                ),
              ]),
            )),
        ],
      ),
    );
  }
}

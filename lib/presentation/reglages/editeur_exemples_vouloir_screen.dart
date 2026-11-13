import 'package:flutter/material.dart';

import '../../application/state/reglages_destiny.dart';
import '../destiny/donnees.dart';
import '../destiny/page.dart';

/// Le mode admin : l'exemple de vouloir de chaque animal, pour les adultes et
/// pour les enfants. Les textes changés passent par-dessus la grammaire ; un
/// champ vidé reprend le texte du fichier.
class EditeurExemplesVouloirScreen extends StatefulWidget {
  const EditeurExemplesVouloirScreen({super.key, required this.reglages});

  final ReglagesDestiny reglages;

  @override
  State<EditeurExemplesVouloirScreen> createState() => _EditeurExemplesVouloirScreenState();
}

class _EditeurExemplesVouloirScreenState extends State<EditeurExemplesVouloirScreen> {
  final Map<String, TextEditingController> _champs = {};

  TextEditingController _champ(String cle, String texte) =>
      _champs.putIfAbsent(cle, () => TextEditingController(text: texte));

  @override
  void dispose() {
    for (final c in _champs.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Enregistre ce qui a changé ; un champ vide rend le texte de la grammaire.
  Future<void> _enregistrer() async {
    final g = context.grammaire;
    final t = context.textes;
    final messager = ScaffoldMessenger.of(context);
    for (final a in g.animaux) {
      for (final kids in [false, true]) {
        final champ = _champs[kids ? '${a.id}.kids' : a.id];
        if (champ == null) continue;
        final texte = champ.text.trim();
        if (texte == a.exempleVouloirPour(kids: kids)) continue;
        await widget.reglages.changerExempleVouloir(a.id, texte.isEmpty ? null : texte, kids: kids);
      }
    }
    messager.showSnackBar(SnackBar(content: Text(t.t('editeurs.catalogue.enregistre'))));
  }

  Future<void> _remettre(String animalId) async {
    await widget.reglages.changerExempleVouloir(animalId, null);
    await widget.reglages.changerExempleVouloir(animalId, null, kids: true);
    _champs.remove(animalId)?.dispose();
    _champs.remove('$animalId.kids')?.dispose();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final g = context.grammaire;
    final t = context.textes;
    String k(String x) => t.t('trouver_vouloir.$x');
    final changes = widget.reglages.exemplesVouloir;
    return PageDestiny(
      titre: k('admin_titre'),
      enfants: [
        Paragraphe(k('admin_aide'), italique: true),
        for (final arch in g.archetypes)
          SectionDestiny(titre: arch.nom, enfants: [
            for (final a in g.animauxDe(arch.id)) ...[
              Row(children: [
                Expanded(child: Text(a.nom, style: Theme.of(context).textTheme.titleMedium)),
                if (changes.containsKey(a.id) || changes.containsKey('${a.id}.kids'))
                  TextButton.icon(
                    onPressed: () => _remettre(a.id),
                    icon: const Icon(Icons.restart_alt_rounded, size: 18),
                    label: Text(k('admin_remettre')),
                  ),
              ]),
              const SizedBox(height: 6),
              TextField(
                key: ValueKey('vouloir_${a.id}'),
                controller: _champ(a.id, a.exempleVouloir),
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(labelText: k('admin_adulte')),
              ),
              const SizedBox(height: 8),
              TextField(
                key: ValueKey('vouloir_${a.id}_kids'),
                controller: _champ('${a.id}.kids', a.exempleVouloirKids),
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(labelText: k('admin_kids')),
              ),
              const SizedBox(height: 14),
            ],
          ]),
        const SizedBox(height: 8),
        FilledButton.icon(
          key: const ValueKey('vouloir_enregistrer'),
          onPressed: _enregistrer,
          icon: const Icon(Icons.save_outlined),
          label: Text(t.t('editeurs.catalogue.enregistrer')),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../../domain/grammaire/controle_besoin.dart';
import '../../domain/troupe/session.dart';
import '../destiny/composants.dart';
import '../destiny/donnees.dart';
import '../destiny/page.dart';
import '../theme/destiny_theme.dart';
import 'troupe_screen.dart';

/// Le débrief : pour chaque personnage, la phrase du groupe face à celle
/// choisie au premier figé, le choix de l'acte 4 et le prix payé. Puis ce qui
/// a marché. Le ton reste positif.
class DebriefScreen extends StatefulWidget {
  const DebriefScreen({super.key, required this.contexte, required this.session});

  final ContexteTroupe contexte;
  final SessionTroupe session;

  @override
  State<DebriefScreen> createState() => _DebriefScreenState();
}

class _DebriefScreenState extends State<DebriefScreen> {
  final TextEditingController _marche = TextEditingController();

  SessionTroupe get s => widget.session;

  @override
  void dispose() {
    _marche.dispose();
    super.dispose();
  }

  Future<void> _sauver() => widget.contexte.store.enregistrer(s);

  @override
  Widget build(BuildContext context) {
    final t = context.textes;
    final c = context.destiny;
    String d(String k) => t.t('debrief.$k');
    return PageDestiny(
      titre: d('titre'),
      enfants: [
        Paragraphe(d('intro'), gras: true),
        for (final p in s.personnages) _personnage(context, p),
        SectionDestiny(titre: d('ce_qui_a_marche'), enfants: [
          Row(children: [
            Expanded(
              child: TextField(
                controller: _marche,
                decoration: InputDecoration(hintText: d('aide_marche'), isDense: true),
                onSubmitted: (_) => _ajouter(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(onPressed: _ajouter, child: Text(d('ajouter'))),
          ]),
          const SizedBox(height: 8),
          for (final m in s.ceQuiAMarche) Puce(m),
        ]),
        const SizedBox(height: 22),
        FilledButton.icon(
          icon: const Icon(Icons.celebration_rounded),
          onPressed: () async {
            s.etape = EtapeSession.terminee;
            await _sauver();
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(d('bravo'))));
            ouvrirEtape(context, widget.contexte, s, remplacer: true);
          },
          label: Text(d('enregistrer')),
        ),
        const SizedBox(height: 8),
        Center(child: Text(d('bravo'), style: TextStyle(fontFamily: kPoliceTitres, color: c.titre))),
      ],
    );
  }

  void _ajouter() {
    final v = _marche.text.trim();
    if (v.isEmpty) return;
    setState(() {
      s.ceQuiAMarche.add(v);
      _marche.clear();
    });
    _sauver();
  }

  Widget _personnage(BuildContext context, PersonnageTroupe p) {
    final g = context.grammaire;
    final t = context.textes;
    final c = context.destiny;
    String d(String k) => t.t('debrief.$k');
    final a = g.archetype(p.archetypeId);
    final animal = g.animal(p.animalId);
    final couleur = a == null ? c.or : c.famille(a.famille);
    final memeBesoin = p.fixeBesoin.isNotEmpty &&
        p.groupeBesoin.isNotEmpty &&
        p.fixeBesoin.trim().toLowerCase() == p.groupeBesoin.trim().toLowerCase();

    Widget champ(String libelle, String valeur, ValueChanged<String> changer, {bool besoin = false}) {
      final avis = besoin ? controlerBesoin(valeur, t) : AvisBesoin.ok;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TextFormField(
          initialValue: valeur,
          decoration: InputDecoration(
            labelText: libelle,
            isDense: true,
            helperText: besoin ? messageBesoin(avis, g, t) : null,
            helperMaxLines: 4,
            helperStyle: TextStyle(color: avis == AvisBesoin.ok ? null : couleur),
          ),
          onChanged: (v) {
            changer(v.trim());
            if (besoin) setState(() {});
            _sauver();
          },
        ),
      );
    }

    return CadreLisere(
      couleur: couleur,
      marge: 14,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          if (animal != null) MedaillonAnimal(animal, taille: 40, source: widget.contexte.visuels.source),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              [if (p.joueur.isNotEmpty) p.joueur, if (a != null) a.nom].join(' · '),
              style: TextStyle(fontFamily: kPoliceTitres, fontWeight: FontWeight.w700, fontSize: 16, color: c.texte),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        Text(d('groupe'), style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 6),
        champ(d('veut'), p.groupeVeut, (v) => p.groupeVeut = v),
        champ(d('besoin'), p.groupeBesoin, (v) => p.groupeBesoin = v, besoin: true),
        Text(d('fixe'), style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 6),
        champ(d('veut'), p.fixeVeut, (v) => p.fixeVeut = v),
        champ(d('besoin'), p.fixeBesoin, (v) => p.fixeBesoin = v, besoin: true),
        if (memeBesoin) Paragraphe(d('meme_phrase'), gras: true),
        Text(d('choix'), style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 6),
        Wrap(spacing: 8, runSpacing: 6, children: [
          for (final (choix, libelle) in [
            (ChoixFinal.vouloir, d('choix_vouloir')),
            (ChoixFinal.besoin, d('choix_besoin')),
          ])
            ChoiceChip(
              label: Text(libelle),
              selected: p.choixFinal == choix,
              onSelected: (oui) {
                setState(() => p.choixFinal = oui ? choix : ChoixFinal.aucun);
                _sauver();
              },
            ),
        ]),
        const SizedBox(height: 8),
        champ(d('prix'), p.prixPaye, (v) => p.prixPaye = v),
      ]),
    );
  }
}

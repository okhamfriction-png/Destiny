import 'package:flutter/material.dart';

import '../../application/assistant/campagne_assistant.dart' show sansPrenoms;
import '../../application/prompts/prompts.dart';
import '../../domain/grammaire/controle_besoin.dart';
import '../../domain/troupe/session.dart';
import '../destiny/bouton_ia.dart';
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

  /// Le coach de débrief : il lit les notes et propose, pour chacun, « il
  /// veut… mais il a besoin de… ». Les prénoms des comédiens ne partent pas :
  /// on envoie « Personnage 1 », « Personnage 2 »…
  Future<void> _coach() async {
    final t = context.textes;
    String nom(int i) => '${t.t('ia_jeu.personnage')} ${i + 1}';
    final roles = {
      for (final (i, p) in s.personnages.indexed)
        if (p.joueur.trim().isNotEmpty) p.joueur.trim(): nom(i),
    };
    final notes = [for (final n in s.notes) '${n.horodatage} ${n.texte}'].join('\n');
    final d = await widget.contexte.ia!.debrief(
      personnages: [
        for (final (i, p) in s.personnages.indexed)
          PersonnagePrompt(
            nom: nom(i),
            archetypeId: p.archetypeId,
            animalId: p.animalId,
            vouloir: p.fixeVeut,
            besoin: p.fixeBesoin,
          ),
      ],
      notes: sansPrenoms(notes, roles),
      kids: s.kids,
    );
    if (!mounted) return;
    final reprendre = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        builder: (ctx, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.all(16),
          children: [
            Text(t.t('ia_jeu.coach_titre'), style: Theme.of(ctx).textTheme.titleLarge, textAlign: TextAlign.center),
            for (final l in d.personnages)
              SectionDestiny(titre: l.nom, enfants: [
                LigneInfo(t.t('debrief.veut'), l.veut),
                LigneInfo(t.t('debrief.besoin'), l.besoin),
                LigneInfo(t.t('ia_jeu.coach_seme'), l.seme),
                LigneInfo(t.t('ia_jeu.coach_nomme'), l.nomme),
                LigneInfo(t.t('ia_jeu.coach_choix'), l.choix),
              ]),
            if (d.ceQuiAMarche.isNotEmpty)
              SectionDestiny(titre: t.t('debrief.ce_qui_a_marche'), enfants: [for (final m in d.ceQuiAMarche) Puce(m)]),
            const SizedBox(height: 12),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(t.t('ia_jeu.reprendre'))),
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t.t('ia_jeu.fermer'))),
          ],
        ),
      ),
    );
    if (reprendre != true || !mounted) return;
    setState(() {
      for (final (i, l) in d.personnages.indexed) {
        if (i >= s.personnages.length) break;
        final p = s.personnages[i];
        if (p.groupeVeut.trim().isEmpty) p.groupeVeut = l.veut;
        if (p.groupeBesoin.trim().isEmpty) p.groupeBesoin = l.besoin;
      }
      for (final m in d.ceQuiAMarche) {
        if (!s.ceQuiAMarche.contains(m)) s.ceQuiAMarche.add(m);
      }
      _version++;
    });
    await _sauver();
  }

  /// Change quand le coach a rempli des champs (pour les reconstruire).
  int _version = 0;

  @override
  Widget build(BuildContext context) {
    final t = context.textes;
    final c = context.destiny;
    String d(String k) => t.t('debrief.$k');
    return PageDestiny(
      titre: d('titre'),
      enfants: [
        Paragraphe(d('intro'), gras: true),
        if (widget.contexte.ia != null)
          BoutonIA(libelle: t.t('ia_jeu.coach'), disponible: widget.contexte.ia!.disponible, action: _coach),
        for (final p in s.personnages) KeyedSubtree(key: ValueKey('$_version-${p.hashCode}'), child: _personnage(context, p)),
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

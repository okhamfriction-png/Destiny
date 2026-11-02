import 'package:flutter/material.dart';

import '../../domain/grammaire/modeles.dart';
import '../destiny/composants.dart';
import '../destiny/donnees.dart';
import '../destiny/page.dart';
import '../theme/destiny_theme.dart';
import 'bibliotheque_screen.dart';
import 'fiches.dart';

/// Les règles du spectacle : règles d'or, paliers, actes, rituel,
/// distribution, échauffement.
class ReglesScreen extends StatelessWidget {
  const ReglesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final g = context.grammaire;
    final t = context.textes;
    final c = context.destiny;
    String r(String k, [Map<String, String> v = const {}]) => t.t('bibliotheque.regles.$k', v);
    return PageDestiny(
      titre: t.t('bibliotheque.entrees.regles.titre'),
      enfants: [
        BandeauAffiche(titre: g.nom.toUpperCase(), sousTitre: g.promesse),
        SectionDestiny(titre: r('regles_d_or'), enfants: [
          for (final (i, regle) in g.reglesDOr.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox(
                  width: 26,
                  child: Text('${i + 1}',
                      style: TextStyle(
                          fontFamily: kPoliceTitres, fontWeight: FontWeight.w900, fontSize: 18, color: c.or)),
                ),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(regle.titre,
                        style: TextStyle(
                            fontFamily: kPoliceTitres, fontWeight: FontWeight.w700, fontSize: 15, color: c.texte)),
                    Text(regle.texte,
                        style: TextStyle(fontFamily: kPoliceTexte, fontSize: 13.5, height: 1.35, color: c.texteSecondaire)),
                  ]),
                ),
              ]),
            ),
        ]),
        SectionDestiny(titre: r('paliers'), enfants: [
          const FrisePaliers(),
          for (final p in g.paliers)
            LigneInfo('${p.nom} · ${r('l_archetype')}', p.etatArchetype),
        ]),
        SectionDestiny(titre: r('actes'), enfants: [
          for (final a in g.actes)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${t.t('rituel.acte', {'numero': '${a.numero}'})} · ${g.palier(a.palier).nom}',
                    style: TextStyle(
                        fontFamily: kPoliceTitres, fontWeight: FontWeight.w700, fontSize: 15, color: c.palier(a.palier))),
                Text(a.ambiance,
                    style: TextStyle(fontFamily: kPoliceTexte, fontStyle: FontStyle.italic, color: c.texteSecondaire)),
                const SizedBox(height: 4),
                for (final consigne in a.consignes) Puce(consigne),
              ]),
            ),
        ]),
        SectionDestiny(titre: r('rituel'), enfants: [
          Paragraphe('${g.rituel.quand[0].toUpperCase()}${g.rituel.quand.substring(1)} · ${g.rituel.quiDeclenche}.'),
          for (final (i, e) in g.rituel.sequence.indexed) Puce(e, numero: i + 1),
          LigneInfo(r('reprise'), g.rituel.reprise),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: c.bleuDestiny.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.bleuDestiny),
            ),
            child: Paragraphe(g.rituel.premierFige, gras: true),
          ),
        ]),
        SectionDestiny(titre: r('distribution'), enfants: [
          Paragraphe(g.distribution.regle),
          for (final comp in g.distribution.compositions)
            LigneInfo(
              r('joueurs', {'n': '${comp.joueurs}'}),
              [
                r('alarmiste'),
                for (final f in FamilleId.values)
                  if (comp.minimumPour(f) > 0)
                    '${comp.minimumPour(f)} · ${g.famille(f).nom.toLowerCase()}',
                if (comp.auChoix > 0) r('au_choix', {'n': '${comp.auChoix}'}),
              ].join(' · '),
            ),
          Paragraphe(g.distribution.aSix, italique: true),
          Text(r('exemples'),
              style: TextStyle(fontFamily: kPoliceTexte, fontWeight: FontWeight.w700, color: c.texteSecondaire)),
          const SizedBox(height: 6),
          for (final e in g.distribution.exemples)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Wrap(spacing: 6, runSpacing: 6, children: [
                for (final id in e.pour(6)) PuceArchetype(id),
              ]),
            ),
        ]),
        SectionDestiny(titre: r('echauffement'), enfants: [
          Paragraphe(g.personnage.echauffement.quand),
          for (final (i, q) in g.personnage.echauffement.questions.indexed) Puce(q, numero: i + 1),
          Paragraphe(g.personnage.echauffement.limite, italique: true),
        ]),
      ],
    );
  }
}

/// Vouloir et besoin : la page pédagogique du personnage.
class VouloirBesoinScreen extends StatelessWidget {
  const VouloirBesoinScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final g = context.grammaire;
    final t = context.textes;
    final c = context.destiny;
    final p = g.personnage;
    String v(String k) => t.t('bibliotheque.vouloir_besoin.$k');
    return PageDestiny(
      titre: t.t('bibliotheque.entrees.vouloir_besoin.titre'),
      enfants: [
        for (final carte in p.troisCartes)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.carte,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.or),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(carte.titre.toUpperCase(),
                  style: TextStyle(
                      fontFamily: kPoliceTitres, fontWeight: FontWeight.w900, fontSize: 18, color: c.titre)),
              Text(carte.sousTitre,
                  style: TextStyle(fontFamily: kPoliceTexte, fontStyle: FontStyle.italic, color: c.texteSecondaire)),
              const SizedBox(height: 6),
              Paragraphe(carte.texte),
              EncartReplique(carte.exemple, couleur: c.or),
            ]),
          ),
        SectionDestiny(titre: v('piege'), enfants: [Paragraphe(p.piege, gras: true)]),
        SectionDestiny(titre: v('detecter'), enfants: [Paragraphe(p.detecterPasJouer)]),
        SectionDestiny(titre: v('phrase_cle'), enfants: [EncartReplique(p.phraseCle, couleur: c.bleuDestiny, taille: 15)]),
        SectionDestiny(titre: v('chaine'), enfants: [
          for (final (i, maillon) in p.chaine.indexed) Puce(maillon, numero: i + 1),
        ]),
        SectionDestiny(titre: v('couches'), enfants: [
          for (final (i, couche) in p.couches.indexed) Puce(couche, numero: i + 1),
        ]),
        SectionDestiny(titre: v('acte_par_acte'), enfants: [
          for (final geste in p.acteParActe)
            LigneInfo('${geste.moment} · ${geste.verbe}', geste.consigne),
        ]),
        SectionDestiny(titre: v('six_directions'), enfants: [
          for (final d in p.sixDirections) CarteDirection(d),
        ]),
      ],
    );
  }
}

/// Les outils de jeu de Mark Jane.
class OutilsScreen extends StatelessWidget {
  const OutilsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.textes;
    return PageDestiny(
      titre: t.t('outils_de_jeu.titre'),
      enfants: [
        Paragraphe(t.t('outils_de_jeu.source'), italique: true),
        for (final o in t.tables('outils_de_jeu.outils'))
          SectionDestiny(titre: '${o['titre']}', enfants: [Paragraphe('${o['texte']}')]),
        const SizedBox(height: 14),
        Paragraphe(t.t('outils_de_jeu.instinct'), gras: true),
      ],
    );
  }
}

/// Le lexique : les mots à utiliser, et ceux qu'on ne dit plus.
class LexiqueScreen extends StatelessWidget {
  const LexiqueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.textes;
    final c = context.destiny;
    final utiliser = t.liste('lexique.utiliser');
    final eviter = t.liste('lexique.ne_plus_utiliser');
    return PageDestiny(
      titre: t.t('lexique.titre'),
      enfants: [
        for (var i = 0; i < utiliser.length; i++)
          ElementListe(
            titre: utiliser[i],
            sousTitre: i < eviter.length ? '✗ ${eviter[i]}' : null,
            couleur: c.or,
          ),
      ],
    );
  }
}

/// Le mode kids, et la série.
class KidsScreen extends StatelessWidget {
  const KidsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final g = context.grammaire;
    final t = context.textes;
    final k = g.modeKids;
    String l(String x, [Map<String, String> v = const {}]) => t.t('bibliotheque.kids.$x', v);
    return PageDestiny(
      titre: t.t('bibliotheque.entrees.kids.titre'),
      enfants: [
        const Align(alignment: Alignment.centerLeft, child: SigleKids()),
        SectionDestiny(titre: l('principe'), enfants: [
          Paragraphe(k.principe),
          if (k.dureeEpisodeMinutes.length == 2)
            Paragraphe(l('duree', {
              'min': '${k.dureeEpisodeMinutes[0]}',
              'max': '${k.dureeEpisodeMinutes[1]}',
            }), italique: true),
        ]),
        SectionDestiny(titre: l('regles'), enfants: [
          for (final r in k.regles) LigneInfo(r.titre, r.texte),
        ]),
        SectionDestiny(titre: l('pouvoirs'), enfants: [
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final p in k.pouvoirsExemples) Chip(label: Text(p)),
          ]),
          const SizedBox(height: 8),
          Paragraphe(k.pouvoirRegle),
        ]),
        SectionDestiny(titre: l('palier4'), enfants: [Paragraphe(k.palier4)]),
        SectionDestiny(titre: t.t('bibliotheque.serie.titre'), enfants: [
          LigneInfo(t.t('serie.natures.episode'), g.serie.episode),
          LigneInfo(t.t('serie.natures.saison'), g.serie.saison),
          LigneInfo(t.t('serie.natures.serie'), g.serie.serie),
        ]),
      ],
    );
  }
}

/// Les figurants : les deux modes, les huit types, les règles, et la table
/// des figurants par lieu.
class FigurantsScreen extends StatelessWidget {
  const FigurantsScreen({super.key, required this.contexte});

  final ContexteBibliotheque contexte;

  @override
  Widget build(BuildContext context) {
    final g = context.grammaire;
    final t = context.textes;
    final f = g.figurants;
    String l(String x) => t.t('bibliotheque.figurants.$x');
    String fi(String x) => t.t('bibliotheque.fiche.$x');
    return PageDestiny(
      titre: t.t('bibliotheque.entrees.figurants.titre'),
      enfants: [
        Paragraphe(f.inspiration, italique: true),
        SectionDestiny(titre: l('modes'), enfants: [
          for (final m in ModePnj.values) LigneInfo(t.t('modes_pnj.${m.name}'), f.modes[m] ?? ''),
        ]),
        SectionDestiny(titre: l('types'), enfants: [
          for (final ty in f.types)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(ty.nom, style: const TextStyle(fontFamily: kPoliceTitres, fontWeight: FontWeight.w700)),
              subtitle: Text(ty.ceQuIlEst),
              childrenPadding: const EdgeInsets.only(bottom: 8),
              children: [
                LigneInfo(fi('veut'), ty.veut),
                LigneInfo(fi('comment_le_jouer'), ty.commentLeJouer),
                LigneInfo(fi('sert_a'), ty.sertA),
              ],
            ),
        ]),
        SectionDestiny(titre: l('regles'), enfants: [
          for (final r in f.regles) LigneInfo(r.titre, r.texte),
        ]),
        SectionDestiny(titre: l('par_lieu'), enfants: [
          Paragraphe(f.parLieu),
          for (final lieu in g.lieux)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Row(children: [
                Flexible(child: Text(lieu.nom)),
                if (lieu.kids) const Padding(padding: EdgeInsets.only(left: 8), child: SigleKids(petit: true)),
              ]),
              children: [for (final fig in lieu.figurants) CarteFigurant(fig)],
            ),
        ]),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../../domain/grammaire/modeles.dart';
import '../../domain/serie/pbta.dart';
import '../destiny/donnees.dart';
import '../destiny/page.dart';
import '../theme/destiny_theme.dart';
import 'pbta_composants.dart';

/// Les onglets de l'aide du MJ.
enum OngletAideMj { piece, joueurs, maitre, horloges }

/// L'aide du Maître du destin, en quatre onglets : la pièce et le second
/// lancer ; les mouvements des joueurs ; son agenda, ses principes et ses
/// mouvements doux et durs ; les horloges et les blessures. Tout vient de la
/// section `pbta` des textes.
class AideMjScreen extends StatelessWidget {
  const AideMjScreen({super.key, required this.kids, this.palier = 0, this.onglet = OngletAideMj.piece});

  final bool kids;

  /// Le palier en cours (0 : hors d'un épisode). Il dit si les mouvements
  /// du moment sont doux ou durs.
  final int palier;
  final OngletAideMj onglet;

  @override
  Widget build(BuildContext context) {
    final t = context.textes;
    final c = context.destiny;
    final r = ReglesPbta.depuis(t);
    String p(String x) => t.t('pbta.$x');
    String a(String x, [Map<String, String> v = const {}]) => t.t('serie.aide_mj.$x', v);
    final gravite = palier > 0 ? graviteAuPalier(palier) : null;
    final onglets = t.liste('serie.aide_mj.onglets');

    Widget liste(List<Widget> enfants) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            for (final e in enfants)
              Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 760), child: e)),
          ],
        );

    Widget mouvementMj(MouvementMj m) => CadreLisere(
          couleur: m.gravite == GraviteMouvement.doux ? c.palier(PalierId.enferme) : c.famille(FamilleId.fissure),
          marge: 8,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(m.nom, style: TextStyle(fontFamily: kPoliceTitres, fontWeight: FontWeight.w700, color: c.texte)),
            Text(m.textePour(kids: kids), style: TextStyle(fontFamily: kPoliceTexte, fontSize: 13, color: c.texteSecondaire)),
          ]),
        );

    final maintenant = gravite == null
        ? null
        : Paragraphe(
            a('maintenant', {
              'n': '$palier',
              'gravite': gravite == GraviteMouvement.doux ? t.t('serie.piece.doux') : t.t('serie.piece.dur'),
            }),
            gras: true,
          );

    final pages = <Widget>[
      liste([
        Paragraphe(p('intro')),
        SectionDestiny(titre: p('piece.titre'), enfants: [
          Paragraphe(p('piece.principe')),
          for (final f in FacePiece.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                PuceFace(f),
                Text(t.t('pbta.piece.faces.${f.name}.approche'), style: TextStyle(color: c.texte)),
              ]),
            ),
          Paragraphe(p('piece.quand')),
          LigneInfo(p('piece.succes'), p('piece.succes_texte')),
          LigneInfo(p('piece.echec'), p('piece.echec_texte')),
          Puce(p('piece.doux')),
          Puce(p('piece.dur')),
        ]),
        SectionDestiny(titre: p('bonus.titre'), enfants: [
          Paragraphe(p('bonus.principe')),
          Paragraphe(p('bonus.choisir')),
          Paragraphe(p('bonus.seconde_chance')),
          Paragraphe(p('bonus.gene')),
        ]),
      ]),
      liste([
        SectionDestiny(titre: p('mouvements_titre'), espace: 0, enfants: [
          for (final m in r.mouvementsPour(kids: kids))
            CadreLisere(
              couleur: c.titre,
              marge: 8,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(m.nom, style: TextStyle(fontFamily: kPoliceTitres, fontWeight: FontWeight.w700, color: c.texte)),
                Text(m.quand, style: TextStyle(fontFamily: kPoliceTexte, fontStyle: FontStyle.italic, color: c.texte)),
                if (m.approche.isNotEmpty)
                  Text(m.approche, style: TextStyle(fontFamily: kPoliceTexte, fontSize: 12.5, color: c.texteSecondaire)),
                const SizedBox(height: 4),
                if (m.avecPiece) ...[
                  LigneInfo(p('piece.succes'), m.reussite),
                  LigneInfo(p('piece.echec'), m.echec),
                ] else
                  LigneInfo(p('effet'), m.effet),
              ]),
            ),
        ]),
      ]),
      liste([
        if (maintenant != null) maintenant,
        SectionDestiny(titre: p('agenda_titre'), espace: maintenant == null ? 0 : 18, enfants: [
          for (final (i, x) in r.agenda.indexed) Puce(x, numero: i + 1),
        ]),
        SectionDestiny(titre: p('principes_titre'), enfants: [
          for (final x in r.principes) Puce(x),
        ]),
        SectionDestiny(titre: p('mouvements_mj.titre'), enfants: [
          Paragraphe(p('mouvements_mj.principe')),
          Paragraphe(p('mouvements_mj.regle'), italique: true),
        ]),
        SectionDestiny(titre: p('mouvements_mj.doux_titre'), enfants: [
          for (final m in r.mouvementsMjDe(GraviteMouvement.doux)) mouvementMj(m),
        ]),
        SectionDestiny(titre: p('mouvements_mj.durs_titre'), enfants: [
          for (final m in r.mouvementsMjDe(GraviteMouvement.dur)) mouvementMj(m),
        ]),
        Paragraphe(p('mouvements_mj.que_fais_tu'), gras: true),
      ]),
      liste([
        SectionDestiny(titre: p('horloges.titre'), espace: 0, enfants: [
          Puce(p('horloges.episode')),
          Puce(p('horloges.saison')),
        ]),
        SectionDestiny(titre: p('blessures.titre'), enfants: [
          Paragraphe(p('blessures.principe')),
          for (final (i, x) in r.blessures(kids: kids).indexed) Puce(x, numero: i + 1),
          Paragraphe(kids ? p('blessures.hors_jeu_kids') : p('blessures.hors_jeu'), italique: true),
        ]),
      ]),
    ];

    return DefaultTabController(
      length: pages.length,
      initialIndex: onglet.index,
      child: Scaffold(
        appBar: AppBar(
          title: Text(a('titre')),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              for (var i = 0; i < pages.length; i++) Tab(text: i < onglets.length ? onglets[i] : '${i + 1}'),
            ],
          ),
        ),
        body: SafeArea(top: false, child: TabBarView(children: pages)),
      ),
    );
  }
}

import 'dart:math';

import 'package:flutter/material.dart';

import '../../domain/grammaire/modeles.dart';
import '../../domain/serie/pbta.dart';
import '../../domain/serie/serie.dart';
import '../destiny/donnees.dart';
import '../destiny/page.dart';
import '../theme/destiny_theme.dart';
import 'pbta_composants.dart';

/// Ce que le Maître du destin a choisi avant de lancer la pièce.
class ChoixPiece {
  const ChoixPiece({
    required this.personnageId,
    required this.approche,
    required this.mode,
    this.mouvementId = '',
    this.lancers,
  });

  final String personnageId;

  /// La ligne du destin choisie.
  final FacePiece approche;
  final ModeLancer mode;
  final String mouvementId;

  /// Les faces de la vraie pièce, quand on l'a lancée à la main (null :
  /// c'est l'appli qui lance).
  final List<FacePiece>? lancers;
}

/// Les personnages qui peuvent lancer la pièce : ceux des joueurs, encore
/// dans l'histoire et pas hors jeu.
List<PersonnageSerie> lanceurs(Serie s, EpisodeSerie e) => [
      for (final p in s.personnagesActifs)
        if (!p.pnj && !(e.role(p.id)?.horsJeu ?? false)) p,
    ];

/// « Tirer la pièce » : qui agit, sa ligne du destin (BRAVE ou SMART, son
/// bonus mis en avant), le mouvement (facultatif), et ce qui donne le second
/// lancer. On lance avec l'appli, ou on dit sur quoi la vraie pièce est
/// tombée.
Future<ChoixPiece?> ouvrirChoixPiece(
  BuildContext context, {
  required Serie serie,
  required EpisodeSerie episode,
  required ReglesPbta regles,
  String? personnageId,
}) =>
    showModalBottomSheet<ChoixPiece>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.92,
        maxChildSize: 0.95,
        builder: (ctx, scroll) => _FeuillePiece(
          serie: serie,
          episode: episode,
          regles: regles,
          personnageId: personnageId,
          scroll: scroll,
        ),
      ),
    );

class _FeuillePiece extends StatefulWidget {
  const _FeuillePiece({
    required this.serie,
    required this.episode,
    required this.regles,
    required this.personnageId,
    required this.scroll,
  });

  final Serie serie;
  final EpisodeSerie episode;
  final ReglesPbta regles;
  final String? personnageId;
  final ScrollController scroll;

  @override
  State<_FeuillePiece> createState() => _FeuillePieceState();
}

class _FeuillePieceState extends State<_FeuillePiece> {
  String _perso = '';
  FacePiece _approche = FacePiece.brave;
  String _mouvement = '';
  bool _aide = false;
  bool _vouloir = false;
  bool _pouvoir = false;
  bool _gene = false;
  bool _vraie = false;
  final List<FacePiece> _lancersVrais = [];

  Serie get s => widget.serie;
  EpisodeSerie get e => widget.episode;

  @override
  void initState() {
    super.initState();
    final possibles = lanceurs(s, e);
    final demande = widget.personnageId;
    _choisirPerso(possibles.any((p) => p.id == demande) ? demande! : (possibles.isEmpty ? '' : possibles.first.id));
  }

  PersonnageSerie? get _personnage => s.personnage(_perso);

  void _choisirPerso(String id) {
    _perso = id;
    final p = s.personnage(id);
    _approche = p?.bonus ?? _approche;
    _vouloir = e.role(id)?.elan ?? false;
    _lancersVrais.clear();
  }

  ModeLancer get _mode => modeDuLancer(
        approche: _approche,
        bonus: _personnage?.bonus,
        aide: _aide,
        vouloirDit: _vouloir,
        pouvoir: s.kids && _pouvoir,
        gene: _gene,
      );

  ChoixPiece _choix({List<FacePiece>? lancers}) =>
      ChoixPiece(personnageId: _perso, approche: _approche, mode: _mode, mouvementId: _mouvement, lancers: lancers);

  void _faceVraie(FacePiece f) {
    setState(() => _lancersVrais.add(f));
    if (!encoreUnLancer(_approche, _mode, _lancersVrais)) {
      Navigator.of(context).pop(_choix(lancers: [..._lancersVrais]));
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = context.grammaire;
    final t = context.textes;
    final c = context.destiny;
    String k(String x, [Map<String, String> v = const {}]) => t.t('serie.piece.$x', v);
    final possibles = lanceurs(s, e);
    final perso = _personnage;
    final mouvements = [for (final m in widget.regles.mouvementsPour(kids: s.kids)) if (m.avecPiece) m];
    final mouvement = widget.regles.mouvement(_mouvement);
    final face = nomFace(context, _approche);
    final mode = _mode;
    Widget titre(String x) => Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 6),
          child: Text(x, style: TextStyle(fontFamily: kPoliceTitres, fontWeight: FontWeight.w700, color: c.titre)),
        );

    return ListView(
      controller: widget.scroll,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Text(t.t('pbta.piece.titre'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
        if (possibles.isEmpty) ...[
          const SizedBox(height: 12),
          Paragraphe(k('personne'), italique: true),
        ] else ...[
          titre(k('qui')),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final p in possibles)
              ChoiceChip(
                label: Text([p.appel, g.archetype(p.archetypeId)?.nom ?? ''].where((x) => x.isNotEmpty).join(' · ')),
                selected: _perso == p.id,
                onSelected: (_) => setState(() => _choisirPerso(p.id)),
              ),
          ]),
          titre(k('approche')),
          ChoixFace(
            face: _approche,
            bonus: perso?.bonus,
            motBonus: k('bonus'),
            onChoisi: (f) => setState(() {
              _approche = f;
              _lancersVrais.clear();
            }),
          ),
          const SizedBox(height: 4),
          Text(t.t('pbta.piece.faces.${_approche.name}.approche'),
              style: TextStyle(fontFamily: kPoliceTexte, fontSize: 12.5, color: c.texteSecondaire)),
          titre(k('mouvement')),
          Wrap(spacing: 6, runSpacing: 6, children: [
            ChoiceChip(
              label: Text(k('aucun_mouvement')),
              selected: _mouvement.isEmpty,
              onSelected: (_) => setState(() => _mouvement = ''),
            ),
            for (final m in mouvements)
              ChoiceChip(
                label: Text(m.nom),
                selected: _mouvement == m.id,
                onSelected: (_) => setState(() {
                  _mouvement = m.id;
                  if (m.approches.length == 1) _approche = m.approches.first;
                  _lancersVrais.clear();
                }),
              ),
          ]),
          if (mouvement != null) ...[
            const SizedBox(height: 6),
            Text(mouvement.quand, style: TextStyle(fontFamily: kPoliceTexte, fontStyle: FontStyle.italic, color: c.texte)),
            Text(mouvement.approche, style: TextStyle(fontFamily: kPoliceTexte, fontSize: 12.5, color: c.texteSecondaire)),
          ],
          titre(k('second_lancer')),
          for (final (valeur, libelle, aide, changer) in [
            (_aide, k('aide'), '', (bool v) => _aide = v),
            (_vouloir, k('vouloir'), (e.role(_perso)?.elan ?? false) ? k('vouloir_aide') : '', (bool v) => _vouloir = v),
            if (s.kids) (_pouvoir, k('pouvoir'), perso?.pouvoir ?? '', (bool v) => _pouvoir = v),
            (_gene, k('gene'), '', (bool v) => _gene = v),
          ])
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(libelle),
              subtitle: aide.isEmpty ? null : Text(aide),
              value: valeur,
              onChanged: (v) => setState(() {
                changer(v ?? false);
                _lancersVrais.clear();
              }),
            ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: couleurFace(_approche), width: 1.5),
              color: couleurFace(_approche).withValues(alpha: 0.08),
            ),
            child: Row(children: [
              Icon(iconeFace(_approche), color: couleurFace(_approche)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  switch (mode) {
                    ModeLancer.simple => k('mode_simple', {'face': face}),
                    ModeLancer.secondeChance => k('mode_seconde', {'face': face}),
                    ModeLancer.gene => k('mode_gene', {'face': face}),
                  },
                  style: TextStyle(fontFamily: kPoliceTexte, fontWeight: FontWeight.w700, color: c.texte),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size(48, 56)),
            onPressed: perso == null ? null : () => Navigator.of(context).pop(_choix()),
            icon: const Icon(Icons.toll_rounded),
            label: Text(k('lancer')),
          ),
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: perso == null
                ? null
                : () => setState(() {
                      _vraie = !_vraie;
                      _lancersVrais.clear();
                    }),
            icon: const Icon(Icons.back_hand_outlined),
            label: Text(k('vraie_piece')),
          ),
          if (_vraie && perso != null) ...[
            Text(
              k('tombee', {'n': '${_lancersVrais.length + 1}'}),
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: kPoliceTexte, fontWeight: FontWeight.w700, color: c.texte),
            ),
            const SizedBox(height: 6),
            Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 6, children: [
              for (final f in FacePiece.values)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(side: BorderSide(color: couleurFace(f), width: 2)),
                  onPressed: () => _faceVraie(f),
                  icon: Icon(iconeFace(f), color: couleurFace(f)),
                  label: Text(nomFace(context, f)),
                ),
            ]),
          ],
        ],
      ],
    );
  }
}

/// Le résultat : SUCCÈS ou ÉCHEC, les faces tombées, ce que donne le
/// mouvement, et après un échec la gravité du mouvement du Maître du destin
/// (doux aux paliers 1 et 2, dur aux paliers 3 et 4) avec deux ou trois
/// idées de mouvements.
Future<void> ouvrirResultatPiece(
  BuildContext context, {
  required ResultatPiece resultat,
  required ReglesPbta regles,
  required bool kids,
  String nom = '',
  MouvementJoueur? mouvement,
  VoidCallback? onBlessure,
  VoidCallback? onAideMj,
  Random? hasard,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        builder: (ctx, scroll) => _FeuilleResultat(
          resultat: resultat,
          regles: regles,
          kids: kids,
          nom: nom,
          mouvement: mouvement,
          onBlessure: onBlessure,
          onAideMj: onAideMj,
          hasard: hasard ?? Random(),
          scroll: scroll,
        ),
      ),
    );

class _FeuilleResultat extends StatefulWidget {
  const _FeuilleResultat({
    required this.resultat,
    required this.regles,
    required this.kids,
    required this.nom,
    required this.mouvement,
    required this.onBlessure,
    required this.onAideMj,
    required this.hasard,
    required this.scroll,
  });

  final ResultatPiece resultat;
  final ReglesPbta regles;
  final bool kids;
  final String nom;
  final MouvementJoueur? mouvement;
  final VoidCallback? onBlessure;
  final VoidCallback? onAideMj;
  final Random hasard;
  final ScrollController scroll;

  @override
  State<_FeuilleResultat> createState() => _FeuilleResultatState();
}

class _FeuilleResultatState extends State<_FeuilleResultat> {
  late List<MouvementMj> _idees = _tirer();
  bool _blessureMarquee = false;

  List<MouvementMj> _tirer() => suggestionsMj(widget.regles, widget.resultat.gravite, hasard: widget.hasard);

  @override
  Widget build(BuildContext context) {
    final t = context.textes;
    final c = context.destiny;
    String k(String x, [Map<String, String> v = const {}]) => t.t('serie.piece.$x', v);
    final r = widget.resultat;
    final ok = r.reussite;
    final couleur = ok ? c.titre : c.famille(FamilleId.fissure);
    final m = widget.mouvement;
    final doux = r.gravite == GraviteMouvement.doux;

    return ListView(
      controller: widget.scroll,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        if (widget.nom.isNotEmpty)
          Text(widget.nom, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
        Text(
          (ok ? t.t('pbta.piece.succes') : t.t('pbta.piece.echec')).toUpperCase(),
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: kPoliceTitres, fontWeight: FontWeight.w900, fontSize: 32, color: couleur),
        ),
        Text(
          ok ? k('succes_phrase') : k('echec_phrase'),
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: kPoliceTexte, fontWeight: FontWeight.w600, color: c.texte),
        ),
        const SizedBox(height: 10),
        Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text(k('ligne'), style: TextStyle(fontFamily: kPoliceTexte, color: c.texteSecondaire)),
          PuceFace(r.approche),
        ]),
        const SizedBox(height: 6),
        Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Text(k('tombees'), style: TextStyle(fontFamily: kPoliceTexte, color: c.texteSecondaire)),
          for (final f in r.lancers) PuceFace(f),
        ]),
        if (m != null) ...[
          const SizedBox(height: 12),
          LigneInfo(m.nom, ok ? m.reussite : m.echec),
        ],
        if (!ok) ...[
          SectionDestiny(titre: k('gravite', {'gravite': doux ? k('doux') : k('dur'), 'n': '${r.palier}'}), enfants: [
            Paragraphe(doux ? t.t('pbta.piece.doux') : t.t('pbta.piece.dur'), italique: true),
            const SizedBox(height: 6),
            Text(k('idees'), style: TextStyle(fontFamily: kPoliceTexte, fontWeight: FontWeight.w700, color: c.texte)),
            const SizedBox(height: 6),
            for (final x in _idees)
              CadreLisere(
                couleur: doux ? c.palier(PalierId.enferme) : c.famille(FamilleId.fissure),
                marge: 8,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Text(x.nom, style: TextStyle(fontFamily: kPoliceTitres, fontWeight: FontWeight.w700, color: c.texte)),
                  Text(x.textePour(kids: widget.kids),
                      style: TextStyle(fontFamily: kPoliceTexte, fontSize: 13, color: c.texteSecondaire)),
                ]),
              ),
            Wrap(spacing: 8, runSpacing: 6, children: [
              TextButton.icon(
                onPressed: () => setState(() => _idees = _tirer()),
                icon: const Icon(Icons.refresh_rounded),
                label: Text(k('autres_idees')),
              ),
              if (widget.onAideMj != null)
                TextButton.icon(
                  onPressed: widget.onAideMj,
                  icon: const Icon(Icons.menu_book_outlined),
                  label: Text(t.t('serie.aide_mj.titre')),
                ),
            ]),
            Paragraphe(t.t('pbta.mouvements_mj.que_fais_tu'), gras: true),
          ]),
          if (widget.onBlessure != null)
            OutlinedButton.icon(
              onPressed: _blessureMarquee
                  ? null
                  : () {
                      widget.onBlessure!();
                      setState(() => _blessureMarquee = true);
                    },
              icon: Icon(_blessureMarquee ? Icons.check_rounded : Icons.healing_outlined),
              label: Text(_blessureMarquee ? k('blessure_marquee') : k('marquer_blessure')),
            ),
        ],
        const SizedBox(height: 12),
        FilledButton(onPressed: () => Navigator.of(context).pop(), child: Text(k('fermer'))),
      ],
    );
  }
}

import 'dart:math';

import 'package:flutter/material.dart';

import '../../application/services/audio_service.dart';
import '../../domain/entities/exercice.dart';
import '../../domain/grammaire/modeles.dart';
import '../../infrastructure/datasources/exercices_source.dart';
import '../bibliotheque/bibliotheque_screen.dart';
import '../destiny/donnees.dart';
import '../destiny/page.dart';
import '../theme/destiny_theme.dart';
import 'chrono_exercice_screen.dart';
import 'fiche_exercice_screen.dart';

/// L'ordre des thèmes du carnet (le premier est l'onglet ouvert d'abord).
const List<String> _themesCarnet = ['Échauffement', 'Statut', 'Spontanéité', 'Écoute', 'Dialogue', 'Imagination'];

Color _couleurCarnet(String theme) => switch (theme) {
      'Échauffement' => const Color(0xFFE5735F),
      'Statut' => const Color(0xFFD9A030),
      'Spontanéité' => const Color(0xFF2FAF95),
      'Écoute' => const Color(0xFF4A90D0),
      'Imagination' => const Color(0xFF9B7FE0),
      'Dialogue' => const Color(0xFF2DB0C0),
      _ => const Color(0xFFD06A95),
    };

IconData _iconeCarnet(String theme) => switch (theme) {
      'Échauffement' => Icons.local_fire_department_outlined,
      'Statut' => Icons.swap_vert_rounded,
      'Spontanéité' => Icons.bolt_rounded,
      'Écoute' => Icons.hearing_outlined,
      'Imagination' => Icons.auto_awesome_outlined,
      'Dialogue' => Icons.forum_outlined,
      _ => Icons.record_voice_over_outlined,
    };

/// Un onglet : un thème du carnet, un thème de la grammaire, ou Solo.
sealed class _Onglet {
  const _Onglet();
}

class _OngletCarnet extends _Onglet {
  const _OngletCarnet(this.theme);
  final String theme;
}

class _OngletGrammaire extends _Onglet {
  const _OngletGrammaire(this.theme);
  final ThemeExercice theme;
}

class _OngletSolo extends _Onglet {
  const _OngletSolo();
}

/// Les Exercices : les thèmes du carnet (Échauffement, Statut, Spontanéité,
/// Écoute, Dialogue, Imagination), puis les trois thèmes de la grammaire
/// (CROW, Lieu, Destiny), puis Solo (diction). Chronométrés, sans score.
class ExercicesScreen extends StatefulWidget {
  const ExercicesScreen({required this.audioService, this.bibliotheque, this.carnet, super.key});

  final AudioService audioService;

  /// Pour revoir la notion d'un exercice dans la Bibliothèque.
  final ContexteBibliotheque? bibliotheque;

  /// Le carnet déjà chargé (tests) ; sinon lu depuis les assets.
  final CarnetExercices? carnet;

  @override
  State<ExercicesScreen> createState() => _ExercicesScreenState();
}

class _ExercicesScreenState extends State<ExercicesScreen> {
  CarnetExercices? _carnet;

  @override
  void initState() {
    super.initState();
    _carnet = widget.carnet;
    if (_carnet == null) {
      chargerCarnetExercices().then((c) {
        if (mounted) setState(() => _carnet = c);
      });
    }
  }

  void _ouvrir(Widget page) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final carnet = _carnet;
    if (carnet == null) return const Center(child: CircularProgressIndicator());
    final g = context.grammaire;
    final t = context.textes;
    final c = context.destiny;

    final onglets = <_Onglet>[
      for (final th in _themesCarnet)
        if (carnet.exercices.any((e) => e.categorie == th)) _OngletCarnet(th),
      for (final th in {for (final e in carnet.exercices) e.categorie}.where((x) => !_themesCarnet.contains(x)))
        _OngletCarnet(th),
      for (final th in g.themesExercices) _OngletGrammaire(th),
      if (carnet.virelangues.isNotEmpty) const _OngletSolo(),
    ];

    Widget etiquette(IconData icone, Color couleur, String texte) => Tab(
          height: 44,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icone, size: 18, color: couleur),
            const SizedBox(width: 6),
            Text(texte),
          ]),
        );

    return DefaultTabController(
      length: onglets.length,
      child: Column(children: [
        TabBar(
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: c.titre,
          labelColor: c.texte,
          unselectedLabelColor: c.texteSecondaire,
          labelStyle: const TextStyle(fontFamily: kPoliceTexte, fontWeight: FontWeight.w700, fontSize: 14),
          unselectedLabelStyle: const TextStyle(fontFamily: kPoliceTexte, fontSize: 14),
          dividerColor: c.filet,
          tabs: [
            for (final o in onglets)
              switch (o) {
                _OngletCarnet(:final theme) => etiquette(_iconeCarnet(theme), _couleurCarnet(theme), theme),
                _OngletGrammaire(:final theme) => etiquette(
                    iconeThemeExercice(theme.id), couleurThemeExercice(context, theme.id), theme.nom),
                _OngletSolo() => etiquette(_iconeCarnet(''), _couleurCarnet(''), t.t('exercices.solo')),
              },
          ],
        ),
        Expanded(
          child: TabBarView(children: [
            for (final o in onglets)
              switch (o) {
                _OngletCarnet(:final theme) => _listeCarnet(carnet, theme),
                _OngletGrammaire(:final theme) => _listeGrammaire(theme),
                _OngletSolo() => _OngletDiction(virelangues: carnet.virelangues),
              },
          ]),
        ),
      ]),
    );
  }

  Widget _liste(List<Widget> enfants) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
        children: [
          for (final e in enfants)
            Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 760), child: e)),
        ],
      );

  Widget _listeCarnet(CarnetExercices carnet, String theme) {
    final t = context.textes;
    final c = context.destiny;
    final couleur = _couleurCarnet(theme);
    return _liste([
      CadreLisere(
        couleur: c.or,
        marge: 14,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            t.t('exercices.principe_du_jour').toUpperCase(),
            style: TextStyle(
                fontFamily: kPoliceTexte, fontSize: 11.5, letterSpacing: 2, fontWeight: FontWeight.w700, color: c.titre),
          ),
          const SizedBox(height: 6),
          Text(
            carnet.principeDuJour(DateTime.now()),
            style: TextStyle(
                fontFamily: kPoliceTexte, fontSize: 15, height: 1.35, fontWeight: FontWeight.w600, color: c.texte),
          ),
        ]),
      ),
      for (final ex in carnet.exercices.where((e) => e.categorie == theme))
        ElementListe(
          titre: ex.nom,
          sousTitre: ex.consigne,
          devant: _Pastille(icone: _iconeCarnet(theme), couleur: couleur),
          apres: Text(t.t('exercices.minutes', {'n': '${(ex.duree / 60).round()}'}),
              style: TextStyle(fontFamily: kPoliceTexte, fontSize: 12.5, color: c.texteSecondaire)),
          onTap: () => _ouvrir(ChronoExerciceScreen(
            titre: ex.nom,
            consigne: ex.consigne,
            secondes: ex.duree,
            audio: widget.audioService,
            icone: _iconeCarnet(theme),
            couleur: couleur,
          )),
        ),
    ]);
  }

  Widget _listeGrammaire(ThemeExercice theme) {
    final g = context.grammaire;
    final exercices = g.exercices.where((e) => e.themeId == theme.id).toList();
    return _liste([
      _BandeauTheme(theme: theme, nombre: exercices.length),
      for (final e in exercices)
        _CarteExercice(
          exercice: e,
          onTap: () => _ouvrir(FicheExerciceScreen(
            exercice: e,
            theme: theme,
            audio: widget.audioService,
            bibliotheque: widget.bibliotheque,
          )),
        ),
      if (exercices.isEmpty) Paragraphe(context.textes.t('exercices.vide'), italique: true),
    ]);
  }
}

/// Une icône sur une pastille teintée.
class _Pastille extends StatelessWidget {
  const _Pastille({required this.icone, required this.couleur});

  final IconData icone;
  final Color couleur;

  @override
  Widget build(BuildContext context) => Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: couleur.withValues(alpha: context.destiny.sombre ? 0.2 : 0.14),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icone, color: couleur, size: 21),
      );
}

/// Le bandeau d'un thème de la grammaire : son nom, son sous-titre, le
/// principe (une phrase de Mark Jane) et son explication.
class _BandeauTheme extends StatelessWidget {
  const _BandeauTheme({required this.theme, required this.nombre});

  final ThemeExercice theme;
  final int nombre;

  @override
  Widget build(BuildContext context) {
    final c = context.destiny;
    final t = context.textes;
    final couleur = couleurThemeExercice(context, theme.id);
    return CadreLisere(
      couleur: couleur,
      marge: 14,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(iconeThemeExercice(theme.id), color: couleur, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(theme.nom,
                style: TextStyle(
                    fontFamily: kPoliceTitres, fontSize: 20, fontWeight: FontWeight.w900, color: c.titre)),
          ),
          Text(t.t('exercices.nombre', {'n': '$nombre'}),
              style: TextStyle(fontFamily: kPoliceTexte, fontSize: 12, color: c.texteSecondaire)),
        ]),
        if (theme.sousTitre.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 8),
            child: Text(theme.sousTitre,
                style: TextStyle(fontFamily: kPoliceTexte, fontSize: 13, color: c.texteSecondaire)),
          ),
        if (theme.principe.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(theme.principe,
                style: TextStyle(
                    fontFamily: kPoliceTexte,
                    fontSize: 15,
                    height: 1.35,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w600,
                    color: c.texte)),
          ),
        if (theme.explication.isNotEmpty)
          Text(theme.explication,
              style: TextStyle(fontFamily: kPoliceTexte, fontSize: 13.5, height: 1.35, color: c.texte)),
      ]),
    );
  }
}

/// La carte d'un exercice de la grammaire dans la liste.
class _CarteExercice extends StatelessWidget {
  const _CarteExercice({required this.exercice, required this.onTap});

  final ExerciceGrammaire exercice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.destiny;
    final e = exercice;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: c.carte,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.filet),
            ),
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(e.titre,
                      style: TextStyle(
                          fontFamily: kPoliceTitres, fontWeight: FontWeight.w700, fontSize: 15.5, color: c.texte)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 10, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    EtiquetteExercice(icone: Icons.timer_outlined, texte: e.duree),
                    EtiquetteExercice(icone: Icons.groups_outlined, texte: e.joueurs),
                    if (avecMarkJane(context, e)) const BadgeMarkJane(),
                  ]),
                  if (e.but.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(e.but,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontFamily: kPoliceTexte, fontSize: 12.5, height: 1.3, color: c.texteSecondaire)),
                  ],
                ]),
              ),
              Icon(Icons.chevron_right_rounded, color: c.texteSecondaire),
            ]),
          ),
        ),
      ),
    );
  }
}

/// L'onglet Solo : les virelangues, un tirage au hasard, et un affichage en
/// grand pour s'entraîner à voix haute.
class _OngletDiction extends StatefulWidget {
  const _OngletDiction({required this.virelangues});

  final List<String> virelangues;

  @override
  State<_OngletDiction> createState() => _OngletDictionState();
}

class _OngletDictionState extends State<_OngletDiction> {
  final Random _rng = Random();
  final ScrollController _defilement = ScrollController();
  int? _choisi;

  @override
  void dispose() {
    _defilement.dispose();
    super.dispose();
  }

  void _auHasard() {
    final n = widget.virelangues.length;
    if (n == 0) return;
    var i = _rng.nextInt(n);
    if (n > 1 && i == _choisi) i = (i + 1) % n;
    setState(() => _choisi = i);
    if (_defilement.hasClients) {
      _defilement.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.textes;
    final c = context.destiny;
    final couleur = _couleurCarnet('');
    final total = widget.virelangues.length;
    final courant = _choisi == null ? null : widget.virelangues[_choisi!];
    String k(String x, [Map<String, String> v = const {}]) => t.t('exercices.$x', v);
    return ListView(
      controller: _defilement,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        SectionDestiny(titre: k('diction'), espace: 0, enfants: [
          Paragraphe(k('diction_aide', {'n': '$total'})),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: couleur.withValues(alpha: c.sombre ? 0.14 : 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: couleur.withValues(alpha: 0.5)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (courant != null)
                Text(k('numero', {'n': '${_choisi! + 1}', 'total': '$total'}),
                    style: TextStyle(
                        fontFamily: kPoliceTexte,
                        fontSize: 12,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w700,
                        color: c.texteSecondaire)),
              const SizedBox(height: 8),
              Text(
                courant ?? k('diction_vide'),
                style: TextStyle(
                  fontFamily: kPoliceTexte,
                  color: courant == null ? c.texteSecondaire : c.texte,
                  fontSize: courant == null ? 15 : 22,
                  height: 1.35,
                  fontWeight: courant == null ? FontWeight.w500 : FontWeight.w800,
                ),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _auHasard,
            icon: const Icon(Icons.shuffle_rounded),
            label: Text(k('au_hasard')),
          ),
        ]),
        SectionDestiny(titre: k('tous_virelangues'), enfants: [
          for (var i = 0; i < total; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Material(
                color: _choisi == i ? couleur.withValues(alpha: 0.14) : c.carte,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: () => setState(() => _choisi = i),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _choisi == i ? couleur : c.filet),
                    ),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      SizedBox(
                        width: 28,
                        child: Text('${i + 1}',
                            style: TextStyle(
                                fontFamily: kPoliceTexte, fontWeight: FontWeight.w700, color: c.texteSecondaire)),
                      ),
                      Expanded(
                        child: Text(widget.virelangues[i],
                            style: TextStyle(fontFamily: kPoliceTexte, height: 1.3, color: c.texte)),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
        ]),
      ],
    );
  }
}

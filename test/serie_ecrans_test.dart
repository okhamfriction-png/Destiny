import 'dart:convert';

import 'package:destiny/application/services/audio_service.dart';
import 'package:destiny/application/state/music_controller.dart';
import 'package:destiny/application/state/reglages_destiny.dart';
import 'package:destiny/application/state/serie_store.dart';
import 'package:destiny/application/state/visual_settings.dart';
import 'package:destiny/domain/grammaire/modeles.dart';
import 'package:destiny/domain/grammaire/textes.dart';
import 'package:destiny/domain/serie/pbta.dart';
import 'package:destiny/domain/serie/regles_serie.dart';
import 'package:destiny/domain/serie/serie.dart';
import 'package:destiny/presentation/bibliotheque/dangers_lieux_screen.dart';
import 'package:destiny/presentation/destiny/donnees.dart';
import 'package:destiny/presentation/serie/aide_mj_screen.dart';
import 'package:destiny/presentation/serie/bilan_screen.dart';
import 'package:destiny/presentation/serie/contexte_serie.dart';
import 'package:destiny/presentation/serie/creer_serie_screen.dart';
import 'package:destiny/presentation/serie/fiche_serie_screen.dart';
import 'package:destiny/presentation/serie/jeu_screen.dart';
import 'package:destiny/presentation/serie/personnages_screen.dart';
import 'package:destiny/presentation/serie/preparation_screen.dart';
import 'package:destiny/presentation/serie/saison_screen.dart';
import 'package:destiny/presentation/serie/series_screen.dart';
import 'package:destiny/presentation/theme/destiny_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'outils/grammaire_partagee.dart';
import 'outils/textes_utilises.dart';
import 'troupe_test.dart' show CatalogueDeTest;

late Grammaire g;
late TextesDestiny t;
late CatalogueDeTest catalogue;

Future<ContexteSerie> _contexte(WidgetTester tester) async {
  final store = SerieStore(lire: lireFichier);
  await tester.runAsync(() => store.charger(grammaire: g));
  final reglages = ReglagesDestiny();
  return ContexteSerie(
    store: store,
    reglages: reglages,
    catalogue: catalogue,
    audio: AudioService()..setMuted(true),
    musique: MusicController(),
    visuels: VisualSettings(),
  );
}

Widget _appli(Widget home, {bool sombre = true, double echelle = 1}) => MaterialApp(
      theme: themeDestiny(g, sombre: sombre),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(echelle)),
        child: DestinyDonnees(grammaire: g, textes: t, child: child!),
      ),
      home: home,
    );

/// Un téléphone de 390 px de large.
void _telephone(WidgetTester tester, {double hauteur = 844}) {
  tester.view.physicalSize = Size(390, hauteur);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

String _face(FacePiece f) => t.t('pbta.piece.faces.${f.name}.nom');

Future<void> _taper(WidgetTester tester, Finder f, {Finder? dans}) async {
  if (f.evaluate().isEmpty) {
    await tester.scrollUntilVisible(f, 300, scrollable: dans ?? find.byType(Scrollable).first);
  }
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
  await tester.tap(f.first);
  await tester.pumpAndSettle();
}

/// Fait défiler toute la page (ou la feuille) en vérifiant qu'aucun
/// débordement ni aucune erreur n'apparaît.
Future<void> _parcourir(WidgetTester tester, String ecran, {Finder? dans}) async {
  expect(tester.takeException(), isNull, reason: ecran);
  final scrollable = dans ?? find.byType(Scrollable).first;
  for (var i = 0; i < 40; i++) {
    final position = tester.state<ScrollableState>(scrollable).position;
    if (position.pixels >= position.maxScrollExtent) break;
    await tester.drag(scrollable, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: '$ecran (défilement ${i + 1})');
  }
}

/// La liste verticale affichée (dans un onglet, la page en cours).
final Finder _liste = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first;

/// Ouvre un onglet de l'aide du MJ (les onglets défilent, à texte agrandi).
Future<void> _onglet(WidgetTester tester, String nom) async {
  await tester.ensureVisible(find.text(nom));
  await tester.pumpAndSettle();
  await tester.tap(find.text(nom));
  await tester.pumpAndSettle();
}

/// Fait défiler [dans] jusqu'à voir [f].
Future<void> _voir(WidgetTester tester, Finder f, {required Finder dans}) async {
  for (var i = 0; i < 60 && f.evaluate().isEmpty; i++) {
    await tester.drag(dans, const Offset(0, -200));
    await tester.pumpAndSettle();
  }
  expect(f, findsWidgets);
  await tester.ensureVisible(f.first);
  await tester.pumpAndSettle();
}

/// La pièce tourne (une ou deux fois), puis le résultat s'affiche.
Future<void> _laisserTomber(WidgetTester tester) async {
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(seconds: 2));
  }
  await tester.pumpAndSettle();
}

/// Une série en jeu : deux joueurs (bonus BRAVE et SMART), l'alarmiste tenu
/// par le maître du jeu, un épisode au palier 2.
Future<(Serie, EpisodeSerie)> _serieEnJeu(ContexteSerie ctx, {bool kids = false}) async {
  final s = await ctx.store.creer(nom: 'La brume', public: kids ? PublicSerie.kids : PublicSerie.adulte);
  s.personnages.addAll([
    PersonnageSerie(
        id: 'p1', joueur: 'Léa', nom: 'Rose', archetypeId: 'leader', animalId: 'lion', bonus: FacePiece.brave, pouvoir: kids ? 'voler' : ''),
    PersonnageSerie(id: 'p2', joueur: 'Tom', nom: 'Gus', archetypeId: 'cynique', animalId: 'singe', bonus: FacePiece.smart),
    PersonnageSerie(id: 'p3', archetypeId: 'alarmiste', animalId: 'rat', pnj: true),
  ]);
  final lieu = catalogue.lieux.firstWhere((l) => !kids || l.kids);
  final danger = catalogue.dangers.firstWhere((d) => d.paliers.length == 4 && (!kids || d.kids));
  final m = g.mechants.firstWhere((x) => !kids || x.kids);
  final e = EpisodeSerie(
    id: 'e1',
    date: DateTime(2026, 11, 2),
    etape: EtapeEpisode.jeu,
    lieuId: lieu.id,
    lieuNom: lieu.name,
    groupe: 'une troupe de cirque',
    dangerId: danger.id,
    dangerNom: danger.name,
    paliers: danger.paliersPour(kids: kids),
    mechantId: m.id,
    palierAtteint: 2,
    roles: [
      RoleEpisode(personnageId: 'p1', vouloir: 'Sauver le chapiteau'),
      RoleEpisode(personnageId: 'p2', vouloir: 'Partir avec la caisse'),
      RoleEpisode(personnageId: 'p3'),
    ],
    pnjs: [
      ...figurantsDuLieu(g, prets: g.lieuNomme(lieu.name)?.figurants ?? const []),
      ...sbiresDuMechant(m),
    ],
  );
  s.episodes.add(e);
  await ctx.store.enregistrer(s);
  return (s, e);
}

void main() {
  setUpAll(() async {
    final c = await chargerGrammaire();
    g = c.grammaire;
    t = c.textes;
    final d = donneesDeTest();
    catalogue = CatalogueDeTest(await d.loadDangers(), await d.loadLocations());
  });

  testWidgets('un épisode, puis « Faire la suite » : il devient le premier d\'une saison', (tester) async {
    SharedPreferences.setMockInitialValues({});
    _telephone(tester, hauteur: 8000);
    final ctx = await _contexte(tester);
    await tester.pumpWidget(_appli(SeriesScreen(contexte: ctx)));
    await tester.pumpAndSettle();
    expect(find.text(t.t('serie.vide')), findsOneWidget);

    // Un nouvel épisode, pour des adultes : ni univers, ni ton, ni lore.
    await _taper(tester, find.text(t.t('serie.nouvel_episode')));
    for (final ancien in ['Univers', 'Ton', 'Lore', 'Destiny, sans univers']) {
      expect(find.text(ancien), findsNothing);
    }
    await _taper(tester, find.text(t.t('serie.creer.suivant')));

    // Les personnages : quatre joueurs, une distribution équilibrée, un bonus
    // proposé par l'archétype ; ni place dans le lieu, ni peuple.
    final s = ctx.store.series.single;
    expect(s.univers, isEmpty);
    expect(s.ton, isEmpty);
    expect(s.personnages.where((p) => !p.pnj), hasLength(4));
    expect(s.personnages.every((p) => p.archetypeId.isNotEmpty && p.animalId.isNotEmpty), isTrue);
    expect(s.personnages.any((p) => p.archetypeId == Grammaire.alarmisteId), isTrue);
    final regles = ReglesPbta.depuis(t);
    for (final p in s.personnages) {
      expect(p.bonus, regles.bonusSuggere(p.archetypeId), reason: p.archetypeId);
    }
    expect(find.text('Sa place dans le lieu'), findsNothing);
    expect(find.text('Peuple'), findsNothing);
    await tester.enterText(find.byType(TextField).first, 'Naël');
    await tester.pump();
    expect(s.personnages.first.joueur, 'Naël');
    // Le joueur choisit l'autre bonus.
    final premier = s.personnages.first;
    final autre = premier.bonus!.autre;
    await _taper(tester, find.widgetWithText(ChoiceChip, _face(autre)));
    expect(premier.bonus, autre);
    await _taper(tester, find.text(t.t('serie.personnages.vers_episode')));

    // La préparation : le lieu et le danger sont déjà tirés dans le catalogue
    // de Destiny, avec les trois figurants du lieu de la grammaire.
    final e = s.episodes.single;
    expect(e.saison, 0);
    expect(catalogue.lieux.map((l) => l.id), contains(e.lieuId));
    expect(catalogue.dangers.map((d) => d.id), contains(e.dangerId));
    expect(e.paliers, hasLength(4));
    expect(e.pnjs.map((p) => p.id), g.lieuNomme(e.lieuNom)!.figurants.map((f) => f.id));
    expect(e.pnjs.every((p) => p.mode == ModePnj.figurant), isTrue);
    final avant = e.lieuId;
    await _taper(tester, find.byTooltip(t.t('serie.preparation.autre_lieu')));
    expect(e.lieuId, isNot(avant));
    expect(e.pnjs.map((p) => p.id), g.lieuNomme(e.lieuNom)!.figurants.map((f) => f.id));
    // Les fiches de la Bibliothèque, depuis les vignettes.
    await _taper(tester, find.byTooltip(t.t('serie.preparation.info_de', {'nom': e.lieuNom})));
    expect(find.byType(FicheLieu), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await _taper(tester, find.byTooltip(t.t('serie.preparation.info_de', {'nom': e.dangerNom})));
    expect(find.byType(FicheDanger), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await _taper(tester, find.text(t.liste('mise_en_place.groupes').first));
    await _taper(tester, find.text(t.t('serie.preparation.commencer')));
    expect(e.etape, EtapeEpisode.jeu);

    // Le jeu : Destiny fait monter d'un palier, avec son rituel.
    await _taper(tester, find.text(t.t('regie.destiny').toUpperCase()));
    await tester.pump(const Duration(seconds: 10));
    await tester.pump(const Duration(seconds: 2));
    await _taper(tester, find.text(t.t('rituel.reprendre')));
    expect(e.palierAtteint, 2);
    expect(find.text(t.t('serie.jeu.rappel_fixer')), findsOneWidget);
    // Plus de combat : ni cœurs, ni malus, ni bonus chiffrés.
    expect(find.byIcon(Icons.favorite), findsNothing);
    expect(find.byIcon(Icons.add_circle_outline), findsNothing);
    // Un figurant passe au service du méchant ? Pas sans méchant.
    expect(find.text(t.t('serie.jeu.accepte_offre')), findsNothing);
    // Un figurant change de mode.
    await _taper(tester, find.text(t.t('modes_pnj.figurant')));
    expect(e.pnjs.where((p) => p.mode == ModePnj.sbire), hasLength(1));
    await _taper(tester, find.text(t.t('serie.jeu.terminer')));
    await _taper(tester, find.text(t.t('serie.oui')));
    expect(e.etape, EtapeEpisode.bilan);

    // Le bilan, puis la fiche de la série.
    await _taper(tester, find.text(t.t('debrief.choix_besoin')));
    expect(e.roles.first.choix, ChoixFinal.besoin);
    await _taper(tester, find.text(t.t('serie.bilan.terminer')));
    expect(e.etape, EtapeEpisode.termine);
    expect(find.text(t.t('serie.fiche.faire_la_suite')), findsOneWidget);

    // Faire la suite : le méchant reflet du protagoniste visé, parmi les 24.
    await _taper(tester, find.text(t.t('serie.fiche.faire_la_suite')));
    expect(find.text(t.t('serie.saison.depuis_episode')), findsOneWidget);
    final cible = s.personnages.firstWhere((p) => !p.pnj);
    final reflet = mechantsReflets(g, archetypeId: cible.archetypeId, kids: false).first;
    expect(g.mechants, contains(reflet));
    await _taper(tester, find.text(reflet.nom));
    final champs = find.byType(TextField);
    expect(champs, findsNWidgets(4));
    for (var i = 0; i < 4; i++) {
      await tester.enterText(champs.at(i), 'Présage ${i + 1}');
    }
    await tester.pump();
    await _taper(tester, find.text(t.t('serie.saison.valider')));

    expect(s.saisons.single.mechantId, reflet.id);
    expect(s.saisons.single.cibleId, cible.id);
    expect(e.saison, 1);
    expect(e.numero, 1);
    expect(e.presage, 'Présage 1');
    expect(s.nature, NatureSerie.saison);

    // L'épisode 2 : le méchant reste dans l'ombre, ses deux sbires sont là.
    await _taper(tester, find.text(t.t('serie.fiche.preparer', {'n': '2'})));
    expect(find.text(t.t('serie.preparation.ombre')), findsOneWidget);
    expect(find.textContaining('Présage 2'), findsWidgets);
    final e2 = s.episodes.last;
    expect(e2.numero, 2);
    expect(e2.lieuNom, isNotEmpty);
    expect(e2.pnjs.where((p) => p.duMechant), hasLength(2));

    // Tout est gardé.
    final prefs = await SharedPreferences.getInstance();
    final relu = Serie.depuisJson(
        (jsonDecode(prefs.getString(SerieStore.cleSeries)!) as List).first as Map<String, dynamic>);
    expect(relu.saisons.single.presages, ['Présage 1', 'Présage 2', 'Présage 3', 'Présage 4']);
    expect(relu.personnages.first.bonus, autre);
  });

  for (final sombre in [false, true]) {
    final theme = sombre ? 'sombre' : 'clair';

    testWidgets('le poste du MJ ($theme, texte agrandi) : la pièce avec le bonus, la vraie pièce, une blessure, l\'aide du MJ',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      _telephone(tester);
      final ctx = await _contexte(tester);
      final (s, e) = await _serieEnJeu(ctx);
      await tester.pumpWidget(_appli(JeuEpisodeScreen(contexte: ctx, serie: s, episode: e), sombre: sombre, echelle: 1.6));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // Les deux horloges : l'épisode, et la saison seulement en saison.
      expect(find.text(t.t('serie.jeu.horloge_episode')), findsOneWidget);
      expect(find.text(t.t('serie.jeu.horloge_saison')), findsNothing);

      // Rose agit avec son bonus (BRAVE) : deux lancers.
      await _taper(tester, find.text(t.t('serie.jeu.tirer_piece')));
      final feuille = find.byType(Scrollable).last;
      final deuxLancers = find.text(t.t('serie.piece.mode_seconde', {'face': 'BRAVE'}));
      await _voir(tester, deuxLancers, dans: feuille);
      expect(deuxLancers, findsOneWidget);
      await _parcourir(tester, 'la feuille de la pièce', dans: feuille);
      await _taper(tester, find.text(t.t('serie.piece.lancer')), dans: feuille);
      await _laisserTomber(tester);
      expect(tester.takeException(), isNull);
      final succes = find.text(t.t('pbta.piece.succes').toUpperCase());
      final echec = find.text(t.t('pbta.piece.echec').toUpperCase());
      expect(succes.evaluate().length + echec.evaluate().length, 1);
      await _parcourir(tester, 'le résultat', dans: find.byType(Scrollable).last);
      await _taper(tester, find.text(t.t('serie.piece.fermer')), dans: find.byType(Scrollable).last);

      // Gus agit en BRAVE (son bonus est SMART) : un seul lancer, avec la
      // vraie pièce, tombée sur SMART : échec, mouvement doux au palier 2.
      await _taper(tester, find.byTooltip(t.t('serie.jeu.tirer_pour', {'nom': 'Gus'})));
      final feuille2 = find.byType(Scrollable).last;
      await _taper(tester, find.widgetWithText(ChoiceChip, 'BRAVE'), dans: feuille2);
      final unLancer = find.text(t.t('serie.piece.mode_simple', {'face': 'BRAVE'}));
      await _voir(tester, unLancer, dans: feuille2);
      expect(unLancer, findsOneWidget);
      await _taper(tester, find.text(t.t('serie.piece.vraie_piece')), dans: feuille2);
      await _taper(tester, find.widgetWithText(OutlinedButton, 'SMART'), dans: feuille2);
      expect(echec, findsOneWidget);
      final resultat = find.byType(Scrollable).last;
      final gravite = find.text(t.t('serie.piece.gravite', {'gravite': t.t('serie.piece.doux'), 'n': '2'}).toUpperCase());
      await _voir(tester, gravite, dans: resultat);
      expect(gravite, findsOneWidget);
      final regles = ReglesPbta.depuis(t);
      await _voir(tester, find.text(t.t('serie.piece.autres_idees')), dans: resultat);
      final idees = [
        for (final m in regles.mouvementsMjDe(GraviteMouvement.doux))
          if (find.text(m.nom).evaluate().isNotEmpty) m,
      ];
      expect(idees, hasLength(3));
      await _taper(tester, find.text(t.t('serie.piece.marquer_blessure')), dans: resultat);
      expect(e.role('p2')!.blessures, 1);
      await _parcourir(tester, 'le résultat d\'un échec', dans: resultat);
      await _taper(tester, find.text(t.t('serie.piece.fermer')), dans: resultat);

      // Le MJ coche une case de blessure de Rose, puis la soigne.
      await _taper(tester, find.byTooltip('Blessé'));
      expect(e.role('p1')!.blessures, 2);
      await _taper(tester, find.text(t.t('serie.jeu.soigner')));
      expect(e.role('p1')!.blessures, 1);
      // Rose dit son vouloir : sa prochaine action se joue avec deux lancers.
      await _taper(tester, find.text(t.t('serie.jeu.dit_vouloir')));
      expect(e.role('p1')!.elan, isTrue);
      await _parcourir(tester, 'le poste du MJ');

      // L'aide du MJ : l'agenda, les principes, les mouvements.
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 20000));
      await tester.pumpAndSettle();
      await _taper(tester, find.widgetWithText(OutlinedButton, t.t('serie.aide_mj.titre')));
      expect(find.byType(AideMjScreen), findsOneWidget);
      final titrePiece = find.text(t.t('pbta.piece.titre').toUpperCase());
      await _voir(tester, titrePiece, dans: _liste);
      expect(titrePiece, findsOneWidget);
      await _parcourir(tester, 'l\'aide du MJ : la pièce', dans: _liste);
      final onglets = t.liste('serie.aide_mj.onglets');
      expect(onglets, hasLength(4));
      for (final onglet in onglets.skip(1)) {
        await _onglet(tester, onglet);
        await _parcourir(tester, 'l\'aide du MJ : $onglet', dans: _liste);
      }
      await _onglet(tester, onglets[2]);
      await _voir(tester, find.text(regles.principes.last), dans: _liste);
      expect(find.text(regles.principes.last), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Tout est gardé.
      final prefs = await SharedPreferences.getInstance();
      final relu = Serie.depuisJson(
          (jsonDecode(prefs.getString(SerieStore.cleSeries)!) as List).first as Map<String, dynamic>);
      expect(relu.episodes.single.role('p2')!.blessures, 1);
      expect(relu.episodes.single.role('p1')!.elan, isTrue);
    });

    testWidgets('créer, les personnages, préparer, jouer en kids : tout tient ($theme, texte agrandi)', (tester) async {
      SharedPreferences.setMockInitialValues({});
      _telephone(tester);
      final ctx = await _contexte(tester);

      await tester.pumpWidget(_appli(CreerSerieScreen(contexte: ctx, saison: false), sombre: sombre, echelle: 1.6));
      await tester.pumpAndSettle();
      await _parcourir(tester, 'créer');

      final s = await ctx.store.creer(public: PublicSerie.kids);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(_appli(
          PersonnagesScreen(key: UniqueKey(), contexte: ctx, serie: s, apres: ApresPersonnages.fiche),
          sombre: sombre,
          echelle: 1.6));
      await tester.pumpAndSettle();
      expect(s.personnages.where((p) => !p.pnj), hasLength(4));
      // En kids, chacun a son pouvoir ; pas de place dans le lieu.
      await _voir(tester, find.text(t.t('serie.personnages.pouvoir')), dans: find.byType(Scrollable).first);
      expect(find.text(t.t('serie.personnages.pouvoir')), findsWidgets);
      await _parcourir(tester, 'les personnages');

      final e = EpisodeSerie(id: 'e', date: DateTime(2026, 11, 2));
      s.episodes.add(e);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(_appli(
          PreparationEpisodeScreen(key: UniqueKey(), contexte: ctx, serie: s, episode: e),
          sombre: sombre,
          echelle: 1.6));
      await tester.pumpAndSettle();
      // En kids, seulement des lieux et des dangers kids.
      expect(catalogue.lieux.firstWhere((l) => l.id == e.lieuId).kids, isTrue);
      expect(catalogue.dangers.firstWhere((d) => d.id == e.dangerId).kids, isTrue);
      await _parcourir(tester, 'la préparation');

      final (s2, e2) = await _serieEnJeu(ctx, kids: true);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(_appli(
          JeuEpisodeScreen(key: UniqueKey(), contexte: ctx, serie: s2, episode: e2),
          sombre: sombre,
          echelle: 1.6));
      await tester.pumpAndSettle();
      // Les cases des enfants : personne ne meurt.
      await _voir(tester, find.byTooltip('Doit se reposer'), dans: find.byType(Scrollable).first);
      expect(find.byTooltip('Doit se reposer'), findsWidgets);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 20000));
      await tester.pumpAndSettle();
      await _taper(tester, find.text(t.t('serie.jeu.tirer_piece')));
      final pouvoir = find.text(t.t('serie.piece.pouvoir'));
      await _voir(tester, pouvoir, dans: find.byType(Scrollable).last);
      expect(pouvoir, findsOneWidget);
      await _parcourir(tester, 'la feuille de la pièce, en kids', dans: find.byType(Scrollable).last);
      await tester.tapAt(const Offset(195, 10));
      await tester.pumpAndSettle();
      await _parcourir(tester, 'le poste du MJ, en kids');

      // Le bilan, la fiche de la série et la saison suivante.
      e2
        ..etape = EtapeEpisode.bilan
        ..roles.first.blessures = 3;
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(_appli(
          BilanEpisodeScreen(key: UniqueKey(), contexte: ctx, serie: s2, episode: e2),
          sombre: sombre,
          echelle: 1.6));
      await tester.pumpAndSettle();
      await _voir(tester, find.text(t.t('serie.bilan.quitte_kids')), dans: _liste);
      expect(find.text('Doit se reposer'), findsOneWidget);
      await _parcourir(tester, 'le bilan, en kids');
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(_appli(FicheSerieScreen(contexte: ctx, serieId: s2.id), sombre: sombre, echelle: 1.6));
      await tester.pumpAndSettle();
      await _parcourir(tester, 'la fiche de la série');
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(_appli(SaisonScreen(key: UniqueKey(), contexte: ctx, serie: s2), sombre: sombre, echelle: 1.6));
      await tester.pumpAndSettle();
      // En kids, seulement les grands méchants kids.
      for (final m in g.mechants.where((m) => !m.kids)) {
        expect(find.text(m.nom), findsNothing);
      }
      await _parcourir(tester, 'la saison');

      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
          _appli(const AideMjScreen(kids: true, palier: 3, onglet: OngletAideMj.maitre), sombre: sombre, echelle: 1.6));
      await tester.pumpAndSettle();
      // Au palier 3, les mouvements sont durs ; en kids, jamais la mort.
      expect(find.text(t.t('serie.aide_mj.maintenant', {'n': '3', 'gravite': t.t('serie.piece.dur')})), findsOneWidget);
      await _voir(tester, find.textContaining('Jamais la mort'), dans: _liste);
      expect(find.textContaining('Jamais la mort'), findsOneWidget);
      await _parcourir(tester, 'l\'aide du MJ, en kids', dans: _liste);
      await _onglet(tester, t.liste('serie.aide_mj.onglets')[3]);
      expect(find.text('Doit se reposer'), findsOneWidget);
      await _parcourir(tester, 'les blessures, en kids', dans: _liste);
    });
  }

  testWidgets('le traître : un seul joueur voit l\'offre, écran caché', (tester) async {
    SharedPreferences.setMockInitialValues({});
    _telephone(tester, hauteur: 8000);
    final ctx = await _contexte(tester);
    final s = await ctx.store.creer(reglages: ReglagesSerie(traitre: true));
    s.personnages.addAll([
      PersonnageSerie(id: 'a', joueur: 'Léa', archetypeId: 'leader', animalId: 'lion'),
      PersonnageSerie(id: 'b', joueur: 'Tom', archetypeId: 'cynique', animalId: 'singe'),
      PersonnageSerie(id: 'c', archetypeId: 'alarmiste', animalId: 'rat', pnj: true),
    ]);
    await tester.pumpWidget(_appli(SaisonScreen(contexte: ctx, serie: s)));
    await tester.pumpAndSettle();
    final reflet = g.mechantsReflets('leader').first;
    await _taper(tester, find.text(reflet.nom));
    for (var i = 0; i < 4; i++) {
      await tester.enterText(find.byType(TextField).at(i), 'P$i');
    }
    await tester.pump();
    await _taper(tester, find.text(t.t('serie.saison.valider')));

    // Le traître n'est ni la cible (Léa), ni le personnage du maître du jeu.
    expect(s.saisons.single.traitre!.personnageId, 'b');
    expect(find.text(t.t('serie.traitre.passer', {'joueur': 'Tom'})), findsOneWidget);
    expect(find.text(reflet.offreAuTraitre), findsNothing);
    await _taper(tester, find.text(t.t('serie.traitre.voir')));
    expect(find.text(reflet.offreAuTraitre), findsOneWidget);
    await _taper(tester, find.text(t.t('serie.traitre.accepte')));
    expect(s.saisons.single.traitre!.accepte, isTrue);
    expect(find.text(t.t('serie.traitre.fin')), findsOneWidget);
  });

  test('chaque texte des écrans de la Série, du livret et des réglages existe', () {
    expect(
      textesManquants([
        'lib/presentation/serie',
        'lib/presentation/widgets/piece_destin_flip.dart',
        'lib/presentation/reglages/reglages_destiny_screen.dart',
        'lib/application/livret/livret.dart',
        'lib/application/state/serie_store.dart',
      ]),
      isEmpty,
    );
  });
}

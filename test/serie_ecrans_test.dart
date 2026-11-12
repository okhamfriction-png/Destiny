import 'dart:convert';

import 'package:destiny/application/services/audio_service.dart';
import 'package:destiny/application/state/ai_settings.dart';
import 'package:destiny/application/state/music_controller.dart';
import 'package:destiny/application/state/reglages_destiny.dart';
import 'package:destiny/application/state/serie_store.dart';
import 'package:destiny/application/state/visual_settings.dart';
import 'package:destiny/domain/grammaire/modeles.dart';
import 'package:destiny/domain/grammaire/textes.dart';
import 'package:destiny/domain/serie/regles_serie.dart';
import 'package:destiny/domain/serie/serie.dart';
import 'package:destiny/presentation/bibliotheque/dangers_lieux_screen.dart';
import 'package:destiny/presentation/destiny/donnees.dart';
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
import 'package:destiny/presentation/troupe/regie_screen.dart' show TabletteSon;
import 'package:destiny/presentation/destiny/composants.dart' show FrisePaliers;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'outils/grammaire_partagee.dart';
import 'outils/textes_utilises.dart';
import 'serie_test.dart' show FauxLlm;
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

/// Une série en jeu : deux joueurs, l'alarmiste tenu par le maître du jeu,
/// un épisode au palier 2 avec un grand méchant, ses sbires et les figurants.
Future<(Serie, EpisodeSerie)> _serieEnJeu(ContexteSerie ctx, {bool kids = false}) async {
  final s = await ctx.store.creer(nom: 'La brume', public: kids ? PublicSerie.kids : PublicSerie.adulte);
  s.personnages.addAll([
    PersonnageSerie(
        id: 'p1', joueur: 'Léa', nom: 'Rose', archetypeId: 'leader', animalId: 'lion', pouvoir: kids ? 'voler' : ''),
    PersonnageSerie(id: 'p2', joueur: 'Tom', nom: 'Gus', archetypeId: 'cynique', animalId: 'singe'),
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

  testWidgets('le mode vient de l\'entrée : on crée en enfant sans le redemander, et on ne voit que ses séries', (tester) async {
    SharedPreferences.setMockInitialValues({});
    _telephone(tester, hauteur: 8000);
    final ctx = await _contexte(tester);
    await tester.runAsync(() => ctx.store.creer(nom: 'Les grands', public: PublicSerie.adulte));
    await tester.pumpWidget(_appli(SeriesScreen(contexte: ctx, public: PublicSerie.kids)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('bandeau_mode_kids')), findsOneWidget);
    expect(find.text('Les grands'), findsNothing, reason: 'une série adulte ne se voit pas en mode enfant');
    await _taper(tester, find.text(t.t('serie.nouvel_episode')));
    // Plus de choix « pour qui ? » : le mode est déjà choisi.
    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.byKey(const ValueKey('bandeau_mode_kids')), findsOneWidget);
    await _taper(tester, find.text(t.t('serie.creer.suivant')));
    final enfant = ctx.store.series.firstWhere((s) => s.nom != 'Les grands');
    expect(enfant.public, PublicSerie.kids);
    expect(enfant.reglages.traitre, isFalse, reason: 'en kids, le traître reste éteint');
  });

  testWidgets('un épisode, puis « Faire la suite » : il devient le premier d\'une saison', (tester) async {
    SharedPreferences.setMockInitialValues({});
    _telephone(tester, hauteur: 8000);
    final ctx = await _contexte(tester);
    await tester.pumpWidget(_appli(SeriesScreen(contexte: ctx, public: PublicSerie.adulte)));
    await tester.pumpAndSettle();
    expect(find.text(t.t('serie.vide')), findsOneWidget);

    // Un nouvel épisode, pour des adultes : ni univers, ni ton, ni lore, ni
    // module traître ou registre à régler.
    await _taper(tester, find.text(t.t('serie.nouvel_episode')));
    for (final ancien in ['Univers', 'Ton', 'Lore', 'Destiny, sans univers', t.t('serie.creer.traitre')]) {
      expect(find.text(ancien), findsNothing);
    }
    await _taper(tester, find.text(t.t('serie.creer.suivant')));

    // Les personnages : quatre joueurs, une distribution équilibrée ; plus de
    // bonus à la pièce, ni blessure, ni besoin à remplir.
    final s = ctx.store.series.single;
    expect(s.reglages.traitre, isFalse);
    expect(s.personnages.where((p) => !p.pnj), hasLength(4));
    expect(s.personnages.every((p) => p.archetypeId.isNotEmpty && p.animalId.isNotEmpty), isTrue);
    expect(s.personnages.any((p) => p.archetypeId == Grammaire.alarmisteId), isTrue);
    for (final ancien in [t.t('serie.personnages.bonus'), t.t('serie.personnages.blessure'), t.t('serie.personnages.besoin')]) {
      expect(find.text(ancien), findsNothing);
    }
    await tester.enterText(find.byType(TextField).first, 'Naël');
    await tester.pump();
    expect(s.personnages.first.joueur, 'Naël');
    await _taper(tester, find.text(t.t('serie.personnages.vers_episode')));

    // La préparation, comme au théâtre : le fil des étapes, le lieu et le
    // danger déjà tirés, les figurants du lieu ; ni groupe, ni mystère, ni
    // vouloirs, ni registre.
    final e = s.episodes.single;
    expect(e.saison, 0);
    expect(find.byKey(const ValueKey('fil_preparer')), findsOneWidget);
    expect(catalogue.lieux.map((l) => l.id), contains(e.lieuId));
    expect(catalogue.dangers.map((d) => d.id), contains(e.dangerId));
    expect(e.paliers, hasLength(4));
    expect(e.pnjs.map((p) => p.id), g.lieuNomme(e.lieuNom)!.figurants.map((f) => f.id));
    for (final ancien in [t.t('mise_en_place.groupe'), t.t('mise_en_place.mystere'), t.t('serie.preparation.vouloirs')]) {
      expect(find.text(ancien), findsNothing, reason: ancien);
    }
    final avant = e.lieuId;
    await _taper(tester, find.byTooltip(t.t('serie.preparation.autre_lieu')));
    expect(e.lieuId, isNot(avant));
    // Les fiches de la Bibliothèque, depuis les vignettes.
    await _taper(tester, find.byTooltip(t.t('serie.preparation.info_de', {'nom': e.lieuNom})));
    expect(find.byType(FicheLieu), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('fermer_fenetre')));
    await tester.pumpAndSettle();
    await _taper(tester, find.byKey(const ValueKey('commencer_episode')));
    expect(e.etape, EtapeEpisode.jeu);

    // Le jeu : pas de flèche de retour, ni pièce du destin, ni aide du MJ.
    expect(find.byType(JeuEpisodeScreen), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
    expect(find.text(t.t('serie.jeu.tirer_piece')), findsNothing);
    expect(find.text(t.t('serie.aide_mj.titre')), findsNothing);
    // DESTINY fait monter d'un palier, avec son rituel.
    await _taper(tester, find.byKey(const ValueKey('pilote_destiny')));
    await tester.pump(const Duration(seconds: 10));
    await tester.pump(const Duration(seconds: 2));
    if (find.text(t.t('rituel.reprendre')).evaluate().isNotEmpty) {
      await _taper(tester, find.text(t.t('rituel.reprendre')));
    }
    await tester.pumpAndSettle();
    expect(e.palierAtteint, 2);
    // Le cœur et le cerveau de chacun.
    final premier = s.personnagesActifs.first;
    await _taper(tester, find.byKey(ValueKey('coeur_blesse_${premier.id}')));
    await _taper(tester, find.byKey(ValueKey('esprit_auBord_${premier.id}')));
    expect(e.role(premier.id)!.sante, Sante.blesse);
    expect(e.role(premier.id)!.esprit, Esprit.auBord);
    // Un figurant change de mode.
    await _taper(tester, find.text(t.t('modes_pnj.figurant')));
    expect(e.pnjs.where((p) => p.mode == ModePnj.sbire), hasLength(1));
    await _taper(tester, find.byKey(const ValueKey('terminer_episode')));
    await _taper(tester, find.text(t.t('serie.oui')));
    expect(e.etape, EtapeEpisode.bilan);

    // Le bilan : le compte rendu de l'IA, le cœur et le cerveau de chacun.
    expect(find.text(t.t('serie.bilan.compte_rendu').toUpperCase()), findsOneWidget);
    expect(find.byKey(const ValueKey('compte_rendu_ia')), findsOneWidget);
    for (final ancien in [t.t('debrief.choix_besoin'), t.t('serie.bilan.sortie'), t.t('serie.bilan.ce_qui_a_marche')]) {
      expect(find.text(ancien), findsNothing, reason: ancien);
    }
    await _taper(tester, find.byKey(const ValueKey('ranger_episode')));
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
    expect(s.saisons.single.traitre, isNull, reason: 'plus de traître');
    expect(e.saison, 1);
    expect(e.presage, 'Présage 1');
    expect(s.nature, NatureSerie.saison);

    // L'épisode 2 : le méchant reste dans l'ombre, ses deux sbires sont là ;
    // le blessé l'est encore, et son cerveau aussi.
    await _taper(tester, find.text(t.t('serie.fiche.preparer', {'n': '2'})));
    expect(find.text(t.t('serie.preparation.ombre')), findsOneWidget);
    final e2 = s.episodes.last;
    expect(e2.numero, 2);
    expect(e2.pnjs.where((p) => p.duMechant), hasLength(2));
    expect(e2.role(premier.id)!.sante, Sante.blesse);
    expect(e2.role(premier.id)!.esprit, Esprit.auBord);

    // Tout est gardé.
    final prefs = await SharedPreferences.getInstance();
    final relu = Serie.depuisJson(
        (jsonDecode(prefs.getString(SerieStore.cleSeries)!) as List).first as Map<String, dynamic>);
    expect(relu.saisons.single.presages, ['Présage 1', 'Présage 2', 'Présage 3', 'Présage 4']);
    expect(relu.episodes.first.role(premier.id)!.esprit, Esprit.auBord);
  });

  for (final sombre in [false, true]) {
    final theme = sombre ? 'sombre' : 'clair';

    testWidgets('le jeu ($theme, texte agrandi) : le cœur, le cerveau, la régie en pop-up', (tester) async {
      SharedPreferences.setMockInitialValues({});
      _telephone(tester);
      final ctx = await _contexte(tester);
      final (s, e) = await _serieEnJeu(ctx);
      await tester.pumpWidget(_appli(JeuEpisodeScreen(contexte: ctx, serie: s, episode: e), sombre: sombre, echelle: 1.6));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      // Comme au théâtre : le fil, le chrono et DESTINY, la régie.
      expect(find.byKey(const ValueKey('fil_jeu')), findsOneWidget);
      expect(find.byKey(const ValueKey('pilote_reste')), findsOneWidget);
      expect(find.byKey(const ValueKey('pilote_destiny')), findsOneWidget);
      expect(find.byType(FrisePaliers), findsOneWidget);
      // Plus de pièce, d'horloges, de cases de blessure ni de vouloir.
      for (final ancien in [
        t.t('serie.jeu.tirer_piece'),
        t.t('serie.jeu.horloge_episode'),
        t.t('serie.jeu.escalade'),
        t.t('serie.jeu.dit_vouloir'),
        t.t('regie.mystere'),
        t.t('regie.notes'),
      ]) {
        expect(find.text(ancien), findsNothing, reason: ancien);
      }

      // Gus est mort ; Rose perd la tête.
      await _voir(tester, find.byKey(const ValueKey('coeur_sorti_p2')), dans: find.byType(Scrollable).first);
      await _taper(tester, find.byKey(const ValueKey('coeur_sorti_p2')));
      expect(e.role('p2')!.sante, Sante.sorti);
      expect(find.text(t.t('serie.sante.coeur.sorti')), findsWidgets);
      await _taper(tester, find.byKey(const ValueKey('esprit_fou_p1')));
      expect(e.role('p1')!.esprit, Esprit.fou);
      expect(find.text(t.t('serie.sante.esprit.fou')), findsWidgets);
      expect(find.text(t.t('serie.sante.esprit_titre').toUpperCase()), findsWidgets);
      // Le grand méchant, ses sbires et les figurants.
      final sbires = find.text(t.t('serie.jeu.sbires').toUpperCase());
      await _voir(tester, sbires, dans: find.byType(Scrollable).first);
      expect(sbires, findsOneWidget);
      await _parcourir(tester, 'le jeu');

      // La régie : la table, directement, en pop-up ; la croix ramène au jeu.
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 20000));
      await tester.pumpAndSettle();
      await _taper(tester, find.byKey(const ValueKey('ouvrir_regie')));
      expect(find.byType(TabletteSon), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'la table tient au texte agrandi');
      await tester.tap(find.byKey(const ValueKey('fermer_regie_son')));
      await tester.pumpAndSettle();
      expect(find.byType(TabletteSon), findsNothing);
      expect(find.byType(JeuEpisodeScreen), findsOneWidget);

      // Tout est gardé.
      final prefs = await SharedPreferences.getInstance();
      final relu = Serie.depuisJson(
          (jsonDecode(prefs.getString(SerieStore.cleSeries)!) as List).first as Map<String, dynamic>);
      expect(relu.episodes.single.role('p2')!.sante, Sante.sorti);
      expect(relu.episodes.single.role('p1')!.esprit, Esprit.fou);
    });

    testWidgets('créer, les personnages, préparer, jouer en kids : tout tient ($theme, texte agrandi)', (tester) async {
      SharedPreferences.setMockInitialValues({});
      _telephone(tester);
      final ctx = await _contexte(tester);

      await tester.pumpWidget(_appli(
          CreerSerieScreen(contexte: ctx, saison: false, public: PublicSerie.kids),
          sombre: sombre,
          echelle: 1.6));
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
      // En kids, chacun a son pouvoir.
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
      // Les mots des enfants : personne ne meurt, on quitte l'histoire.
      await _voir(tester, find.text(t.t('serie.sante.coeur.sorti_kids')), dans: find.byType(Scrollable).first);
      expect(find.text(t.t('serie.sante.coeur.sorti_kids')), findsWidgets);
      expect(find.text(t.t('serie.sante.coeur.sorti')), findsNothing);
      expect(find.text(t.t('serie.sante.esprit_kids.lucide')), findsWidgets);
      expect(find.text(t.t('serie.sante.esprit.fou')), findsNothing);
      await _parcourir(tester, 'le jeu, en kids');

      // Le bilan, la fiche de la série et la saison suivante.
      e2
        ..etape = EtapeEpisode.bilan
        ..roles.first.sante = Sante.sorti;
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(_appli(
          BilanEpisodeScreen(key: UniqueKey(), contexte: ctx, serie: s2, episode: e2),
          sombre: sombre,
          echelle: 1.6));
      await tester.pumpAndSettle();
      final sortis = find.text(t.t('serie.bilan.sortis_kids').toUpperCase());
      await _voir(tester, sortis, dans: _liste);
      expect(sortis, findsOneWidget);
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
    });
  }

  testWidgets('sans chrono, DESTINY part à la main, trois fois', (tester) async {
    SharedPreferences.setMockInitialValues({});
    _telephone(tester, hauteur: 8000);
    final ctx = await _contexte(tester);
    final (s, e) = await _serieEnJeu(ctx, kids: true);
    e
      ..palierAtteint = 1
      ..dureeMinutes = 0
      ..destinyMinutes = [];
    await tester.pumpWidget(_appli(JeuEpisodeScreen(contexte: ctx, serie: s, episode: e)));
    await tester.pumpAndSettle();
    expect(find.text(t.t('serie.jeu.destinys')), findsNothing, reason: 'pas de frise sans chrono');
    for (var i = 1; i <= 3; i++) {
      await tester.tap(find.byKey(const ValueKey('pilote_destiny')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 10));
      await tester.pump(const Duration(seconds: 2));
      if (find.text(t.t('rituel.reprendre')).evaluate().isNotEmpty) {
        await tester.tap(find.text(t.t('rituel.reprendre')));
      }
      await tester.pumpAndSettle();
      expect(e.palierAtteint, i + 1);
    }
    final bouton = tester.widget<ButtonStyleButton>(find.byKey(const ValueKey('pilote_destiny')));
    expect(bouton.onPressed, isNull, reason: 'au palier 4, plus de Destiny');
  });

  testWidgets('le compte rendu par l\'IA, même sans transcription : la trame part, sans prénom', (tester) async {
    SharedPreferences.setMockInitialValues({'ai_token': 'jeton'});
    _telephone(tester, hauteur: 8000);
    final ia = await tester.runAsync(AiSettings.load);
    final llm = FauxLlm('{"resume": "Ils ont sauvé le chapiteau.", "suite": "Le cirque repart.", "registre": []}');
    final store = SerieStore(lire: lireFichier, llm: llm, aiSettings: ia);
    await tester.runAsync(() => store.charger(grammaire: g));
    final ctx = ContexteSerie(
      store: store,
      reglages: ReglagesDestiny(),
      catalogue: catalogue,
      audio: AudioService()..setMuted(true),
      musique: MusicController(),
      visuels: VisualSettings(),
    );
    final (s, e) = await _serieEnJeu(ctx);
    e
      ..etape = EtapeEpisode.bilan
      ..roles.first.sante = Sante.blesse
      ..roles.first.esprit = Esprit.ebranle;
    await tester.pumpWidget(_appli(BilanEpisodeScreen(contexte: ctx, serie: s, episode: e)));
    await tester.pumpAndSettle();
    expect(find.text(t.t('serie.bilan.compte_rendu_aide')), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('notes_mj')), 'Léa a sauvé le chapiteau.');
    await tester.pump();
    await _taper(tester, find.byKey(const ValueKey('compte_rendu_ia')));
    // Le texte exact qui partira : la trame, sans les prénoms des joueurs.
    final champ = tester.widget<TextField>(find.byType(TextField).first);
    final texte = champ.controller!.text;
    expect(texte, contains(e.lieuNom));
    expect(texte, contains('Rose'));
    expect(texte, contains(t.t('serie.sante.esprit.ebranle').toLowerCase()));
    expect(texte, isNot(contains('Léa')));
    await tester.runAsync(() async {
      await tester.tap(find.text(t.t('serie.resume.demander')));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    await tester.pumpAndSettle();
    expect(llm.envois.single, isNot(contains('Léa')));
    await _taper(tester, find.text(t.t('serie.resume.accepter')));
    expect(e.resume, 'Ils ont sauvé le chapiteau.');
    expect(find.text('Ils ont sauvé le chapiteau.'), findsOneWidget);
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

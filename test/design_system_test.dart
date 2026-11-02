import 'package:destiny/application/state/visual_settings.dart';
import 'package:destiny/domain/grammaire/modeles.dart';
import 'package:destiny/domain/grammaire/textes.dart';
import 'package:destiny/presentation/destiny/cartes.dart';
import 'package:destiny/presentation/destiny/composants.dart';
import 'package:destiny/presentation/destiny/donnees.dart';
import 'package:destiny/presentation/destiny/rituel_destiny.dart';
import 'package:destiny/presentation/theme/destiny_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'outils/grammaire_partagee.dart';
import 'outils/polices.dart';

late Grammaire g;
late TextesDestiny t;

Widget _scene(Widget enfant, {bool sombre = true, Size taille = const Size(380, 640)}) => MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: themeDestiny(g, sombre: sombre),
      // Comme dans l'appli : les données sont au-dessus du Navigator.
      builder: (context, child) => DestinyDonnees(grammaire: g, textes: t, child: child!),
      home: Scaffold(
        body: Center(
          child: RepaintBoundary(
            child: SizedBox(
              width: taille.width,
              child: SingleChildScrollView(
                child: Padding(padding: const EdgeInsets.all(16), child: enfant),
              ),
            ),
          ),
        ),
      ),
    );

Future<void> _photo(WidgetTester tester, Widget w, String nom,
    {bool sombre = true, Size ecran = const Size(420, 760)}) async {
  tester.view.physicalSize = ecran;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_scene(w, sombre: sombre));
  await tester.pumpAndSettle();
  await expectLater(find.byType(RepaintBoundary).first, matchesGoldenFile('goldens/$nom.png'));
}

void main() {
  setUpAll(() async {
    final c = await chargerGrammaire();
    g = c.grammaire;
    t = c.textes;
    await chargerPolices();
  });

  group('Thème', () {
    test('les couleurs viennent de la direction artistique', () {
      final c = DestinyCouleurs.depuisGrammaire(g, sombre: true);
      expect(c.nuit, const Color(0xFF100D08));
      expect(c.or, const Color(0xFFC9A35A));
      expect(c.bleuDestiny, const Color(0xFF3F74B5));
      expect(c.famille(FamilleId.tient), const Color(0xFF4E9F7A));
      expect(c.famille(FamilleId.interprete), const Color(0xFF3F74B5));
      expect(c.famille(FamilleId.fissure), const Color(0xFFB5473A));
      expect(c.statuts[Statut.haut], const Color(0xFFD6ECD9));
      expect(c.kidsFond, const Color(0xFFF2C230));
    });

    test('Cinzel pour les titres, Montserrat pour le texte', () {
      final th = themeDestiny(g, sombre: false);
      expect(th.textTheme.headlineMedium!.fontFamily, kPoliceTitres);
      expect(th.textTheme.bodyMedium!.fontFamily, kPoliceTexte);
      expect(th.extension<DestinyCouleurs>()!.sombre, isFalse);
    });
  });

  group('Cartes (rendu)', () {
    testWidgets('carte d\'archétype, sombre', (tester) async {
      await _photo(tester,
          const CarteArchetype.archetype('leader', source: VisualSource.minimal, courant: PalierId.enferme),
          'carte_archetype_leader_sombre');
    });

    testWidgets('carte d\'archétype, clair', (tester) async {
      await _photo(tester, const CarteArchetype.archetype('paranoiaque', source: VisualSource.minimal),
          'carte_archetype_paranoiaque_clair',
          sombre: false);
    });

    testWidgets('carte d\'animal', (tester) async {
      await _photo(tester, const CarteArchetype.animal('rat', source: VisualSource.minimal), 'carte_animal_rat');
    });

    testWidgets('carte kids', (tester) async {
      await _photo(tester, const CarteArchetype.kids('loup', source: VisualSource.minimal), 'carte_kids_loup',
          sombre: false);
    });

    testWidgets('dos de carte', (tester) async {
      await _photo(tester, const DosCarte(famille: FamilleId.interprete, largeur: 300, hauteur: 420),
          'dos_carte_interprete');
    });

    testWidgets('frise des paliers avec un danger', (tester) async {
      final danger = g.dangerNomme('Un incendie')!;
      await _photo(tester, FrisePaliers(textes: danger.textes, courant: PalierId.envahit), 'frise_paliers');
    });
  });

  group('Cartes (contenu)', () {
    testWidgets('la carte montre la réplique, jamais sa source', (tester) async {
      await tester.pumpWidget(_scene(const CarteArchetype.archetype('alarmiste', source: VisualSource.minimal)));
      for (final a in g.animauxDe('alarmiste')) {
        expect(find.textContaining(a.replique), findsOneWidget);
        expect(find.textContaining(a.sourceReplique), findsNothing);
      }
      expect(find.text(g.archetype('alarmiste')!.monteeA(PalierId.envahit)), findsOneWidget);
      expect(find.text(g.famille(FamilleId.interprete).nom), findsOneWidget);
    });

    testWidgets('la carte kids montre la réplique kids et le sigle', (tester) async {
      await tester.pumpWidget(_scene(const CarteArchetype.kids('renard', source: VisualSource.minimal)));
      final renard = g.animal('renard')!;
      expect(find.textContaining(renard.repliqueKids), findsOneWidget);
      expect(find.textContaining(renard.replique), findsNothing);
      expect(find.byType(SigleKids), findsOneWidget);
    });

    testWidgets('la puce de famille porte la couleur de la famille', (tester) async {
      await tester.pumpWidget(_scene(const PuceFamille(FamilleId.fissure)));
      expect(find.text(g.famille(FamilleId.fissure).nom), findsOneWidget);
    });
  });

  group('Rituel Destiny', () {
    testWidgets('tonnerre, figé, ellipse, puis le nouveau palier', (tester) async {
      var tonnerre = 0;
      await tester.pumpWidget(_scene(Builder(
        builder: (context) => TextButton(
          onPressed: () => lancerRituelDestiny(
            context,
            nouveauPalier: PalierId.enferme,
            nouvelle: 'Les issues sont bloquées.',
            premierFige: true,
            auTonnerre: () => tonnerre++,
          ),
          child: const Text('Destiny !'),
        ),
      )));
      await tester.tap(find.text('Destiny !'));
      await tester.pump();
      await tester.pump();
      expect(tonnerre, 1);
      await tester.pump(const Duration(milliseconds: 2400));
      // Le premier figé rappelle de fixer le besoin.
      expect(find.text(g.rituel.premierFige), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text(t.t('rituel.texte_ellipse')), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text(g.palier(PalierId.enferme).nom), findsOneWidget);
      expect(find.text('Les issues sont bloquées.'), findsOneWidget);
      expect(find.text('Bloquer'), findsOneWidget);
      await tester.tap(find.text(t.t('rituel.reprendre')));
      await tester.pumpAndSettle();
      expect(find.text('Destiny !'), findsOneWidget);
    });

    testWidgets('animations réduites : on arrive vite au palier', (tester) async {
      await tester.pumpWidget(_scene(Builder(
        builder: (context) => TextButton(
          onPressed: () => lancerRituelDestiny(context,
              nouveauPalier: PalierId.supprime,
              reglages: const ReglagesRituel(reduireAnimations: true, dureeFige: Duration(seconds: 1))),
          child: const Text('Go'),
        ),
      )));
      await tester.tap(find.text('Go'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 2600));
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text(g.palier(PalierId.supprime).nom), findsOneWidget);
    });
  });
}

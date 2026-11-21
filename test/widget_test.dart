import 'package:destiny/application/notes/acces_admin.dart';
import 'package:destiny/application/notes/notes_controller.dart';
import 'package:destiny/application/services/audio_service.dart';
import 'package:destiny/application/services/llm_service.dart';
import 'package:destiny/application/state/ai_settings.dart';
import 'package:destiny/application/state/serie_store.dart';
import 'package:destiny/application/state/chat_controller.dart';
import 'package:destiny/application/state/location_details.dart';
import 'package:destiny/application/state/music_controller.dart';
import 'package:destiny/application/state/reglages_destiny.dart';
import 'package:destiny/application/state/troupe_store.dart';
import 'package:destiny/application/state/relation_cheatsheet.dart';
import 'package:destiny/application/state/spectacle_controller.dart';
import 'package:destiny/application/state/visual_settings.dart';
import 'package:destiny/infrastructure/datasources/cache_notes.dart';
import 'package:destiny/infrastructure/datasources/in_memory_catalog_store.dart';
import 'package:destiny/infrastructure/datasources/in_memory_chat_store.dart';
import 'package:destiny/infrastructure/datasources/local_json_datasource.dart';
import 'package:destiny/infrastructure/platform/coffre_secret.dart';
import 'package:destiny/main.dart';
import 'package:destiny/presentation/notes/notes_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:destiny/presentation/accueil/decouvrir_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'destiny_note_test.dart' show depotInitialise, deriverDirect;
import 'outils/grammaire_partagee.dart';

void main() {
  testWidgets('Destiny app starts', (tester) async {
    await _lancer(tester);
  });

  testWidgets('l\'onglet Notes n\'existe que si l\'accès administrateur est ouvert', (tester) async {
    // Le lecteur audio n'existe pas en test : ses canaux répondent « rien ».
    final messager = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messager.allMessagesHandler = (canal, gestionnaire, message) {
      if (canal.startsWith('xyz.luan/audioplayers')) {
        return Future<ByteData?>.value(const StandardMethodCodec().encodeSuccessEnvelope(null));
      }
      return gestionnaire != null ? gestionnaire(message) : messager.delegate.send(canal, message);
    };
    addTearDown(() => messager.allMessagesHandler = null);
    final depot = (await tester.runAsync(() => depotInitialise('le bon')))!;
    final acces = AccesAdmin(coffre: CoffreMemoire(), fabriqueDepot: (_) => depot, deriver: deriverDirect);
    final notes = NotesController(acces: acces, cache: CacheMemoire());
    final t = await _lancer(tester, acces: acces, notes: notes);
    expect(find.byKey(const ValueKey('onglet_notes')), findsNothing);
    expect(find.text(t.t('navigation.notes')), findsNothing);
    // Un mauvais mot de passe n'ouvre rien.
    await tester.runAsync(() => acces.deverrouiller(token: 'tok', motDePasse: 'le mauvais'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('onglet_notes')), findsNothing);
    // Le bon : l'onglet apparaît, à droite.
    await tester.runAsync(() => acces.deverrouiller(token: 'tok', motDePasse: 'le bon'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('onglet_notes')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('onglet_notes')));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pumpAndSettle();
    expect(find.byType(NotesScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('carte_seance')), findsOneWidget);
    // Verrouillé : l'onglet disparaît, retour sur Troupe.
    await tester.runAsync(acces.verrouiller);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('onglet_notes')), findsNothing);
    expect(find.byType(NotesScreen), findsNothing);
  });
}

Future<dynamic> _lancer(WidgetTester tester, {AccesAdmin? acces, NotesController? notes}) async {
    SharedPreferences.setMockInitialValues({});
    // Le cache des assets garde des chargements lancés par le test d'avant.
    rootBundle.clear();
    final grammaire = (await tester.runAsync(chargerGrammaire))!;
    final dataSource = LocalJsonDataSource();
    final catalogStore = InMemoryCatalogStore(seedSource: dataSource);
    final aiSettings = await AiSettings.load();
    final llmService = LlmService();
    final chatController = ChatController(
      chatStore: InMemoryChatStore(),
      llm: llmService,
      aiSettings: aiSettings,
      catalogue: catalogStore,
      grammaire: grammaire,
    );
    final spectacleController = SpectacleController(
      catalogue: catalogStore,
      grammaire: grammaire,
      llm: llmService,
      aiSettings: aiSettings,
    );

    final reglages = ReglagesDestiny();
    await tester.pumpWidget(
      DestinyApp(
        grammaire: grammaire,
        audioService: AudioService(),
        visualSettings: VisualSettings(),
        musicController: MusicController(),
        catalogStore: catalogStore,
        aiSettings: aiSettings,
        chatController: chatController,
        spectacleController: spectacleController,
        relationCheatsheet: RelationCheatsheet(),
        locationDetails: LocationDetailsStore(),
        serieStore: SerieStore(),
        troupeStore: TroupeStore(),
        reglages: reglages,
        accesAdmin: acces,
        notes: notes,
      ),
    );

    await tester.pumpAndSettle();
    final t = grammaire.textes;
    // Au premier lancement, « Découvrir Destiny » ; on peut le passer.
    expect(find.byType(DecouvrirScreen), findsOneWidget);
    await tester.tap(find.text(t.t('decouvrir.passer')));
    await tester.pumpAndSettle();
    expect(find.byType(DecouvrirScreen), findsNothing);
    expect(reglages.decouverteVue, isTrue);
    // L'appli s'ouvre sur Troupe ; les trois onglets sont là.
    expect(find.text(t.t('navigation.jouer')), findsWidgets);
    expect(find.text(t.t('navigation.troupe')), findsWidgets);
    expect(find.text(t.t('navigation.exercices')), findsWidgets);
    expect(find.text(t.t('troupe.preparer')), findsOneWidget);
    expect(find.text(grammaire.grammaire.promesse), findsWidgets);
    return t;
}

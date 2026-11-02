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
import 'package:destiny/infrastructure/datasources/in_memory_catalog_store.dart';
import 'package:destiny/infrastructure/datasources/in_memory_chat_store.dart';
import 'package:destiny/infrastructure/datasources/local_json_datasource.dart';
import 'package:destiny/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'outils/grammaire_partagee.dart';

void main() {
  testWidgets('Destiny app starts', (tester) async {
    SharedPreferences.setMockInitialValues({});
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
        reglages: ReglagesDestiny(),
      ),
    );

    await tester.pumpAndSettle();
    // L'appli s'ouvre sur Troupe ; les trois onglets sont là.
    final t = grammaire.textes;
    expect(find.text(t.t('navigation.jouer')), findsWidgets);
    expect(find.text(t.t('navigation.troupe')), findsWidgets);
    expect(find.text(t.t('navigation.exercices')), findsWidgets);
    expect(find.text(t.t('troupe.preparer')), findsOneWidget);
    expect(find.text(grammaire.grammaire.promesse), findsWidgets);
  });
}

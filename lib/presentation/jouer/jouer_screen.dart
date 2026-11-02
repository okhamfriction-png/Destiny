import 'package:flutter/material.dart';

import '../../application/services/audio_service.dart';
import '../../application/state/campagne_store.dart';
import '../../application/state/chat_controller.dart';
import '../../application/state/music_controller.dart';
import '../../application/state/spectacle_controller.dart';
import '../../application/state/visual_settings.dart';
import '../destiny/donnees.dart';
import '../destiny/page.dart';
import '../screens/campagne_liste_screen.dart';
import '../screens/chat_screen.dart';
import '../screens/spectacle_screen.dart';
import '../theme/destiny_theme.dart';
import '../widgets/ecran_sombre.dart';

/// L'onglet Jouer : le jeu de rôle, entre humains ou avec l'IA (comme aux
/// échecs : avec quelqu'un, ou contre l'ordinateur).
class JouerScreen extends StatelessWidget {
  const JouerScreen({
    super.key,
    required this.chatController,
    required this.spectacleController,
    required this.campagneStore,
    required this.audioService,
    required this.visualSettings,
    required this.musicController,
  });

  final ChatController chatController;
  final SpectacleController spectacleController;
  final CampagneStore campagneStore;
  final AudioService audioService;
  final VisualSettings visualSettings;
  final MusicController musicController;

  @override
  Widget build(BuildContext context) {
    final g = context.grammaire;
    final t = context.textes;
    final c = context.destiny;
    String j(String k) => t.t('jouer.$k');
    void ouvrir(Widget page) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(j('titre'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium),
              Text(j('sous_titre'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
              SectionDestiny(titre: j('humains.titre'), enfants: [
                Paragraphe(j('humains.sous_titre')),
                for (final (cle, texte) in [
                  ('episode', g.serie.episode),
                  ('saison', g.serie.saison),
                  ('serie', g.serie.serie),
                ])
                  LigneInfo(j('humains.$cle.titre'), texte),
                FilledButton.icon(
                  icon: const Icon(Icons.groups_rounded),
                  onPressed: () => ouvrir(CampagneListeScreen(
                    store: campagneStore,
                    audioService: audioService,
                    musicController: musicController,
                  )),
                  label: Text(j('humains.ouvrir')),
                ),
              ]),
              SectionDestiny(titre: j('ia.titre'), enfants: [
                Paragraphe(j('ia.sous_titre')),
                ElementListe(
                  titre: j('ia.histoire.titre'),
                  sousTitre: '${j('ia.histoire.texte')}\n${j('ia.cle')}',
                  devant: const Icon(Icons.auto_stories_outlined, color: DestinyCouleurs.ia),
                  onTap: () => ouvrir(EcranSombre(
                    child: ChatScreen(
                      controller: chatController,
                      audioService: audioService,
                      visualSettings: visualSettings,
                      musicController: musicController,
                    ),
                  )),
                ),
                ElementListe(
                  titre: j('ia.spectacle.titre'),
                  sousTitre: '${j('ia.spectacle.texte')}\n${j('ia.cle')}',
                  devant: const Icon(Icons.theater_comedy_outlined, color: DestinyCouleurs.ia),
                  onTap: () => ouvrir(EcranSombre(child: SpectacleScreen(controller: spectacleController))),
                ),
              ]),
              const SizedBox(height: 8),
              Text(g.promesse, textAlign: TextAlign.center, style: TextStyle(fontFamily: kPoliceTitres, color: c.titre)),
            ]),
          ),
        ),
      ],
    );
  }
}

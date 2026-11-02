import 'package:flutter/material.dart';

import '../../application/services/audio_service.dart';
import '../../application/state/chat_controller.dart';
import '../../application/state/music_controller.dart';
import '../../application/state/spectacle_controller.dart';
import '../../application/state/visual_settings.dart';
import '../destiny/donnees.dart';
import '../destiny/page.dart';
import '../screens/chat_screen.dart';
import '../screens/spectacle_screen.dart';
import '../serie/contexte_serie.dart';
import '../serie/creer_serie_screen.dart';
import '../serie/fiche_serie_screen.dart';
import '../serie/series_screen.dart';
import '../theme/destiny_theme.dart';

/// L'onglet Jouer : le jeu de rôle, entre humains ou avec l'IA (comme aux
/// échecs : avec quelqu'un, ou contre l'ordinateur).
class JouerScreen extends StatelessWidget {
  const JouerScreen({
    super.key,
    required this.serie,
    required this.chatController,
    required this.spectacleController,
    required this.audioService,
    required this.visualSettings,
    required this.musicController,
  });

  final ContexteSerie serie;
  final ChatController chatController;
  final SpectacleController spectacleController;
  final AudioService audioService;
  final VisualSettings visualSettings;
  final MusicController musicController;

  @override
  Widget build(BuildContext context) {
    final g = context.grammaire;
    final t = context.textes;
    final c = context.destiny;
    String j(String k) => t.t('jouer.$k');
    void ouvrir(Widget page) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SizedBox(height: 4),
              Text(j('titre'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text(j('sous_titre'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: kPoliceTexte, fontSize: 15, color: c.texteSecondaire)),
              SectionDestiny(titre: j('humains.titre'), enfants: [
                Paragraphe(j('humains.sous_titre')),
                ElementListe(
                  titre: t.t('serie.nouvel_episode'),
                  sousTitre: g.serie.episode,
                  devant: const Icon(Icons.movie_creation_outlined, color: DestinyCouleurs.corail),
                  onTap: () => ouvrir(CreerSerieScreen(contexte: serie, saison: false)),
                ),
                ElementListe(
                  titre: t.t('serie.nouvelle_saison'),
                  sousTitre: g.serie.saison,
                  devant: Icon(Icons.video_library_outlined, color: c.or),
                  onTap: () => ouvrir(CreerSerieScreen(contexte: serie, saison: true)),
                ),
                ListenableBuilder(
                  listenable: serie.store,
                  builder: (context, _) {
                    final recentes = serie.store.series.take(2).toList();
                    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      for (final s in recentes)
                        ElementListe(
                          titre: s.nom.isEmpty ? t.t('serie.sans_titre') : s.nom,
                          sousTitre: ouEnEst(context, s),
                          devant: Icon(Icons.play_circle_outline_rounded, color: c.bleuDestiny),
                          onTap: () => ouvrirFiche(context, serie, s.id),
                        ),
                    ]);
                  },
                ),
                const SizedBox(height: 4),
                FilledButton.icon(
                  icon: const Icon(Icons.groups_rounded),
                  onPressed: () => ouvrir(SeriesScreen(contexte: serie)),
                  label: Text(j('humains.ouvrir')),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(g.serie.serie,
                      style: TextStyle(fontFamily: kPoliceTexte, fontSize: 14, height: 1.4, color: c.texteSecondaire)),
                ),
              ]),
              SectionDestiny(titre: j('ia.titre'), enfants: [
                Paragraphe(j('ia.sous_titre')),
                ElementListe(
                  titre: j('ia.histoire.titre'),
                  sousTitre: '${j('ia.histoire.texte')}\n${j('ia.cle')}',
                  devant: const Icon(Icons.auto_stories_outlined, color: DestinyCouleurs.ia),
                  onTap: () => ouvrir(ChatScreen(
                    controller: chatController,
                    audioService: audioService,
                    visualSettings: visualSettings,
                    musicController: musicController,
                    univers: serie.store.catalogue,
                  )),
                ),
                ElementListe(
                  titre: j('ia.spectacle.titre'),
                  sousTitre: '${j('ia.spectacle.texte')}\n${j('ia.cle')}',
                  devant: const Icon(Icons.theater_comedy_outlined, color: DestinyCouleurs.ia),
                  onTap: () => ouvrir(SpectacleScreen(controller: spectacleController, univers: serie.store.catalogue)),
                ),
              ]),
              const SizedBox(height: 20),
              Text(g.promesse,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: kPoliceTitres, fontSize: 17, fontWeight: FontWeight.w700, color: c.titre)),
            ]),
          ),
        ),
      ],
    );
  }
}

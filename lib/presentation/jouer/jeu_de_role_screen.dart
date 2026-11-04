import 'package:flutter/material.dart';

import '../../application/services/audio_service.dart';
import '../../application/state/chat_controller.dart';
import '../../application/state/music_controller.dart';
import '../../application/state/spectacle_controller.dart';
import '../../application/state/visual_settings.dart';
import '../../domain/serie/serie.dart';
import '../destiny/donnees.dart';
import '../destiny/page.dart';
import '../screens/chat_screen.dart';
import '../screens/spectacle_screen.dart';
import '../serie/composants_serie.dart';
import '../serie/contexte_serie.dart';
import '../serie/creer_serie_screen.dart';
import '../serie/fiche_serie_screen.dart';
import '../serie/series_screen.dart';
import '../theme/destiny_theme.dart';

/// Ce qu'il faut pour lancer le jeu de rôle, entre humains ou avec l'IA.
class ContexteJeuDeRole {
  const ContexteJeuDeRole({
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
}

/// Le jeu de rôle dans un mode, adulte ou enfant, choisi en entrant : tout
/// suit ce choix (les séries, les lieux, les dangers, les méchants, les
/// règles et l'IA), sans qu'on le redemande.
class JeuDeRoleScreen extends StatelessWidget {
  const JeuDeRoleScreen({super.key, required this.contexte, required this.public});

  final ContexteJeuDeRole contexte;
  final PublicSerie public;

  bool get _kids => public == PublicSerie.kids;

  @override
  Widget build(BuildContext context) {
    final g = context.grammaire;
    final t = context.textes;
    final c = context.destiny;
    String j(String k) => t.t('jouer.$k');
    final serie = contexte.serie;
    void ouvrir(Widget page) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

    return PageDestiny(
      titre: j('mode.${public.name}.titre'),
      enfants: [
        BandeauMode(public: public),
        SectionDestiny(titre: j('humains.titre'), enfants: [
          Paragraphe(j('humains.sous_titre')),
          ElementListe(
            titre: t.t('serie.nouvel_episode'),
            sousTitre: g.serie.episode,
            devant: const Icon(Icons.movie_creation_outlined, color: DestinyCouleurs.corail),
            onTap: () => ouvrir(CreerSerieScreen(contexte: serie, saison: false, public: public)),
          ),
          ElementListe(
            titre: t.t('serie.nouvelle_saison'),
            sousTitre: g.serie.saison,
            devant: Icon(Icons.video_library_outlined, color: c.or),
            onTap: () => ouvrir(CreerSerieScreen(contexte: serie, saison: true, public: public)),
          ),
          ListenableBuilder(
            listenable: serie.store,
            builder: (context, _) {
              final recentes = [for (final s in serie.store.series) if (s.public == public) s].take(2);
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
            onPressed: () => ouvrir(SeriesScreen(contexte: serie, public: public)),
            label: Text(j('humains.ouvrir')),
          ),
        ]),
        SectionDestiny(titre: j('ia.titre'), enfants: [
          Paragraphe(j('ia.sous_titre')),
          ElementListe(
            titre: j('ia.histoire.titre'),
            sousTitre: '${j('ia.histoire.texte')}\n${j('ia.cle')}',
            devant: const Icon(Icons.auto_stories_outlined, color: DestinyCouleurs.ia),
            onTap: () => ouvrir(ChatScreen(
              controller: contexte.chatController,
              audioService: contexte.audioService,
              visualSettings: contexte.visualSettings,
              musicController: contexte.musicController,
              univers: serie.store.catalogue,
              kids: _kids,
            )),
          ),
          ElementListe(
            titre: j('ia.spectacle.titre'),
            sousTitre: '${j('ia.spectacle.texte')}\n${j('ia.cle')}',
            devant: const Icon(Icons.theater_comedy_outlined, color: DestinyCouleurs.ia),
            onTap: () => ouvrir(SpectacleScreen(
              controller: contexte.spectacleController,
              univers: serie.store.catalogue,
              kids: _kids,
            )),
          ),
        ]),
      ],
    );
  }
}

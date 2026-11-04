import 'package:flutter/material.dart';

import '../../application/services/audio_service.dart';
import '../../application/state/chat_controller.dart';
import '../../application/state/music_controller.dart';
import '../../application/state/spectacle_controller.dart';
import '../../application/state/visual_settings.dart';
import '../../domain/serie/serie.dart';
import '../destiny/composants.dart';
import '../destiny/donnees.dart';
import '../destiny/page.dart';
import '../serie/contexte_serie.dart';
import '../theme/destiny_theme.dart';
import 'jeu_de_role_screen.dart';

/// L'onglet Jouer : le jeu de rôle. On choisit d'abord le mode, adulte ou
/// enfant ; tout le reste suit ce choix ([JeuDeRoleScreen]).
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
    final contexte = ContexteJeuDeRole(
      serie: serie,
      chatController: chatController,
      spectacleController: spectacleController,
      audioService: audioService,
      visualSettings: visualSettings,
      musicController: musicController,
    );
    void entrer(PublicSerie public) => Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => JeuDeRoleScreen(contexte: contexte, public: public)));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              // Le titre « Jouer » est déjà dans la barre du haut.
              const SizedBox(height: 4),
              Text(j('sous_titre'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: kPoliceTexte, fontSize: 15, color: c.texteSecondaire)),
              SectionDestiny(titre: j('mode.titre'), enfants: [
                Paragraphe(j('mode.aide')),
                for (final public in PublicSerie.values)
                  _CarteMode(public: public, onTap: () => entrer(public)),
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

/// Une grande carte de mode : adulte, ou enfant avec le sigle KIDS.
class _CarteMode extends StatelessWidget {
  const _CarteMode({required this.public, required this.onTap});

  final PublicSerie public;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.textes;
    final c = context.destiny;
    final kids = public == PublicSerie.kids;
    final couleur = kids ? c.kidsFond : c.or;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: c.carte,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: couleur, width: 2),
        ),
        child: InkWell(
          key: ValueKey('mode_${public.name}'),
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(children: [
              if (kids)
                const SigleKids()
              else
                PastilleIcone(Icons.theater_comedy_rounded, couleur: couleur, taille: 52),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    t.t('jouer.mode.${public.name}.nom'),
                    style: TextStyle(fontFamily: kPoliceTitres, fontWeight: FontWeight.w700, fontSize: 22, color: c.titre),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    t.t('jouer.mode.${public.name}.texte'),
                    style: TextStyle(fontFamily: kPoliceTexte, fontSize: 14.5, height: 1.35, color: c.texteSecondaire),
                  ),
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

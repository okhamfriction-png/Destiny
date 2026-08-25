import 'package:flutter/material.dart';

import '../../application/services/audio_service.dart';
import '../../application/state/campagne_store.dart';
import '../../application/state/chat_controller.dart';
import '../../application/state/music_controller.dart';
import '../../application/state/visual_settings.dart';
import '../widgets/ecran_sombre.dart';
import '../widgets/mode_card.dart';
import 'campagne_liste_screen.dart';
import 'chat_screen.dart';

const Color _gold = Color(0xFFFFC24B);
const Color _lav = Color(0xFFB9A6FF);

/// Accueil de l'onglet Histoire : deux façons de raconter.
/// - IA : le maître du jeu mené par l'IA (existant, une histoire par choix).
/// - Campagne : des épisodes qui se suivent dans un même monde (à venir).
class HistoireHubScreen extends StatelessWidget {
  const HistoireHubScreen({
    required this.chatController,
    required this.audioService,
    required this.visualSettings,
    required this.musicController,
    required this.campagneStore,
    super.key,
  });

  final ChatController chatController;
  final AudioService audioService;
  final VisualSettings visualSettings;
  final MusicController musicController;
  final CampagneStore campagneStore;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        const Text('Raconter une histoire',
            style: TextStyle(
                color: _gold, fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text('Choisis ton mode.',
            style: TextStyle(color: Colors.white54, fontSize: 14)),
        const SizedBox(height: 18),
        ModeCard(
          icon: Icons.smart_toy,
          color: _lav,
          title: 'IA',
          subtitle:
              'Une histoire interactive menée par l\'IA : elle propose, tu '
              'décides. Une partie par choix. Nécessite une clé IA (Paramètres).',
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => EcranSombre(
              child: ChatScreen(
                controller: chatController,
                audioService: audioService,
                visualSettings: visualSettings,
                musicController: musicController,
              ),
            ),
          )),
        ),
        const SizedBox(height: 12),
        ModeCard(
          icon: Icons.auto_stories,
          color: _gold,
          title: 'Campagne',
          subtitle:
              'Des épisodes qui se suivent dans un même monde, avec un méchant '
              'qui revient : 12 univers, cartes, escalade et chrono. Sans IA.',
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => CampagneListeScreen(
              store: campagneStore,
              audioService: audioService,
              musicController: musicController,
            ),
          )),
        ),
      ],
    );
  }
}

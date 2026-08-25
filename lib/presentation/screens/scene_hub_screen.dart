import 'package:flutter/material.dart';

import '../../application/services/audio_service.dart';
import '../../application/state/spectacle_controller.dart';
import '../widgets/ecran_sombre.dart';
import '../widgets/mode_card.dart';
import 'exercices_screen.dart';
import 'spectacle_screen.dart';

const Color _gold = Color(0xFFFFC24B);
const Color _lav = Color(0xFFB9A6FF);
const Color _teal = Color(0xFF5EE0C4);

/// Accueil de l'onglet Scène : deux façons de jouer.
/// - Spectacle : la partie solo menée par l'IA (existant).
/// - Exercices : échauffements et jeux de théâtre chronométrés.
class SceneHubScreen extends StatelessWidget {
  const SceneHubScreen({
    required this.spectacleController,
    required this.audioService,
    super.key,
  });
  final SpectacleController spectacleController;
  final AudioService audioService;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        const Text('Jouer une scène',
            style: TextStyle(
                color: _gold, fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text('Choisis ton mode de jeu.',
            style: TextStyle(color: Colors.white54, fontSize: 14)),
        const SizedBox(height: 18),
        ModeCard(
          icon: Icons.smart_toy,
          color: _lav,
          title: 'Spectacle (IA)',
          subtitle:
              'Une partie solo menée par une IA : elle joue les partenaires, '
              'le régisseur et le coach. Nécessite une clé IA (Paramètres).',
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) =>
                EcranSombre(child: SpectacleScreen(controller: spectacleController)),
          )),
        ),
        const SizedBox(height: 12),
        ModeCard(
          icon: Icons.sports_gymnastics,
          color: _teal,
          title: 'Exercices',
          subtitle:
              'Échauffements et jeux de théâtre courts, chronométrés, pour '
              'lancer la séance dans le rire. Un principe d\'impro par jour.',
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ExercicesScreen(audioService: audioService),
          )),
        ),
      ],
    );
  }
}

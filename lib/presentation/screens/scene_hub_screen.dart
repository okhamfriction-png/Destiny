import 'package:flutter/material.dart';

import '../../application/services/audio_service.dart';
import '../../application/state/spectacle_controller.dart';
import 'exercices_screen.dart';
import 'spectacle_screen.dart';

const Color _gold = Color(0xFFFFC24B);
const Color _lav = Color(0xFFB9A6FF);
const Color _teal = Color(0xFF5EE0C4);

/// Accueil de l'onglet Scène : trois façons de jouer.
/// - Spectacle : la partie solo menée par l'IA (existant).
/// - Histoire : campagnes d'épisodes à jouer en famille (à venir).
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
        _ModeCard(
          icon: Icons.smart_toy,
          color: _lav,
          title: 'Spectacle (IA)',
          subtitle:
              'Une partie solo menée par une IA : elle joue les partenaires, '
              'le régisseur et le coach. Nécessite une clé IA (Paramètres).',
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) =>
                SpectacleScreen(controller: spectacleController),
          )),
        ),
        const SizedBox(height: 12),
        const _ModeCard(
          icon: Icons.auto_stories,
          color: _gold,
          title: 'Histoire (famille)',
          subtitle:
              'Des campagnes d\'épisodes à jouer en famille : un univers, un '
              'méchant qui revient, des cartes et un chrono. Bientôt disponible.',
          onTap: null,
          badge: 'Bientôt',
        ),
        const SizedBox(height: 12),
        _ModeCard(
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

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.6,
      child: Card(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 54,
                  height: 54,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(title,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800)),
                          if (badge != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(badge!,
                                  style: TextStyle(
                                      color: color,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700)),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(subtitle,
                          style: const TextStyle(
                              color: Colors.white60,
                              fontSize: 14,
                              height: 1.35)),
                    ],
                  ),
                ),
                if (enabled)
                  const Icon(Icons.chevron_right, color: Colors.white38),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

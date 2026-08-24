import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _features = <(IconData, String, String)>[
    (
      Icons.auto_stories,
      'Générateur',
      'Tire un lieu, un danger et distribue archétypes + rôles. Modes Théâtre (tout) et Rue (enjeux visuels immédiats). Visuels Réaliste (images) ou Vectoriel.'
    ),
    (
      Icons.library_music,
      'Musique',
      'Bibliothèque d\'ambiances et d\'émotions, filtrable, avec lecteur intégré.'
    ),
    (
      Icons.chat_bubble,
      'Chat — Maître du jeu',
      'Une IA mène une histoire interactive (lieu + danger + personnages), tu joues par choix, la pièce Brave/Smart tranche. Chaque partie est sauvegardée.'
    ),
    (
      Icons.tune,
      'Paramètres',
      'Édite lieux & dangers, configure l\'IA, gère la base de données, parcours le catalogue.'
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('À propos')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF141029), Color(0xFF0A0818)],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 8),
            Center(
              child: Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFD86B), Color(0xFFB8860B)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.casino, color: Colors.black, size: 44),
              ),
            ),
            const SizedBox(height: 12),
            Text('DestinyStory',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text('Générateur de situations d\'improvisation dramatique',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: Colors.white70)),
            const SizedBox(height: 6),
            Text('Version 1.0.0',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: Colors.white38)),
            const SizedBox(height: 24),
            Text('Fonctionnalités', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            for (final f in _features)
              Card(
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListTile(
                  leading: Icon(f.$1, color: theme.colorScheme.primary),
                  title: Text(f.$2),
                  subtitle: Text(f.$3),
                  isThreeLine: true,
                ),
              ),
            const SizedBox(height: 16),
            Text(
              'Deux modes de jeu, une base de lieux et de dangers entièrement '
              'éditable, des dangers à 4 paliers d\'escalade, et un maître du jeu '
              'IA pour faire vivre l\'histoire.',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }
}

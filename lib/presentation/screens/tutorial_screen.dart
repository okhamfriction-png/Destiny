import 'package:flutter/material.dart';

/// Tutoriel explicatif de l'application (lecture seule).
class TutorialScreen extends StatelessWidget {
  const TutorialScreen({super.key});

  static const _sections = <({IconData icon, String title, String body})>[
    (
      icon: Icons.auto_awesome,
      title: 'Bienvenue dans DestinyStory',
      body: 'DestinyStory aide à improviser des situations dramatiques et à vivre '
          'des histoires guidées par une IA. Voici à quoi servent les 5 onglets '
          'en bas de l\'écran.',
    ),
    (
      icon: Icons.casino,
      title: 'Générateur',
      body: 'Tire au sort une SITUATION : un lieu + un danger (avec un style) '
          'et des rôles. L\'app retient les combinaisons déjà sorties pour ne '
          'pas se répéter avant d\'avoir tout utilisé.',
    ),
    (
      icon: Icons.library_music,
      title: 'Musique',
      body: 'Des ambiances, émotions et thèmes musicaux à lancer en fond '
          'pendant tes scènes.',
    ),
    (
      icon: Icons.chat_bubble,
      title: 'Chat — Maître du jeu (IA)',
      body: 'Le cœur de l\'app : une histoire interactive menée par l\'IA.\n\n'
          '• Touche « Nouvelle histoire ».\n'
          '• Choisis le mode (Adulte / Enfant) et le nombre de joueurs '
          '(Solo / Duo).\n'
          '• Choisis l\'univers, le ton (humour, drame, épique…), puis le ou '
          'les héros : un nom + un archétype animal (révélé en grand avec son).\n'
          '• Règle la longueur de l\'histoire et la narration (« tu » ou 3ᵉ '
          'personne).',
    ),
    (
      icon: Icons.sports_esports,
      title: 'Comment jouer une histoire',
      body: 'À chaque tour, choisis une action BRAVE ou SMART, ou écris ta '
          'propre action. L\'app lance les dés :\n\n'
          '• DONC (vert) = réussite.\n'
          '• MAIS (rouge) = échec, mais l\'histoire rebondit toujours.\n\n'
          'En Duo, les deux héros jouent chacun leur tour. Les actions '
          'proposées collent à la personnalité de l\'archétype.',
    ),
    (
      icon: Icons.bolt,
      title: 'La montée du danger',
      body: 'Régulièrement, le danger monte : un éclair traverse l\'écran avec '
          'le tonnerre. Ta prochaine action devient plus dure (il faut alors '
          '2 réussites). Le danger ne redescend jamais.',
    ),
    (
      icon: Icons.summarize,
      title: 'Tes histoires',
      body: 'Chaque partie est sauvegardée. Depuis la liste, touche l\'icône '
          'résumé pour un récap (en mode Enfant, il commence par « Il était '
          'une fois »), ou la corbeille pour supprimer.',
    ),
    (
      icon: Icons.smart_toy,
      title: 'Activer l\'IA',
      body: 'Le Chat a besoin d\'une clé IA. Va dans Paramètres → Configurer '
          'l\'IA (ou le bouton depuis le Chat) et saisis ton fournisseur + '
          'jeton. Astuce : Google (Gemini) fonctionne aussi dans le navigateur.',
    ),
    (
      icon: Icons.settings,
      title: 'Paramètres utiles',
      body: '• Apparence : taille du texte du Chat.\n'
          '• Gérer lieux & dangers : éditer le contenu.\n'
          '• Catalogue de données : tout parcourir (avec les étapes des '
          'dangers).\n'
          '• Base de données : compteur et réinitialisation.\n'
          '• Le bouton 🔊 en haut à droite coupe/active le son.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Tutoriel')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF141029), Color(0xFF0A0818)],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final s in _sections)
              Card(
                margin: const EdgeInsets.symmetric(vertical: 6),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(s.icon, color: theme.colorScheme.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(s.title,
                                style: theme.textTheme.titleMedium),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(s.body,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(height: 1.45, color: Colors.white70)),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Center(
              child: Text('Amuse-toi bien ! 🎭',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: Colors.white38)),
            ),
          ],
        ),
      ),
    );
  }
}

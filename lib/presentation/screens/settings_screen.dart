import 'package:flutter/material.dart';

import '../../application/state/ai_settings.dart';
import '../../application/state/visual_settings.dart';
import '../../domain/repositories/catalog_store.dart';
import '../../domain/repositories/combination_memory.dart';
import '../../domain/repositories/story_repository.dart';
import 'about_screen.dart';
import 'ai_config_screen.dart';
import 'appearance_screen.dart';
import 'catalog_editor_screen.dart';
import 'catalog_view_screen.dart';
import 'dilemma_editor_screen.dart';
import 'contact_screen.dart';
import 'credits_screen.dart';
import 'database_screen.dart';
import 'tutorial_screen.dart';

/// Menu des paramètres : chaque entrée ouvre un écran dédié.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    required this.repository,
    required this.combinationMemory,
    required this.visualSettings,
    required this.catalogStore,
    required this.aiSettings,
    super.key,
  });

  final StoryRepository repository;
  final CombinationMemory combinationMemory;
  final VisualSettings visualSettings;
  final CatalogStore catalogStore;
  final AiSettings aiSettings;

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF141029), Color(0xFF0A0818)],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            _item(
              context,
              icon: Icons.school,
              title: 'Tutoriel',
              subtitle: 'Comment fonctionne l\'application.',
              onTap: () => _push(context, const TutorialScreen()),
            ),
            _item(
              context,
              icon: Icons.tune,
              title: 'Gérer lieux & dangers',
              subtitle: 'Ajouter, renommer, supprimer, Rue / Théâtre, activer.',
              onTap: () =>
                  _push(context, CatalogEditorScreen(catalogStore: catalogStore)),
            ),
            _item(
              context,
              icon: Icons.balance,
              title: 'Dilemmes par danger',
              subtitle: 'Ajouter, modifier, supprimer des dilemmes (mode Dilemme).',
              onTap: () => _push(
                  context, DilemmaEditorScreen(catalogStore: catalogStore)),
            ),
            _item(
              context,
              icon: Icons.grid_view,
              title: 'Catalogue de données',
              subtitle: 'Parcourir lieux, dangers et archétypes (lecture seule).',
              onTap: () => _push(
                  context,
                  CatalogViewScreen(
                      repository: repository, visualSettings: visualSettings)),
            ),
            _item(
              context,
              icon: Icons.format_size,
              title: 'Apparence',
              subtitle: 'Taille du texte, écriture, visuels des cartes.',
              onTap: () => _push(
                  context, AppearanceScreen(visualSettings: visualSettings)),
            ),
            _item(
              context,
              icon: Icons.smart_toy,
              title: 'Configurer l\'IA',
              subtitle: aiSettings.configured
                  ? '${aiSettings.provider.label} · ${aiSettings.model}'
                  : 'Fournisseur, modèle, jeton API (pour le Chat).',
              onTap: () => _push(context, AiConfigScreen(settings: aiSettings)),
            ),
            _item(
              context,
              icon: Icons.storage,
              title: 'Base de données',
              subtitle: 'Compteur d\'histoires et réinitialisation.',
              onTap: () => _push(
                  context, DatabaseScreen(combinationMemory: combinationMemory)),
            ),
            _item(
              context,
              icon: Icons.alternate_email,
              title: 'Me contacter',
              subtitle: 'Instagram & TikTok — @destinyimpro.',
              onTap: () => _push(context, const ContactScreen()),
            ),
            _item(
              context,
              icon: Icons.favorite_border,
              title: 'Crédits',
              subtitle: 'Sons d\'ambiance (freesound.org, licences CC).',
              onTap: () => _push(context, const CreditsScreen()),
            ),
            _item(
              context,
              icon: Icons.info_outline,
              title: 'À propos',
              subtitle: 'Récapitulatif de l\'application.',
              onTap: () => _push(context, const AboutScreen()),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text('Destiny · v1.0.0',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: Colors.white38)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _item(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: Icon(icon, color: theme.colorScheme.primary),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

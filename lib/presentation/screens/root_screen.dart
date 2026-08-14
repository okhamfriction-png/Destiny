import 'package:flutter/material.dart';

import '../../application/services/audio_service.dart';
import '../../application/services/llm_service.dart';
import '../../application/state/ai_settings.dart';
import '../../application/state/chat_controller.dart';
import '../../application/state/generation_history.dart';
import '../../application/state/music_controller.dart';
import '../../application/state/spectacle_controller.dart';
import '../../application/state/spinoff_history.dart';
import '../../application/state/story_controller.dart';
import '../../application/state/visual_settings.dart';
import '../../domain/repositories/catalog_store.dart';
import '../../domain/repositories/combination_memory.dart';
import '../../domain/repositories/story_repository.dart';
import '../social_links.dart';
import 'catalog_view_screen.dart';
import 'chat_screen.dart';
import 'dice_screen.dart';
import 'generator_screen.dart';
import 'music_screen.dart';
import 'settings_screen.dart';
import 'spectacle_screen.dart';
import 'timer_screen.dart';

/// Shell de navigation : Générateur · Dés · Minuteur · Musique · Chat.
class RootScreen extends StatefulWidget {
  const RootScreen({
    required this.controller,
    required this.audioService,
    required this.visualSettings,
    required this.musicController,
    required this.repository,
    required this.combinationMemory,
    required this.catalogStore,
    required this.aiSettings,
    required this.chatController,
    required this.generationHistory,
    required this.spectacleController,
    required this.llm,
    required this.spinoffHistory,
    super.key,
  });

  final StoryController controller;
  final AudioService audioService;
  final VisualSettings visualSettings;
  final MusicController musicController;
  final StoryRepository repository;
  final CombinationMemory combinationMemory;
  final CatalogStore catalogStore;
  final AiSettings aiSettings;
  final ChatController chatController;
  final GenerationHistory generationHistory;
  final SpectacleController spectacleController;
  final LlmService llm;
  final SpinoffHistory spinoffHistory;

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  int _index = 0;

  void _openCatalog(CatalogTab tab) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CatalogViewScreen(
          repository: widget.repository,
          visualSettings: widget.visualSettings,
          initialTab: tab,
        ),
      ),
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          repository: widget.repository,
          combinationMemory: widget.combinationMemory,
          visualSettings: widget.visualSettings,
          catalogStore: widget.catalogStore,
          aiSettings: widget.aiSettings,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      GeneratorScreen(
        controller: widget.controller,
        visualSettings: widget.visualSettings,
        audioService: widget.audioService,
        history: widget.generationHistory,
        aiSettings: widget.aiSettings,
        llm: widget.llm,
        spinoffHistory: widget.spinoffHistory,
        repository: widget.repository,
      ),
      DiceScreen(
        audioService: widget.audioService,
        visualSettings: widget.visualSettings,
      ),
      TimerScreen(audioService: widget.audioService),
      MusicScreen(controller: widget.musicController),
      ChatScreen(
          controller: widget.chatController,
          audioService: widget.audioService,
          visualSettings: widget.visualSettings,
          musicController: widget.musicController),
      SpectacleScreen(controller: widget.spectacleController),
    ];

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF141029), Color(0xFF0A0818)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Le contenu commence sous la barre d'icônes (réseaux / réglages).
              Padding(
                padding: const EdgeInsets.only(top: 52),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: IndexedStack(
                      index: _index,
                      children: pages,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 4,
                left: 8,
                child: Row(
                  children: [
                    _RoundIcon(
                      icon: instagramIcon,
                      tooltip: 'Instagram @destinyimpro',
                      color: const Color(0xFFE1306C),
                      onPressed: () => openSocial(kInstagramUrl),
                    ),
                    const SizedBox(width: 6),
                    _RoundIcon(
                      icon: tiktokIcon,
                      tooltip: 'TikTok @destinyimpro',
                      color: const Color(0xFF25F4EE),
                      onPressed: () => openSocial(kTiktokUrl),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 4,
                right: 8,
                child: Row(
                  children: [
                    _RoundIcon(
                      icon: Icons.warning_amber_rounded,
                      tooltip: 'Catalogue des dangers',
                      onPressed: () => _openCatalog(CatalogTab.dangers),
                    ),
                    const SizedBox(width: 6),
                    _RoundIcon(
                      icon: Icons.pets,
                      tooltip: 'Catalogue des archétypes',
                      onPressed: () => _openCatalog(CatalogTab.archetypes),
                    ),
                    const SizedBox(width: 6),
                    _RoundIcon(
                      icon: Icons.settings,
                      tooltip: 'Paramètres',
                      onPressed: _openSettings,
                    ),
                    const SizedBox(width: 6),
                    _MuteButton(
                        audioService: widget.audioService,
                        musicController: widget.musicController),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.auto_stories_outlined),
            selectedIcon: Icon(Icons.auto_stories),
            label: 'Générateur',
          ),
          NavigationDestination(
            icon: Icon(Icons.casino_outlined),
            selectedIcon: Icon(Icons.casino),
            label: 'Dés',
          ),
          NavigationDestination(
            icon: Icon(Icons.timer_outlined),
            selectedIcon: Icon(Icons.timer),
            label: 'Minuteur',
          ),
          NavigationDestination(
            icon: Icon(Icons.library_music_outlined),
            selectedIcon: Icon(Icons.library_music),
            label: 'Musique',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Histoire',
          ),
          NavigationDestination(
            icon: Icon(Icons.theater_comedy_outlined),
            selectedIcon: Icon(Icons.theater_comedy),
            label: 'Scène',
          ),
        ],
      ),
    );
  }
}

/// Petit bouton rond discret pour les overlays (paramètres, son).
class _RoundIcon extends StatelessWidget {
  const _RoundIcon({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.color = Colors.white70,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.black.withValues(alpha: 0.35),
        shape: const CircleBorder(),
        child: IconButton(
          icon: Icon(icon),
          color: color,
          iconSize: 20,
          onPressed: onPressed,
        ),
      ),
    );
  }
}

/// Bouton global d'activation/coupure du son (effets ET musique).
class _MuteButton extends StatefulWidget {
  const _MuteButton({required this.audioService, required this.musicController});

  final AudioService audioService;
  final MusicController musicController;

  @override
  State<_MuteButton> createState() => _MuteButtonState();
}

class _MuteButtonState extends State<_MuteButton> {
  @override
  void initState() {
    super.initState();
    // Se met à jour si la musique démarre/s'arrête ailleurs.
    widget.musicController.addListener(_onChange);
  }

  @override
  void dispose() {
    widget.musicController.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // « Son actif » = effets non coupés OU musique en lecture.
    final muted = widget.audioService.muted;
    final musicPlaying = widget.musicController.playing;
    final somethingOn = !muted || musicPlaying;
    return _RoundIcon(
      icon: somethingOn ? Icons.volume_up : Icons.volume_off,
      tooltip: somethingOn ? 'Couper le son' : 'Activer le son',
      onPressed: () {
        setState(() {
          if (somethingOn) {
            // Tout couper : effets + musique.
            widget.audioService.setMuted(true);
            widget.musicController.stop();
          } else {
            widget.audioService.setMuted(false);
          }
        });
      },
    );
  }
}

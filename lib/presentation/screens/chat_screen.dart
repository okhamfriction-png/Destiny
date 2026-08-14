import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../application/services/audio_service.dart';
import '../../application/state/ai_settings.dart';
import '../../application/state/chat_controller.dart';
import '../../application/state/music_controller.dart';
import '../../application/state/visual_settings.dart';
import 'ai_config_screen.dart';
import 'chat_archives_screen.dart';
import '../../domain/entities/archetype.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/chat_story.dart';
import '../visuals/entity_visuals.dart';
import '../widgets/entity_image.dart';

const List<({String name, IconData icon})> _universes = [
  (name: 'Contemporain', icon: Icons.location_city),
  (name: 'Policier', icon: Icons.local_police),
  (name: 'High Fantasy', icon: Icons.castle),
  (name: 'Shonen', icon: Icons.sports_martial_arts),
  (name: 'Science-Fiction', icon: Icons.rocket_launch),
  (name: 'Dark Fantasy', icon: Icons.dark_mode),
  (name: 'Cyberpunk', icon: Icons.memory),
  (name: 'Horreur', icon: Icons.bloodtype),
  (name: 'Post-apocalyptique', icon: Icons.dangerous),
  (name: 'Steampunk', icon: Icons.settings),
  (name: 'Super-héros', icon: Icons.shield),
  (name: 'Historique', icon: Icons.account_balance),
];

/// Univers adaptés aux enfants (façon Disney / manga / contes).
const List<({String name, IconData icon})> _kidUniverses = [
  (name: 'Conte de fées', icon: Icons.auto_stories),
  (name: 'Dessin animé', icon: Icons.movie_filter),
  (name: 'Manga rigolo', icon: Icons.sports_martial_arts),
  (name: 'Animaux qui parlent', icon: Icons.pets),
  (name: 'Super-héros', icon: Icons.shield),
  (name: 'Pirates', icon: Icons.sailing),
  (name: 'Espace rigolo', icon: Icons.rocket_launch),
  (name: 'Monde magique', icon: Icons.auto_fix_high),
  (name: 'Sous la mer', icon: Icons.water),
  (name: 'Chevaliers & dragons', icon: Icons.castle),
];

/// Tons / genres d'histoire proposés.
const List<({String name, IconData icon})> _tones = [
  (name: 'Aventure', icon: Icons.explore),
  (name: 'Humour', icon: Icons.sentiment_very_satisfied),
  (name: 'Drame', icon: Icons.theater_comedy),
  (name: 'Épique', icon: Icons.auto_awesome),
  (name: 'Voyage initiatique', icon: Icons.hiking),
  (name: 'Romance', icon: Icons.favorite),
  (name: 'Mystère', icon: Icons.search),
  (name: 'Action', icon: Icons.bolt),
];

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    required this.controller,
    required this.audioService,
    required this.visualSettings,
    required this.musicController,
    super.key,
  });

  final ChatController controller;
  final AudioService audioService;
  final VisualSettings visualSettings;
  final MusicController musicController;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with TickerProviderStateMixin {
  final ScrollController _scroll = ScrollController();
  final TextEditingController _custom = TextEditingController();

  late final AnimationController _resultAnim;
  late final AnimationController _dangerAnim;
  int _lastPulse = 0;
  int _lastDangerPulse = 0;
  bool _animSuccess = false;

  // Sélection multiple dans la liste des histoires.
  bool _selectMode = false;
  final Set<String> _selected = {};

  // Dernière histoire active (pour lancer/arrêter son thème d'univers).
  String? _themeStoryId;

  // Géométrie précalculée (normalisée) des fissures et de l'éclair.
  late final List<List<Offset>> _cracks;
  late final List<Offset> _bolt;

  @override
  void initState() {
    super.initState();
    _resultAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1150));
    _dangerAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2600));
    _lastPulse = widget.controller.resultPulse;
    _lastDangerPulse = widget.controller.dangerPulse;
    _buildGeometry();
    widget.controller.addListener(_onChange);
    widget.controller.loadList();
  }

  void _buildGeometry() {
    // Fissures : 7 branches en étoile depuis le centre (espace [-1, 1]).
    final rnd = math.Random(42);
    _cracks = List.generate(7, (i) {
      var a = (i / 7) * 2 * math.pi + (rnd.nextDouble() - 0.5) * 0.5;
      final pts = <Offset>[Offset.zero];
      var p = Offset.zero;
      final segs = 4 + rnd.nextInt(3);
      for (var s = 0; s < segs; s++) {
        a += (rnd.nextDouble() - 0.5) * 0.8;
        final len = 0.12 + rnd.nextDouble() * 0.18;
        p = p + Offset(math.cos(a) * len, math.sin(a) * len);
        pts.add(p);
      }
      return pts;
    });
    // Éclair : ligne brisée du haut vers le bas (x, y normalisés 0..1).
    final rnd2 = math.Random(7);
    final bolt = <Offset>[];
    var x = 0.25 + rnd2.nextDouble() * 0.25;
    for (var y = 0.0; y <= 1.0001; y += 0.075) {
      x += (rnd2.nextDouble() - 0.5) * 0.18;
      bolt.add(Offset(x.clamp(0.06, 0.94), y));
    }
    _bolt = bolt;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    _resultAnim.dispose();
    _dangerAnim.dispose();
    _scroll.dispose();
    _custom.dispose();
    super.dispose();
  }

  Future<void> _showSummary(ChatController c, ChatStory s) async {
    final future = c.summarize(s);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.summarize, size: 20),
            const SizedBox(width: 8),
            Expanded(
                child: Text(s.title,
                    style: const TextStyle(fontSize: 16),
                    overflow: TextOverflow.ellipsis)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: FutureBuilder<String>(
            future: future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              return SingleChildScrollView(
                child: Text(snap.data ?? 'Résumé indisponible.',
                    style: const TextStyle(height: 1.5)),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  /// Univers de l'histoire active, extrait du contexte « univers · lieu · danger ».
  String _currentUniverse(ChatController c) {
    final ctx = c.active?.context ?? '';
    return ctx.split('·').first.trim();
  }

  /// Icône correspondant à un univers (sinon masque de théâtre par défaut).
  IconData _universeIcon(String universe) {
    final u = universe.toLowerCase();
    for (final e in [..._universes, ..._kidUniverses]) {
      if (e.name.toLowerCase() == u) return e.icon;
    }
    return Icons.theater_comedy;
  }

  Future<void> _openAiConfig(ChatController c) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AiConfigScreen(settings: c.aiSettings),
      ),
    );
    if (mounted) setState(() {});
  }

  void _sendCustom() {
    final text = _custom.text.trim();
    if (text.isEmpty) return;
    _custom.clear();
    widget.controller.sendCustomAction(text);
  }

  void _onChange() {
    if (!mounted) return;
    final c = widget.controller;
    if (c.resultPulse != _lastPulse) {
      _lastPulse = c.resultPulse;
      _animSuccess = c.lastSuccess;
      _resultAnim.forward(from: 0);
      if (_animSuccess) {
        widget.audioService.playShine();
      } else {
        widget.audioService.playCrack();
      }
    }
    if (c.dangerPulse != _lastDangerPulse) {
      _lastDangerPulse = c.dangerPulse;
      _dangerAnim.forward(from: 0);
      widget.audioService.playThunder();
    }
    // Thème musical de l'univers : démarre à l'ouverture d'une histoire,
    // s'arrête quand on la ferme (mode « jeu vidéo »).
    final active = c.active;
    if (active != null && active.id != _themeStoryId) {
      _themeStoryId = active.id;
      if (!widget.audioService.muted) {
        widget.musicController.playUniverse(_currentUniverse(c));
      }
    } else if (active == null && _themeStoryId != null) {
      _themeStoryId = null;
      widget.musicController.stop();
    }
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _newStory() async {
    final nameCtrls = [TextEditingController(), TextEditingController()];
    String? universe;
    String? tone;
    final chosen = <Archetype?>[null, null];
    var playerCount = 1;
    var directAddress = true;
    var maxResponses = 30;
    var childMode = false;
    final archetypes = widget.controller.archetypes;

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) {
          final theme = Theme.of(context);
          var ready = universe != null && tone != null;
          for (var i = 0; i < playerCount; i++) {
            if (nameCtrls[i].text.trim().isEmpty || chosen[i] == null) {
              ready = false;
            }
          }
          final universes = childMode ? _kidUniverses : _universes;

          Widget label(String t) => Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 8),
                child: Text(t, style: theme.textTheme.titleMedium),
              );

          Widget playerBlock(int i) {
            final a = chosen[i];
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 6),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(playerCount > 1 ? 'Joueur ${i + 1}' : 'Ton héros',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(color: theme.colorScheme.primary)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nameCtrls[i],
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nom du héros',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (_) => setLocal(() {}),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<Archetype>(
                      initialValue: a,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Archétype',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: [
                        for (final ar in archetypes)
                          DropdownMenuItem(
                            value: ar,
                            child: Row(
                              children: [
                                Text(
                                    EntityVisuals.forArchetype(ar).emoji ?? '🎭',
                                    style: const TextStyle(fontSize: 20)),
                                const SizedBox(width: 8),
                                Flexible(
                                    child: Text(ar.name,
                                        overflow: TextOverflow.ellipsis)),
                              ],
                            ),
                          ),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setLocal(() => chosen[i] = v);
                        _revealArchetype(v);
                      },
                    ),
                    if (a != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6, left: 4),
                        child: Text(a.traits,
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: Colors.white54)),
                      ),
                  ],
                ),
              ),
            );
          }

          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.9,
            maxChildSize: 0.95,
            builder: (context, scrollCtrl) => Padding(
              padding: EdgeInsets.fromLTRB(
                  20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Nouvelle histoire', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: SegmentedButton<bool>(
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(value: false, label: Text('Adulte')),
                            ButtonSegment(value: true, label: Text('Enfant')),
                          ],
                          selected: {childMode},
                          onSelectionChanged: (s) => setLocal(() {
                            childMode = s.first;
                            universe = null; // univers différents selon le mode
                          }),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: SegmentedButton<int>(
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(value: 1, label: Text('Solo')),
                            ButtonSegment(value: 2, label: Text('Duo')),
                          ],
                          selected: {playerCount},
                          onSelectionChanged: (s) =>
                              setLocal(() => playerCount = s.first),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: ListView(
                      controller: scrollCtrl,
                      children: [
                        label('Univers'),
                        DropdownButtonFormField<String>(
                          initialValue: universe,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            isDense: true,
                            hintText: 'Choisis un univers',
                          ),
                          items: [
                            for (final u in universes)
                              DropdownMenuItem(
                                value: u.name,
                                child: Row(
                                  children: [
                                    Icon(u.icon,
                                        size: 18,
                                        color: theme.colorScheme.primary),
                                    const SizedBox(width: 8),
                                    Flexible(
                                        child: Text(u.name,
                                            overflow: TextOverflow.ellipsis)),
                                  ],
                                ),
                              ),
                          ],
                          onChanged: (v) => setLocal(() => universe = v),
                        ),
                        label('Ton de l\'histoire'),
                        DropdownButtonFormField<String>(
                          initialValue: tone,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            isDense: true,
                            hintText: 'Choisis un ton',
                          ),
                          items: [
                            for (final t in _tones)
                              DropdownMenuItem(
                                value: t.name,
                                child: Row(
                                  children: [
                                    Icon(t.icon,
                                        size: 18,
                                        color: theme.colorScheme.primary),
                                    const SizedBox(width: 8),
                                    Flexible(
                                        child: Text(t.name,
                                            overflow: TextOverflow.ellipsis)),
                                  ],
                                ),
                              ),
                          ],
                          onChanged: (v) => setLocal(() => tone = v),
                        ),
                        label(playerCount > 1 ? 'Les héros' : 'Héros'),
                        for (var i = 0; i < playerCount; i++) playerBlock(i),
                        label('Narration'),
                        SegmentedButton<bool>(
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(
                                value: true, label: Text('« Tu » (direct)')),
                            ButtonSegment(
                                value: false, label: Text('3ᵉ personne')),
                          ],
                          selected: {directAddress},
                          onSelectionChanged: (s) =>
                              setLocal(() => directAddress = s.first),
                        ),
                        label('Longueur : $maxResponses réponses'),
                        Slider(
                          value: maxResponses.toDouble(),
                          min: 10,
                          max: 100,
                          divisions: 18,
                          label: '$maxResponses',
                          onChanged: (v) =>
                              setLocal(() => maxResponses = v.round()),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed:
                          ready ? () => Navigator.pop(context, true) : null,
                      icon: const Icon(Icons.auto_stories),
                      label: const Text('Lancer l\'histoire'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (ok == true && universe != null && tone != null) {
      final players = <ChatPlayer>[];
      for (var i = 0; i < playerCount; i++) {
        final a = chosen[i];
        if (a == null) continue;
        players.add(ChatPlayer(
          name: nameCtrls[i].text.trim(),
          archetype: a.name,
          traits: a.traits,
          emoji: EntityVisuals.forArchetype(a).emoji,
        ));
      }
      if (players.isEmpty) return;
      await widget.controller.newStory(
        players: players,
        universe: universe!,
        tone: tone!,
        directAddress: directAddress,
        maxResponses: maxResponses,
        childMode: childMode,
      );
    }
  }

  /// Révélation plein écran de l'archétype choisi, avec un son de tambour/foudre.
  Future<void> _revealArchetype(Archetype a) async {
    widget.audioService.playReveal();
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'archetype',
      barrierColor: Colors.black.withValues(alpha: 0.88),
      transitionDuration: const Duration(milliseconds: 420),
      pageBuilder: (_, __, ___) =>
          _ArchetypeReveal(archetype: a, source: widget.visualSettings.source),
      transitionBuilder: (_, anim, __, child) => FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    // Taille du texte + écriture manuscrite (réglées dans Apparence) : Chat seul.
    return ListenableBuilder(
      listenable: widget.visualSettings,
      builder: (context, _) {
        final vs = widget.visualSettings;
        Widget content = MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(vs.textScale),
          ),
          child: c.active == null ? _buildList(c) : _buildSession(c),
        );
        if (!vs.handwritten) return content;
        // Écriture manuscrite : police thème + styles bruts (Text sans famille).
        final base = Theme.of(context);
        content = DefaultTextStyle.merge(
          style: const TextStyle(fontFamily: VisualSettings.handwrittenFamily),
          child: content,
        );
        return Theme(
          data: base.copyWith(
            textTheme: base.textTheme
                .apply(fontFamily: VisualSettings.handwrittenFamily),
          ),
          child: content,
        );
      },
    );
  }

  // --- Liste des histoires ---
  Widget _buildList(ChatController c) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
          children: [
            Text('Chat — Maître du jeu',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium),
            const SizedBox(height: 8),
            if (!c.aiConfigured)
              Card(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.key_off_outlined,
                              size: 20, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text('Aucune clé IA configurée',
                                style: theme.textTheme.titleSmall),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Ajoute un fournisseur + un jeton API pour jouer. '
                        'Google (Gemini) fonctionne aussi dans le navigateur.',
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: () => _openAiConfig(c),
                          icon: const Icon(Icons.settings),
                          label: const Text('Configurer l\'IA'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 4),
            _listToolbar(c, theme),
            const SizedBox(height: 4),
            if (c.activeStories.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('Aucune histoire pour l\'instant.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54)),
              ),
            for (final s in c.activeStories) _storyTile(c, s, theme),
          ],
        ),
        if (!_selectMode)
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.extended(
              onPressed: c.busy ? null : _newStory,
              icon: const Icon(Icons.add),
              label: const Text('Nouvelle histoire'),
            ),
          ),
        if (_selectMode) _selectionBar(c, theme),
        if (c.busy)
          const Positioned.fill(
            child: ColoredBox(
              color: Colors.black54,
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }

  // --- Barre d'outils + tuiles + sélection ---

  Widget _listToolbar(ChatController c, ThemeData theme) {
    final visible = c.activeStories;
    if (_selectMode) {
      final allSelected =
          visible.isNotEmpty && _selected.length == visible.length;
      return Row(
        children: [
          IconButton(
            tooltip: 'Annuler',
            icon: const Icon(Icons.close),
            onPressed: () => setState(() {
              _selectMode = false;
              _selected.clear();
            }),
          ),
          Expanded(
            child: Text('${_selected.length} sélectionnée(s)',
                style: theme.textTheme.titleSmall),
          ),
          TextButton.icon(
            icon: Icon(allSelected ? Icons.deselect : Icons.select_all),
            label: Text(allSelected ? 'Aucun' : 'Tout'),
            onPressed: () => setState(() {
              if (allSelected) {
                _selected.clear();
              } else {
                _selected
                  ..clear()
                  ..addAll(visible.map((s) => s.id));
              }
            }),
          ),
        ],
      );
    }
    return Row(
      children: [
        TextButton.icon(
          icon: const Icon(Icons.checklist),
          label: const Text('Sélectionner'),
          onPressed: visible.isEmpty
              ? null
              : () => setState(() {
                    _selectMode = true;
                    _selected
                      ..clear()
                      ..addAll(visible.map((s) => s.id)); // « tout » par défaut
                  }),
        ),
        const Spacer(),
        TextButton.icon(
          icon: const Icon(Icons.archive_outlined),
          label: Text('Archives (${c.archivedStories.length})'),
          onPressed: _openArchives,
        ),
      ],
    );
  }

  Widget _storyTile(ChatController c, ChatStory s, ThemeData theme) {
    final selected = _selected.contains(s.id);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: selected ? theme.colorScheme.primary.withValues(alpha: 0.18) : null,
      child: ListTile(
        leading: _selectMode
            ? Checkbox(
                value: selected,
                onChanged: (_) => _toggleSelect(s.id),
              )
            : Icon(Icons.menu_book, color: theme.colorScheme.primary),
        title: Text(s.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: _selectMode
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Résumé',
                    icon: const Icon(Icons.summarize),
                    onPressed: () => _showSummary(c, s),
                  ),
                  IconButton(
                    tooltip: 'Archiver',
                    icon: const Icon(Icons.archive_outlined),
                    onPressed: () => c.setArchived(s.id, true),
                  ),
                  IconButton(
                    tooltip: 'Supprimer',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => c.deleteStory(s.id),
                  ),
                ],
              ),
        onTap: _selectMode ? () => _toggleSelect(s.id) : () => c.openStory(s),
      ),
    );
  }

  void _toggleSelect(String id) => setState(() {
        if (!_selected.add(id)) _selected.remove(id);
      });

  Widget _selectionBar(ChatController c, ThemeData theme) {
    final n = _selected.length;
    return Positioned(
      left: 12,
      right: 12,
      bottom: 16,
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(16),
        color: theme.colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: n == 0
                      ? null
                      : () async {
                          await c.archiveMany(_selected.toList(), true);
                          setState(() {
                            _selectMode = false;
                            _selected.clear();
                          });
                        },
                  icon: const Icon(Icons.archive),
                  label: Text('Archiver ($n)'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    foregroundColor: const Color(0xFFFF6B6B),
                  ),
                  onPressed: n == 0 ? null : () => _confirmDeleteMany(c),
                  icon: const Icon(Icons.delete_outline),
                  label: Text('Supprimer ($n)'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteMany(ChatController c) async {
    final n = _selected.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer ?'),
        content: Text('Supprimer définitivement $n histoire(s) ?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok != true) return;
    await c.deleteMany(_selected.toList());
    setState(() {
      _selectMode = false;
      _selected.clear();
    });
  }

  Future<void> _openArchives() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatArchivesScreen(controller: widget.controller),
      ),
    );
    if (mounted) setState(() {});
  }

  // --- Session de jeu ---
  Widget _buildSession(ChatController c) {
    final theme = Theme.of(context);
    return Stack(
      children: [
        Column(
          children: [
            Row(
              children: [
                IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: c.closeStory),
                Expanded(
                  child: Text(c.active!.title,
                      style: theme.textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            Expanded(
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                children: [
                  for (final m in c.visibleMessages)
                    _bubble(m, theme, _universeIcon(_currentUniverse(c))),
                  if (c.busy)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('Le maître du jeu écrit…',
                          style: TextStyle(
                              color: Colors.white54,
                              fontStyle: FontStyle.italic)),
                    ),
                  if (c.error != null)
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(c.error!,
                          style: const TextStyle(color: Colors.redAccent)),
                    ),
                ],
              ),
            ),
            _choices(c, theme),
          ],
        ),
        _resultOverlay(),
        _dangerOverlay(),
      ],
    );
  }

  /// Réussite → illumination « façon Hearthstone ». Échec → écran fissuré.
  Widget _resultOverlay() {
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _resultAnim,
          builder: (context, _) {
            final t = _resultAnim.value;
            if (t <= 0.0 || t >= 1.0) return const SizedBox.shrink();
            return _animSuccess ? _successFx(t) : _failFx(t);
          },
        ),
      ),
    );
  }

  /// Illumination verte : flash radial, onde de choc, badge ✓.
  Widget _successFx(double t) {
    const color = Color(0xFF2ECC71);
    const glow = Color(0xFF38EF7D);
    final scale = Curves.elasticOut.transform((t / 0.5).clamp(0.0, 1.0));
    double op;
    if (t < 0.08) {
      op = t / 0.08;
    } else if (t < 0.72) {
      op = 1;
    } else {
      op = (1 - (t - 0.72) / 0.26).clamp(0.0, 1.0);
    }
    final flash =
        t < 0.18 ? t / 0.18 : (1 - (t - 0.18) / 0.42).clamp(0.0, 1.0);
    final ringT = (t / 0.6).clamp(0.0, 1.0);
    final ringScale = 0.3 + ringT * 2.2;
    final ringOp = (1 - ringT) * 0.7;

    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                radius: 0.9,
                colors: [
                  color.withValues(alpha: 0.32 * flash),
                  color.withValues(alpha: 0.06 * flash),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.55, 1.0],
              ),
            ),
          ),
        ),
        Transform.scale(
          scale: ringScale,
          child: Opacity(
            opacity: ringOp,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: glow, width: 4),
              ),
            ),
          ),
        ),
        Opacity(
          opacity: op,
          child: Transform.scale(
            scale: scale,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 128,
                  height: 128,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(colors: [glow, color]),
                    boxShadow: [
                      BoxShadow(
                        color: glow.withValues(alpha: 0.75),
                        blurRadius: 40,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.check_rounded,
                      color: Colors.white, size: 78),
                ),
                const SizedBox(height: 14),
                const Text(
                  'RÉUSSITE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3,
                    shadows: [
                      Shadow(color: glow, blurRadius: 24),
                      Shadow(color: Colors.black, blurRadius: 6),
                    ],
                  ),
                ),
                _rollSubtitle(true),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Sous-titre du résultat : détail des dés (et tension du danger).
  Widget _rollSubtitle(bool success) {
    final c = widget.controller;
    final dice = c.lastRolls.length;
    if (dice == 0) return const SizedBox.shrink();
    final heads = c.lastRolls.where((h) => h).length;
    final parts = <String>['🎲 $heads/$dice'];
    if (c.lastRequired >= 2) parts.add('Tension ×2');

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text(
        parts.join('   ·   '),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w700,
          shadows: [Shadow(color: Colors.black, blurRadius: 6)],
        ),
      ),
    );
  }

  /// Échec : l'écran se fissure (secousse + fractures lumineuses) + badge ✗.
  Widget _failFx(double t) {
    // Modes enfant : on reformule l'échec en encouragement (« COURAGE » + cœur),
    // dans une couleur chaude plutôt que rouge alarmant.
    final narration = widget.controller.aiSettings.narration;
    final kid = narration == NarrationStyle.petit ||
        narration == NarrationStyle.child;
    final main = kid ? const Color(0xFFFF8A3D) : const Color(0xFFFF3B3B);
    final light = kid ? const Color(0xFFFFB27A) : const Color(0xFFFF6B6B);
    final word = kid ? 'COURAGE' : 'ÉCHEC';
    final iconData = kid ? Icons.favorite : Icons.close_rounded;
    // Secousse rapide qui s'amortit.
    final shake =
        math.sin(t * math.pi * 14) * 9 * (1 - t).clamp(0.0, 1.0);
    // Flash bref.
    final flash =
        t < 0.12 ? t / 0.12 : (1 - (t - 0.12) / 0.3).clamp(0.0, 1.0);
    // Badge ✗.
    final scale = Curves.elasticOut.transform((t / 0.5).clamp(0.0, 1.0));
    double op;
    if (t < 0.08) {
      op = t / 0.08;
    } else if (t < 0.7) {
      op = 1;
    } else {
      op = (1 - (t - 0.7) / 0.28).clamp(0.0, 1.0);
    }

    return Transform.translate(
      offset: Offset(shake, shake * 0.4),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: ColoredBox(color: main.withValues(alpha: 0.18 * flash)),
          ),
          Positioned.fill(
            child: CustomPaint(painter: _CrackPainter(_cracks, t)),
          ),
          Opacity(
            opacity: op,
            child: Transform.scale(
              scale: scale,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [light, main]),
                      boxShadow: [
                        BoxShadow(
                          color: main.withValues(alpha: 0.7),
                          blurRadius: 36,
                          spreadRadius: 6,
                        ),
                      ],
                    ),
                    child: Icon(iconData, color: Colors.white, size: 72),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    word,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3,
                      shadows: [
                        Shadow(color: main, blurRadius: 24),
                        const Shadow(color: Colors.black, blurRadius: 6),
                      ],
                    ),
                  ),
                  _rollSubtitle(false),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Montée du danger : événement plein écran — voile d'orage, éclairs qui
  /// traversent l'écran, gros titre « ORAGE » couleur foudre, et mise en
  /// évidence du malus (2 réussites requises). Prend son temps.
  Widget _dangerOverlay() {
    const thunder = Color(0xFF8FD3FF); // bleu foudre
    const stormDeep = Color(0xFF0A0E2A);
    return Positioned.fill(
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _dangerAnim,
          builder: (context, _) {
            final t = _dangerAnim.value;
            if (t <= 0.0 || t >= 1.0) return const SizedBox.shrink();

            // Voile d'orage qui s'installe puis se dissipe.
            double veil;
            if (t < 0.12) {
              veil = t / 0.12;
            } else if (t < 0.8) {
              veil = 1;
            } else {
              veil = (1 - (t - 0.8) / 0.2).clamp(0.0, 1.0);
            }

            // Deux salves d'éclairs (début et milieu) — chacune avec flash.
            final phase1 = (t / 0.22).clamp(0.0, 1.0);
            final phase2 = ((t - 0.42) / 0.22).clamp(0.0, 1.0);
            final boltT = phase2 > 0 && phase2 < 1 ? phase2 : phase1;
            double flashOf(double p) =>
                p <= 0 || p >= 1 ? 0.0 : (p < 0.18 ? p / 0.18 : (1 - (p - 0.18) / 0.5).clamp(0.0, 1.0));
            final flash = (flashOf(phase1) + flashOf(phase2)).clamp(0.0, 1.0);

            // Apparition du texte (après le 1er éclair), maintien, sortie.
            double textOp;
            if (t < 0.2) {
              textOp = 0;
            } else if (t < 0.32) {
              textOp = (t - 0.2) / 0.12;
            } else if (t < 0.82) {
              textOp = 1;
            } else {
              textOp = (1 - (t - 0.82) / 0.18).clamp(0.0, 1.0);
            }
            final textScale = 0.85 + 0.15 * Curves.easeOut.transform(
                ((t - 0.2) / 0.18).clamp(0.0, 1.0));

            return Stack(
              children: [
                // Voile d'orage sombre.
                Positioned.fill(
                  child: ColoredBox(
                      color: stormDeep.withValues(alpha: 0.55 * veil)),
                ),
                // Flash bleuté des éclairs.
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          thunder.withValues(alpha: 0.5 * flash),
                          const Color(0xFF6AA7FF).withValues(alpha: 0.12 * flash),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                // Éclairs.
                Positioned.fill(
                  child: CustomPaint(painter: _LightningPainter(_bolt, boltT)),
                ),
                // Bloc texte central : ORAGE + malus.
                Center(
                  child: Opacity(
                    opacity: textOp,
                    child: Transform.scale(
                      scale: textScale,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.bolt,
                              color: thunder,
                              size: 64,
                              shadows: [
                                Shadow(color: thunder, blurRadius: 30),
                                Shadow(color: Colors.black, blurRadius: 8),
                              ]),
                          const SizedBox(height: 4),
                          const Text(
                            'LE DANGER MONTE',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 38,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 4,
                              shadows: [
                                Shadow(color: thunder, blurRadius: 28),
                                Shadow(color: Colors.black, blurRadius: 8),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF9800)
                                  .withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                  color: const Color(0xFFFF9800), width: 2),
                              boxShadow: const [
                                BoxShadow(
                                    color: Color(0x66FF9800), blurRadius: 22),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.warning_amber_rounded,
                                    color: Color(0xFFFFB74D), size: 24),
                                SizedBox(width: 10),
                                Text(
                                  'MALUS · 2 RÉUSSITES REQUISES',
                                  style: TextStyle(
                                    color: Color(0xFFFFB74D),
                                    fontSize: 17,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _bubble(ChatMessage m, ThemeData theme, IconData gmIcon) {
    final isUser = m.isUser;
    if (isUser) {
      final success = m.result == 'success';
      final fail = m.result == 'fail';
      const green = Color(0xFF2ECC71);
      const red = Color(0xFFFF4D4D);
      final bg = success
          ? green.withValues(alpha: 0.22)
          : fail
              ? red.withValues(alpha: 0.22)
              : theme.colorScheme.primary.withValues(alpha: 0.22);
      final border = success
          ? green.withValues(alpha: 0.55)
          : fail
              ? red.withValues(alpha: 0.55)
              : Colors.white.withValues(alpha: 0.08);
      final brave = m.kind == 'brave';
      final smart = m.kind == 'smart';
      final iconData = brave
          ? Icons.bolt
          : smart
              ? Icons.theater_comedy
              : Icons.edit;
      final iconColor = brave
          ? const Color(0xFFF57C00)
          : smart
              ? const Color(0xFF7E3FF2)
              : Colors.white70;
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(12),
          constraints: const BoxConstraints(maxWidth: 460),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (m.actor != null) ...[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(m.actorEmoji ?? '🎭',
                        style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 4),
                    Text(m.actor!,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.primary)),
                  ],
                ),
                const SizedBox(height: 4),
              ],
              Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (m.result != null) ...[
                    Icon(iconData, color: iconColor, size: 18),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(m.display ?? m.content,
                        style: const TextStyle(height: 1.4)),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }
    // Bulle du Maître du jeu, avec DONC/MAIS mis en valeur.
    final text = ChatController.displayContent(m.content);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.25),
            child: Icon(gmIcon, size: 17, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: _gmRich(text),
            ),
          ),
        ],
      ),
    );
  }

  /// Rend la narration ligne par ligne, avec une bannière « ⚡ DANGER ».
  Widget _gmRich(String text) {
    final lines = text.split('\n');
    final children = <Widget>[];
    final dangerRe = RegExp(r'^[⚡⚠️]*\s*DANGER\s*[:\-–]?\s*', caseSensitive: false);
    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      final isDanger = line.startsWith('⚡') || dangerRe.hasMatch(line);
      if (isDanger) {
        final body = line
            .replaceFirst('⚡', '')
            .replaceFirst(dangerRe, '')
            .trim();
        const orange = Color(0xFFFF9800);
        children.add(Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: orange.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: orange.withValues(alpha: 0.55)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.bolt, color: orange, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(body, style: const TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ));
      } else {
        children.add(Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: _gmText(line),
        ));
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }

  /// Met DONC en vert et MAIS en rouge, en majuscules et en gras.
  Widget _gmText(String text) {
    final spans = <TextSpan>[];
    final re = RegExp(r'\b(donc|mais)\b', caseSensitive: false);
    var last = 0;
    for (final m in re.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start)));
      }
      final word = m.group(0)!.toUpperCase();
      spans.add(TextSpan(
        text: word,
        style: TextStyle(
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
          color: word == 'DONC'
              ? const Color(0xFF38EF7D)
              : const Color(0xFFFF4D4D),
        ),
      ));
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return Text.rich(
      TextSpan(children: spans),
      style: const TextStyle(height: 1.5, color: Colors.white),
    );
  }

  Widget _choices(ChatController c, ThemeData theme) {
    if (c.busy) return const SizedBox.shrink();
    if (c.choices.isEmpty) {
      if (c.error == null) {
        return Padding(
          padding: const EdgeInsets.all(12),
          child: Text('— Fin de l\'histoire —',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelLarge
                  ?.copyWith(color: theme.colorScheme.primary)),
        );
      }
      return const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _turnIndicator(c, theme),
          _statusRow(c, theme),
          for (final choice in c.choices) _choiceButton(c, choice),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _custom,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendCustom(),
                  decoration: const InputDecoration(
                    hintText: 'Ou écris ta propre action…',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton.filled(
                icon: const Icon(Icons.send),
                onPressed: _sendCustom,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Indique le héros dont c'est le tour (mis en avant surtout en duo).
  Widget _turnIndicator(ChatController c, ThemeData theme) {
    final actor = c.currentActor;
    if (actor == null) return const SizedBox.shrink();
    final duo = c.isDuo;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(actor.emoji ?? '🎭', style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 6),
          Text(
            duo ? 'À toi, ${actor.name}' : actor.name,
            style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w800,
                fontSize: 14),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text('· ${actor.archetype}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  /// Rappel compact du malus tant que le danger reste « monté ».
  Widget _statusRow(ChatController c, ThemeData theme) {
    if (!c.malusPending) return const SizedBox.shrink();
    const orange = Color(0xFFFF9800);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: orange.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: orange.withValues(alpha: 0.7)),
          boxShadow: [BoxShadow(color: orange.withValues(alpha: 0.3), blurRadius: 10)],
        ),
        child: const Row(
          children: [
            Icon(Icons.bolt, color: orange, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text('DANGER ACCRU — ta prochaine action exige 2 réussites',
                  style: TextStyle(
                      color: Color(0xFFFFB74D),
                      fontSize: 13,
                      fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _choiceButton(ChatController c, String choice) {
    final up = choice.toUpperCase();
    final brave = up.contains('[BRAVE]');
    final smart = up.contains('[SMART]');
    final label = choice
        .replaceAll(RegExp(r'\[BRAVE\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\[SMART\]', caseSensitive: false), '')
        .trim();
    final color = brave
        ? const Color(0xFFF57C00)
        : smart
            ? const Color(0xFF7E3FF2)
            : Colors.white70;
    final icon = brave
        ? Icons.bolt
        : smart
            ? Icons.theater_comedy
            : Icons.chevron_right;
    final tag = brave ? 'BRAVE' : (smart ? 'SMART' : '');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: color, width: 1.5),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          ),
          onPressed: () => c.sendChoice(choice),
          child: Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 10),
              if (tag.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(tag,
                      style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w800,
                          fontSize: 12)),
                ),
              Expanded(
                child: Text(label,
                    style: const TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Révélation plein écran d'un archétype : image du catalogue + nom (auto-ferme).
class _ArchetypeReveal extends StatefulWidget {
  const _ArchetypeReveal({required this.archetype, required this.source});

  final Archetype archetype;
  final VisualSource source;

  @override
  State<_ArchetypeReveal> createState() => _ArchetypeRevealState();
}

class _ArchetypeRevealState extends State<_ArchetypeReveal> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1900), () {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.archetype;
    final color = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).maybePop(),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Image telle qu'elle apparaît dans le catalogue d'images.
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 50),
                ],
              ),
              child: EntityImage(
                visual: EntityVisuals.forArchetype(a),
                source: widget.source,
                size: 240,
                radius: 28,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              a.name,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.w900,
                shadows: [
                  Shadow(color: color, blurRadius: 28),
                  const Shadow(color: Colors.black, blurRadius: 8),
                ],
              ),
            ),
            if (a.temperament.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(a.temperament,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 16)),
            ],
            if (a.port.isNotEmpty)
              // « Port » = entrée en scène → italique.
              Text(a.port,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white60,
                      fontStyle: FontStyle.italic,
                      fontSize: 15)),
            if (a.moteur.isNotEmpty) ...[
              const SizedBox(height: 8),
              // « Moteur » = objectif → gras, couleur d'accent.
              Text(a.moteur,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      letterSpacing: 0.5)),
            ],
          ],
        ),
      ),
    );
  }
}

/// Dessine des fissures lumineuses qui partent du centre (effet d'échec).
class _CrackPainter extends CustomPainter {
  _CrackPainter(this.cracks, this.t);

  final List<List<Offset>> cracks;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * 0.5, size.height * 0.42);
    final scale = size.longestSide * 0.55;
    final reveal = (t / 0.35).clamp(0.0, 1.0);
    final fade = t < 0.65 ? 1.0 : (1 - (t - 0.65) / 0.35).clamp(0.0, 1.0);
    if (fade <= 0) return;

    final glow = Paint()
      ..color = const Color(0xFFFF5A5A).withValues(alpha: 0.5 * fade)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    final core = Paint()
      ..color = Colors.white.withValues(alpha: 0.9 * fade)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    for (final crack in cracks) {
      // Longueur totale de la fissure.
      var total = 0.0;
      for (var i = 1; i < crack.length; i++) {
        total += (crack[i] - crack[i - 1]).distance;
      }
      final budget = total * reveal;
      final path = Path()..moveTo(center.dx, center.dy);
      var used = 0.0;
      var prev = center;
      for (var i = 1; i < crack.length; i++) {
        final seg = (crack[i] - crack[i - 1]) * scale;
        final segLen = seg.distance;
        if (used + segLen <= budget) {
          final p = prev + seg;
          path.lineTo(p.dx, p.dy);
          prev = p;
          used += segLen;
        } else {
          final remain = (budget - used).clamp(0.0, segLen);
          if (remain > 0) {
            final p = prev + seg * (remain / segLen);
            path.lineTo(p.dx, p.dy);
          }
          break;
        }
      }
      canvas.drawPath(path, glow);
      canvas.drawPath(path, core);
    }
  }

  @override
  bool shouldRepaint(_CrackPainter old) => old.t != t;
}

/// Dessine un éclair qui traverse l'écran (montée du danger).
class _LightningPainter extends CustomPainter {
  _LightningPainter(this.bolt, this.t);

  final List<Offset> bolt;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final reveal = (t / 0.12).clamp(0.0, 1.0);
    final fade = (1 - t / 0.6).clamp(0.0, 1.0);
    if (fade <= 0) return;
    final flick = ((t * 16).floor() % 2 == 0) ? 1.0 : 0.45;
    final op = fade * flick;

    final count = (bolt.length * reveal).ceil().clamp(2, bolt.length);
    final path = Path()
      ..moveTo(bolt[0].dx * size.width, bolt[0].dy * size.height);
    for (var i = 1; i < count; i++) {
      path.lineTo(bolt[i].dx * size.width, bolt[i].dy * size.height);
    }

    final glow = Paint()
      ..color = const Color(0xFF8FD3FF).withValues(alpha: 0.6 * op)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    final core = Paint()
      ..color = Colors.white.withValues(alpha: op)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, glow);
    canvas.drawPath(path, core);
  }

  @override
  bool shouldRepaint(_LightningPainter old) => old.t != t;
}

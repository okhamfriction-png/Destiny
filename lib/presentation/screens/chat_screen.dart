import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../application/services/audio_service.dart';
import '../../application/state/ai_settings.dart';
import '../../application/state/chat_controller.dart';
import '../../application/state/music_controller.dart';
import '../../application/state/visual_settings.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/chat_story.dart';
import '../../domain/grammaire/modeles.dart';
import '../../domain/serie/univers.dart';
import '../destiny/cartes.dart';
import '../destiny/composants.dart';
import '../destiny/donnees.dart';
import '../destiny/page.dart';
import '../jouer/univers_ia.dart';
import '../theme/destiny_theme.dart';
import 'ai_config_screen.dart';
import 'chat_archives_screen.dart';

/// Les accents des deux sortes d'actions proposées par l'IA.
const Color _brave = Color(0xFFF57C00);
const Color _smart = Color(0xFF7E3FF2);

/// L'orange du danger (bannière ⚡ et rappel de la pièce plus dure).
const Color _orangeDanger = Color(0xFFFF9800);

/// Une couleur d'accent rendue lisible comme texte : éclaircie en sombre,
/// assombrie en clair (contraste d'au moins 4,5).
Color _lisible(DestinyCouleurs d, Color accent) =>
    d.sombre ? Color.lerp(accent, Colors.white, 0.45)! : Color.lerp(accent, d.encre, 0.5)!;

/// Ce qu'on peut faire d'une histoire de la liste.
enum _ActionHistoire { resume, archiver, supprimer }

/// Une histoire avec l'IA : la liste des histoires, la création d'une
/// nouvelle histoire, puis la partie (le maître du destin raconte, le joueur
/// choisit, la pièce du destin tranche, Destiny entre deux chapitres).
class ChatScreen extends StatefulWidget {
  const ChatScreen({
    required this.controller,
    required this.audioService,
    required this.visualSettings,
    required this.musicController,
    this.univers = CatalogueUnivers.vide,
    super.key,
  });

  final ChatController controller;
  final AudioService audioService;
  final VisualSettings visualSettings;
  final MusicController musicController;

  /// Les univers de `univers.json`.
  final CatalogueUnivers univers;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
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

  /// Raccourci vers les textes de l'écran.
  String k(String x, [Map<String, String> v = const {}]) => context.textes.t('histoire_ia.$x', v);

  @override
  void initState() {
    super.initState();
    _resultAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 1150));
    _dangerAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));
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
    final indisponible = k('resume_indisponible');
    final fermer = k('fermer');
    await showDialog<void>(
      context: context,
      builder: (context) {
        final d = context.destiny;
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.summarize, size: 20, color: d.titre),
              const SizedBox(width: 8),
              Expanded(
                child: Text(s.title,
                    style: TextStyle(fontFamily: kPoliceTexte, fontSize: 16, color: d.titre),
                    overflow: TextOverflow.ellipsis),
              ),
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
                  child: Text(snap.data ?? indisponible, style: TextStyle(height: 1.5, color: d.texte)),
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(fermer)),
          ],
        );
      },
    );
  }

  /// Univers d'une histoire, extrait du contexte « univers · lieu · danger ».
  String _universeOf(ChatStory? s) => (s?.context ?? '').split('·').first.trim();

  /// Univers de l'histoire active.
  String _currentUniverse(ChatController c) => _universeOf(c.active);

  /// Icône correspondant à un univers (sinon masque de théâtre par défaut).
  IconData _universeIcon(String universe) {
    final u = universe.toLowerCase();
    for (final e in [
      ...universPourIa(widget.univers, kids: false),
      ...universPourIa(widget.univers, kids: true),
    ]) {
      if (e.name.toLowerCase() == u) return e.icon;
    }
    return Icons.theater_comedy;
  }

  Future<void> _openAiConfig(ChatController c) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => AiConfigScreen(settings: c.aiSettings)),
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
    final archetypesChoisis = <String?>[null, null];
    final animauxChoisis = <String?>[null, null];
    final blessures = [TextEditingController(), TextEditingController()];
    final vouloirs = [TextEditingController(), TextEditingController()];
    var playerCount = 1;
    var directAddress = true;
    var maxResponses = 30;
    var childMode = false;
    var malus = false;
    final g = context.grammaire;
    final t = context.textes;
    final tons = tonsPourIa(t);

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) {
          final theme = Theme.of(context);
          final d = context.destiny;
          var ready = universe != null && tone != null;
          for (var i = 0; i < playerCount; i++) {
            if (nameCtrls[i].text.trim().isEmpty || archetypesChoisis[i] == null || animauxChoisis[i] == null) {
              ready = false;
            }
          }
          final universes = universPourIa(widget.univers, kids: childMode);

          Widget choixAvecIcone(IconData icone, String nom) => Row(
                children: [
                  Icon(icone, size: 18, color: d.titre),
                  const SizedBox(width: 8),
                  Flexible(child: Text(nom, overflow: TextOverflow.ellipsis)),
                ],
              );

          Widget playerBlock(int i) {
            final a = g.archetype(archetypesChoisis[i] ?? '');
            return CadreLisere(
              couleur: a == null ? d.or : d.famille(a.famille),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (playerCount > 1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(k('creer.joueur', {'n': '${i + 1}'}),
                          style: TextStyle(
                              fontFamily: kPoliceTexte, fontWeight: FontWeight.w700, fontSize: 16, color: d.titre)),
                    ),
                  TextField(
                    controller: nameCtrls[i],
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(labelText: k('creer.nom'), isDense: true),
                    onChanged: (_) => setLocal(() {}),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: archetypesChoisis[i],
                    isExpanded: true,
                    decoration: InputDecoration(labelText: k('creer.archetype'), isDense: true),
                    items: [
                      for (final ar in g.archetypes)
                        DropdownMenuItem(
                          value: ar.id,
                          child: Row(children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(shape: BoxShape.circle, color: d.famille(ar.famille)),
                            ),
                            const SizedBox(width: 8),
                            Flexible(child: Text(ar.nom, overflow: TextOverflow.ellipsis)),
                          ]),
                        ),
                    ],
                    onChanged: (v) => setLocal(() {
                      archetypesChoisis[i] = v;
                      animauxChoisis[i] = null;
                    }),
                  ),
                  if (a != null) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 6, left: 4),
                      child: Text(a.ceQuIlFait,
                          style: TextStyle(fontFamily: kPoliceTexte, fontSize: 12.5, color: d.texteSecondaire)),
                    ),
                    const SizedBox(height: 8),
                    Wrap(spacing: 8, runSpacing: 4, children: [
                      for (final an in g.animauxDe(a.id))
                        ChoiceChip(
                          avatar: Text(kEmojiAnimal[an.id] ?? ''),
                          label: Text(an.nom),
                          selected: animauxChoisis[i] == an.id,
                          selectedColor: d.famille(a.famille).withValues(alpha: d.sombre ? 0.35 : 0.2),
                          showCheckmark: false,
                          onSelected: (_) {
                            setLocal(() => animauxChoisis[i] = an.id);
                            _revealArchetype(an.id, kids: childMode);
                          },
                        ),
                    ]),
                  ],
                  const SizedBox(height: 10),
                  TextField(
                    controller: blessures[i],
                    decoration: InputDecoration(
                      labelText: childMode ? t.t('mode_enfant.mots.blessure') : k('creer.blessure'),
                      helperText: g.personnage.couches.length > 2 ? k('creer.blessure_aide') : null,
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: vouloirs[i],
                    decoration: InputDecoration(labelText: k('creer.vouloir'), isDense: true),
                  ),
                ],
              ),
            );
          }

          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.9,
            maxChildSize: 0.95,
            builder: (context, scrollCtrl) => Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(k('creer.titre'), textAlign: TextAlign.center, style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: SegmentedButton<bool>(
                          showSelectedIcon: false,
                          segments: [
                            ButtonSegment(value: false, label: Text(k('creer.adulte'))),
                            ButtonSegment(value: true, label: Text(k('creer.enfant'))),
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
                          segments: [
                            ButtonSegment(value: 1, label: Text(k('creer.solo'))),
                            ButtonSegment(value: 2, label: Text(k('creer.duo'))),
                          ],
                          selected: {playerCount},
                          onSelectionChanged: (s) => setLocal(() => playerCount = s.first),
                        ),
                      ),
                    ],
                  ),
                  if (childMode) const Padding(padding: EdgeInsets.only(top: 8), child: Center(child: SigleKids())),
                  const SizedBox(height: 4),
                  Expanded(
                    child: ListView(
                      controller: scrollCtrl,
                      children: [
                        SectionDestiny(titre: k('creer.univers'), enfants: [
                          DropdownButtonFormField<String>(
                            initialValue: universe,
                            isExpanded: true,
                            decoration: InputDecoration(isDense: true, hintText: k('creer.univers_aide')),
                            items: [
                              for (final u in universes)
                                DropdownMenuItem(value: u.name, child: choixAvecIcone(u.icon, u.name)),
                            ],
                            onChanged: (v) => setLocal(() => universe = v),
                          ),
                        ]),
                        SectionDestiny(titre: k('creer.ton'), enfants: [
                          DropdownButtonFormField<String>(
                            initialValue: tone,
                            isExpanded: true,
                            decoration: InputDecoration(isDense: true, hintText: k('creer.ton_aide')),
                            items: [
                              for (final x in tons) DropdownMenuItem(value: x.name, child: choixAvecIcone(x.icon, x.name)),
                            ],
                            onChanged: (v) => setLocal(() => tone = v),
                          ),
                        ]),
                        SectionDestiny(
                          titre: playerCount > 1 ? k('creer.les_heros') : k('creer.heros'),
                          enfants: [for (var i = 0; i < playerCount; i++) playerBlock(i)],
                        ),
                        SectionDestiny(titre: k('creer.narration'), enfants: [
                          SegmentedButton<bool>(
                            showSelectedIcon: false,
                            segments: [
                              ButtonSegment(value: true, label: Text(k('creer.tu'))),
                              ButtonSegment(value: false, label: Text(k('creer.il'))),
                            ],
                            selected: {directAddress},
                            onSelectionChanged: (s) => setLocal(() => directAddress = s.first),
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(k('creer.plus_dure')),
                            subtitle: Text(k('creer.plus_dure_aide')),
                            value: malus,
                            onChanged: (v) => setLocal(() => malus = v),
                          ),
                        ]),
                        SectionDestiny(titre: k('creer.longueur'), enfants: [
                          Paragraphe(k('creer.longueur_texte', {'n': '$maxResponses'})),
                          Slider(
                            value: maxResponses.toDouble(),
                            min: 10,
                            max: 100,
                            divisions: 18,
                            label: '$maxResponses',
                            onChanged: (v) => setLocal(() => maxResponses = v.round()),
                          ),
                        ]),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: ready ? () => Navigator.pop(context, true) : null,
                    icon: const Icon(Icons.auto_stories),
                    label: Text(k('creer.lancer')),
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
        final a = g.archetype(archetypesChoisis[i] ?? '');
        final animal = animauxChoisis[i];
        if (a == null || animal == null) continue;
        players.add(ChatPlayer(
          name: nameCtrls[i].text.trim(),
          archetypeId: a.id,
          animalId: animal,
          archetype: a.nom,
          blessure: blessures[i].text.trim(),
          vouloir: vouloirs[i].text.trim(),
          emoji: kEmojiAnimal[animal],
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
        malus: malus,
      );
    }
  }

  /// Révélation plein écran de l'archétype choisi, avec un son de tambour/foudre.
  Future<void> _revealArchetype(String animalId, {required bool kids}) async {
    widget.audioService.playReveal();
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: k('creer.fermer_carte'),
      barrierColor: Colors.black.withValues(alpha: 0.88),
      transitionDuration: const Duration(milliseconds: 420),
      pageBuilder: (_, __, ___) => _ArchetypeReveal(animalId: animalId, kids: kids, source: widget.visualSettings.source),
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
    final t = context.textes;
    // Taille du texte + écriture manuscrite (réglées dans Apparence) : le
    // contenu de l'histoire seulement.
    return ListenableBuilder(
      listenable: widget.visualSettings,
      builder: (context, _) {
        final vs = widget.visualSettings;
        Widget content = MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(vs.textScale)),
          child: c.active == null ? _buildList(c) : _buildSession(c),
        );
        if (vs.handwritten) {
          // Écriture manuscrite : police thème + styles bruts (Text sans famille).
          final base = Theme.of(context);
          content = Theme(
            data: base.copyWith(textTheme: base.textTheme.apply(fontFamily: VisualSettings.handwrittenFamily)),
            child: DefaultTextStyle.merge(
              style: const TextStyle(fontFamily: VisualSettings.handwrittenFamily),
              child: content,
            ),
          );
        }
        final active = c.active;
        return Scaffold(
          appBar: AppBar(
            leading: active == null
                ? null
                : IconButton(
                    tooltip: t.t('accessibilite.retour'),
                    icon: const Icon(Icons.arrow_back),
                    onPressed: c.closeStory,
                  ),
            title: Text(active?.title ?? k('titre'), overflow: TextOverflow.ellipsis),
          ),
          body: SafeArea(top: false, child: content),
        );
      },
    );
  }

  // --- Liste des histoires ---
  Widget _buildList(ChatController c) {
    final d = context.destiny;
    final t = context.textes;
    Widget centre(Widget w) => Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 760), child: w));
    return Stack(
      children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            for (final w in [
              Paragraphe(k('intro')),
              if (!c.aiConfigured)
                CadreLisere(
                  couleur: DestinyCouleurs.ia,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.key_off_outlined, size: 20, color: DestinyCouleurs.ia),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(k('sans_cle.titre'),
                                style: TextStyle(fontSize: 16, fontFamily: kPoliceTexte, fontWeight: FontWeight.w700, color: d.texte)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Paragraphe(k('sans_cle.texte')),
                      FilledButton.icon(
                        onPressed: () => _openAiConfig(c),
                        icon: const Icon(Icons.settings),
                        label: Text(k('sans_cle.configurer')),
                      ),
                    ],
                  ),
                ),
              if (c.error != null) Paragraphe(c.error!, gras: true),
              _listToolbar(c),
              SectionDestiny(titre: k('mes_histoires'), espace: 8, enfants: [
                if (c.activeStories.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(k('aucune'),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontFamily: kPoliceTexte, fontStyle: FontStyle.italic, color: d.texteSecondaire)),
                  ),
                for (final s in c.activeStories) _storyTile(c, s),
              ]),
            ])
              centre(w),
          ],
        ),
        if (!_selectMode)
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.extended(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              onPressed: c.busy ? null : _newStory,
              icon: const Icon(Icons.add),
              label: Text(k('nouvelle')),
            ),
          ),
        if (_selectMode) _selectionBar(c),
        if (c.busy)
          Positioned.fill(
            child: Semantics(
              label: t.t('ia_jeu.en_cours'),
              child: ColoredBox(
                color: d.fond.withValues(alpha: 0.75),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
          ),
      ],
    );
  }

  // --- Barre d'outils + tuiles + sélection ---

  Widget _listToolbar(ChatController c) {
    final visible = c.activeStories;
    if (_selectMode) {
      final allSelected = visible.isNotEmpty && _selected.length == visible.length;
      return Row(
        children: [
          IconButton(
            tooltip: k('annuler'),
            icon: const Icon(Icons.close),
            onPressed: () => setState(() {
              _selectMode = false;
              _selected.clear();
            }),
          ),
          Expanded(
            child: Text(k('selection', {'n': '${_selected.length}'}), style: Theme.of(context).textTheme.titleSmall),
          ),
          TextButton.icon(
            icon: Icon(allSelected ? Icons.deselect : Icons.select_all),
            label: Text(allSelected ? k('aucun') : k('tout')),
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
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      children: [
        TextButton.icon(
          icon: const Icon(Icons.checklist),
          label: Text(k('selectionner')),
          onPressed: visible.isEmpty
              ? null
              : () => setState(() {
                    _selectMode = true;
                    _selected
                      ..clear()
                      ..addAll(visible.map((s) => s.id)); // « tout » par défaut
                  }),
        ),
        TextButton.icon(
          icon: const Icon(Icons.archive_outlined),
          label: Text(k('archives', {'n': '${c.archivedStories.length}'})),
          onPressed: _openArchives,
        ),
      ],
    );
  }

  Widget _storyTile(ChatController c, ChatStory s) {
    final d = context.destiny;
    final selected = _selected.contains(s.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? d.or.withValues(alpha: d.sombre ? 0.22 : 0.14) : d.carte,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: selected ? d.titre : d.filet),
        ),
        child: ListTile(
          leading: _selectMode
              ? Checkbox(value: selected, onChanged: (_) => _toggleSelect(s.id))
              : Icon(_universeIcon(_universeOf(s)), color: d.titre),
          title: Text(
            s.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontFamily: kPoliceTexte, fontWeight: FontWeight.w700, fontSize: 16, color: d.texte),
          ),
          subtitle: s.context.isEmpty
              ? null
              : Text(s.context,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: kPoliceTexte, fontSize: 12.5, color: d.texteSecondaire)),
          trailing: _selectMode
              ? null
              : PopupMenuButton<_ActionHistoire>(
                  tooltip: k('actions'),
                  icon: Icon(Icons.more_vert, color: d.texteSecondaire),
                  onSelected: (a) {
                    switch (a) {
                      case _ActionHistoire.resume:
                        _showSummary(c, s);
                      case _ActionHistoire.archiver:
                        c.setArchived(s.id, true);
                      case _ActionHistoire.supprimer:
                        c.deleteStory(s.id);
                    }
                  },
                  itemBuilder: (_) => [
                    for (final (a, icone, libelle) in [
                      (_ActionHistoire.resume, Icons.summarize, k('resume')),
                      (_ActionHistoire.archiver, Icons.archive_outlined, k('archiver')),
                      (_ActionHistoire.supprimer, Icons.delete_outline, k('supprimer')),
                    ])
                      PopupMenuItem(
                        value: a,
                        child: Row(children: [
                          Icon(icone, size: 20, color: d.titre),
                          const SizedBox(width: 12),
                          Text(libelle),
                        ]),
                      ),
                  ],
                ),
          onTap: _selectMode ? () => _toggleSelect(s.id) : () => c.openStory(s),
        ),
      ),
    );
  }

  void _toggleSelect(String id) => setState(() {
        if (!_selected.add(id)) _selected.remove(id);
      });

  Widget _selectionBar(ChatController c) {
    final d = context.destiny;
    final n = _selected.length;
    return Positioned(
      left: 12,
      right: 12,
      bottom: 16,
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(16),
        color: d.carte,
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
                  label: Text(k('archiver_n', {'n': '$n'})),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(foregroundColor: _lisible(d, d.famille(FamilleId.fissure))),
                  onPressed: n == 0 ? null : () => _confirmDeleteMany(c),
                  icon: const Icon(Icons.delete_outline),
                  label: Text(k('supprimer_n', {'n': '$n'})),
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
        title: Text(k('supprimer_titre')),
        content: Text(k('supprimer_texte', {'n': '$n'})),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(k('annuler'))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(k('supprimer'))),
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
      MaterialPageRoute<void>(builder: (_) => ChatArchivesScreen(controller: widget.controller)),
    );
    if (mounted) setState(() {});
  }

  // --- Session de jeu ---
  Widget _buildSession(ChatController c) {
    final d = context.destiny;
    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                children: [
                  for (final m in c.visibleMessages) _bubble(m, _universeIcon(_currentUniverse(c))),
                  if (c.busy)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(k('jeu.ecrit'),
                          style: TextStyle(color: d.texteSecondaire, fontStyle: FontStyle.italic)),
                    ),
                  if (c.error != null)
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(c.error!,
                          style: TextStyle(color: _lisible(d, d.famille(FamilleId.fissure)), fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
            ),
            _choices(c),
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

  /// Le mot du résultat, en blanc sur une pastille pleine : lisible sur les
  /// deux thèmes.
  Widget _resultBadge(String word, Color couleur, {required bool success}) {
    final fond = Color.lerp(couleur, Colors.black, 0.4)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
      decoration: BoxDecoration(
        color: fond,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: couleur.withValues(alpha: 0.6), blurRadius: 24)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            word,
            style: const TextStyle(
              fontFamily: kPoliceTitres,
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
            ),
          ),
          _rollSubtitle(success),
        ],
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
    final flash = t < 0.18 ? t / 0.18 : (1 - (t - 0.18) / 0.42).clamp(0.0, 1.0);
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
                      BoxShadow(color: glow.withValues(alpha: 0.75), blurRadius: 40, spreadRadius: 8),
                    ],
                  ),
                  child: const Icon(Icons.check_rounded, color: Colors.white, size: 78),
                ),
                const SizedBox(height: 14),
                _resultBadge(k('jeu.reussite'), color, success: true),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Sous-titre du résultat : les lancers de la pièce (et l'option « plus dure »).
  Widget _rollSubtitle(bool success) {
    final c = widget.controller;
    final lancers = c.lastRolls.length;
    if (lancers == 0) return const SizedBox.shrink();
    final reussites = c.lastRolls.where((h) => h).length;
    final parts = <String>[k('jeu.piece', {'reussites': '$reussites', 'lancers': '$lancers'})];
    if (c.lastRequired >= 2) parts.add(k('jeu.tension'));

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        parts.join('   ·   '),
        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
      ),
    );
  }

  /// Échec : l'écran se fissure (secousse + fractures lumineuses) + badge ✗.
  Widget _failFx(double t) {
    // Modes enfant : on reformule l'échec en encouragement (« COURAGE » + cœur),
    // dans une couleur chaude plutôt que rouge alarmant.
    final narration = widget.controller.aiSettings.narration;
    final kid = narration == NarrationStyle.petit || narration == NarrationStyle.child;
    final main = kid ? const Color(0xFFFF8A3D) : const Color(0xFFFF3B3B);
    final light = kid ? const Color(0xFFFFB27A) : const Color(0xFFFF6B6B);
    final word = kid ? k('jeu.courage') : k('jeu.echec');
    final iconData = kid ? Icons.favorite : Icons.close_rounded;
    // Secousse rapide qui s'amortit.
    final shake = math.sin(t * math.pi * 14) * 9 * (1 - t).clamp(0.0, 1.0);
    // Flash bref.
    final flash = t < 0.12 ? t / 0.12 : (1 - (t - 0.12) / 0.3).clamp(0.0, 1.0);
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
                        BoxShadow(color: main.withValues(alpha: 0.7), blurRadius: 36, spreadRadius: 6),
                      ],
                    ),
                    child: Icon(iconData, color: Colors.white, size: 72),
                  ),
                  const SizedBox(height: 14),
                  _resultBadge(word, main, success: false),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Montée du danger (Destiny entre deux chapitres) : événement plein écran
  /// — voile d'orage, éclairs qui traversent l'écran, gros titre couleur
  /// foudre, et le rappel de la pièce plus dure quand l'option est prise.
  /// Le voile reste sombre sur les deux thèmes : c'est un orage.
  Widget _dangerOverlay() {
    const thunder = Color(0xFF8FD3FF); // bleu foudre
    const stormDeep = Color(0xFF0A0E2A);
    final d = context.destiny;
    final voile = d.sombre ? 0.55 : 0.72;
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
            final textScale = 0.85 + 0.15 * Curves.easeOut.transform(((t - 0.2) / 0.18).clamp(0.0, 1.0));

            return Stack(
              children: [
                // Voile d'orage sombre.
                Positioned.fill(
                  child: ColoredBox(color: stormDeep.withValues(alpha: voile * veil)),
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
                // Bloc texte central : le danger monte, et la pièce plus dure.
                Center(
                  child: Opacity(
                    opacity: textOp,
                    child: Transform.scale(
                      scale: textScale,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.bolt, color: thunder, size: 64, shadows: [
                              Shadow(color: thunder, blurRadius: 30),
                              Shadow(color: Colors.black, blurRadius: 8),
                            ]),
                            const SizedBox(height: 4),
                            Text(
                              k('jeu.danger_monte'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: kPoliceTitres,
                                color: Colors.white,
                                fontSize: 34,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 3,
                                shadows: [
                                  Shadow(color: thunder, blurRadius: 28),
                                  Shadow(color: Colors.black, blurRadius: 8),
                                ],
                              ),
                            ),
                            if (widget.controller.malusPending) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                decoration: BoxDecoration(
                                  // Plein et sombre : le texte orangé reste lisible sur les deux thèmes.
                                  color: Color.lerp(_orangeDanger, Colors.black, 0.72)!.withValues(alpha: 0.92),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: _orangeDanger, width: 2),
                                  boxShadow: const [BoxShadow(color: Color(0x66FF9800), blurRadius: 22)],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.warning_amber_rounded, color: Color(0xFFFFB74D), size: 24),
                                    const SizedBox(width: 10),
                                    Flexible(
                                      child: Text(
                                        k('jeu.malus'),
                                        style: const TextStyle(
                                          color: Color(0xFFFFB74D),
                                          fontSize: 17,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
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

  Widget _bubble(ChatMessage m, IconData gmIcon) {
    final d = context.destiny;
    if (m.isUser) {
      final success = m.result == 'success';
      final fail = m.result == 'fail';
      final vert = d.famille(FamilleId.tient);
      final rouge = d.famille(FamilleId.fissure);
      final teinte = d.sombre ? 0.22 : 0.12;
      final bg = success
          ? vert.withValues(alpha: teinte)
          : fail
              ? rouge.withValues(alpha: teinte)
              : d.or.withValues(alpha: teinte);
      final border = success
          ? vert.withValues(alpha: 0.6)
          : fail
              ? rouge.withValues(alpha: 0.6)
              : d.filet;
      final brave = m.kind == 'brave';
      final smart = m.kind == 'smart';
      final iconData = brave
          ? Icons.bolt
          : smart
              ? Icons.theater_comedy
              : Icons.edit;
      final iconColor = brave
          ? _brave
          : smart
              ? _smart
              : d.texteSecondaire;
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
                    Text(m.actorEmoji ?? '🎭', style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 4),
                    Text(m.actor!, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: d.titre)),
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
                    child: Text(m.display ?? m.content, style: TextStyle(height: 1.4, color: d.texte)),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }
    // Bulle du maître du destin, avec DONC/MAIS mis en valeur.
    final text = ChatController.displayContent(m.content);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 15,
            backgroundColor: d.or.withValues(alpha: d.sombre ? 0.25 : 0.18),
            child: Icon(gmIcon, size: 17, color: d.titre),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: d.carte,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: d.filet),
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
    final d = context.destiny;
    final lines = text.split('\n');
    final children = <Widget>[];
    final dangerRe = RegExp(r'^[⚡⚠️]*\s*DANGER\s*[:\-–]?\s*', caseSensitive: false);
    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      final isDanger = line.startsWith('⚡') || dangerRe.hasMatch(line);
      if (isDanger) {
        final body = line.replaceFirst('⚡', '').replaceFirst(dangerRe, '').trim();
        children.add(Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: _orangeDanger.withValues(alpha: d.sombre ? 0.22 : 0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _orangeDanger.withValues(alpha: 0.6)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.bolt, color: _orangeDanger, size: 18),
              const SizedBox(width: 6),
              Expanded(child: Text(body, style: TextStyle(color: d.texte, fontWeight: FontWeight.w600))),
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
    final d = context.destiny;
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
          color: _lisible(d, d.famille(word == 'DONC' ? FamilleId.tient : FamilleId.fissure)),
        ),
      ));
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return Text.rich(
      TextSpan(children: spans),
      style: TextStyle(height: 1.5, color: d.texte),
    );
  }

  Widget _choices(ChatController c) {
    final d = context.destiny;
    final t = context.textes;
    if (c.busy) return const SizedBox.shrink();
    final finStyle = TextStyle(fontSize: 16, fontFamily: kPoliceTexte, fontWeight: FontWeight.w700, color: d.titre);
    if (c.lectureSeule) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: Text(t.t('jouer.ia.ancienne'), textAlign: TextAlign.center, style: finStyle),
      );
    }
    if (c.choices.isEmpty) {
      if (c.error == null) {
        return Padding(
          padding: const EdgeInsets.all(12),
          child: Text(k('jeu.fin'), textAlign: TextAlign.center, style: finStyle),
        );
      }
      return const SizedBox.shrink();
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      decoration: BoxDecoration(
        color: d.carte,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(top: BorderSide(color: d.filet)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _turnIndicator(c),
          _statusRow(c),
          for (final choice in c.choices) _choiceButton(c, choice),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _custom,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendCustom(),
                  decoration: InputDecoration(hintText: k('jeu.action_libre'), isDense: true),
                ),
              ),
              const SizedBox(width: 6),
              IconButton.filled(
                tooltip: t.t('accessibilite.envoyer'),
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
  Widget _turnIndicator(ChatController c) {
    final d = context.destiny;
    final actor = c.currentActor;
    if (actor == null) return const SizedBox.shrink();
    final duo = c.isDuo;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(actor.emoji ?? '🎭', style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              duo ? k('jeu.a_toi', {'nom': actor.name}) : actor.name,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: d.titre, fontWeight: FontWeight.w800, fontSize: 14),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text('· ${actor.archetype}',
                overflow: TextOverflow.ellipsis, style: TextStyle(color: d.texteSecondaire, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  /// Rappel compact de la pièce plus dure, tant que le danger reste « monté ».
  Widget _statusRow(ChatController c) {
    if (!c.malusPending) return const SizedBox.shrink();
    final d = context.destiny;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: _orangeDanger.withValues(alpha: d.sombre ? 0.18 : 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _orangeDanger.withValues(alpha: 0.7)),
        ),
        child: Row(
          children: [
            const Icon(Icons.bolt, color: _orangeDanger, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(k('jeu.plus_dure'),
                  style: TextStyle(color: _lisible(d, _orangeDanger), fontSize: 13, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _choiceButton(ChatController c, String choice) {
    final d = context.destiny;
    // Les étiquettes [BRAVE] et [SMART] viennent de l'IA : on les lit ici,
    // seul le libellé affiché vient des textes.
    final up = choice.toUpperCase();
    final brave = up.contains('[BRAVE]');
    final smart = up.contains('[SMART]');
    final label = choice
        .replaceAll(RegExp(r'\[BRAVE\]', caseSensitive: false), '')
        .replaceAll(RegExp(r'\[SMART\]', caseSensitive: false), '')
        .trim();
    final color = brave
        ? _brave
        : smart
            ? _smart
            : d.texteSecondaire;
    final icon = brave
        ? Icons.bolt
        : smart
            ? Icons.theater_comedy
            : Icons.chevron_right;
    final tag = brave ? k('jeu.brave') : (smart ? k('jeu.smart') : '');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: color, width: 1.5),
            backgroundColor: color.withValues(alpha: d.sombre ? 0.08 : 0.05),
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
                      style: TextStyle(color: _lisible(d, color), fontWeight: FontWeight.w800, fontSize: 12)),
                ),
              Expanded(
                child: Text(label, style: TextStyle(color: d.texte, fontWeight: FontWeight.w500)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Révélation plein écran de la carte de l'animal choisi (auto-ferme).
class _ArchetypeReveal extends StatefulWidget {
  const _ArchetypeReveal({required this.animalId, required this.kids, required this.source});

  final String animalId;
  final bool kids;
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
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).maybePop(),
      child: Center(
        child: widget.kids
            ? CarteArchetype.kids(widget.animalId, source: widget.source)
            : CarteArchetype.animal(widget.animalId, source: widget.source),
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
    final path = Path()..moveTo(bolt[0].dx * size.width, bolt[0].dy * size.height);
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

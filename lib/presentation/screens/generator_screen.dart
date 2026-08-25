import 'package:flutter/material.dart';

import '../../application/services/audio_service.dart';
import '../../application/services/llm_service.dart';
import '../../application/services/spectacle_prompt.dart';
import '../../application/state/ai_settings.dart';
import '../../application/state/generation_history.dart';
import '../../application/state/guide_content.dart';
import '../../application/state/location_details.dart';
import '../../application/state/music_controller.dart';
import '../../application/state/spinoff_history.dart';
import '../../application/state/story_controller.dart';
import '../../application/state/tracking_store.dart';
import '../../application/state/story_state.dart';
import '../../application/state/visual_settings.dart';
import '../../domain/entities/archetype.dart';
import '../../domain/entities/chat_message.dart';
import '../../domain/entities/danger.dart';
import '../../domain/entities/dilemma.dart';
import '../../domain/entities/location.dart';
import '../../domain/entities/player_assignment.dart';
import '../../domain/entities/spectacle_turn.dart';
import '../../domain/entities/story.dart';
import '../../domain/repositories/story_repository.dart';
import '../widgets/dilemma_result_card.dart';
import '../widgets/film_poster.dart';
import '../widgets/rue_result_card.dart';
import '../widgets/spinoff_lottery.dart';
import '../widgets/story_result_card.dart';
import 'generation_history_screen.dart';
import 'spinoff_history_screen.dart';
import 'top_countdown_screen.dart';

/// Décennies et genres pour le spin-off du Générateur.
const List<String> _genDecades = [
  'années 1970',
  'années 1980',
  'années 1990',
  'années 2000',
  'années 2010',
  'années 2020',
];
const List<String> _genGenres = [
  'Action',
  'Aventure',
  'Comédie',
  'Drame',
  'Horreur',
  'Science-Fiction',
  'Fantastique',
  'Thriller',
  'Policier',
  'Guerre',
  'Animation',
  'Romance',
];

/// Contenu de l'onglet « Générateur » (sans Scaffold : il est fourni par
/// le shell de navigation).
class GeneratorScreen extends StatefulWidget {
  const GeneratorScreen({
    required this.controller,
    required this.visualSettings,
    required this.audioService,
    required this.history,
    required this.aiSettings,
    required this.llm,
    required this.spinoffHistory,
    required this.repository,
    required this.guideContent,
    required this.trackingStore,
    required this.locationDetails,
    required this.musicController,
    super.key,
  });

  final StoryController controller;
  final VisualSettings visualSettings;
  final AudioService audioService;
  final GenerationHistory history;
  final AiSettings aiSettings;
  final LlmService llm;
  final SpinoffHistory spinoffHistory;
  final StoryRepository repository;
  final GuideContent guideContent;
  final TrackingStore trackingStore;
  final LocationDetailsStore locationDetails;
  final MusicController musicController;

  @override
  State<GeneratorScreen> createState() => _GeneratorScreenState();
}

class _GeneratorScreenState extends State<GeneratorScreen> {
  // État du spin-off (film).
  FilmContext? _film;
  bool _spinLoading = false;
  String? _spinError;
  String _decade = 'années 1990';
  String _genre = 'Action';

  // Noms du catalogue pour le dé du DESTINY (mode Histoire).
  List<String> _dangerNames = const [];
  List<String> _archetypeNames = const [];
  // Catalogue complet des archétypes (pour modifier un héros avant le chrono).
  List<Archetype> _archetypes = const [];

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onStateChanged);
    widget.visualSettings.addListener(_onStateChanged);
    // L'onglet Dilemme a été retiré : si la dernière scène restaurée était un
    // dilemme, on repasse en Histoire pour éviter une sélection orpheline.
    if (widget.controller.state.mode == GeneratorMode.dilemme) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.controller.setMode(GeneratorMode.histoire);
      });
    }
    // Minimum 3 joueurs (pour garantir un haut + un bas + un neutre) : on
    // remonte un état restauré à 2.
    if (widget.controller.state.playerCount < 3) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.controller.updatePlayerCount(3);
      });
    }
    _loadCatalogNames();
  }

  Future<void> _loadCatalogNames() async {
    try {
      final d = await widget.repository.getDangers();
      final a = await widget.repository.getArchetypes();
      if (!mounted) return;
      setState(() {
        _dangerNames = [for (final x in d) x.name];
        _archetypeNames = [for (final x in a) x.name];
        _archetypes = a;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onStateChanged);
    widget.visualSettings.removeListener(_onStateChanged);
    super.dispose();
  }

  void _onStateChanged() {
    if (mounted) setState(() {});
  }

  void _generate() {
    widget.audioService.playReveal();
    widget.controller.generateStory();
  }

  Future<void> _generateSpinoff() async {
    if (!widget.aiSettings.configured) {
      setState(() =>
          _spinError = 'Configure l\'IA (Paramètres → IA) pour le spin-off.');
      return;
    }
    setState(() {
      _spinLoading = true;
      _spinError = null;
    });
    widget.audioService.playReveal();
    // Films déjà tirés : à ne jamais reproposer (tant que l'historique existe).
    final avoid = <String>[...widget.spinoffHistory.titles];
    try {
      FilmContext? film;
      for (var attempt = 0; attempt < 3; attempt++) {
        final avoidText = avoid.isEmpty
            ? ''
            : ' Ne choisis AUCUN de ces films déjà tirés — prends-en un '
                'DIFFÉRENT : ${avoid.join(' ; ')}.';
        final reply = await widget.llm.complete(
          settings: widget.aiSettings,
          system: kSpinoffCardSystem,
          messages: [
            ChatMessage(
              role: 'user',
              content:
                  'Décennie : $_decade. Genre : $_genre. Choisis un film du top '
                  '100 le plus populaire et renvoie uniquement le JSON.$avoidText',
            ),
          ],
        );
        final f = FilmContext.tryParse(reply);
        if (f == null) {
          if (!mounted) return;
          setState(() {
            _spinLoading = false;
            _spinError = 'Réponse illisible de l\'IA (JSON attendu).';
          });
          return;
        }
        film = f;
        if (!widget.spinoffHistory.contains(f.film)) break; // film neuf
        avoid.add(f.film); // doublon : on réessaie en l'excluant
      }
      if (!mounted || film == null) return;
      // N'ajoute pas de doublon (cas rare où l'IA n'a plus de film neuf).
      if (!widget.spinoffHistory.contains(film.film)) {
        await widget.spinoffHistory
            .add(film: film, decade: _decade, genre: _genre);
      }
      if (!mounted) return;
      setState(() {
        _spinLoading = false;
        _film = film;
      });
    } on LlmException catch (e) {
      if (!mounted) return;
      setState(() {
        _spinLoading = false;
        _spinError = e.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _spinLoading = false;
        _spinError = 'Erreur pendant l\'appel à l\'IA.';
      });
    }
  }

  void _clear() {
    widget.controller.reset();
    setState(() {
      _film = null;
      _spinError = null;
    });
  }

  void _replay() {
    // Rejouer la même histoire : on rejoue la révélation, sans rien changer.
    widget.audioService.playReveal();
  }

  void _openTop() {
    final state = widget.controller.state;
    final mode = state.mode;
    String lieu, danger;
    String? title, year, genre;
    var cast = <({String text, bool antagoniste})>[];
    var heroes = <
        ({
          String archetype,
          String temperament,
          String port,
          String moteur,
          String statut
        })>[];
    var paliers = <String>[];
    var destinyEnabled = false;

    if (mode == GeneratorMode.spinoff && _film != null) {
      lieu = _film!.lieu;
      danger = _film!.danger;
      title = _film!.film;
      year = _film!.annee;
      genre = _genre;
      // Spin-off : pas de distribution, pas de DESTINY (cast vide,
      // destinyEnabled reste false) — on ne garde que le film, le lieu, le
      // danger et l'affiche.
    } else if (state.story != null) {
      lieu = state.story!.location.name;
      danger = state.story!.danger.name;
      if (mode == GeneratorMode.histoire) {
        // Rappel des archétypes + traits et des étapes du danger, + DESTINY.
        heroes = [
          for (final p in state.story!.players)
            (
              archetype: p.archetype.name,
              temperament: p.archetype.temperament,
              port: p.archetype.port,
              moteur: p.archetype.moteur,
              statut: p.archetype.statut,
            ),
        ];
        paliers = state.story!.danger.paliers;
        destinyEnabled = true;
      } else {
        cast = [
          for (final p in state.story!.players)
            (text: 'J${p.playerIndex} · ${p.archetype.name}', antagoniste: false),
        ];
      }
    } else {
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => TopCountdownScreen(
        lieu: lieu,
        danger: danger,
        audioService: widget.audioService,
        musicController: widget.musicController,
        filmTitle: title,
        filmYear: year,
        genre: genre,
        cast: cast,
        heroes: heroes,
        paliers: paliers,
        allArchetypes: _archetypeNames,
        allArchetypeData: _archetypes,
        allDangers: _dangerNames,
        weightArchetype: widget.visualSettings.destinyWeightArchetype,
        weightDanger: widget.visualSettings.destinyWeightDanger,
        weightDestin: widget.visualSettings.destinyWeightDestin,
        destinyEnabled: destinyEnabled,
        // Histoire : 30 min par défaut, DESTINY à 10 / 18 / 27 min (mm:ss).
        minutesUnit: destinyEnabled,
        destinyDefaults:
            destinyEnabled ? const [10 * 60, 18 * 60, 27 * 60] : const [],
        seconds: destinyEnabled ? 30 * 60 : widget.visualSettings.topSeconds,
        cubeAnimation: widget.visualSettings.cubeAnimation,
        // Aides de jeu accessibles pendant le chrono.
        guide: widget.guideContent,
        tracking: widget.trackingStore,
        visualSettings: widget.visualSettings,
        storyController: widget.controller,
        locationDetails: widget.locationDetails,
      ),
    ));
  }

  Future<void> _openHistory() async {
    final spin = widget.controller.state.mode == GeneratorMode.spinoff;
    if (spin) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => SpinoffHistoryScreen(history: widget.spinoffHistory),
      ));
      return;
    }
    // Retour éventuel d'un record à réafficher dans le Générateur.
    final record = await Navigator.of(context).push<GenerationRecord>(
      MaterialPageRoute(
        builder: (_) => GenerationHistoryScreen(history: widget.history),
      ),
    );
    if (record != null && mounted) {
      await _loadFromRecord(record);
    }
  }

  /// Reconstruit une Story depuis un enregistrement d'historique (résolution
  /// des entités par nom via le catalogue) et l'affiche dans le Générateur.
  Future<void> _loadFromRecord(GenerationRecord r) async {
    try {
      final locations = await widget.repository.getLocations();
      final archetypes = await widget.repository.getArchetypes();
      final dilemmas = r.mode == 'dilemme'
          ? await widget.repository.getDilemmas()
          : const <Dilemma>[];
      if (!mounted) return;

      final location = locations.firstWhere(
        (l) => l.name == r.location,
        orElse: () => Location(id: '', name: r.location, roles: r.roles),
      );

      // Le danger est intégralement reconstituable depuis le record.
      final danger = Danger(
        id: '',
        name: r.danger,
        style: r.dangerStyle,
        paliers: r.paliers,
      );

      final players = <PlayerAssignment>[];
      for (var k = 0; k < r.archetypes.length; k++) {
        final arch = archetypes.firstWhere(
          (a) => a.name == r.archetypes[k],
          orElse: () => Archetype(id: '', name: r.archetypes[k], traits: ''),
        );
        players.add(PlayerAssignment(
          playerIndex: k + 1,
          archetype: arch,
          role: k < r.roles.length ? r.roles[k] : '',
        ));
      }

      Dilemma? dilemma;
      if (r.mode == 'dilemme' && r.dilemma.isNotEmpty) {
        for (final d in dilemmas) {
          if (d.nom == r.dilemma) {
            dilemma = d;
            break;
          }
        }
      }

      final story = Story(
        location: location,
        danger: danger,
        players: players,
        dilemma: dilemma,
        cycle: 1,
        usedCount: 1,
        totalCombos: 1,
      );

      final mode = GeneratorMode.values.firstWhere(
        (m) => m.name == r.mode,
        orElse: () => GeneratorMode.histoire,
      );
      widget.controller.showStory(story, mode);
    } catch (_) {
      // Reconstruction impossible : on ignore silencieusement.
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.controller.state;
    final source = widget.visualSettings.source;
    final mode = state.mode;
    final histoire = mode == GeneratorMode.histoire;
    final isSpin = mode == GeneratorMode.spinoff;
    final busy =
        isSpin ? _spinLoading : state.status == StoryStatus.loading;
    final hasResult = isSpin ? _film != null : state.story != null;
    final error = isSpin ? _spinError : state.errorMessage;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        // Barre compacte : mode + historique + effacer.
        Row(
          children: [
            Expanded(
              child: SegmentedButton<GeneratorMode>(
                showSelectedIcon: false,
                style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                segments: const [
                  ButtonSegment(
                      value: GeneratorMode.histoire, label: Text('Histoire')),
                  ButtonSegment(value: GeneratorMode.rue, label: Text('Rue')),
                  ButtonSegment(
                      value: GeneratorMode.spinoff, label: Text('Spin-off')),
                ],
                // Dilemme n'a plus d'onglet : on affiche Histoire le temps que
                // la garde de initState normalise l'état restauré.
                selected: {
                  mode == GeneratorMode.dilemme ? GeneratorMode.histoire : mode
                },
                onSelectionChanged: (s) => widget.controller.setMode(s.first),
              ),
            ),
            IconButton(
              tooltip: 'Historique',
              icon: const Icon(Icons.history),
              onPressed: _openHistory,
            ),
            if (hasResult)
              IconButton(
                tooltip: 'Effacer',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.delete_outline),
                onPressed: _clear,
              ),
          ],
        ),
        const SizedBox(height: 10),

        // Contrôles selon le mode.
        if (histoire)
          _PlayerStepper(
            count: state.playerCount,
            enabled: !busy,
            onChanged: (n) =>
                widget.controller.updatePlayerCount(n.toDouble()),
          ),
        if (isSpin) _DecadeGenrePicker(
          decade: _decade,
          genre: _genre,
          onDecade: (d) => setState(() => _decade = d),
          onGenre: (g) => setState(() => _genre = g),
        ),

        // Bouton générer (tant qu'aucun résultat).
        if (!hasResult) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: busy ? null : (isSpin ? _generateSpinoff : _generate),
              icon: const Icon(Icons.auto_awesome),
              label: Text(busy
                  ? 'Génération…'
                  : switch (mode) {
                      GeneratorMode.histoire => 'Générer une histoire',
                      GeneratorMode.rue => 'Générer une scène',
                      GeneratorMode.dilemme => 'Générer un dilemme',
                      GeneratorMode.spinoff => 'Générer un spin-off',
                    }),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],

        // Loterie de recherche du film (spin-off en cours de génération).
        if (isSpin && busy) ...[
          const SizedBox(height: 14),
          SpinoffLottery(decade: _decade, genre: _genre),
        ],

        if (error != null) ...[
          const SizedBox(height: 12),
          Text(error, style: const TextStyle(color: Colors.redAccent)),
        ],

        // Le résultat : la vedette.
        if (hasResult) ...[
          const SizedBox(height: 14),
          if (isSpin)
            _GeneratorFilmCard(film: _film!, genre: _genre)
          else
            switch (mode) {
              GeneratorMode.dilemme => DilemmaResultCard(
                  story: state.story!,
                  source: source,
                  full: widget.visualSettings.fullMode),
              GeneratorMode.rue => RueResultCard(
                  story: state.story!,
                  source: source,
                  big: widget.visualSettings.bigImages,
                  full: widget.visualSettings.fullMode),
              GeneratorMode.histoire => StoryResultCard(
                  story: state.story!,
                  source: source,
                  big: widget.visualSettings.bigImages,
                  full: widget.visualSettings.fullMode,
                  locationDetails: widget.locationDetails),
              GeneratorMode.spinoff => const SizedBox.shrink(),
            },
          const SizedBox(height: 12),
          // Le TOP : chrono de scène plein écran.
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _openTop,
              icon: const Icon(Icons.timer),
              label: Text(mode == GeneratorMode.histoire
                  ? 'TOP — chrono (30 min, réglable)'
                  : 'TOP — chrono ${widget.visualSettings.topSeconds} s'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFFC24B),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _replay,
                  icon: const Icon(Icons.replay, size: 18),
                  label: const Text('Rejouer'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed:
                      busy ? null : (isSpin ? _generateSpinoff : _generate),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Relancer'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _clear,
                child: const Text('Effacer'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Sélecteurs Décennie + Genre (spin-off), côte à côte.
class _DecadeGenrePicker extends StatelessWidget {
  const _DecadeGenrePicker({
    required this.decade,
    required this.genre,
    required this.onDecade,
    required this.onGenre,
  });

  final String decade;
  final String genre;
  final ValueChanged<String> onDecade;
  final ValueChanged<String> onGenre;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: _genDecades.contains(decade) ? decade : _genDecades.first,
            isExpanded: true,
            decoration: const InputDecoration(
                isDense: true, labelText: 'Décennie', border: OutlineInputBorder()),
            items: [
              for (final d in _genDecades)
                DropdownMenuItem(value: d, child: Text(d)),
            ],
            onChanged: (v) => onDecade(v ?? _genDecades.first),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: _genGenres.contains(genre) ? genre : _genGenres.first,
            isExpanded: true,
            decoration: const InputDecoration(
                isDense: true, labelText: 'Genre', border: OutlineInputBorder()),
            items: [
              for (final g in _genGenres)
                DropdownMenuItem(value: g, child: Text(g)),
            ],
            onChanged: (v) => onGenre(v ?? _genGenres.first),
          ),
        ),
      ],
    );
  }
}

/// Carte de résultat du spin-off : affiche du film + titre + lieu + danger.
/// (Ni distribution ni DESTINY : le spin-off ne garde que le décor du film.)
class _GeneratorFilmCard extends StatelessWidget {
  const _GeneratorFilmCard({required this.film, required this.genre});

  final FilmContext film;
  final String genre;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // L'affiche du film, en vedette.
            Center(
              child: FilmPoster(
                film: film.film,
                annee: film.annee,
                genre: genre,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.movie, color: Color(0xFFFFC24B), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    film.annee.isEmpty
                        ? film.film
                        : '${film.film} (${film.annee})',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _kv(theme, 'Lieu', film.lieu),
            const SizedBox(height: 4),
            _kv(theme, 'Danger', film.danger),
          ],
        ),
      ),
    );
  }

  Widget _kv(ThemeData theme, String k, String v) => Text.rich(TextSpan(children: [
        TextSpan(
            text: '$k : ',
            style: theme.textTheme.labelMedium
                ?.copyWith(color: theme.colorScheme.primary)),
        TextSpan(text: v, style: theme.textTheme.titleMedium),
      ]));
}


/// Sélecteur compact du nombre de joueurs (– N +), sans grande carte.
class _PlayerStepper extends StatelessWidget {
  const _PlayerStepper({
    required this.count,
    required this.enabled,
    required this.onChanged,
  });

  final int count;
  final bool enabled;
  final ValueChanged<int> onChanged;

  static const int _min = 3;
  static const int _max = 10;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(Icons.groups, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text('Joueurs', style: theme.textTheme.titleSmall),
        const Spacer(),
        IconButton.outlined(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.remove),
          onPressed:
              enabled && count > _min ? () => onChanged(count - 1) : null,
        ),
        SizedBox(
          width: 36,
          child: Text('$count',
              textAlign: TextAlign.center, style: theme.textTheme.titleLarge),
        ),
        IconButton.outlined(
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.add),
          onPressed:
              enabled && count < _max ? () => onChanged(count + 1) : null,
        ),
      ],
    );
  }
}

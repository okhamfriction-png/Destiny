import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../application/services/audio_service.dart';
import '../../application/state/guide_content.dart';
import '../../application/state/music_controller.dart';
import '../../application/state/location_details.dart';
import '../../application/state/story_controller.dart';
import '../../application/state/tracking_store.dart';
import '../../application/state/visual_settings.dart';
import '../visuals/entity_visuals.dart';
import '../widgets/destiny_cube_animation.dart';
import '../widgets/film_poster.dart';
import '../widgets/sound_mixer_sheet.dart';
import 'guide_screen.dart';
import 'location_details_screen.dart';
import 'tracking_screen.dart';

/// Police manuscrite (seule la phrase « RIEN EST ÉCRIT » l'utilise).
const String _kHand = 'PatrickHand';
const Color _gold = Color(0xFFFFC24B);

/// Les 24 archétypes (repli si le catalogue n'est pas encore chargé).
const List<String> _kArchetypes = [
  'Aigle', 'Cerf', 'Chat', 'Chien', 'Coq', 'Corbeau', 'Fourmi', 'Hibou',
  'Hyène', 'Lapin', 'Lion', 'Loup', 'Mouton', 'Ours', 'Paon', 'Porc', 'Rat',
  'Renard', 'Serpent', 'Singe', 'Souris', 'Taureau', 'Vautour', 'Âne',
];

/// Cartes « Destin » lancées par le public (Johnstone).
const List<String> _kDestinyCards = [
  'Quelqu\'un que l\'un de vous aime apparaît, et il est en danger.',
  'Quelqu\'un que l\'un de vous croyait mort est là, vivant.',
  'Il n\'y a plus qu\'une issue pour un seul d\'entre vous.',
  'L\'un de vous détient, sans le savoir, ce qui peut tous vous sauver ou tous vous perdre.',
  'Le plus faible d\'entre vous prend le pouvoir de décider pour tous.',
  'L\'un de vous a menti sur quelque chose d\'essentiel — il doit l\'avouer maintenant.',
];

/// Chrono plein écran lancé par le bouton TOP. En mode Histoire, on rappelle
/// aussi les archétypes (et leurs traits) et les étapes du danger, on peut
/// paramétrer la durée et les 3 moments où le DESTINY se déclenche.
class TopCountdownScreen extends StatefulWidget {
  const TopCountdownScreen({
    required this.lieu,
    required this.danger,
    required this.audioService,
    this.musicController,
    this.filmTitle,
    this.filmYear,
    this.genre,
    this.cast = const [],
    this.heroes = const [],
    this.paliers = const [],
    this.allArchetypes = const [],
    this.allDangers = const [],
    this.destinyEnabled = false,
    this.destinyDefaults = const [],
    this.minutesUnit = false,
    this.weightArchetype = 3,
    this.weightDanger = 2,
    this.weightDestin = 7,
    this.seconds = 30,
    this.alertAt = 10,
    this.cubeAnimation = false,
    this.guide,
    this.tracking,
    this.visualSettings,
    this.storyController,
    this.locationDetails,
    super.key,
  });

  /// Aides de jeu accessibles pendant le chrono (Guide + tableaux de suivi).
  final GuideContent? guide;
  final TrackingStore? tracking;
  final VisualSettings? visualSettings;
  final StoryController? storyController;
  final LocationDetailsStore? locationDetails;

  final String lieu;
  final String danger;
  final AudioService audioService;

  /// Musiques scénaristiques du chrono (Commencement au lancement, Conclusion
  /// 15 s après le 3ᵉ DESTINY). Null = pas de musique.
  final MusicController? musicController;

  final String? filmTitle;
  final String? filmYear;
  final String? genre;

  /// Distribution simple (texte + antagoniste) — modes non-Histoire.
  final List<({String text, bool antagoniste})> cast;

  /// Héros détaillés (archétype + tempérament / port / moteur) — mode Histoire.
  final List<
      ({
        String archetype,
        String temperament,
        String port,
        String moteur
      })> heroes;

  /// Étapes du danger (paliers).
  final List<String> paliers;

  /// Noms des archétypes et dangers du catalogue (pour le tirage du DESTINY).
  final List<String> allArchetypes;
  final List<String> allDangers;

  /// Active la config du chrono + les 3 DESTINY (mode Histoire uniquement).
  final bool destinyEnabled;

  /// Moments par défaut des 3 DESTINY (en secondes écoulées).
  final List<int> destinyDefaults;

  /// Config et affichage du chrono en minutes (mm:ss) plutôt qu'en secondes.
  final bool minutesUnit;

  /// Poids du dé DESTINY (0 = ce type ne tombe jamais).
  final int weightArchetype;
  final int weightDanger;
  final int weightDestin;

  final int seconds;
  final int alertAt;

  /// Active l'animation du cube doré (lancement du chrono + DESTINY).
  /// Désactivée par défaut.
  final bool cubeAnimation;

  @override
  State<TopCountdownScreen> createState() => _TopCountdownScreenState();
}

class _TopCountdownScreenState extends State<TopCountdownScreen> {
  // Phase config (Histoire) puis course.
  late bool _setup = widget.destinyEnabled;
  late int _duration = widget.seconds;
  late List<int> _destiny;

  int _remaining = 0;
  Timer? _timer;
  bool _alerted = false;
  bool _done = false;
  final Set<int> _fired = {};
  int? _flash; // numéro du DESTINY en cours d'affichage
  Timer? _flashTimer;
  Timer? _conclusionTimer; // musique de conclusion, 15 s après DESTINY 3
  // Cube animé au lancement du chrono (flourish de départ).
  bool _showLaunchCube = false;
  int _launchToken = 0;
  bool _paused = false; // chrono en pause
  final Random _rng = Random();
  // Résultats du dé, un par DESTINY.
  final List<({int num, String kind, String text, String? emoji})> _rolls = [];

  ({String kind, String text, String? emoji}) _archetypeRoll() {
    final list =
        widget.allArchetypes.isNotEmpty ? widget.allArchetypes : _kArchetypes;
    final name = list[_rng.nextInt(list.length)];
    return (
      kind: 'Archétype',
      text: name,
      emoji: EntityVisuals.emojiForArchetypeName(name) ?? '🎭'
    );
  }

  ({String kind, String text, String? emoji}) _destinRoll() => (
        kind: 'Destin',
        text: _kDestinyCards[_rng.nextInt(_kDestinyCards.length)],
        emoji: '🎲'
      );

  /// Lance le dé du DESTINY selon les poids réglés (archétype / danger / destin).
  ({String kind, String text, String? emoji}) _rollDestiny() {
    final wA = widget.weightArchetype;
    // Danger désactivé automatiquement si le catalogue est vide.
    final wD = widget.allDangers.isEmpty ? 0 : widget.weightDanger;
    final wX = widget.weightDestin;
    final total = wA + wD + wX;
    if (total <= 0) return _destinRoll(); // sécurité : rien de réglé
    final r = _rng.nextInt(total);
    if (r < wA) return _archetypeRoll();
    if (r < wA + wD) {
      return (
        kind: 'Danger',
        text: widget.allDangers[_rng.nextInt(widget.allDangers.length)],
        emoji: '⚠️'
      );
    }
    return _destinRoll();
  }

  static List<int> _defaultDestiny(int total) => [
        (total * 0.25).round().clamp(1, total - 1),
        (total * 0.5).round().clamp(1, total - 1),
        (total * 0.75).round().clamp(1, total - 1),
      ];

  @override
  void initState() {
    super.initState();
    // DESTINY seulement si le mode l'active (Histoire). En spin-off / rue /
    // dilemme, aucun moment n'est armé → aucun DESTINY ne se déclenche.
    _destiny = !widget.destinyEnabled
        ? const []
        : (widget.destinyDefaults.length == 3
            ? [...widget.destinyDefaults]
            : _defaultDestiny(_duration));
    if (!widget.destinyEnabled) _start();
  }

  /// Format d'affichage du temps restant.
  String _fmt(int s) {
    if (!widget.minutesUnit) return '$s';
    final m = s ~/ 60;
    final r = s % 60;
    return '${m.toString().padLeft(2, '0')}:${r.toString().padLeft(2, '0')}';
  }

  /// Étiquette d'un moment DESTINY (minutes ou secondes).
  String _moment(int s) => widget.minutesUnit ? '${s ~/ 60} min' : '${s}s';

  @override
  void dispose() {
    _timer?.cancel();
    _flashTimer?.cancel();
    _conclusionTimer?.cancel();
    // Restaure les barres système.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _start() {
    _timer?.cancel();
    // Plein écran immersif pendant le chrono (cache les barres système).
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    setState(() {
      _setup = false;
      _remaining = _duration;
      _alerted = false;
      _done = false;
      _fired.clear();
      _rolls.clear();
      _flash = null;
      // Cube animé au démarrage du chrono (si l'animation est activée).
      _showLaunchCube = widget.cubeAnimation;
      _launchToken++;
      _paused = false;
    });
    if (widget.cubeAnimation) widget.audioService.playDice();
    _conclusionTimer?.cancel();
    // Musique du Commencement au lancement (mode Histoire, son non coupé).
    if (widget.destinyEnabled &&
        widget.musicController != null &&
        !widget.audioService.muted) {
      widget.musicController!.playCommencement();
    }
    _timer = Timer.periodic(const Duration(seconds: 1), _tick);
  }

  /// Met en pause ou reprend le chrono en cours.
  void _togglePause() {
    if (_done || _setup) return;
    setState(() => _paused = !_paused);
    _timer?.cancel();
    if (!_paused) {
      _timer = Timer.periodic(const Duration(seconds: 1), _tick);
    }
  }

  void _tick(Timer t) {
    if (!mounted) return;
    setState(() {
      _remaining--;
      final elapsed = _duration - _remaining;
      // DESTINY aux moments configurés.
      for (var i = 0; i < _destiny.length; i++) {
        if (!_fired.contains(i) && elapsed == _destiny[i]) {
          _fired.add(i);
          _flash = i + 1;
          final roll = _rollDestiny();
          _rolls.add((
            num: i + 1,
            kind: roll.kind,
            text: roll.text,
            emoji: roll.emoji
          ));
          widget.audioService.playStorm(); // vrai son Destiny (DestinyStorm)
          _flashTimer?.cancel();
          _flashTimer = Timer(const Duration(milliseconds: 2200), () {
            if (mounted) setState(() => _flash = null);
          });
          // 3ᵉ (dernier) DESTINY : musique de Conclusion 15 s plus tard.
          if (i == 2 &&
              widget.musicController != null &&
              !widget.audioService.muted) {
            _conclusionTimer?.cancel();
            _conclusionTimer = Timer(const Duration(seconds: 15), () {
              if (mounted) widget.musicController!.playConclusion();
            });
          }
        }
      }
      if (_remaining == widget.alertAt && !_alerted) {
        _alerted = true;
        widget.audioService.playThunder();
      }
      if (_remaining <= 0) {
        _remaining = 0;
        _done = true;
        t.cancel();
        widget.audioService.playCrack();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: (_remaining <= widget.alertAt && !_setup && !_done)
          ? const Color(0xFF2A0A0A)
          : const Color(0xFF0A0818),
      body: Stack(
          children: [
            // Contenu plein écran (edge-to-edge).
            Positioned.fill(
              child: _setup ? _buildSetup(context) : _buildRun(context),
            ),
            // Croix TOUJOURS au-dessus du contenu (donc cliquable).
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Coupe / active le son (effets + musique), à gauche de la croix.
                    Builder(builder: (context) {
                      final on = !widget.audioService.muted ||
                          (widget.musicController?.playing ?? false);
                      return IconButton(
                        tooltip: on ? 'Couper le son' : 'Activer le son',
                        icon: Icon(on ? Icons.volume_up : Icons.volume_off,
                            color: Colors.white70),
                        onPressed: () => setState(() {
                          if (on) {
                            widget.audioService.setMuted(true);
                            widget.musicController?.stop();
                          } else {
                            widget.audioService.setMuted(false);
                          }
                        }),
                      );
                    }),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () {
                        SystemChrome.setEnabledSystemUIMode(
                            SystemUiMode.edgeToEdge);
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
              ),
            ),
            // Aides de jeu pendant le chrono : Guide + tableaux de suivi.
            // Le chrono continue de tourner sous l'écran ouvert.
            if (widget.guide != null &&
                widget.tracking != null &&
                widget.visualSettings != null &&
                widget.storyController != null)
              SafeArea(
                child: Align(
                  alignment: Alignment.topLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Guide Destiny',
                        icon: const Icon(Icons.menu_book, color: _gold),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => GuideScreen(
                              guide: widget.guide!,
                              visualSettings: widget.visualSettings!,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Tableaux de suivi',
                        icon:
                            const Icon(Icons.fact_check_outlined, color: _gold),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => TrackingScreen(
                              store: widget.tracking!,
                              storyController: widget.storyController!,
                              locationDetails: widget.locationDetails,
                            ),
                          ),
                        ),
                      ),
                      if (widget.locationDetails != null)
                        IconButton(
                          tooltip: 'Détails du lieu',
                          icon: const Icon(Icons.place_outlined, color: _gold),
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => LocationDetailsScreen(
                                store: widget.locationDetails!,
                                locationName: widget.lieu,
                              ),
                            ),
                          ),
                        ),
                      // Pupitre de régie son : lancer une musique en direct.
                      if (widget.musicController != null)
                        IconButton(
                          tooltip: 'Régie son (musiques)',
                          icon: const Icon(Icons.tune, color: _gold),
                          onPressed: () =>
                              showSoundMixer(context, widget.musicController!),
                        ),
                    ],
                  ),
                ),
              ),
            // Cube animé au lancement du chrono (flourish de départ).
            if (_showLaunchCube)
              DestinyCubeAnimation(
                key: ValueKey('launch_$_launchToken'),
                size: (MediaQuery.of(context).size.shortestSide * 0.6)
                    .clamp(200.0, 420.0)
                    .toDouble(),
                fullscreenScrim: true,
                onCompleted: () {
                  if (mounted) setState(() => _showLaunchCube = false);
                },
              ),
            if (_flash != null)
              _DestinyFlash(number: _flash!, useCube: widget.cubeAnimation),
          ],
        ),
      );
  }

  // --------------------------------------------------------------- infos
  Widget _infoBlock(BuildContext context, {double scale = 1}) {
    final theme = Theme.of(context);
    final isFilm = (widget.filmTitle ?? '').isNotEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('RIEN EST ÉCRIT',
            style: TextStyle(
                fontFamily: _kHand, fontSize: 30 * scale, color: _gold)),
        SizedBox(height: 14 * scale),
        _ContextLine(
          label: 'LIEU',
          value: widget.lieu,
          scale: scale,
          onTap: (widget.locationDetails != null && widget.lieu.isNotEmpty)
              ? () => showLocationDetailsPopup(
                  context, widget.locationDetails!, widget.lieu)
              : null,
        ),
        SizedBox(height: 10 * scale),
        _ContextLine(label: 'DANGER', value: widget.danger, scale: scale),
        if (widget.heroes.isNotEmpty) ...[
          SizedBox(height: 12 * scale),
          _MiniLabel('HÉROS', scale: scale),
          SizedBox(height: 4 * scale),
          for (final h in widget.heroes)
            Padding(
              padding: EdgeInsets.only(bottom: 4 * scale),
              // Row + Expanded → largeur STRICTE ; FittedBox réduit le texte
              // pour que chaque héros tienne TOUJOURS sur une seule ligne.
              child: Row(
                children: [
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: Text.rich(
                TextSpan(children: [
                  TextSpan(
                      text:
                          '${EntityVisuals.emojiForArchetypeName(h.archetype) ?? '🎭'}  ',
                      style: TextStyle(fontSize: 18 * scale)),
                  TextSpan(
                      text: h.archetype,
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18 * scale,
                          fontWeight: FontWeight.w700)),
                  if (h.temperament.isNotEmpty)
                    TextSpan(
                        text: '  ·  ${h.temperament}',
                        style: TextStyle(
                            color: Colors.white54, fontSize: 15 * scale)),
                  if (h.port.isNotEmpty)
                    TextSpan(
                        text: '  ·  ${h.port}',
                        style: TextStyle(
                            color: Colors.white54,
                            fontSize: 15 * scale,
                            fontStyle: FontStyle.italic)),
                  if (h.moteur.isNotEmpty)
                    TextSpan(
                        text: '  ·  ${h.moteur}',
                        style: TextStyle(
                            color: const Color(0xFFFF5252),
                            fontSize: 15 * scale,
                            fontWeight: FontWeight.w800)),
                ]),
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.visible,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ] else if (widget.cast.isNotEmpty) ...[
          SizedBox(height: 12 * scale),
          _MiniLabel('QUI', scale: scale),
          SizedBox(height: 4 * scale),
          for (final m in widget.cast)
            Text(m.text,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 18 * scale,
                    fontWeight: FontWeight.w600,
                    color: m.antagoniste ? const Color(0xFFFF5252) : Colors.white)),
        ],
        if (widget.paliers.isNotEmpty) ...[
          SizedBox(height: 12 * scale),
          _MiniLabel('ÉTAPES DU DANGER', scale: scale),
          SizedBox(height: 4 * scale),
          // Étape en cours (avance à chaque DESTINY) : gras blanc, plus grande.
          for (var i = 0; i < widget.paliers.length; i++)
            Builder(builder: (context) {
              final current = _setup
                  ? -1
                  : _fired.length.clamp(0, widget.paliers.length - 1);
              final active = i == current;
              return Padding(
                padding: EdgeInsets.only(bottom: (active ? 6 : 3) * scale),
                child: Text('${i + 1}. ${widget.paliers[i]}',
                    textAlign: TextAlign.center,
                    style: active
                        ? TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 19 * scale,
                            height: 1.3)
                        : theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white38,
                            height: 1.2,
                            fontSize:
                                (theme.textTheme.bodySmall?.fontSize ?? 12) *
                                    scale)),
              );
            }),
        ],
        if (isFilm) ...[
          SizedBox(height: 16 * scale),
          FilmPoster(
            film: widget.filmTitle!,
            annee: widget.filmYear ?? '',
            genre: widget.genre ?? '',
            width: 190 * scale,
          ),
        ],
      ],
    );
  }

  // --------------------------------------------------------------- setup
  Widget _buildSetup(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 40, 20, 24),
      child: Column(
        children: [
          _infoBlock(context),
          const SizedBox(height: 20),
          const _MiniLabel('DURÉE DU CHRONO'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final m in const [30, 40, 45, 50])
                ChoiceChip(
                  label: Text('$m min'),
                  selected: _duration == m * 60,
                  onSelected: (_) => setState(() {
                    _duration = m * 60;
                    _destiny = _defaultDestiny(_duration);
                  }),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const _MiniLabel('MOMENTS DES 3 DESTINY'),
          const SizedBox(height: 4),
          for (var i = 0; i < 3; i++)
            Builder(builder: (context) {
              final durMin = (_duration ~/ 60).clamp(2, 240);
              final curMin = (_destiny[i] / 60).round().clamp(1, durMin - 1);
              return Row(
                children: [
                  SizedBox(
                    width: 96,
                    child: Text('DESTINY ${i + 1}',
                        style: theme.textTheme.labelMedium
                            ?.copyWith(color: _gold)),
                  ),
                  Expanded(
                    child: Slider(
                      value: curMin.toDouble(),
                      min: 1,
                      max: (durMin - 1).toDouble(),
                      divisions: (durMin - 1).clamp(1, 240),
                      label: '$curMin min',
                      onChanged: (v) =>
                          setState(() => _destiny[i] = v.round() * 60),
                    ),
                  ),
                  SizedBox(
                      width: 48,
                      child: Text('$curMin min',
                          style: theme.textTheme.bodySmall)),
                ],
              );
            }),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _start,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Lancer le chrono'),
              style: FilledButton.styleFrom(
                backgroundColor: _gold,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------- run
  Widget _buildRun(BuildContext context) {
    final warning = _remaining <= widget.alertAt;
    // Après le dernier DESTINY (le 3ᵉ), le chrono vire au rouge : on est dans
    // l'acte final.
    final afterLastDestiny = widget.destinyEnabled &&
        _destiny.isNotEmpty &&
        _fired.contains(_destiny.length - 1);
    final accent = _done
        ? Colors.white
        : ((warning || afterLastDestiny)
            ? const Color(0xFFFF5252)
            : const Color(0xFFB9A6FF));
    final timerSize = _done ? 66.0 : (widget.minutesUnit ? 84.0 : 104.0);

    // Contenu à largeur de référence ; un FittedBox le met à l'échelle pour
    // occuper TOUT l'écran sans jamais défiler (ni déborder, ni laisser de vide).
    final content = SizedBox(
      width: 360,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _infoBlock(context),
          const SizedBox(height: 18),
          Text(_done ? 'TOP !' : _fmt(_remaining),
              style: TextStyle(
                  fontSize: timerSize,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  color: accent,
                  letterSpacing: 2)),
          const SizedBox(height: 6),
          Text(
            _done
                ? 'Scène terminée.'
                : _paused
                    ? 'En pause'
                    : (warning ? 'Conclus, $_remaining s !' : 'À toi de jouer.'),
            style: TextStyle(
                color: _paused
                    ? _gold
                    : (warning ? const Color(0xFFFF8A80) : Colors.white54),
                fontSize: 16),
          ),
          if (widget.destinyEnabled) ...[
            const SizedBox(height: 6),
            Text('DESTINY à ${_destiny.map(_moment).join(" · ")}',
                style: const TextStyle(color: _gold, fontSize: 13)),
          ],
          // Résultats du dé (un par DESTINY passé).
          if (_rolls.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final roll in _rolls)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _gold.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _gold.withValues(alpha: 0.35)),
                ),
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(
                        text: 'DESTINY ${roll.num} — ',
                        style: const TextStyle(
                            color: _gold, fontWeight: FontWeight.w800)),
                    TextSpan(
                        text: '${roll.emoji ?? '🎲'} ${roll.kind} : ',
                        style: const TextStyle(color: Colors.white70)),
                    TextSpan(
                        text: roll.text,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            height: 1.3)),
                  ]),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              // Pause / Reprendre (uniquement pendant que le chrono tourne).
              if (!_done)
                FilledButton.icon(
                  onPressed: _togglePause,
                  style: FilledButton.styleFrom(
                    backgroundColor: _gold,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    textStyle: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800),
                  ),
                  icon: Icon(_paused ? Icons.play_arrow : Icons.pause, size: 20),
                  label: Text(_paused ? 'Reprendre' : 'Pause'),
                ),
              OutlinedButton.icon(
                onPressed: widget.destinyEnabled
                    ? () {
                        _timer?.cancel();
                        SystemChrome.setEnabledSystemUIMode(
                            SystemUiMode.edgeToEdge);
                        setState(() => _setup = true);
                      }
                    : _start,
                icon: const Icon(Icons.replay, size: 18),
                label: Text(
                    widget.destinyEnabled ? 'Régler / relancer' : 'Relancer'),
              ),
            ],
          ),
        ],
      ),
    );

    // SizedBox.expand donne des contraintes SERRÉES au FittedBox → il met le
    // contenu à l'échelle pour occuper toute la hauteur (au lieu de rester à sa
    // taille naturelle avec du vide). BoxFit.contain garantit : aucun scroll.
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox.expand(
        child: FittedBox(fit: BoxFit.contain, child: content),
      ),
    );
  }
}

class _DestinyFlash extends StatelessWidget {
  const _DestinyFlash({required this.number, this.useCube = false});
  final int number;
  final bool useCube;

  @override
  Widget build(BuildContext context) {
    // Animation désactivée : flash léger d'origine (éclair + texte).
    if (!useCube) {
      return Positioned.fill(
        child: IgnorePointer(
          child: Container(
            color: _gold.withValues(alpha: 0.14),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bolt, color: _gold, size: 48),
                Text('DESTINY $number',
                    style: const TextStyle(
                        color: _gold,
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3)),
              ],
            ),
          ),
        ),
      );
    }
    // Animation activée : le cube DESTINY surgit et tourne, puis reste affiché
    // (holdAtEnd) jusqu'à ce que le parent retire le flash.
    return LayoutBuilder(builder: (context, c) {
      final double size =
          (c.biggest.shortestSide * 0.55).clamp(200.0, 380.0).toDouble();
      return DestinyCubeAnimation(
        size: size,
        label: 'DESTINY $number',
        fullscreenScrim: true,
        holdAtEnd: true,
      );
    });
  }
}

class _MiniLabel extends StatelessWidget {
  const _MiniLabel(this.text, {this.scale = 1});
  final String text;
  final double scale;
  @override
  Widget build(BuildContext context) => Text(text,
      style: TextStyle(
          color: const Color(0xFFB9A6FF),
          letterSpacing: 3,
          fontSize: 12 * scale));
}

class _ContextLine extends StatelessWidget {
  const _ContextLine(
      {required this.label, required this.value, this.scale = 1, this.onTap});
  final String label;
  final String value;
  final double scale;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final valueText = Text(value.isEmpty ? '—' : value,
        textAlign: TextAlign.center,
        style: TextStyle(
            color: Colors.white,
            fontSize: 22 * scale,
            fontWeight: FontWeight.w700,
            height: 1.15));
    return Column(
      children: [
        _MiniLabel(label, scale: scale),
        SizedBox(height: 2 * scale),
        if (onTap == null)
          valueText
        else
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: 8 * scale, vertical: 2 * scale),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(child: valueText),
                  SizedBox(width: 6 * scale),
                  Icon(Icons.info_outline, size: 17 * scale, color: _gold),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

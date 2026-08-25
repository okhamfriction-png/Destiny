import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../../application/services/audio_service.dart';
import '../../application/services/transcription_service.dart';
import '../../application/state/campagne_store.dart';
import '../../application/state/music_controller.dart';
import '../../domain/entities/campagne.dart';
import '../visuals/campagne_visuals.dart';
import '../widgets/destiny_cube_animation.dart';
import '../widgets/piece_destin_flip.dart';
import '../widgets/sound_mixer_sheet.dart';
import 'campagne_bilan_screen.dart';

const Color _lieuC = Color(0xFF5EE0C4);
const Color _figC = Color(0xFFB79CFF);
const Color _mechC = Color(0xFFFFC24B);
const Color _escC = Color(0xFFFF8A80);
const Color _roleC = Color(0xFF64B5F6);

/// Écran de jeu d'un épisode : compte à rebours, cinq cartes, escalade sonore.
/// Le parent n'a aucune main sur l'escalade pendant la séance.
class JeuScreen extends StatefulWidget {
  const JeuScreen({
    required this.store,
    required this.campagne,
    required this.episode,
    required this.dureeMs,
    required this.horairesMs,
    required this.audioService,
    required this.musicController,
    this.transcription,
    super.key,
  });
  final CampagneStore store;
  final Campagne campagne;
  final Episode episode;
  final int dureeMs;
  final List<int> horairesMs;
  final AudioService audioService;
  final MusicController musicController;
  final TranscriptionService? transcription;

  @override
  State<JeuScreen> createState() => _JeuScreenState();
}

class _JeuScreenState extends State<JeuScreen> {
  late int _resteMs = widget.dureeMs;
  Timer? _timer;
  final Set<int> _tombes = {}; // index des marches d'escalade révélées
  bool _peutSortir = false;
  String _micRaison = ''; // raison si le micro n'a pas démarré
  // État de combat par personnage (clé stable : 'j0', 'f0', 's0', 'm').
  final Map<String, EtatPerso> _etats = {};

  EtatPerso _etat(String id) => _etats.putIfAbsent(id, EtatPerso.new);

  int? _flash; // numéro du danger en cours d'animation (dé)
  Timer? _flashTimer;

  // Pièce du destin (BRAVE / SMART), lancée à la demande par le MJ.
  bool _piece = false;
  bool _pieceBrave = true;
  int _pieceNo = 0; // incrémenté à chaque lancer → relance l'animation
  final Random _rng = Random();

  /// Le MJ lance la pièce du destin : tirage aléatoire + animation de flip.
  void _lancerPiece() {
    if (_piece) return; // une pièce à la fois
    HapticFeedback.mediumImpact();
    widget.audioService.playCoin();
    setState(() {
      _pieceBrave = _rng.nextBool();
      _pieceNo++;
      _piece = true;
    });
  }

  /// L'emblème Destiny en « mode pièce » : disque cerclé d'or (icône du bouton).
  Widget _pieceDestin() => Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF0A0818),
          border: Border.all(color: _mechC, width: 2),
        ),
        padding: const EdgeInsets.all(3),
        child: Image.asset('assets/images/destiny_cube.png', fit: BoxFit.contain),
      );

  /// Bouton outil du MJ, coloré. [vedette] = fond plein, mis en avant (la pièce).
  Widget _boutonMJ({
    IconData? icon,
    Widget? customLead,
    required String label,
    required Color couleur,
    required VoidCallback onTap,
    bool vedette = false,
  }) {
    // Tailles identiques quel que soit le statut : seul le style (fond/halo/
    // couleur de texte) change avec [vedette] → les deux boutons font la
    // même taille.
    final child = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        customLead ??
            Icon(icon, size: 24, color: vedette ? Colors.black : couleur),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
                color: vedette ? Colors.black : couleur,
                fontWeight: FontWeight.w800,
                fontSize: 14)),
      ],
    );
    return Material(
      color: vedette ? couleur : couleur.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: vedette ? couleur : couleur.withValues(alpha: 0.5),
                width: vedette ? 0 : 1),
            boxShadow: vedette
                ? [
                    BoxShadow(
                        color: couleur.withValues(alpha: 0.45),
                        blurRadius: 14,
                        spreadRadius: 1)
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: child,
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    // Le danger 1 démarre l'épisode : il est révélé d'emblée (pas minuté).
    if (widget.episode.escalade.isNotEmpty) _tombes.add(0);
    _timer = Timer.periodic(const Duration(seconds: 1), _battement);
    _demarrerMicro();
  }

  /// Le dernier danger est tombé → l'acte final, le chrono vire au rouge.
  bool get _rouge =>
      _tombes.contains(widget.episode.escalade.length - 1) &&
      widget.episode.escalade.isNotEmpty;

  Future<void> _demarrerMicro() async {
    final t = widget.transcription;
    if (t == null) return;
    // Le micro ne doit JAMAIS empêcher un épisode de commencer : l'échec est un
    // simple bandeau, la séance continue.
    final echec = await t.demarrer(
      onPhrase: (_) {},
      onChangement: () {
        if (mounted) setState(() {});
      },
      dureeMax: const Duration(minutes: 12),
    );
    if (!echec.ok && mounted) setState(() => _micRaison = echec.message);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _flashTimer?.cancel();
    // arreter() attrape ses exceptions : une exception ici emporterait la
    // fermeture de l'écran pour un micro qu'on éteignait de toute façon.
    widget.transcription?.arreter();
    super.dispose();
  }

  void _battement(Timer t) {
    if (!mounted) return;
    setState(() {
      _resteMs -= 1000;
      final ecoule = widget.dureeMs - _resteMs;
      // horairesMs[i] correspond au danger d'escalade d'index i+1 (le 1 est déjà là).
      for (var i = 0; i < widget.horairesMs.length; i++) {
        if (!_tombes.contains(i + 1) && ecoule >= widget.horairesMs[i]) {
          _tombes.add(i + 1);
          widget.audioService.playStorm(); // coup de tonnerre (montée du danger)
          // Animation du dé : le cube surgit avec « DANGER N ».
          _flash = i + 2; // le danger 1 démarre l'épisode, on est aux 2/3/4
          _flashTimer?.cancel();
          _flashTimer = Timer(const Duration(milliseconds: 2400), () {
            if (mounted) setState(() => _flash = null);
          });
        }
      }
      if (_resteMs <= 0) {
        _resteMs = 0;
        t.cancel();
        _versBilan();
      }
    });
  }

  String get _fmt {
    final s = (_resteMs / 1000).ceil();
    final m = s ~/ 60;
    final r = s % 60;
    return '${m.toString().padLeft(2, '0')}:${r.toString().padLeft(2, '0')}';
  }

  void _versBilan() {
    _timer?.cancel();
    widget.transcription?.arreter();
    setState(() => _peutSortir = true);
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => BilanScreen(
        store: widget.store,
        campagne: widget.campagne,
        episode: widget.episode,
        audioService: widget.audioService,
        transcription: widget.transcription?.texte ?? '',
      ),
    ));
  }

  Future<bool> _confirmerQuitter() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('On arrête l\'épisode ?'),
        content: const Text('Ce qui a été joué ne sera pas gardé.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Continuer')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Arrêter')),
        ],
      ),
    );
    return ok ?? false;
  }

  /// Légende simple des icônes de combat (bouton « i » de la barre du haut).
  void _expliquerCombat() {
    Widget ligne(IconData ic, Color col, String titre, String texte) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(ic, color: col, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(TextSpan(children: [
                  TextSpan(
                      text: '$titre — ',
                      style: TextStyle(
                          color: col, fontWeight: FontWeight.w800)),
                  TextSpan(
                      text: texte,
                      style: const TextStyle(color: Colors.white70)),
                ])),
              ),
            ],
          ),
        );
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1530),
        title: const Text('Le combat, en un coup d\'œil',
            style: TextStyle(color: Colors.white, fontSize: 18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
                'Tapez une icône à côté d\'un personnage pour changer son état.',
                style: TextStyle(color: Colors.white54, fontSize: 13)),
            const SizedBox(height: 8),
            ligne(Icons.favorite, Colors.redAccent, 'Cœur rouge',
                'en forme. Tapez pour passer blessé, puis mort, puis de nouveau en forme.'),
            ligne(Icons.heart_broken, Colors.orangeAccent, 'Cœur brisé',
                'le personnage est blessé.'),
            ligne(Icons.favorite_border, Colors.white38, 'Cœur vidé',
                'le personnage est mort (son nom est barré).'),
            ligne(Icons.remove_circle_outline, Colors.orangeAccent, 'Moins',
                'malus : le personnage est affaibli (−1, −2…).'),
            ligne(Icons.add_circle_outline, const Color(0xFF66BB6A), 'Plus',
                'bonus : le personnage est renforcé (+1, +2…).'),
          ],
        ),
        actions: [
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Compris')),
        ],
      ),
    );
  }

  /// Contrôles de combat d'un personnage, tous sur UNE ligne, à côté de lui :
  /// cœur (en forme → blessé → mort) · − malus · valeur · + bonus.
  Widget _combatInline(String id) {
    final e = _etat(id);
    // Zone tactile de 40×40 (confort de tap), icône visuelle plus petite au
    // centre. Un léger retour haptique confirme chaque action.
    Widget mini(IconData ic, Color col, bool on, VoidCallback mut) => InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(mut);
          },
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(ic,
                size: 20,
                color: on ? col : Colors.white.withValues(alpha: 0.32)),
          ),
        );
    // Cœur à 3 états, distincts PAR LA FORME (et pas seulement la couleur) :
    // plein rouge (en forme) → brisé orange (blessé) → contour éteint (mort).
    final IconData coeurIcon;
    final Color coeurColor;
    if (e.mort) {
      coeurIcon = Icons.favorite_border; // contour = vidé / éteint
      coeurColor = Colors.white38;
    } else if (e.blesse) {
      coeurIcon = Icons.heart_broken; // brisé
      coeurColor = Colors.orangeAccent;
    } else {
      coeurIcon = Icons.favorite; // plein, rouge, en forme
      coeurColor = Colors.redAccent;
    }
    final modColor = e.mod > 0
        ? const Color(0xFF66BB6A)
        : (e.mod < 0 ? Colors.orangeAccent : Colors.white38);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _cyclerSante(e));
          },
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(coeurIcon, size: 20, color: coeurColor),
          ),
        ),
        mini(Icons.remove_circle_outline, Colors.orangeAccent, e.mod < 0,
            () => e.mod--),
        SizedBox(
          width: 22,
          child: Text(
              e.mod == 0 ? '0' : (e.mod > 0 ? '+${e.mod}' : '${e.mod}'),
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: modColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w800)),
        ),
        mini(Icons.add_circle_outline, const Color(0xFF66BB6A), e.mod > 0,
            () => e.mod++),
      ],
    );
  }

  /// Raye le nom d'un personnage mort (barré). Sinon aucune décoration.
  TextDecoration? _rayeSiMort(String id) =>
      (_etats[id]?.mort ?? false) ? TextDecoration.lineThrough : null;

  /// Fait avancer l'état de santé du cœur : en forme → blessé → mort → en forme.
  void _cyclerSante(EtatPerso e) {
    if (!e.blesse && !e.mort) {
      e.blesse = true; // en forme → blessé
    } else if (e.blesse && !e.mort) {
      e.blesse = false;
      e.mort = true; // blessé → mort
    } else {
      e.mort = false;
      e.blesse = false; // mort → en forme
    }
  }

  @override
  Widget build(BuildContext context) {
    final ep = widget.episode;
    // canPop=false intercepte aussi le pop programmatique : on passe canPop à
    // true, on attend la fin de frame, puis on sort (sinon boucle infinie).
    return PopScope(
      canPop: _peutSortir,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmerQuitter() && mounted) {
          setState(() => _peutSortir = true);
          await Future<void>.delayed(Duration.zero);
          if (mounted) Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0818),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(_fmt,
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                  color: _rouge ? const Color(0xFFFF5252) : null)),
          actions: [
            if (widget.transcription?.ecoute ?? false)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Row(children: [
                  Icon(Icons.mic, color: _escC, size: 18),
                  SizedBox(width: 4),
                  Text('transcription',
                      style: TextStyle(color: _escC, fontSize: 12)),
                ]),
              ),
            IconButton(
              tooltip: 'À quoi servent les icônes de combat ?',
              icon: const Icon(Icons.info_outline, color: Colors.white54),
              onPressed: _expliquerCombat,
            ),
          ],
        ),
        body: Stack(children: [
          ListView(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
          children: [
            if (_micRaison.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _escC.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Le micro n\'a pas démarré ($_micRaison). L\'épisode continue '
                  'normalement ; l\'autorisation se donne dans les réglages du '
                  'téléphone.',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            // Lieu + figurants : côte à côte sur écran large, empilés sur
            // téléphone (sinon la carte figurants + ses contrôles se tassent
            // et le texte se replie mot par mot).
            LayoutBuilder(builder: (context, c) {
              if (c.maxWidth >= 560) {
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _carteLieu(ep)),
                      const SizedBox(width: 10),
                      Expanded(child: _carteFigurants(ep)),
                    ],
                  ),
                );
              }
              return Column(
                children: [
                  _carteLieu(ep),
                  const SizedBox(height: 10),
                  _carteFigurants(ep),
                ],
              );
            }),
            const SizedBox(height: 10),
            _carteMechant(ep),
            const SizedBox(height: 10),
            _carteEscalade(ep),
            const SizedBox(height: 10),
            _carteRoles(ep),
            const SizedBox(height: 16),
            // Outils du MJ : la Pièce du destin (vedette) et la Régie son.
            // (Le combat se gère directement à côté de chaque personnage.)
            // IntrinsicHeight + stretch → les deux boutons ont la même taille.
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _boutonMJ(
                      customLead: _pieceDestin(),
                      label: 'Destin',
                      couleur: _roleC,
                      onTap: _lancerPiece,
                      vedette: true, // la pièce, mise en avant (couleur/halo)
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _boutonMJ(
                      icon: Icons.tune,
                      label: 'Régie',
                      couleur: _mechC,
                      onTap: () =>
                          showSoundMixer(context, widget.musicController),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _versBilan,
              icon: const Icon(Icons.flag_outlined),
              label: const Text('On arrête là'),
            ),
          ],
          ),
          // DestinyCubeAnimation renvoie un Positioned.fill (mode scrim) : il
          // DOIT être un enfant direct du Stack. L'emballer dans un
          // Positioned.fill/LayoutBuilder plantait l'écran (ParentDataWidget)
          // au déclenchement du danger minuté.
          if (_flash != null)
            DestinyCubeAnimation(
              key: ValueKey('danger_$_flash'),
              size: (MediaQuery.of(context).size.shortestSide * 0.55)
                  .clamp(180.0, 360.0)
                  .toDouble(),
              label: 'DANGER $_flash',
              fullscreenScrim: true,
              holdAtEnd: true,
            ),
          if (_piece)
            Positioned.fill(
              child: LayoutBuilder(builder: (context, c) {
                final size = (c.biggest.shortestSide * 0.6)
                    .clamp(180.0, 320.0)
                    .toDouble();
                return PieceDestinFlip(
                  // Clé unique par tirage → l'animation se relance à chaque fois.
                  key: ValueKey(_pieceNo),
                  brave: _pieceBrave,
                  size: size,
                  onFini: () {
                    if (mounted) setState(() => _piece = false);
                  },
                );
              }),
            ),
        ]),
      ),
    );
  }

  Widget _carte(Color c, String titre, Widget corps) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(titre.toUpperCase(),
                style: TextStyle(
                    color: c,
                    letterSpacing: 2,
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            corps,
          ],
        ),
      );

  Widget _carteLieu(Episode ep) => _carte(
        _lieuC,
        'Le lieu',
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ep.lieu.nom,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(ep.lieu.description,
                style: const TextStyle(color: Colors.white60, fontSize: 13)),
            const SizedBox(height: 8),
            for (final e in ep.lieu.espaces)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('• ${e.nom}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ),
          ],
        ),
      );

  Widget _carteFigurants(Episode ep) => _carte(
        _figC,
        'Les figurants',
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var fi = 0; fi < ep.figurants.length; fi++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                        _visages[ep.figurants[fi].visage % _visages.length],
                        color: _figC,
                        size: 26),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ep.figurants[fi].role,
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  decoration: _rayeSiMort('f$fi'))),
                          Text(
                              '${emojiArchetype(ep.figurants[fi].archetype.id)} ${ep.figurants[fi].archetype.nom}',
                              style: TextStyle(
                                  color: couleurStatut(
                                      ep.figurants[fi].archetype.statut),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                          Text(ep.figurants[fi].objectif,
                              style: const TextStyle(
                                  color: _figC, fontSize: 12, height: 1.3)),
                        ],
                      ),
                    ),
                    // Contrôles de combat à droite, en fin de ligne (comme les joueurs).
                    _combatInline('f$fi'),
                  ],
                ),
              ),
          ],
        ),
      );

  Widget _carteMechant(Episode ep) => _carte(
        _mechC,
        'Le méchant',
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(ep.mechant.nom,
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        decoration: _rayeSiMort('m'))),
              ),
              _combatInline('m'),
            ]),
            const SizedBox(height: 4),
            Text(ep.mechant.description,
                style: const TextStyle(color: Colors.white60, fontSize: 13)),
            const SizedBox(height: 8),
            Text('Ce qu\'il veut : ${ep.mechant.but}',
                style: const TextStyle(color: Colors.white, height: 1.3)),
            if (ep.mechant.sbires.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (var si = 0; si < ep.mechant.sbires.length; si++)
                Row(children: [
                  Expanded(
                    child: Text(
                        '· ${ep.mechant.sbires[si].nom} — ${ep.mechant.sbires[si].description}',
                        style: TextStyle(
                            color: Colors.white54,
                            fontSize: 13,
                            decoration: _rayeSiMort('s$si'))),
                  ),
                  _combatInline('s$si'),
                ]),
            ],
          ],
        ),
      );

  Widget _carteEscalade(Episode ep) => _carte(
        _escC,
        'L\'escalade',
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < ep.escalade.length; i++)
              Builder(builder: (_) {
                final m = ep.escalade[i];
                final tombe = _tombes.contains(i);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Opacity(
                    opacity: tombe ? 1 : 0.4,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(tombe ? Icons.bolt : Icons.circle_outlined,
                            size: 18, color: _escC),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text.rich(TextSpan(children: [
                            TextSpan(
                                text: '${m.quiAgit} : ',
                                style: TextStyle(
                                    color: tombe ? _escC : Colors.white54,
                                    fontWeight: FontWeight.w700)),
                            TextSpan(
                                text: m.ceQueCaProduit,
                                style: TextStyle(
                                    color: tombe
                                        ? Colors.white
                                        : Colors.white38,
                                    height: 1.3)),
                          ])),
                        ),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      );

  Widget _carteRoles(Episode ep) => _carte(
        _roleC,
        'Les rôles',
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < ep.roles.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text.rich(TextSpan(children: [
                        TextSpan(
                            text:
                                '${ep.roles[i].joueur.isEmpty ? 'Joueur ${i + 1}' : ep.roles[i].joueur} — ',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                decoration: _rayeSiMort('j$i'))),
                        TextSpan(
                            text: ep.roles[i].role,
                            style: const TextStyle(color: Colors.white70)),
                        if (ep.roles[i].peuple.isNotEmpty)
                          TextSpan(
                              text: ' · ${ep.roles[i].peuple}',
                              style: const TextStyle(
                                  color: _lieuC,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                        TextSpan(
                            text: '  ${emojiArchetype(ep.roles[i].archetype.id)} ',
                            style: const TextStyle(fontSize: 14)),
                        TextSpan(
                            text: ep.roles[i].archetype.nom,
                            style: TextStyle(
                                color: couleurStatut(
                                    ep.roles[i].archetype.statut),
                                fontWeight: FontWeight.w700,
                                fontSize: 13)),
                        TextSpan(
                            text: ' · ${ep.roles[i].archetype.moteur}',
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 13)),
                      ])),
                    ),
                    _combatInline('j$i'),
                  ],
                ),
              ),
          ],
        ),
      );

  static const List<IconData> _visages = [
    Icons.face,
    Icons.face_2,
    Icons.face_3,
    Icons.face_4,
    Icons.face_5,
    Icons.face_6,
  ];
}

/// État de combat d'un personnage, tenu par le MJ pendant l'épisode.
class EtatPerso {
  bool mort = false;
  bool blesse = false;
  int mod = 0; // bonus (+) / malus (-)
  bool get actif => mort || blesse || mod != 0;
}

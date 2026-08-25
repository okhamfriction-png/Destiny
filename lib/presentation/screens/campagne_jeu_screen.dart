import 'dart:async';

import 'package:flutter/material.dart';

import '../../application/services/audio_service.dart';
import '../../application/services/transcription_service.dart';
import '../../application/state/campagne_store.dart';
import '../../application/state/music_controller.dart';
import '../../domain/entities/campagne.dart';
import '../visuals/campagne_visuals.dart';
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
          widget.audioService.playShine(); // son court et net
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

  void _ouvrirCombat() {
    final ep = widget.episode;
    // (groupe, id, libellé) pour chaque personnage.
    final persos = <(String, String, String)>[
      for (var i = 0; i < ep.roles.length; i++)
        ('Joueurs', 'j$i', '${ep.roles[i].joueur} — ${ep.roles[i].role}'),
      for (var f = 0; f < ep.figurants.length; f++)
        ('Figurants', 'f$f', ep.figurants[f].role),
      ('Méchant & sbires', 'm', ep.mechant.nom),
      for (var s = 0; s < ep.mechant.sbires.length; s++)
        ('Méchant & sbires', 's$s', ep.mechant.sbires[s].nom),
    ];
    final groupes = <String>[];
    for (final p in persos) {
      if (!groupes.contains(p.$1)) groupes.add(p.$1);
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF120F1E),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => StatefulBuilder(builder: (context, setSheet) {
        Widget ligne(String id, String label) {
          final e = _etat(id);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Expanded(
                  child: Text(label,
                      style: TextStyle(
                          color: e.mort ? Colors.white38 : Colors.white,
                          decoration:
                              e.mort ? TextDecoration.lineThrough : null)),
                ),
                _btn(e.mort ? Icons.heart_broken : Icons.favorite,
                    e.mort ? Colors.redAccent : const Color(0xFF66BB6A),
                    e.mort ? 'Ressusciter' : 'Marquer mort',
                    () => setSheet(() => e.mort = !e.mort)),
                _btn(Icons.healing,
                    e.blesse ? Colors.orangeAccent : Colors.white24,
                    'Blessé', () => setSheet(() => e.blesse = !e.blesse)),
                _btn(Icons.remove_circle_outline, Colors.white54, 'Malus',
                    () => setSheet(() => e.mod--)),
                SizedBox(
                  width: 30,
                  child: Text(
                      e.mod == 0
                          ? '0'
                          : (e.mod > 0 ? '+${e.mod}' : '${e.mod}'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: e.mod > 0
                              ? const Color(0xFF66BB6A)
                              : (e.mod < 0 ? Colors.orangeAccent : Colors.white54),
                          fontWeight: FontWeight.w700)),
                ),
                _btn(Icons.add_circle_outline, Colors.white54, 'Bonus',
                    () => setSheet(() => e.mod++)),
              ],
            ),
          );
        }

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          minChildSize: 0.4,
          maxChildSize: 0.94,
          builder: (context, scroll) => ListView(
            controller: scroll,
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
            children: [
              Center(
                child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 12),
              const Text('Combat',
                  style: TextStyle(
                      color: _escC, fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text(
                  'Vie / mort, blessures, bonus et malus. Le MJ garde la main.',
                  style: TextStyle(color: Colors.white54, fontSize: 13)),
              for (final g in groupes) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 4),
                  child: Text(g.toUpperCase(),
                      style: const TextStyle(
                          color: _figC,
                          letterSpacing: 2,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ),
                for (final p in persos.where((x) => x.$1 == g))
                  ligne(p.$2, p.$3),
              ],
            ],
          ),
        );
      }),
    ).then((_) {
      if (mounted) setState(() {}); // reflète les états sur les cartes
    });
  }

  Widget _btn(IconData icon, Color color, String tip, VoidCallback onTap) =>
      IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: tip,
          icon: Icon(icon, color: color, size: 20),
          onPressed: onTap);

  /// Petit badge d'état (💀 mort, 🩹 blessé, +n/-n) à côté d'un personnage.
  Widget _badge(String id) {
    final e = _etats[id];
    if (e == null || !e.actif) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Text(
        [
          if (e.mort) '💀',
          if (e.blesse) '🩹',
          if (e.mod != 0) (e.mod > 0 ? '+${e.mod}' : '${e.mod}'),
        ].join(' '),
        style: TextStyle(
            fontSize: 12,
            color: e.mort ? Colors.redAccent : Colors.orangeAccent,
            fontWeight: FontWeight.w700),
      ),
    );
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
              tooltip: 'Combat (vie / blessures / bonus-malus)',
              icon: const Icon(Icons.shield, color: _escC),
              onPressed: _ouvrirCombat,
            ),
            IconButton(
              tooltip: 'Régie son',
              icon: const Icon(Icons.tune, color: _mechC),
              onPressed: () => showSoundMixer(context, widget.musicController),
            ),
          ],
        ),
        body: ListView(
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
            // Lieu + figurants côte à côte.
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: _carteLieu(ep)),
                  const SizedBox(width: 10),
                  Expanded(child: _carteFigurants(ep)),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _carteMechant(ep),
            const SizedBox(height: 10),
            _carteEscalade(ep),
            const SizedBox(height: 10),
            _carteRoles(ep),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _versBilan,
              icon: const Icon(Icons.flag_outlined),
              label: const Text('On arrête là'),
            ),
          ],
        ),
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
                          Row(children: [
                            Flexible(
                              child: Text(ep.figurants[fi].role,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700)),
                            ),
                            _badge('f$fi'),
                          ]),
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
              Flexible(
                child: Text(ep.mechant.nom,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800)),
              ),
              _badge('m'),
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
                  Flexible(
                    child: Text(
                        '· ${ep.mechant.sbires[si].nom} — ${ep.mechant.sbires[si].description}',
                        style: const TextStyle(
                            color: Colors.white54, fontSize: 13)),
                  ),
                  _badge('s$si'),
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
                            text: '${ep.roles[i].joueur} — ',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700)),
                        TextSpan(
                            text: ep.roles[i].role,
                            style: const TextStyle(color: Colors.white70)),
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
                    _badge('j$i'),
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

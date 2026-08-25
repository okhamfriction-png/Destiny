import 'dart:async';

import 'package:flutter/material.dart';

import '../../application/services/audio_service.dart';
import '../../application/services/transcription_service.dart';
import '../../application/state/campagne_store.dart';
import '../../application/state/music_controller.dart';
import '../../domain/entities/campagne.dart';
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

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), _battement);
    _demarrerMicro();
  }

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
      for (var i = 0; i < widget.horairesMs.length; i++) {
        if (!_tombes.contains(i) && ecoule >= widget.horairesMs[i]) {
          _tombes.add(i);
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
              style: const TextStyle(
                  fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 2)),
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
            for (final f in ep.figurants)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(_visages[f.visage % _visages.length],
                        color: _figC, size: 26),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(f.role,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700)),
                          Text(f.archetype.nom,
                              style: const TextStyle(
                                  color: Colors.white54, fontSize: 12)),
                          Text(f.objectif,
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
            Text(ep.mechant.nom,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(ep.mechant.description,
                style: const TextStyle(color: Colors.white60, fontSize: 13)),
            const SizedBox(height: 8),
            Text('Ce qu\'il veut : ${ep.mechant.but}',
                style: const TextStyle(color: Colors.white, height: 1.3)),
            if (ep.mechant.sbires.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final s in ep.mechant.sbires)
                Text('· ${s.nom} — ${s.description}',
                    style: const TextStyle(color: Colors.white54, fontSize: 13)),
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
            for (final r in ep.roles)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text.rich(TextSpan(children: [
                  TextSpan(
                      text: '${r.joueur} — ',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700)),
                  TextSpan(
                      text: r.role,
                      style: const TextStyle(color: Colors.white70)),
                  TextSpan(
                      text: '  (${r.archetype.nom} · ${r.archetype.moteur})',
                      style: const TextStyle(color: _roleC, fontSize: 13)),
                ])),
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

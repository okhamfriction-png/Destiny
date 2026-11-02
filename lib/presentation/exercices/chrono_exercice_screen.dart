import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../application/services/audio_service.dart';
import '../destiny/donnees.dart';
import '../theme/destiny_theme.dart';

/// Le chrono d'un exercice : la consigne en grand, le temps qui reste, et une
/// célébration à la fin. Sans score.
class ChronoExerciceScreen extends StatefulWidget {
  const ChronoExerciceScreen({
    required this.titre,
    required this.consigne,
    required this.secondes,
    required this.audio,
    this.icone = Icons.timer_outlined,
    this.couleur,
    super.key,
  });

  final String titre;
  final String consigne;
  final int secondes;
  final AudioService audio;
  final IconData icone;
  final Color? couleur;

  @override
  State<ChronoExerciceScreen> createState() => _ChronoExerciceScreenState();
}

class _ChronoExerciceScreenState extends State<ChronoExerciceScreen> {
  late int _reste = widget.secondes;
  Timer? _timer;
  bool _enCours = false;
  bool _fini = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _basculer() {
    if (_fini) return;
    setState(() => _enCours = !_enCours);
    _timer?.cancel();
    if (!_enCours) return;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() {
        _reste--;
        if (_reste <= 0) {
          _reste = 0;
          _enCours = false;
          _fini = true;
          t.cancel();
          widget.audio.playShine();
        }
      });
    });
  }

  void _rejouer() {
    _timer?.cancel();
    setState(() {
      _reste = widget.secondes;
      _fini = false;
      _enCours = false;
    });
  }

  String get _temps {
    final m = _reste ~/ 60;
    final s = _reste % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.textes;
    final c = context.destiny;
    final couleur = widget.couleur ?? c.titre;
    String k(String x) => t.t('exercices.$x');
    return Scaffold(
      body: Stack(children: [
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
            child: Column(children: [
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  tooltip: k('fermer'),
                  icon: Icon(Icons.close_rounded, color: c.texteSecondaire),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(widget.icone, color: couleur, size: 40),
                      const SizedBox(height: 12),
                      Text(
                        widget.titre,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontFamily: kPoliceTitres, fontSize: 26, fontWeight: FontWeight.w900, color: c.texte),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        widget.consigne,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontFamily: kPoliceTexte, fontSize: 16.5, height: 1.4, color: c.texteSecondaire),
                      ),
                      const SizedBox(height: 32),
                      FittedBox(
                        child: Text(
                          _fini ? k('bravo') : _temps,
                          style: TextStyle(
                            fontFamily: kPoliceTitres,
                            color: _fini ? c.titre : couleur,
                            fontSize: _fini ? 60 : 84,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _fini ? k('termine') : (_enCours ? k('parti') : k('prets')),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontFamily: kPoliceTexte, fontSize: 16, color: c.texteSecondaire),
                      ),
                    ]),
                  ),
                ),
              ),
              if (!_fini)
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _basculer,
                    icon: Icon(_enCours ? Icons.pause_rounded : Icons.play_arrow_rounded),
                    label: Text(_enCours ? k('pause') : k('demarrer')),
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  ),
                )
              else
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _rejouer,
                      icon: const Icon(Icons.replay_rounded, size: 18),
                      label: Text(k('rejouer')),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(k('terminer')),
                    ),
                  ),
                ]),
            ]),
          ),
        ),
        if (_fini) const Positioned.fill(child: IgnorePointer(child: _Confettis())),
      ]),
    );
  }
}

/// Une pluie de confettis, une seule passe.
class _Confettis extends StatefulWidget {
  const _Confettis();

  @override
  State<_Confettis> createState() => _ConfettisState();
}

class _ConfettisState extends State<_Confettis> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))..forward();
  List<_Particule>? _parts;

  List<_Particule> _creer(DestinyCouleurs c) {
    final rng = Random();
    final couleurs = [c.or, c.orClair, c.bleuDestiny, ...c.familles.values, Colors.white];
    return List.generate(90, (_) {
      return _Particule(
        x: rng.nextDouble(),
        delai: rng.nextDouble() * 0.35,
        vitesse: 0.7 + rng.nextDouble() * 0.6,
        derive: (rng.nextDouble() - 0.5) * 0.3,
        taille: 6 + rng.nextDouble() * 8,
        couleur: couleurs[rng.nextInt(couleurs.length)],
        rotation: rng.nextDouble() * 6.28,
      );
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final parts = _parts ??= _creer(context.destiny);
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => CustomPaint(painter: _PeintreConfettis(parts, _c.value)),
    );
  }
}

class _Particule {
  const _Particule({
    required this.x,
    required this.delai,
    required this.vitesse,
    required this.derive,
    required this.taille,
    required this.couleur,
    required this.rotation,
  });
  final double x, delai, vitesse, derive, taille, rotation;
  final Color couleur;
}

class _PeintreConfettis extends CustomPainter {
  _PeintreConfettis(this.parts, this.t);
  final List<_Particule> parts;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in parts) {
      final local = ((t - p.delai) / (1 - p.delai)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final y = (local * p.vitesse) * (size.height + 40) - 20;
      final x = (p.x + p.derive * local) * size.width;
      final pinceau = Paint()..color = p.couleur.withValues(alpha: (1 - local).clamp(0.0, 1.0));
      canvas
        ..save()
        ..translate(x, y)
        ..rotate(p.rotation + local * 6)
        ..drawRect(Rect.fromCenter(center: Offset.zero, width: p.taille, height: p.taille * 0.5), pinceau)
        ..restore();
    }
  }

  @override
  bool shouldRepaint(covariant _PeintreConfettis old) => old.t != t;
}

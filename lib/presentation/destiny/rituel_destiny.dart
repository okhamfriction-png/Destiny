import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../domain/troupe/annonce_destiny.dart';
import '../theme/destiny_theme.dart';
import 'donnees.dart';

/// Les réglages du rituel (section « Destiny » des réglages).
class ReglagesRituel {
  const ReglagesRituel({
    this.lumiereBleue = true,
    this.dureeFige = const Duration(seconds: 4),
    this.reduireAnimations = false,
  });

  final bool lumiereBleue;

  /// Le temps de la lumière bleue, avant l'annonce.
  final Duration dureeFige;
  final bool reduireAnimations;
}

/// Lance le rituel DESTINY en plein écran : l'éclair, la lumière bleue, puis
/// l'annonce, qui se ferme seule. Aucun bouton, aucune question : l'acte
/// suivant repart tout seul.
///
/// [auTonnerre] est appelé au début (le son DESTINY : le tonnerre et le
/// rire). [aLAnnonce] est appelé quand l'annonce s'affiche (la voix).
Future<void> lancerRituelDestiny(
  BuildContext context, {
  required AnnonceDestiny annonce,
  ReglagesRituel reglages = const ReglagesRituel(),
  VoidCallback? auTonnerre,
  VoidCallback? aLAnnonce,
}) {
  return Navigator.of(context).push(PageRouteBuilder<void>(
    opaque: false,
    barrierDismissible: false,
    transitionDuration: Duration.zero,
    reverseTransitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (_, __, ___) => RituelDestiny(
      annonce: annonce,
      reglages: reglages,
      auTonnerre: auTonnerre,
      aLAnnonce: aLAnnonce,
    ),
    transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
  ));
}

/// Les étapes du rituel.
enum EtapeRituel { tonnerre, rire, lumiere, fige, annonce }

class RituelDestiny extends StatefulWidget {
  const RituelDestiny({
    super.key,
    required this.annonce,
    this.reglages = const ReglagesRituel(),
    this.auTonnerre,
    this.aLAnnonce,
  });

  final AnnonceDestiny annonce;
  final ReglagesRituel reglages;
  final VoidCallback? auTonnerre;
  final VoidCallback? aLAnnonce;

  @override
  State<RituelDestiny> createState() => _RituelDestinyState();
}

class _RituelDestinyState extends State<RituelDestiny> with SingleTickerProviderStateMixin {
  EtapeRituel _etape = EtapeRituel.tonnerre;
  late final AnimationController _secousse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  final List<Timer> _minuteurs = [];

  bool get _reduit => widget.reglages.reduireAnimations || MediaQuery.maybeDisableAnimationsOf(context) == true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _derouler());
  }

  void _derouler() {
    widget.auTonnerre?.call();
    if (!_reduit) _secousse.forward();
    final rapide = _reduit;
    final finFige = (rapide ? 700 : 2300) + widget.reglages.dureeFige.inMilliseconds;
    final etapes = <(Duration, EtapeRituel)>[
      (Duration(milliseconds: rapide ? 200 : 700), EtapeRituel.rire),
      (Duration(milliseconds: rapide ? 400 : 1500), EtapeRituel.lumiere),
      (Duration(milliseconds: rapide ? 700 : 2300), EtapeRituel.fige),
      (Duration(milliseconds: finFige), EtapeRituel.annonce),
      // L'annonce se ferme seule : l'acte suivant est déjà parti.
      (Duration(milliseconds: finFige) + widget.annonce.duree, EtapeRituel.annonce),
    ];
    for (final (i, (delai, etape)) in etapes.indexed) {
      final fin = i == etapes.length - 1;
      _minuteurs.add(Timer(delai, () {
        if (!mounted) return;
        if (fin) {
          _fermer();
        } else {
          _aller(etape);
        }
      }));
    }
  }

  void _aller(EtapeRituel etape) {
    setState(() => _etape = etape);
    if (etape == EtapeRituel.annonce) widget.aLAnnonce?.call();
  }

  void _fermer() {
    final route = ModalRoute.of(context);
    if (route == null || !route.isActive) return;
    final nav = Navigator.of(context);
    route.isCurrent ? nav.pop() : nav.removeRoute(route);
  }

  @override
  void dispose() {
    for (final t in _minuteurs) {
      t.cancel();
    }
    _secousse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.destiny;
    final avance = _etape.index;
    final voile = widget.reglages.lumiereBleue && avance >= EtapeRituel.lumiere.index;
    final fige = avance >= EtapeRituel.fige.index;

    final flou = fige && !_reduit
        ? ui.ImageFilter.compose(
            outer: const ColorFilter.matrix(<double>[
              0.33, 0.59, 0.11, 0, 0, //
              0.33, 0.59, 0.11, 0, 0,
              0.33, 0.59, 0.11, 0, 0,
              0, 0, 0, 1, 0,
            ]),
            inner: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4),
          )
        : ui.ImageFilter.blur(sigmaX: 0.01, sigmaY: 0.01);

    return AnimatedBuilder(
      animation: _secousse,
      builder: (context, child) {
        final v = _secousse.value;
        final dx = _reduit ? 0.0 : math.sin(v * math.pi * 10) * 9 * (1 - v);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: Material(
        key: const ValueKey('rituel_destiny'),
        type: MaterialType.transparency,
        child: Stack(fit: StackFit.expand, children: [
          // L'écran derrière se fige (flou et désaturé).
          BackdropFilter(filter: flou, child: const SizedBox.expand()),
          // L'éclair du tonnerre.
          AnimatedOpacity(
            opacity: _etape == EtapeRituel.tonnerre && !_reduit ? 0.75 : 0,
            duration: const Duration(milliseconds: 180),
            child: const ColoredBox(color: Colors.white),
          ),
          // La lumière bleue.
          AnimatedOpacity(
            opacity: voile || _etape == EtapeRituel.annonce ? 0.62 : 0,
            duration: Duration(milliseconds: _reduit ? 150 : 700),
            child: ColoredBox(color: c.bleuDestiny),
          ),
          if (_etape == EtapeRituel.annonce) const ColoredBox(color: Color(0x88000000)),
          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: AnimatedSwitcher(
                  duration: Duration(milliseconds: _reduit ? 120 : 500),
                  child: _contenu(context),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _contenu(BuildContext context) {
    final c = context.destiny;
    final t = context.textes;
    final style = TextStyle(
      fontFamily: kPoliceTitres,
      fontWeight: FontWeight.w900,
      color: Colors.white,
      shadows: [Shadow(color: c.bleuDestiny, blurRadius: 18)],
    );
    if (_etape != EtapeRituel.annonce) {
      return Text(t.t('rituel.titre').toUpperCase(),
          key: const ValueKey('destiny'), style: style.copyWith(fontSize: 54, letterSpacing: 8));
    }
    final a = widget.annonce;
    final titre = a.titre();
    return Column(key: const ValueKey('annonce_destiny'), mainAxisSize: MainAxisSize.min, children: [
      if (titre.isNotEmpty)
        Text(titre.toUpperCase(),
            key: const ValueKey('annonce_titre'),
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: kPoliceTexte, letterSpacing: 3, fontSize: 15, color: c.orClair)),
      const SizedBox(height: 10),
      Text(
        a.phrase(t.t),
        key: const ValueKey('annonce_phrase'),
        textAlign: TextAlign.center,
        // Les survivants : la police du texte, où « 1 » ne se lit pas « I ».
        style: a.survivants == null
            ? style.copyWith(fontSize: 40)
            : style.copyWith(fontFamily: kPoliceTexte, fontSize: 34),
      ),
    ]);
  }
}

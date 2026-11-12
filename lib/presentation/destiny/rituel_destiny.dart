import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../domain/grammaire/modeles.dart';
import '../../domain/grammaire/progression.dart';
import '../theme/destiny_theme.dart';
import 'donnees.dart';

/// Les réglages du rituel (section « Destiny » des réglages).
class ReglagesRituel {
  const ReglagesRituel({
    this.lumiereBleue = true,
    this.dureeFige = const Duration(seconds: 4),
    this.texteEllipse,
    this.reduireAnimations = false,
    this.rappelPremierFige = true,
    this.fermetureAuto = const Duration(seconds: 10),
  });

  /// La carte de l'acte se ferme seule après ce temps sans action (null :
  /// elle attend « Reprendre »).
  final Duration? fermetureAuto;

  final bool lumiereBleue;
  final Duration dureeFige;

  /// Texte d'ellipse (par défaut celui des textes de l'appli).
  final String? texteEllipse;
  final bool reduireAnimations;
  final bool rappelPremierFige;
}

/// Lance le rituel Destiny en plein écran : le tonnerre, le rire, la lumière
/// bleue, le figé, l'ellipse, puis la carte du nouveau palier. Rend la main
/// quand la régie appuie sur « Reprendre ».
///
/// [auTonnerre] est appelé au début (c'est là qu'on joue le son Destiny :
/// le tonnerre et le rire). [nouvelle] est la nouvelle du palier, à souffler à
/// l'alarmiste.
Future<void> lancerRituelDestiny(
  BuildContext context, {
  required PalierId nouveauPalier,
  String? nouvelle,
  bool premierFige = false,
  ReglagesRituel reglages = const ReglagesRituel(),
  VoidCallback? auTonnerre,
}) {
  return Navigator.of(context).push(PageRouteBuilder<void>(
    opaque: false,
    barrierDismissible: false,
    transitionDuration: Duration.zero,
    reverseTransitionDuration: const Duration(milliseconds: 250),
    pageBuilder: (_, __, ___) => RituelDestiny(
      nouveauPalier: nouveauPalier,
      nouvelle: nouvelle,
      premierFige: premierFige,
      reglages: reglages,
      auTonnerre: auTonnerre,
    ),
    transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
  ));
}

/// Les étapes du rituel.
enum EtapeRituel { tonnerre, rire, lumiere, fige, ellipse, palier }

class RituelDestiny extends StatefulWidget {
  const RituelDestiny({
    super.key,
    required this.nouveauPalier,
    this.nouvelle,
    this.premierFige = false,
    this.reglages = const ReglagesRituel(),
    this.auTonnerre,
  });

  final PalierId nouveauPalier;
  final String? nouvelle;
  final bool premierFige;
  final ReglagesRituel reglages;
  final VoidCallback? auTonnerre;

  @override
  State<RituelDestiny> createState() => _RituelDestinyState();
}

class _RituelDestinyState extends State<RituelDestiny> with SingleTickerProviderStateMixin {
  EtapeRituel _etape = EtapeRituel.tonnerre;
  late final AnimationController _secousse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  final List<Timer> _minuteurs = [];
  Timer? _fermeture;

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
    final fige = widget.reglages.dureeFige;
    final etapes = <(Duration, EtapeRituel)>[
      (Duration(milliseconds: rapide ? 200 : 700), EtapeRituel.rire),
      (Duration(milliseconds: rapide ? 400 : 1500), EtapeRituel.lumiere),
      (Duration(milliseconds: rapide ? 700 : 2300), EtapeRituel.fige),
      (Duration(milliseconds: (rapide ? 700 : 2300) + fige.inMilliseconds), EtapeRituel.ellipse),
      (Duration(milliseconds: (rapide ? 1500 : 4300) + fige.inMilliseconds), EtapeRituel.palier),
    ];
    for (final (delai, etape) in etapes) {
      _minuteurs.add(Timer(delai, () {
        if (mounted) _aller(etape);
      }));
    }
  }

  /// Passe à [etape]. Sur la carte de l'acte, la fermeture automatique part.
  void _aller(EtapeRituel etape) {
    setState(() => _etape = etape);
    if (etape == EtapeRituel.palier) _relancerFermeture();
  }

  /// La carte se ferme seule après [ReglagesRituel.fermetureAuto] sans action :
  /// chaque toucher relance le compte.
  void _relancerFermeture() {
    final d = widget.reglages.fermetureAuto;
    if (d == null || _etape != EtapeRituel.palier) return;
    _fermeture?.cancel();
    _fermeture = Timer(d, () {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  @override
  void dispose() {
    _fermeture?.cancel();
    for (final t in _minuteurs) {
      t.cancel();
    }
    _secousse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.destiny;
    final g = context.grammaire;
    final t = context.textes;
    final palier = g.palier(widget.nouveauPalier);
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
      child: Listener(
        // Un toucher, c'est une action : la carte reste encore 10 s.
        onPointerDown: (_) => _relancerFermeture(),
        child: Material(
          type: MaterialType.transparency,
          child: Stack(fit: StackFit.expand, children: [
            // Le figé : l'écran derrière se fige (flou et désaturé).
            BackdropFilter(filter: flou, child: const SizedBox.expand()),
            // L'éclair du tonnerre.
            AnimatedOpacity(
              opacity: _etape == EtapeRituel.tonnerre && !_reduit ? 0.75 : 0,
              duration: const Duration(milliseconds: 180),
              child: const ColoredBox(color: Colors.white),
            ),
            // La lumière bleue.
            AnimatedOpacity(
              opacity: voile ? 0.62 : (avance >= EtapeRituel.ellipse.index ? 0.62 : 0),
              duration: Duration(milliseconds: _reduit ? 150 : 700),
              child: ColoredBox(color: c.bleuDestiny),
            ),
            if (avance >= EtapeRituel.ellipse.index) const ColoredBox(color: Color(0x88000000)),
            SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: AnimatedSwitcher(
                    duration: Duration(milliseconds: _reduit ? 120 : 500),
                    child: _contenu(context, palier),
                  ),
                ),
              ),
            ),
            // Pendant le figé : chaque étape du rituel, en petit.
            Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: _Frise(etape: _etape, libelles: t.liste('rituel.etapes_courtes')),
            ),
            if (_etape != EtapeRituel.palier)
              Positioned(
                top: 8,
                right: 8,
                child: SafeArea(
                  child: TextButton(
                    onPressed: () => _aller(EtapeRituel.palier),
                    style: TextButton.styleFrom(foregroundColor: Colors.white70),
                    child: const Icon(Icons.skip_next_rounded),
                  ),
                ),
              ),
          ]),
        ),
      ),
    );
  }

  Widget _contenu(BuildContext context, Palier palier) {
    final c = context.destiny;
    final g = context.grammaire;
    final t = context.textes;
    final style = TextStyle(
      fontFamily: kPoliceTitres,
      fontWeight: FontWeight.w900,
      color: Colors.white,
      shadows: [Shadow(color: c.bleuDestiny, blurRadius: 18)],
    );
    switch (_etape) {
      case EtapeRituel.tonnerre:
      case EtapeRituel.rire:
      case EtapeRituel.lumiere:
        return Text(t.t('rituel.titre').toUpperCase(),
            key: const ValueKey('destiny'), style: style.copyWith(fontSize: 54, letterSpacing: 8));
      case EtapeRituel.fige:
        return Column(key: const ValueKey('fige'), mainAxisSize: MainAxisSize.min, children: [
          Text(t.t('rituel.titre').toUpperCase(), style: style.copyWith(fontSize: 40, letterSpacing: 6)),
          if (widget.premierFige && widget.reglages.rappelPremierFige) ...[
            const SizedBox(height: 22),
            Text(
              g.rituel.premierFige,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: kPoliceTexte,
                fontSize: 18,
                height: 1.35,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ]);
      case EtapeRituel.ellipse:
        return Text(
          widget.reglages.texteEllipse ?? t.t('rituel.texte_ellipse'),
          key: const ValueKey('ellipse'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: kPoliceTexte,
            fontStyle: FontStyle.italic,
            fontSize: 24,
            color: Colors.white,
          ),
        );
      case EtapeRituel.palier:
        return _CartePalier(
          key: const ValueKey('palier'),
          palier: palier,
          nouvelle: widget.nouvelle,
          geste: gestePourActe(g, palier.acte)?.verbe,
          onReprendre: () => Navigator.of(context).maybePop(),
        );
    }
  }
}

class _Frise extends StatelessWidget {
  const _Frise({required this.etape, required this.libelles});

  final EtapeRituel etape;
  final List<String> libelles;

  @override
  Widget build(BuildContext context) {
    if (libelles.isEmpty || etape == EtapeRituel.palier) return const SizedBox.shrink();
    return Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [
      for (var i = 0; i < libelles.length; i++) ...[
        Text(
          libelles[i],
          style: TextStyle(
            fontFamily: kPoliceTexte,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: i <= etape.index ? Colors.white : Colors.white38,
          ),
        ),
        if (i < libelles.length - 1)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text('·', style: TextStyle(color: Colors.white38)),
          ),
      ],
    ]);
  }
}

class _CartePalier extends StatelessWidget {
  const _CartePalier({
    super.key,
    required this.palier,
    required this.nouvelle,
    required this.geste,
    required this.onReprendre,
  });

  final Palier palier;
  final String? nouvelle;
  final String? geste;
  final VoidCallback onReprendre;

  @override
  Widget build(BuildContext context) {
    final c = context.destiny;
    final t = context.textes;
    return Container(
      constraints: const BoxConstraints(maxWidth: 460),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: c.nuit.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.palier(palier.id), width: 2),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(
          t.t('rituel.acte', {'numero': '${palier.acte}'}).toUpperCase(),
          style: TextStyle(fontFamily: kPoliceTexte, letterSpacing: 3, fontSize: 12, color: c.orClair),
        ),
        const SizedBox(height: 6),
        Text(
          palier.nom,
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: kPoliceTitres, fontWeight: FontWeight.w900, fontSize: 28, color: c.or),
        ),
        Text(
          palier.ambiance,
          style: const TextStyle(fontFamily: kPoliceTexte, fontStyle: FontStyle.italic, color: Colors.white70),
        ),
        if (nouvelle != null && nouvelle!.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(
            t.t('rituel.nouvelle_palier'),
            style: TextStyle(fontFamily: kPoliceTexte, fontSize: 12, color: c.orClair),
          ),
          Text(
            t.t('rituel.nouvelle_aide'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: kPoliceTexte, fontSize: 11.5, fontStyle: FontStyle.italic, color: Colors.white60),
          ),
          const SizedBox(height: 4),
          Text(
            nouvelle!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: kPoliceTexte, fontSize: 17, height: 1.35, color: Colors.white),
          ),
        ],
        if (geste != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: c.or),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(geste!, style: TextStyle(fontFamily: kPoliceTitres, fontWeight: FontWeight.w700, color: c.or)),
          ),
        ],
        const SizedBox(height: 18),
        FilledButton(onPressed: onReprendre, child: Text(t.t('rituel.reprendre'))),
      ]),
    );
  }
}

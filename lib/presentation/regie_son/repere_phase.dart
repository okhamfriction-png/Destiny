import 'dart:async';

import 'package:flutter/material.dart';

import '../../application/son/conduite_son.dart';
import '../destiny/donnees.dart';
import '../theme/destiny_theme.dart';

/// Le repère de phase de l'enchaînement fluide, bien visible pendant la
/// séquence : « Destiny — ralenti », « Musique — jeu muet », « Fond — on
/// parle », avec le temps qui reste dans la phase.
class ReperePhase extends StatefulWidget {
  const ReperePhase({super.key, required this.conduite});

  final ConduiteSon conduite;

  @override
  State<ReperePhase> createState() => _ReperePhaseState();
}

class _ReperePhaseState extends State<ReperePhase> {
  Timer? _tic;

  @override
  void initState() {
    super.initState();
    widget.conduite.addListener(_maj);
    _minuterie();
  }

  @override
  void didUpdateWidget(ReperePhase ancien) {
    super.didUpdateWidget(ancien);
    if (ancien.conduite != widget.conduite) {
      ancien.conduite.removeListener(_maj);
      widget.conduite.addListener(_maj);
      _maj();
    }
  }

  @override
  void dispose() {
    widget.conduite.removeListener(_maj);
    _tic?.cancel();
    super.dispose();
  }

  void _maj() {
    _minuterie();
    if (mounted) setState(() {});
  }

  /// Le compte à rebours ne tourne que pendant une phase qui a une fin.
  void _minuterie() {
    final compte = widget.conduite.resteDePhase != null;
    if (compte && _tic == null) {
      _tic = Timer.periodic(const Duration(milliseconds: 250), (_) {
        if (!mounted) return;
        if (widget.conduite.resteDePhase == null) {
          _tic?.cancel();
          _tic = null;
        }
        setState(() {});
      });
    } else if (!compte) {
      _tic?.cancel();
      _tic = null;
    }
  }

  static const Map<PhaseFluide, (IconData, Color)> _styles = {
    PhaseFluide.destiny: (Icons.slow_motion_video_rounded, Color(0xFF6E9BF5)),
    PhaseFluide.jeuMuet: (Icons.music_note_rounded, Color(0xFFE2B347)),
    PhaseFluide.fond: (Icons.record_voice_over_rounded, Color(0xFF6CC28E)),
  };

  @override
  Widget build(BuildContext context) {
    final c = widget.conduite;
    final style = _styles[c.phase];
    if (style == null) return const SizedBox.shrink();
    final (icone, couleur) = style;
    final t = context.textes;
    final reste = c.resteDePhase;
    return Container(
      key: const ValueKey('repere_phase'),
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: couleur.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: couleur, width: 1.6),
      ),
      child: Row(children: [
        Icon(icone, color: couleur, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            t.t('regie_son.phase.${c.phase.name}'),
            style: TextStyle(fontFamily: kPoliceTexte, fontSize: 18, fontWeight: FontWeight.w800, color: couleur),
          ),
        ),
        if (reste != null)
          Text(
            t.t('regie_son.phase.reste', {'n': '${(reste.inMilliseconds / 1000).ceil()}'}),
            style: TextStyle(
              fontFamily: kPoliceTexte,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: couleur,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
      ]),
    );
  }
}

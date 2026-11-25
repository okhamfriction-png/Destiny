import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../application/exercices/seance_exercice_destiny.dart';
import '../../../domain/exercices/exercices_destiny.dart';
import '../../destiny/donnees.dart';
import '../../theme/destiny_theme.dart';
import 'exercices_destiny_section.dart';

/// Le libellé d'une face du dé des survivants.
String libelleSurvivants(BuildContext context, FaceSurvivants f) {
  final t = context.textes;
  String k(String x, [Map<String, String> v = const {}]) => t.t('exercices.destiny.$x', v);
  return switch (f) {
    FaceNombre(nombre: 0) => k('personne'),
    FaceNombre(nombre: 1) => k('un_survivant'),
    FaceNombre(:final nombre) => k('survivants_n', {'n': '$nombre'}),
    FaceTous() => k('tous'),
    FacePublic() => k('public'),
  };
}

String libelleType(BuildContext context, TypeDanger type) => context.textes.t('exercices.destiny.type_${type.name}');

/// Un exercice Destiny en cours : le grand chrono, le lieu, les boutons.
class ExerciceDestinyScreen extends StatefulWidget {
  const ExerciceDestinyScreen({required this.seance, required this.titre, required this.consigne, super.key});

  /// L'exercice, prêt à lancer ; l'écran le lance, puis le libère en partant.
  final SeanceExerciceDestiny seance;
  final String titre;
  final String consigne;

  @override
  State<ExerciceDestinyScreen> createState() => _ExerciceDestinyScreenState();
}

class _ExerciceDestinyScreenState extends State<ExerciceDestinyScreen> {
  SeanceExerciceDestiny get s => widget.seance;

  @override
  void initState() {
    super.initState();
    // L'écran reste allumé pendant l'exercice.
    WakelockPlus.enable().catchError((_) {});
    s.lancer();
  }

  @override
  void dispose() {
    s.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.textes;
    final c = context.destiny;
    String k(String x, [Map<String, String> v = const {}]) => t.t('exercices.destiny.$x', v);
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final etat = s.fini
            ? k('fini')
            : s.enPause
                ? k('en_pause')
                : s.lance
                    ? k('en_cours')
                    : k('prets');
        return Scaffold(
          body: Stack(children: [
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Column(children: [
                  Row(children: [
                    Expanded(
                      child: Text(widget.titre,
                          style: TextStyle(
                              fontFamily: kPoliceTitres, fontSize: 20, fontWeight: FontWeight.w900, color: c.titre)),
                    ),
                    IconButton(
                      key: const ValueKey('fermer_exercice'),
                      tooltip: t.t('exercices.fermer'),
                      icon: Icon(Icons.close_rounded, color: c.texteSecondaire),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ]),
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 640),
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.place_rounded, color: c.or),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(s.nomLieu,
                                    key: const ValueKey('lieu_exercice'),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontFamily: kPoliceTitres,
                                        fontSize: 26,
                                        fontWeight: FontWeight.w900,
                                        color: c.texte)),
                              ),
                            ]),
                            Text(k('acte_n', {'n': '${s.acte}'}),
                                  style: TextStyle(fontFamily: kPoliceTexte, fontSize: 14, color: c.texteSecondaire)),
                            const SizedBox(height: 18),
                            FittedBox(
                              child: Text(
                                minutesSecondes(s.reste),
                                key: const ValueKey('chrono_exercice'),
                                style: TextStyle(
                                  fontFamily: kPoliceTitres,
                                  fontSize: 96,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2,
                                  color: s.fini ? c.titre : (s.reste <= 10 ? DestinyCouleurs.corail : c.or),
                                ),
                              ),
                            ),
                            Text(etat,
                                textAlign: TextAlign.center,
                                style: TextStyle(fontFamily: kPoliceTexte, fontSize: 16, color: c.texteSecondaire)),
                            const SizedBox(height: 18),
                            Text(widget.consigne,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    fontFamily: kPoliceTexte, fontSize: 14.5, height: 1.4, color: c.texteSecondaire)),
                            if (s.packIncomplet)
                              Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Text(k('pack_incomplet'),
                                    key: const ValueKey('pack_incomplet'),
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontFamily: kPoliceTexte, fontSize: 12.5, color: c.texteSecondaire)),
                              ),
                          ]),
                        ),
                      ),
                    ),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      if (s.fini)
                        Row(children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              key: const ValueKey('relancer_exercice'),
                              onPressed: s.relancer,
                              icon: const Icon(Icons.replay_rounded, size: 18),
                              label: Text(k('relancer')),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: FilledButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: Text(k('terminer')),
                            ),
                          ),
                        ])
                      else
                        Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
                          FilledButton.tonalIcon(
                            key: const ValueKey('pause_exercice'),
                            onPressed: !s.lance ? null : (s.enPause ? s.reprendre : s.pause),
                            icon: Icon(s.enPause ? Icons.play_arrow_rounded : Icons.pause_rounded),
                            label: Text(s.enPause ? k('reprendre') : k('pause')),
                          ),
                          OutlinedButton.icon(
                            key: const ValueKey('relancer_exercice'),
                            onPressed: s.relancer,
                            icon: const Icon(Icons.replay_rounded, size: 18),
                            label: Text(k('relancer')),
                          ),
                          OutlinedButton.icon(
                            key: const ValueKey('nouveau_lieu_exercice'),
                            onPressed: s.nouveauLieu,
                            icon: const Icon(Icons.casino_outlined, size: 18),
                            label: Text(k('nouveau_lieu')),
                          ),
                          OutlinedButton.icon(
                            key: const ValueKey('arreter_exercice'),
                            // On revient à la préparation ; l'exercice s'arrête en partant.
                            onPressed: () {
                              unawaited(s.arreter());
                              Navigator.of(context).pop();
                            },
                            icon: const Icon(Icons.stop_rounded, size: 18),
                            label: Text(k('arreter')),
                          ),
                        ]),
                    ]),
                  ),
                ]),
              ),
            ),
          ]),
        );
      },
    );
  }
}

/// Un dé qui roule : les faces défilent, ralentissent, puis il tombe sur
/// [resultat] ; [apres] apparaît ensuite.
class DeQuiRoule extends StatefulWidget {
  const DeQuiRoule({required this.faces, required this.resultat, this.apres, super.key});

  final List<String> faces;
  final String resultat;
  final Widget? apres;

  @override
  State<DeQuiRoule> createState() => _DeQuiRouleState();
}

class _DeQuiRouleState extends State<DeQuiRoule> {
  final _hasard = Random();
  Timer? _timer;
  int _tours = 0;
  String _face = '';
  bool _pose = false;

  static const int _toursMax = 16;

  @override
  void initState() {
    super.initState();
    _face = widget.faces.isEmpty ? widget.resultat : widget.faces[_hasard.nextInt(widget.faces.length)];
    _rouler();
  }

  void _rouler() {
    // De plus en plus lent : 70 ms, puis jusqu'à 250 ms.
    _timer = Timer(Duration(milliseconds: 70 + _tours * 12), () {
      if (!mounted) return;
      setState(() {
        _tours++;
        if (_tours >= _toursMax || widget.faces.length < 2) {
          _face = widget.resultat;
          _pose = true;
        } else {
          var f = widget.faces[_hasard.nextInt(widget.faces.length)];
          if (f == _face) f = widget.faces[(widget.faces.indexOf(f) + 1) % widget.faces.length];
          _face = f;
        }
      });
      if (!_pose) _rouler();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.destiny;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      AnimatedScale(
        scale: _pose ? 1.12 : 1,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutBack,
        child: Transform.rotate(
          angle: _pose ? 0 : (_tours.isEven ? -0.08 : 0.08),
          child: Container(
            constraints: const BoxConstraints(minWidth: 220, maxWidth: 420),
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 34),
            decoration: BoxDecoration(
              color: const Color(0xFF15161B),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _pose ? c.orClair : c.or.withValues(alpha: 0.6), width: _pose ? 3 : 2),
              boxShadow: [if (_pose) BoxShadow(color: c.or.withValues(alpha: 0.45), blurRadius: 28)],
            ),
            child: Text(
              _face,
              key: ValueKey(_pose ? 'face_posee' : 'face_roule'),
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: kPoliceTitres,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: _pose ? c.orClair : Colors.white),
            ),
          ),
        ),
      ),
      AnimatedOpacity(
        opacity: _pose ? 1 : 0,
        duration: const Duration(milliseconds: 300),
        child: IgnorePointer(ignoring: !_pose, child: widget.apres ?? const SizedBox.shrink()),
      ),
    ]);
  }
}

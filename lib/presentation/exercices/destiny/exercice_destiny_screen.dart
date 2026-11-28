import 'dart:async';

import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../application/exercices/seance_exercice_destiny.dart';
import '../../../domain/exercices/exercices_destiny.dart';
import '../../destiny/donnees.dart';
import '../../theme/destiny_theme.dart';
import 'exercices_destiny_section.dart';

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

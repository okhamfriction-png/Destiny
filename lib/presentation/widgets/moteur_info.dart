import 'package:flutter/material.dart';

import '../../domain/entities/archetype.dart';
import '../../domain/entities/danger.dart' show kStadesEscalade;

/// Étiquettes des 4 niveaux d'escalade d'un moteur (calés sur les paliers du
/// danger : Signale → Enferme → Envahit → Supprime).
const List<String> kNiveauxMoteur = ['Masqué', 'Affleure', 'Domine', 'Extrême'];

/// Ouvre la bulle d'info « moteur » d'un archétype : son intention dirigée vers
/// l'autre et comment elle monte de niveau à mesure que le danger monte.
Future<void> showMoteurInfo(BuildContext context, Archetype a,
    {Color accent = const Color(0xFFFFC24B)}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF120F1E),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
    ),
    builder: (_) => _MoteurSheet(archetype: a, accent: accent),
  );
}

class _MoteurSheet extends StatelessWidget {
  const _MoteurSheet({required this.archetype, required this.accent});
  final Archetype archetype;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final a = archetype;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
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
          const SizedBox(height: 14),
          Text('${a.name} — moteur',
              style: TextStyle(
                  color: accent, fontSize: 20, fontWeight: FontWeight.w800)),
          if (a.intention.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(a.intention,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontStyle: FontStyle.italic,
                    height: 1.3)),
          ],
          const SizedBox(height: 6),
          const Text(
              'Une seule intention, dirigée vers quelqu\'un. Elle monte d\'un cran '
              'quand le danger monte :',
              style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.3)),
          const SizedBox(height: 14),
          for (var i = 0; i < a.niveaux.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent.withValues(alpha: 0.18),
                    ),
                    child: Text('$i',
                        style: TextStyle(
                            color: accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text.rich(TextSpan(children: [
                          TextSpan(
                              text: i < kNiveauxMoteur.length
                                  ? kNiveauxMoteur[i]
                                  : 'Niveau $i',
                              style: TextStyle(
                                  color: accent, fontWeight: FontWeight.w800)),
                          if (i < kStadesEscalade.length)
                            TextSpan(
                                text:
                                    '  ·  quand le danger ${kStadesEscalade[i].mot.toLowerCase()}',
                                style: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic)),
                        ])),
                        const SizedBox(height: 2),
                        Text(a.niveaux[i],
                            style: const TextStyle(
                                color: Colors.white70, height: 1.3)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

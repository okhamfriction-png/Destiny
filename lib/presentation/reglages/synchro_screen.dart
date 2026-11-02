import 'package:flutter/material.dart';

import '../../domain/repositories/catalog_store.dart';
import '../destiny/donnees.dart';
import '../destiny/page.dart';

String _date(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Ce que la dernière version de la grammaire a changé dans le catalogue :
/// ce qui a été mis à jour, ce qui a été gardé tel que tu l'avais modifié, ce
/// que tu avais supprimé et qui n'est pas revenu.
class SynchroScreen extends StatelessWidget {
  const SynchroScreen({super.key, required this.catalogue});

  final CatalogStore catalogue;

  @override
  Widget build(BuildContext context) {
    final t = context.textes;
    String k(String x, [Map<String, String> v = const {}]) => t.t('reglages.$x', v);
    return FutureBuilder<RapportSynchroCatalogue?>(
      future: catalogue.dernierRapport(),
      builder: (context, snap) {
        final r = snap.data;
        return PageDestiny(
          titre: k('synchro_titre'),
          enfants: [
            if (snap.connectionState != ConnectionState.done)
              const Center(child: CircularProgressIndicator())
            else if (r == null)
              Paragraphe(k('synchro_vide'), italique: true)
            else ...[
              Paragraphe(k('synchro_date', {'date': _date(r.date)}), gras: true),
              Puce(k('synchro_dangers', {'n': '${r.dangersMisAJour}'})),
              Puce(k('synchro_lieux', {'n': '${r.lieuxMisAJour}'})),
              Puce(k('synchro_gardes', {'n': '${r.gardes.length}'})),
              for (final g in r.gardes) Padding(padding: const EdgeInsets.only(left: 24), child: Text(g)),
              Puce(k('synchro_absents', {'n': '${r.absents.length}'})),
              for (final a in r.absents) Padding(padding: const EdgeInsets.only(left: 24), child: Text(a)),
              if (r.sansCorrespondance.isNotEmpty) Paragraphe(k('synchro_sans', {'liste': r.sansCorrespondance.join(', ')})),
            ],
          ],
        );
      },
    );
  }
}

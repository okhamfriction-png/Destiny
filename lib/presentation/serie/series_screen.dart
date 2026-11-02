import 'package:flutter/material.dart';

import '../../domain/serie/serie.dart';
import '../destiny/composants.dart';
import '../destiny/donnees.dart';
import '../destiny/page.dart';
import 'contexte_serie.dart';
import 'creer_serie_screen.dart';
import 'fiche_serie_screen.dart';

String _date(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// Où en est une série, en une ligne.
String ouEnEst(BuildContext context, Serie s) {
  final t = context.textes;
  final saison = s.saisonEnCours;
  final dernier = s.episodes.isEmpty ? null : s.episodes.last;
  final morceaux = <String>[
    t.t('serie.natures.${s.nature.name}'),
    if (saison != null && dernier != null && dernier.saison == saison.numero)
      t.t('serie.ou_on_en_est', {'s': '${saison.numero}', 'e': '${dernier.numero}'})
    else if (dernier != null && dernier.intitule.isNotEmpty)
      dernier.intitule,
    if (s.migreDe.isNotEmpty) t.t('serie.ancienne'),
  ];
  final enCours = s.episodeEnCours;
  if (enCours != null) {
    morceaux.add(t.t('serie.en_cours', {
      'n': '${enCours.numero}',
      'etape': t.t('serie.etapes.${enCours.etape.name}'),
    }));
  }
  return morceaux.join(' · ');
}

/// « Mes séries » : les épisodes, saisons et séries entre humains.
class SeriesScreen extends StatelessWidget {
  const SeriesScreen({super.key, required this.contexte});

  final ContexteSerie contexte;

  @override
  Widget build(BuildContext context) {
    final t = context.textes;
    String s(String k) => t.t('serie.$k');
    void ouvrir(Widget page) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
    return ListenableBuilder(
      listenable: contexte.store,
      builder: (context, _) {
        final series = contexte.store.series;
        return PageDestiny(
          titre: s('titre'),
          enfants: [
            Paragraphe(s('intro')),
            if (contexte.store.lectureEchouee) Paragraphe(s('lecture_echouee'), gras: true),
            FilledButton.icon(
              onPressed: () => ouvrir(CreerSerieScreen(contexte: contexte, saison: false)),
              icon: const Icon(Icons.movie_creation_outlined),
              label: Text(s('nouvel_episode')),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => ouvrir(CreerSerieScreen(contexte: contexte, saison: true)),
              icon: const Icon(Icons.video_library_outlined),
              label: Text(s('nouvelle_saison')),
            ),
            const SizedBox(height: 16),
            if (series.isEmpty) Paragraphe(s('vide'), italique: true),
            for (final serie in series)
              ElementListe(
                titre: serie.nom.trim().isEmpty ? '${s('sans_titre')} · ${_date(serie.creee)}' : serie.nom,
                sousTitre: ouEnEst(context, serie),
                apres: serie.kids ? const SigleKids(petit: true) : null,
                onTap: () => ouvrirFiche(context, contexte, serie.id),
              ),
          ],
        );
      },
    );
  }
}

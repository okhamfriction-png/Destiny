import 'package:flutter/material.dart';

import '../../domain/grammaire/modeles.dart';
import '../../domain/serie/serie.dart';
import '../destiny/composants.dart';
import '../destiny/donnees.dart';
import '../destiny/page.dart';
import '../theme/destiny_theme.dart';
import 'composants_serie.dart';
import 'contexte_serie.dart';
import 'personnages_screen.dart';
import 'registre_screen.dart';
import 'saison_screen.dart';

String _nomRoute(String id) => '/serie/$id';

/// Ouvre la fiche d'une série.
Future<void> ouvrirFiche(BuildContext context, ContexteSerie ctx, String serieId, {bool remplacer = false}) {
  final route = MaterialPageRoute<void>(
    settings: RouteSettings(name: _nomRoute(serieId)),
    builder: (_) => FicheSerieScreen(contexte: ctx, serieId: serieId),
  );
  final nav = Navigator.of(context);
  return remplacer ? nav.pushReplacement(route) : nav.push(route);
}

/// Revient à la fiche de la série : on la retrouve si elle est déjà ouverte,
/// sinon on l'ouvre à la place de l'écran courant.
void revenirALaFiche(BuildContext context, ContexteSerie ctx, Serie s) {
  if (FicheSerieScreen.ouvertes.contains(s.id)) {
    Navigator.of(context).popUntil((r) => r.settings.name == _nomRoute(s.id) || r.isFirst);
  } else {
    ouvrirFiche(context, ctx, s.id, remplacer: true);
  }
}

/// La fiche d'une série : où on en est, la suite, les saisons et leurs
/// méchants, les épisodes, les personnages, le registre et les réglages.
class FicheSerieScreen extends StatefulWidget {
  const FicheSerieScreen({super.key, required this.contexte, required this.serieId});

  final ContexteSerie contexte;
  final String serieId;

  /// Les fiches ouvertes (pour y revenir après un épisode).
  static final Set<String> ouvertes = {};

  @override
  State<FicheSerieScreen> createState() => _FicheSerieScreenState();
}

class _FicheSerieScreenState extends State<FicheSerieScreen> {
  ContexteSerie get ctx => widget.contexte;

  @override
  void initState() {
    super.initState();
    FicheSerieScreen.ouvertes.add(widget.serieId);
  }

  @override
  void dispose() {
    FicheSerieScreen.ouvertes.remove(widget.serieId);
    super.dispose();
  }

  void _pousser(Widget page) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  Future<void> _episodeSuivant(Serie s) async {
    final e = await nouvelEpisode(ctx, s);
    if (mounted) await ouvrirEpisode(context, ctx, s, e);
  }

  void _faireLaSuite(Serie s) {
    if ([for (final p in s.personnagesActifs) if (!p.pnj) p].isEmpty) {
      _pousser(PersonnagesScreen(contexte: ctx, serie: s, apres: ApresPersonnages.saison));
      return;
    }
    final dernier = s.dernierEpisode;
    final depuis = s.saisons.isEmpty && dernier != null && dernier.saison == 0 && !dernier.ancienneGrammaire ? dernier : null;
    _pousser(SaisonScreen(contexte: ctx, serie: s, depuisEpisode: depuis));
  }

  Future<void> _supprimer(Serie s) async {
    final t = context.textes;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        content: Text(t.t('serie.supprimer_confirmer')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(t.t('serie.non'))),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(t.t('serie.oui'))),
        ],
      ),
    );
    if (ok != true) return;
    await ctx.store.supprimer(s.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ctx.store,
      builder: (context, _) {
        final s = ctx.store.serie(widget.serieId);
        if (s == null) return const Scaffold();
        return _fiche(context, s);
      },
    );
  }

  Widget _fiche(BuildContext context, Serie s) {
    final g = context.grammaire;
    final t = context.textes;
    final c = context.destiny;
    String k(String x, [Map<String, String> v = const {}]) => t.t('serie.fiche.$x', v);
    final enCours = s.episodeEnCours;
    final saison = s.saisonEnCours;
    final prochain = s.prochainNumero;
    final univers = ctx.store.catalogue.universDe(s.univers);
    final horsSaison = s.episodesDe(0);

    return PageDestiny(
      titre: s.nom.isEmpty ? t.t('serie.sans_titre') : s.nom,
      actions: [
        IconButton(
          tooltip: k('registre').replaceAll('{n}', '${s.registre.length}'),
          icon: const Icon(Icons.menu_book_outlined),
          onPressed: () => _pousser(RegistreScreen(contexte: ctx, serie: s)),
        ),
        IconButton(
          tooltip: t.t('serie.supprimer'),
          icon: const Icon(Icons.delete_outline_rounded),
          onPressed: () => _supprimer(s),
        ),
      ],
      enfants: [
        Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
          Chip(label: Text(t.t('serie.natures.${s.nature.name}'))),
          if (univers != null) Chip(label: Text(univers.nom)),
          if (s.ton.isNotEmpty) Chip(label: Text(ctx.store.catalogue.tons[s.ton] ?? s.ton)),
          if (s.lore.isNotEmpty) Chip(label: Text(s.lore)),
          if (s.kids) const SigleKids(),
        ]),
        const SizedBox(height: 12),
        if (enCours != null)
          FilledButton.icon(
            onPressed: () => ouvrirEpisode(context, ctx, s, enCours),
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(k('reprendre', {'n': '${enCours.numero}'})),
          )
        else if (saison != null && !saison.terminee && prochain != null)
          FilledButton.icon(
            onPressed: () => _episodeSuivant(s),
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(k('preparer', {'n': '$prochain'})),
          )
        else if (s.saisons.isEmpty) ...[
          FilledButton.icon(
            onPressed: () => _faireLaSuite(s),
            icon: const Icon(Icons.video_library_outlined),
            label: Text(k('faire_la_suite')),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Text(k('faire_la_suite_aide'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
          ),
          OutlinedButton.icon(
            onPressed: () => _episodeSuivant(s),
            icon: const Icon(Icons.movie_creation_outlined),
            label: Text(k('un_autre_episode')),
          ),
        ] else
          FilledButton.icon(
            onPressed: () => _faireLaSuite(s),
            icon: const Icon(Icons.skip_next_rounded),
            label: Text(k('saison_suivante')),
          ),
        if (s.accroche.isNotEmpty)
          SectionDestiny(titre: k('accroche'), enfants: [EncartReplique(s.accroche, couleur: c.bleuDestiny)]),
        if (s.resume.isNotEmpty) SectionDestiny(titre: k('resume'), enfants: [Paragraphe(s.resume)]),
        for (final sa in s.saisons.reversed) _saison(context, s, sa),
        if (horsSaison.isNotEmpty)
          SectionDestiny(titre: s.saisons.isEmpty ? k('episodes') : t.t('serie.hors_saison'), enfants: [
            for (final e in horsSaison) _episode(context, s, e),
          ]),
        SectionDestiny(titre: k('personnages'), enfants: [
          for (final p in s.personnages)
            ElementListe(
              titre: [p.appel, if (p.joueur.isNotEmpty && p.joueur != p.appel) '(${p.joueur})'].join(' '),
              sousTitre: [
                g.archetype(p.archetypeId)?.nom ?? '',
                g.animal(p.animalId)?.nom ?? '',
                if (p.pnj) t.t('serie.personnages.pnj'),
                if (s.kids && p.pouvoir.isNotEmpty) p.pouvoir,
              ].where((x) => x.isNotEmpty).join(' · '),
              couleur: c.famille(g.archetype(p.archetypeId)?.famille ?? FamilleId.tient),
              devant: g.animal(p.animalId) == null ? null : MedaillonAnimal(g.animal(p.animalId)!, taille: 36, source: ctx.visuels.source),
            ),
          OutlinedButton.icon(
            onPressed: () => _pousser(PersonnagesScreen(contexte: ctx, serie: s, apres: ApresPersonnages.fiche)),
            icon: const Icon(Icons.edit_outlined),
            label: Text(k('modifier_personnages')),
          ),
        ]),
        SectionDestiny(titre: k('reglages'), enfants: [
          for (final (cle, valeur, changer) in [
            ('traitre', s.reglages.traitre, (bool v) => s.reglages.traitre = v),
            ('registre', s.reglages.registre, (bool v) => s.reglages.registre = v),
            ('combat', s.reglages.combat, (bool v) => s.reglages.combat = v),
            ('piece', s.reglages.piece, (bool v) => s.reglages.piece = v),
          ])
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(t.t('serie.creer.$cle')),
              value: valeur,
              onChanged: (v) {
                changer(v);
                ctx.store.enregistrer(s);
              },
            ),
        ]),
      ],
    );
  }

  Widget _saison(BuildContext context, Serie s, SaisonSerie sa) {
    final g = context.grammaire;
    final t = context.textes;
    final c = context.destiny;
    String k(String x, [Map<String, String> v = const {}]) => t.t('serie.fiche.$x', v);
    final m = ctx.mechant(g, sa.mechantId);
    final cible = s.personnage(sa.cibleId);
    final episodes = s.episodesDe(sa.numero);
    return SectionDestiny(titre: t.t('serie.saison_n', {'n': '${sa.numero}'}), enfants: [
      if (m != null)
        ElementListe(
          titre: m.nom,
          sousTitre: [
            if (cible != null) k('cible', {'nom': cible.appel}),
            m.veut,
          ].where((x) => x.isNotEmpty).join('\n'),
          couleur: c.titre,
          apres: const Icon(Icons.open_in_full_rounded),
          onTap: () => ouvrirCarteMechant(context, m, kids: s.kids),
        ),
      for (var i = 0; i < 4; i++)
        Puce(sa.presageDe(i + 1), numero: i + 1),
      for (final e in episodes) _episode(context, s, e),
      if (sa.ceQuIlLaisse.isNotEmpty) LigneInfo(t.t('serie.bilan.heritage'), sa.ceQuIlLaisse),
    ]);
  }

  Widget _episode(BuildContext context, Serie s, EpisodeSerie e) {
    final t = context.textes;
    return ElementListe(
      titre: '${t.t('serie.episode_n', {'n': '${e.numero}'})} · ${e.intitule}',
      sousTitre: [
        if (e.ancienneGrammaire) t.t('serie.ancienne_aide'),
        if (e.etape != EtapeEpisode.termine) t.t('serie.etapes.${e.etape.name}'),
        if (e.phrase.isNotEmpty) '« ${e.phrase} »',
      ].join('\n'),
      onTap: () => ouvrirEpisode(context, ctx, s, e),
    );
  }
}

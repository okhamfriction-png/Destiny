import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../application/services/export_pdf.dart';

import '../../domain/entities/danger.dart';
import '../../domain/entities/location.dart';
import '../../domain/grammaire/modeles.dart';
import '../destiny/composants.dart';
import '../destiny/donnees.dart';
import '../destiny/page.dart';
import 'bibliotheque_screen.dart';
import 'fiches.dart';

/// Une liste du catalogue avec recherche et filtre kids.
class _ListeCatalogue<T> extends StatefulWidget {
  const _ListeCatalogue({
    required this.titre,
    required this.charger,
    required this.nom,
    required this.kids,
    required this.element,
    this.actions,
  });

  final String titre;
  final List<Widget>? actions;
  final Future<List<T>> Function() charger;
  final String Function(T) nom;
  final bool Function(T) kids;
  final Widget Function(BuildContext, T) element;

  @override
  State<_ListeCatalogue<T>> createState() => _ListeCatalogueState<T>();
}

class _ListeCatalogueState<T> extends State<_ListeCatalogue<T>> {
  late final Future<List<T>> _elements = widget.charger();
  String _recherche = '';
  bool _kids = false;

  @override
  Widget build(BuildContext context) {
    final t = context.textes;
    return FutureBuilder<List<T>>(
      future: _elements,
      builder: (context, snap) {
        final tous = snap.data ?? const [];
        final cle = Grammaire.normaliser(_recherche);
        final visibles = [
          for (final e in tous)
            if ((!_kids || widget.kids(e)) && (cle.isEmpty || Grammaire.normaliser(widget.nom(e)).contains(cle))) e,
        ];
        return PageDestiny(
          titre: widget.titre,
          actions: widget.actions,
          entete: Column(children: [
            TextField(
              decoration: InputDecoration(
                hintText: t.t('bibliotheque.recherche'),
                prefixIcon: const Icon(Icons.search_rounded),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _recherche = v),
            ),
            const SizedBox(height: 6),
            Row(children: [
              FilterChip(
                label: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(t.t('bibliotheque.kids_seulement')),
                  const SizedBox(width: 6),
                  const SigleKids(petit: true),
                ]),
                selected: _kids,
                onSelected: (v) => setState(() => _kids = v),
              ),
              const Spacer(),
              Text('${visibles.length}', style: Theme.of(context).textTheme.bodySmall),
            ]),
          ]),
          enfants: [
            if (snap.connectionState != ConnectionState.done)
              const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
            else if (visibles.isEmpty)
              Paragraphe(t.t('bibliotheque.aucun_resultat'), italique: true)
            else
              for (final e in visibles) widget.element(context, e),
          ],
        );
      },
    );
  }
}

/// Les dangers, avec leur frise de quatre paliers.
class DangersScreen extends StatelessWidget {
  const DangersScreen({super.key, required this.contexte});

  final ContexteBibliotheque contexte;

  @override
  Widget build(BuildContext context) {
    return _ListeCatalogue<Danger>(
      titre: context.textes.t('bibliotheque.entrees.dangers.titre'),
      actions: [
        IconButton(
          key: const ValueKey('imprimer_dangers'),
          tooltip: context.textes.t('bibliotheque.imprimer.dangers_titre'),
          icon: const Icon(Icons.print_outlined),
          onPressed: () => imprimerCartesDangers(context, contexte),
        ),
      ],
      charger: contexte.catalogue.getDangers,
      nom: (d) => d.name,
      kids: (d) => d.kids,
      element: (context, d) => ElementListe(
        titre: d.name,
        sousTitre: d.paliers.isEmpty ? null : d.paliers.first,
        apres: d.kids ? const SigleKids(petit: true) : null,
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => FicheDanger(danger: d))),
      ),
    );
  }
}

/// Les dangers à imprimer : les dangers actifs du catalogue (ou seulement
/// ceux qu'on joue avec des enfants), par ordre alphabétique.
List<Danger> dangersAImprimer(List<Danger> tous, {bool kids = false}) => [
      for (final d in tous)
        if (d.actif && d.paliers.isNotEmpty && (!kids || d.kids)) d,
    ]..sort((a, b) => Grammaire.normaliser(a.name).compareTo(Grammaire.normaliser(b.name)));

/// Propose d'imprimer les cartes de dangers (tous, ou les dangers kids avec
/// le palier 4 des enfants), puis partage le PDF.
Future<void> imprimerCartesDangers(BuildContext context, ContexteBibliotheque contexte) async {
  final g = context.grammaire;
  final t = context.textes;
  final messager = ScaffoldMessenger.of(context);
  String k(String x, [Map<String, String> v = const {}]) => t.t('bibliotheque.imprimer.$x', v);
  final tous = await contexte.catalogue.getDangers();
  if (!context.mounted) return;
  final adultes = dangersAImprimer(tous);
  final enfants = dangersAImprimer(tous, kids: true);
  final kids = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(k('dangers_titre'), style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Paragraphe(k('dangers_aide')),
          ElementListe(
            titre: k('dangers_tous'),
            sousTitre: k('dangers_tous_aide', {'n': '${adultes.length}'}),
            devant: const Icon(Icons.warning_amber_rounded),
            onTap: () => Navigator.of(context).pop(false),
          ),
          ElementListe(
            titre: k('dangers_kids'),
            sousTitre: k('dangers_kids_aide', {'n': '${enfants.length}'}),
            devant: const Icon(Icons.child_care_outlined),
            apres: const SigleKids(petit: true),
            onTap: () => Navigator.of(context).pop(true),
          ),
        ]),
      ),
    ),
  );
  if (kids == null) return;
  messager.showSnackBar(SnackBar(content: Text(k('en_cours'))));
  try {
    final polices = await PolicesPdf.chargerDepuisAssets();
    final octets =
        await cartesDangersPdf(g: g, t: t, polices: polices, dangers: kids ? enfants : adultes, kids: kids);
    await Printing.sharePdf(
        bytes: octets, filename: kids ? 'destiny-cartes-dangers-kids.pdf' : 'destiny-cartes-dangers.pdf');
  } catch (_) {
    messager.showSnackBar(SnackBar(content: Text(k('echec'))));
  }
}

class FicheDanger extends StatelessWidget {
  const FicheDanger({super.key, required this.danger});

  final Danger danger;

  @override
  Widget build(BuildContext context) {
    final t = context.textes;
    String f(String k) => t.t('bibliotheque.fiche.$k');
    return PageDestiny(
      titre: danger.name,
      enfants: [
        if (danger.kids) const Align(alignment: Alignment.centerLeft, child: SigleKids()),
        SectionDestiny(titre: f('paliers'), enfants: [FrisePaliers(textes: danger.paliers)]),
        if (danger.kids && danger.palier4Kids.isNotEmpty)
          SectionDestiny(titre: f('palier4_kids'), enfants: [Paragraphe(danger.palier4Kids)]),
      ],
    );
  }
}

/// Les lieux, avec leurs espaces, leurs rôles et leurs figurants.
class LieuxScreen extends StatelessWidget {
  const LieuxScreen({super.key, required this.contexte});

  final ContexteBibliotheque contexte;

  @override
  Widget build(BuildContext context) {
    return _ListeCatalogue<Location>(
      titre: context.textes.t('bibliotheque.entrees.lieux.titre'),
      charger: contexte.catalogue.getLocations,
      nom: (l) => l.name,
      kids: (l) => l.kids,
      element: (context, l) => ElementListe(
        titre: l.name,
        sousTitre: l.espaces.join(' · '),
        apres: l.kids ? const SigleKids(petit: true) : null,
        onTap: () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => FicheLieu(lieu: l, contexte: contexte))),
      ),
    );
  }
}

class FicheLieu extends StatelessWidget {
  const FicheLieu({super.key, required this.lieu, required this.contexte});

  final Location lieu;
  final ContexteBibliotheque contexte;

  @override
  Widget build(BuildContext context) {
    final g = context.grammaire;
    final t = context.textes;
    String f(String k) => t.t('bibliotheque.fiche.$k');
    final lg = g.lieuNomme(lieu.name);
    final details = contexte.detailsLieux?.byId(lieu.id);
    final autres = [
      for (final s in details?.sousEspaces ?? const <String>[])
        if (!lieu.espaces.any((e) => Grammaire.normaliser(e) == Grammaire.normaliser(s))) s,
    ];
    return PageDestiny(
      titre: lieu.name,
      enfants: [
        if (lieu.kids) const Align(alignment: Alignment.centerLeft, child: SigleKids()),
        SectionDestiny(titre: f('espaces'), enfants: [for (final e in lieu.espaces) Puce(e)]),
        if (autres.isNotEmpty)
          SectionDestiny(titre: f('sous_espaces'), enfants: [
            Wrap(spacing: 6, runSpacing: 6, children: [for (final s in autres) Chip(label: Text(s))]),
          ]),
        SectionDestiny(titre: f('roles'), enfants: [
          Wrap(spacing: 6, runSpacing: 6, children: [for (final r in lieu.roles) Chip(label: Text(r))]),
        ]),
        if (lg != null && lg.figurants.isNotEmpty)
          SectionDestiny(titre: f('figurants'), enfants: [for (final fig in lg.figurants) CarteFigurant(fig)]),
      ],
    );
  }
}

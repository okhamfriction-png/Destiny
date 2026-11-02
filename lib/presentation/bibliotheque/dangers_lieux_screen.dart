import 'package:flutter/material.dart';

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
  });

  final String titre;
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

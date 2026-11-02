import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../application/services/export_pdf.dart';
import '../../domain/serie/serie.dart';
import '../destiny/donnees.dart';
import '../destiny/page.dart';
import '../theme/destiny_theme.dart';
import 'contexte_serie.dart';

/// Le libellé du statut d'une entrée (en kids, on « quitte l'histoire »).
String libelleStatut(BuildContext context, StatutRegistre statut, {required bool kids}) =>
    context.textes.t('serie.registre.${kids ? 'statuts_kids' : 'statuts'}.${statut.name}');

/// Écrire ou corriger une entrée du registre. Rend null si on annule.
Future<EntreeRegistre?> editerEntree(
  BuildContext context, {
  required Serie serie,
  required String id,
  EntreeRegistre? existante,
  int saison = 0,
  int episode = 1,
}) {
  final t = context.textes;
  String k(String x) => t.t('serie.registre.$x');
  final nom = TextEditingController(text: existante?.nom ?? '');
  final detail = TextEditingController(text: existante?.detail ?? '');
  final liens = TextEditingController(text: existante?.liens.join(', ') ?? '');
  var categorie = existante?.categorie ?? CategorieRegistre.figurant;
  var statut = existante?.statut ?? StatutRegistre.present;
  final categories = [
    for (final c in CategorieRegistre.values)
      if (!serie.kids || c != CategorieRegistre.mort) c,
  ];
  final statuts = [
    for (final s in StatutRegistre.values)
      if (!serie.kids || s != StatutRegistre.tombe) s,
  ];
  return showDialog<EntreeRegistre>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, maj) => AlertDialog(
        title: Text(existante == null ? k('ajouter') : k('modifier')),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            DropdownButtonFormField<CategorieRegistre>(
              initialValue: categorie,
              decoration: InputDecoration(labelText: k('categorie')),
              items: [
                for (final c in categories) DropdownMenuItem(value: c, child: Text(t.t('serie.registre.categories.${c.name}'))),
              ],
              onChanged: (v) => maj(() => categorie = v ?? categorie),
            ),
            TextField(controller: nom, decoration: InputDecoration(labelText: k('nom'))),
            TextField(controller: detail, maxLines: 3, minLines: 1, decoration: InputDecoration(labelText: k('detail'))),
            DropdownButtonFormField<StatutRegistre>(
              initialValue: statuts.contains(statut) ? statut : StatutRegistre.parti,
              decoration: InputDecoration(labelText: k('statut')),
              items: [
                for (final s in statuts)
                  DropdownMenuItem(value: s, child: Text(libelleStatut(context, s, kids: serie.kids))),
              ],
              onChanged: (v) => maj(() => statut = v ?? statut),
            ),
            TextField(controller: liens, decoration: InputDecoration(labelText: k('liens'))),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t.t('serie.annuler'))),
          FilledButton(
            onPressed: () {
              if (nom.text.trim().isEmpty) return;
              Navigator.pop(
                ctx,
                EntreeRegistre(
                  id: existante?.id ?? id,
                  categorie: categorie,
                  nom: nom.text.trim(),
                  detail: detail.text.trim(),
                  statut: serie.kids && statut == StatutRegistre.tombe ? StatutRegistre.parti : statut,
                  liens: [for (final l in liens.text.split(',')) if (l.trim().isNotEmpty) l.trim()],
                  saison: existante?.saison ?? saison,
                  episode: existante?.episode ?? episode,
                  deLIa: existante?.deLIa ?? false,
                ),
              );
            },
            child: Text(t.t('serie.enregistrer')),
          ),
        ],
      ),
    ),
  );
}

/// Une entrée du registre, en une ligne.
class LigneRegistre extends StatelessWidget {
  const LigneRegistre({super.key, required this.entree, required this.kids, this.onTap});

  final EntreeRegistre entree;
  final bool kids;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.textes;
    final c = context.destiny;
    final ne = entree.saison == 0
        ? t.t('serie.registre.nee_hors')
        : t.t('serie.registre.nee', {'s': '${entree.saison}', 'e': '${entree.episode}'});
    return ElementListe(
      titre: entree.nom,
      sousTitre: [
        if (entree.detail.isNotEmpty) entree.detail,
        [
          libelleStatut(context, entree.statut, kids: kids),
          ne,
          if (entree.deLIa) t.t('serie.registre.de_l_ia'),
        ].join(' · '),
        if (entree.liens.isNotEmpty) entree.liens.join(' · '),
      ].join('\n'),
      couleur: entree.statut == StatutRegistre.present ? c.titre : c.texteSecondaire,
      onTap: onTap,
    );
  }
}

/// Le registre d'une série : consultable, corrigeable, exportable.
class RegistreScreen extends StatefulWidget {
  const RegistreScreen({super.key, required this.contexte, required this.serie});

  final ContexteSerie contexte;
  final Serie serie;

  @override
  State<RegistreScreen> createState() => _RegistreScreenState();
}

class _RegistreScreenState extends State<RegistreScreen> {
  Serie get s => widget.serie;

  Future<void> _editer([EntreeRegistre? e]) async {
    final dernier = s.episodes.isEmpty ? null : s.episodes.last;
    final r = await editerEntree(
      context,
      serie: s,
      id: widget.contexte.store.nouvelId('r'),
      existante: e,
      saison: dernier?.saison ?? 0,
      episode: dernier?.numero ?? 1,
    );
    if (r == null) return;
    setState(() {
      final i = s.registre.indexWhere((x) => x.id == r.id);
      if (i >= 0) {
        s.registre[i] = r;
      } else {
        s.registre.add(r);
      }
    });
    await widget.contexte.store.enregistrer(s);
  }

  Future<void> _supprimer(EntreeRegistre e) async {
    final t = context.textes;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(t.t('serie.registre.supprimer_confirmer')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t.t('serie.non'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(t.t('serie.oui'))),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => s.registre.removeWhere((x) => x.id == e.id));
    await widget.contexte.store.enregistrer(s);
  }

  Future<void> _exporter() async {
    final t = context.textes;
    final polices = await PolicesPdf.chargerDepuisAssets();
    final octets = await registrePdf(s: s, t: t, polices: polices);
    await Printing.sharePdf(bytes: octets, filename: 'registre-${s.nom.isEmpty ? s.id : s.nom}.pdf');
  }

  @override
  Widget build(BuildContext context) {
    final g = context.grammaire;
    final t = context.textes;
    String k(String x) => t.t('serie.registre.$x');
    return PageDestiny(
      titre: k('titre'),
      actions: [
        IconButton(tooltip: k('exporter'), icon: const Icon(Icons.picture_as_pdf_outlined), onPressed: _exporter),
      ],
      enfants: [
        Paragraphe(g.serie.registre.principe),
        FilledButton.icon(onPressed: () => _editer(), icon: const Icon(Icons.add_rounded), label: Text(k('ajouter'))),
        if (s.registre.isEmpty) Paragraphe(k('vide'), italique: true),
        for (final c in CategorieRegistre.values)
          if (s.registre.any((e) => e.categorie == c))
            SectionDestiny(titre: t.t('serie.registre.categories.${c.name}'), enfants: [
              for (final e in s.registre.where((e) => e.categorie == c))
                Row(children: [
                  Expanded(child: LigneRegistre(entree: e, kids: s.kids, onTap: () => _editer(e))),
                  IconButton(
                    tooltip: k('supprimer'),
                    icon: Icon(Icons.delete_outline_rounded, color: context.destiny.texteSecondaire),
                    onPressed: () => _supprimer(e),
                  ),
                ]),
            ]),
      ],
    );
  }
}

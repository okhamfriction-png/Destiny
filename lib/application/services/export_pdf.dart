import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../domain/grammaire/modeles.dart';
import '../../domain/grammaire/textes.dart';
import '../../domain/serie/serie.dart';
import '../../domain/troupe/session.dart';
import '../livret/livret.dart';

/// Les polices des PDF (les mêmes que l'appli).
class PolicesPdf {
  const PolicesPdf({required this.titre, required this.texte, required this.texteGras, required this.italique});

  final ByteData titre;
  final ByteData texte;
  final ByteData texteGras;
  final ByteData italique;

  /// Les polices embarquées de l'appli.
  static Future<PolicesPdf> chargerDepuisAssets() async => PolicesPdf(
        titre: await rootBundle.load('assets/fonts/Cinzel-Bold.ttf'),
        texte: await rootBundle.load('assets/fonts/Montserrat-Regular.ttf'),
        texteGras: await rootBundle.load('assets/fonts/Montserrat-Bold.ttf'),
        italique: await rootBundle.load('assets/fonts/Montserrat-Italic.ttf'),
      );
}

PdfColor _hex(String hex) {
  final v = int.tryParse(hex.replaceAll('#', ''), radix: 16) ?? 0x888888;
  return PdfColor.fromInt(0xFF000000 | v);
}

/// La fiche d'un spectacle en PDF : distribution, lieu, danger, paliers,
/// Destiny, notes de régie et débrief.
Future<Uint8List> fichePdfSession({
  required SessionTroupe s,
  required Grammaire g,
  required TextesDestiny t,
  required PolicesPdf polices,
}) async {
  final titre = pw.Font.ttf(polices.titre);
  final texte = pw.Font.ttf(polices.texte);
  final gras = pw.Font.ttf(polices.texteGras);
  final italique = pw.Font.ttf(polices.italique);
  final or = _hex(g.directionArtistique.couleurs['or_fonce'] ?? '#8a5f14');
  final theme = pw.ThemeData.withFont(base: texte, bold: gras, italic: italique);

  pw.Widget h(String x) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
        child: pw.Text(x.toUpperCase(), style: pw.TextStyle(font: gras, fontSize: 10, letterSpacing: 1.5, color: or)),
      );
  pw.Widget ligne(String libelle, String valeur) => valeur.trim().isEmpty
      ? pw.SizedBox()
      : pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4),
          child: pw.RichText(
            text: pw.TextSpan(children: [
              pw.TextSpan(text: '$libelle : ', style: pw.TextStyle(font: gras, fontSize: 10.5)),
              pw.TextSpan(text: valeur, style: const pw.TextStyle(fontSize: 10.5)),
            ]),
          ),
        );
  String date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  String horloge(int sec) => '${(sec ~/ 60).toString().padLeft(2, '0')}:${(sec % 60).toString().padLeft(2, '0')}';

  final doc = pw.Document(title: '${g.nom} — ${date(s.date)}', author: g.nom);
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    theme: theme,
    margin: const pw.EdgeInsets.all(36),
    header: (ctx) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
      pw.Text(g.nom.toUpperCase(), style: pw.TextStyle(font: titre, fontSize: 11, color: or)),
      pw.Text(g.promesse, style: pw.TextStyle(font: italique, fontSize: 9)),
    ]),
    build: (ctx) => [
      pw.Text('${t.t('troupe.types.${s.type.name}')} · ${date(s.date)}',
          style: pw.TextStyle(font: titre, fontSize: 22, color: or)),
      pw.SizedBox(height: 6),
      ligne(t.t('mise_en_place.lieu'), s.lieuNom),
      ligne(t.t('mise_en_place.groupe'), s.groupe),
      ligne(t.t('mise_en_place.danger'), s.dangerNom),
      ligne(t.t('mise_en_place.chrono'), '${s.dureeMinutes} min'),
      h(t.t('bibliotheque.regles.paliers')),
      for (final p in g.paliers)
        ligne('${p.numero}. ${p.nom}', s.paliers.length > p.id.index ? s.paliers[p.id.index] : ''),
      h(t.t('regie.mystere')),
      ligne(t.t('mise_en_place.mystere'), s.mystere),
      ligne(t.t('mise_en_place.reponse'), s.reponseMystere),
      h(t.t('historique.distribution')),
      for (final p in s.personnages)
        ligne(
          p.joueur.isEmpty ? '—' : p.joueur,
          [
            g.archetype(p.archetypeId)?.nom ?? '',
            g.archetype(p.archetypeId) == null ? '' : g.familleDe(g.archetype(p.archetypeId)!).nom,
            g.animal(p.animalId)?.nom ?? '',
          ].where((x) => x.isNotEmpty).join(' · '),
        ),
      h(t.t('historique.destinys')),
      for (final d in s.destinys)
        pw.Bullet(
          text: t.t('historique.destiny_n', {
            'n': '${d.numero}',
            't': horloge(d.secondes),
            'manuel': d.manuel ? t.t('historique.manuel') : '',
          }),
          style: const pw.TextStyle(fontSize: 10.5),
        ),
      ligne(t.t('historique.palier_atteint', {'n': '${s.palierAtteint}'}), g.palier(PalierId.deNumero(s.palierAtteint)).nom),
      if (s.notes.isNotEmpty) h(t.t('regie.notes')),
      for (final n in s.notes) ligne(n.horodatage, n.texte),
      h(t.t('debrief.titre')),
      for (final p in s.personnages) ...[
        pw.Text(
          [if (p.joueur.isNotEmpty) p.joueur, g.archetype(p.archetypeId)?.nom ?? ''].join(' · '),
          style: pw.TextStyle(font: gras, fontSize: 11.5),
        ),
        ligne(t.t('debrief.groupe'), [p.groupeVeut, p.groupeBesoin].where((x) => x.isNotEmpty).join(' / ')),
        ligne(t.t('debrief.fixe'), [p.fixeVeut, p.fixeBesoin].where((x) => x.isNotEmpty).join(' / ')),
        ligne(
          t.t('debrief.choix'),
          switch (p.choixFinal) {
            ChoixFinal.vouloir => t.t('debrief.choix_vouloir'),
            ChoixFinal.besoin => t.t('debrief.choix_besoin'),
            ChoixFinal.aucun => '',
          },
        ),
        ligne(t.t('debrief.prix'), p.prixPaye),
        pw.SizedBox(height: 6),
      ],
      if (s.ceQuiAMarche.isNotEmpty) h(t.t('debrief.ce_qui_a_marche')),
      for (final m in s.ceQuiAMarche) pw.Bullet(text: m, style: const pw.TextStyle(fontSize: 10.5)),
    ],
  ));
  return doc.save();
}

/// Le registre d'une série en PDF, rangé par catégorie. Il ne contient que
/// des personnages, des lieux, des secrets et des promesses (et les objets
/// notés avant la 2.0.2, gardés pour ne rien perdre).
Future<Uint8List> registrePdf({
  required Serie s,
  required TextesDestiny t,
  required PolicesPdf polices,
}) async {
  final titre = pw.Font.ttf(polices.titre);
  final texte = pw.Font.ttf(polices.texte);
  final gras = pw.Font.ttf(polices.texteGras);
  final italique = pw.Font.ttf(polices.italique);
  final or = _hex('#8a5f14');
  final theme = pw.ThemeData.withFont(base: texte, bold: gras, italic: italique);
  final statuts = s.kids ? 'statuts_kids' : 'statuts';
  final doc = pw.Document(title: t.t('serie.registre.titre'));
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    theme: theme,
    margin: const pw.EdgeInsets.all(36),
    build: (ctx) => [
      pw.Text(s.nom.isEmpty ? t.t('serie.registre.titre') : '${t.t('serie.registre.titre')} · ${s.nom}',
          style: pw.TextStyle(font: titre, fontSize: 20, color: or)),
      if (s.registre.isEmpty) pw.Text(t.t('serie.registre.vide'), style: pw.TextStyle(font: italique)),
      for (final c in CategorieRegistre.values)
        if (s.registre.any((e) => e.categorie == c)) ...[
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
            child: pw.Text(t.t('serie.registre.categories.${c.name}').toUpperCase(),
                style: pw.TextStyle(font: gras, fontSize: 10, letterSpacing: 1.5, color: or)),
          ),
          for (final e in s.registre.where((e) => e.categorie == c))
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 6),
              child: pw.RichText(
                text: pw.TextSpan(children: [
                  pw.TextSpan(text: e.nom, style: pw.TextStyle(font: gras, fontSize: 10.5)),
                  pw.TextSpan(
                      text: ' (${t.t('serie.registre.$statuts.${e.statut.name}')}, '
                          '${e.saison == 0 ? t.t('serie.registre.nee_hors') : t.t('serie.registre.nee', {'s': '${e.saison}', 'e': '${e.episode}'})})',
                      style: pw.TextStyle(font: italique, fontSize: 9.5)),
                  if (e.detail.isNotEmpty) pw.TextSpan(text: ' : ${e.detail}', style: const pw.TextStyle(fontSize: 10.5)),
                ]),
              ),
            ),
        ],
    ],
  ));
  return doc.save();
}

/// Le livret de règles en PDF, composé depuis le même [livret] que l'écran.
Future<Uint8List> livretPdf({
  required Livret livret,
  required Grammaire g,
  required PolicesPdf polices,
}) async {
  final titre = pw.Font.ttf(polices.titre);
  final texte = pw.Font.ttf(polices.texte);
  final gras = pw.Font.ttf(polices.texteGras);
  final italique = pw.Font.ttf(polices.italique);
  final or = _hex(g.directionArtistique.couleurs['or_fonce'] ?? '#8a5f14');
  final bleu = _hex(g.directionArtistique.couleurs['bleu_destiny'] ?? '#3F74B5');
  final theme = pw.ThemeData.withFont(base: texte, bold: gras, italic: italique);
  const corps = pw.TextStyle(fontSize: 10.5, lineSpacing: 1.5);

  pw.Widget bloc(BlocLivret b) => switch (b) {
        IntertitreLivret(:final texte) => pw.Padding(
            padding: const pw.EdgeInsets.only(top: 10, bottom: 4),
            child: pw.Text(texte, style: pw.TextStyle(font: titre, fontSize: 12)),
          ),
        ParagrapheLivret(:final texte, :final italique) => pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 5),
            child: pw.Text(texte, style: italique ? corps.copyWith(fontStyle: pw.FontStyle.italic) : corps),
          ),
        PucesLivret(:final items, :final numerotees) => pw.Column(children: [
            for (var i = 0; i < items.length; i++)
              numerotees
                  ? pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 3),
                      child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                        pw.SizedBox(
                            width: 16, child: pw.Text('${i + 1}.', style: pw.TextStyle(font: gras, fontSize: 10.5, color: or))),
                        pw.Expanded(child: pw.Text(items[i], style: corps)),
                      ]),
                    )
                  : pw.Bullet(text: items[i], style: corps, bulletColor: or),
          ]),
        InfoLivret(:final libelle, :final valeur) => pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 4),
            child: pw.RichText(
              text: pw.TextSpan(children: [
                pw.TextSpan(text: '$libelle : ', style: pw.TextStyle(font: gras, fontSize: 10.5)),
                pw.TextSpan(text: valeur, style: corps),
              ]),
            ),
          ),
        EncartLivret(:final texte) => pw.Container(
            margin: const pw.EdgeInsets.symmetric(vertical: 6),
            padding: const pw.EdgeInsets.fromLTRB(10, 6, 8, 6),
            decoration: pw.BoxDecoration(border: pw.Border(left: pw.BorderSide(color: bleu, width: 3))),
            child: pw.Text(texte, style: pw.TextStyle(font: italique, fontSize: 11)),
          ),
      };

  final doc = pw.Document(title: '${g.nom} — ${livret.titre}', author: g.nom);
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    theme: theme,
    margin: const pw.EdgeInsets.fromLTRB(48, 40, 48, 40),
    header: (ctx) => ctx.pageNumber == 1
        ? pw.SizedBox()
        : pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
            pw.Text(g.nom.toUpperCase(), style: pw.TextStyle(font: titre, fontSize: 9, color: or)),
            pw.Text(livret.titre, style: pw.TextStyle(font: italique, fontSize: 9)),
          ]),
    footer: (ctx) => pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Text('${ctx.pageNumber} / ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 8.5)),
    ),
    build: (ctx) => [
      pw.Center(child: pw.Text(g.nom.toUpperCase(), style: pw.TextStyle(font: titre, fontSize: 30, color: or))),
      pw.SizedBox(height: 4),
      pw.Center(child: pw.Text(livret.titre, style: pw.TextStyle(font: titre, fontSize: 18))),
      pw.SizedBox(height: 6),
      pw.Center(
          child: pw.Text(livret.sousTitre,
              textAlign: pw.TextAlign.center, style: pw.TextStyle(font: italique, fontSize: 11))),
      pw.Divider(color: or, thickness: 0.8, height: 24),
      for (final s in livret.sections) ...[
        pw.Header(
          level: 1,
          decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: or, width: 0.8))),
          padding: const pw.EdgeInsets.only(bottom: 3),
          margin: const pw.EdgeInsets.only(top: 14, bottom: 8),
          child: pw.Text(s.titre.toUpperCase(),
              style: pw.TextStyle(font: titre, fontSize: 14, color: or, letterSpacing: 1.2)),
        ),
        for (final b in s.blocs) bloc(b),
      ],
    ],
  ));
  return doc.save();
}

/// Les cartes d'archétypes à imprimer, au format 63 × 88 mm, neuf par page
/// A4 : un recto par archétype (12 cartes) ou par animal (24 cartes), et
/// après chaque page de rectos, sa page de versos Destiny, placée pour une
/// impression recto verso (bord long).
Future<Uint8List> cartesArchetypesPdf({
  required Grammaire g,
  required TextesDestiny t,
  required PolicesPdf polices,
  bool parAnimal = false,
}) async {
  final titre = pw.Font.ttf(polices.titre);
  final texte = pw.Font.ttf(polices.texte);
  final gras = pw.Font.ttf(polices.texteGras);
  final italique = pw.Font.ttf(polices.italique);
  final da = g.directionArtistique.couleurs;
  final or = _hex(da['or'] ?? '#C9A24A');
  final orFonce = _hex(da['or_fonce'] ?? '#8a5f14');
  final nuit = _hex(da['nuit'] ?? '#14100a');
  final creme = _hex(da['creme'] ?? '#f6efe0');
  final encre = _hex(da['encre'] ?? '#2a2108');
  final bleu = _hex(da['bleu_destiny'] ?? '#3F74B5');
  final theme = pw.ThemeData.withFont(base: texte, bold: gras, italic: italique);

  const largeur = 63 * PdfPageFormat.mm;
  const hauteur = 88 * PdfPageFormat.mm;
  const colonnes = 3;
  const lignes = 3;
  const parPage = colonnes * lignes;
  const trait = PdfColors.grey400;

  pw.Widget bandeau(FamilleId f, String haut) => pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        color: _hex(g.famille(f).couleur),
        child: pw.Text(haut.toUpperCase(),
            style: pw.TextStyle(font: gras, fontSize: 6.5, letterSpacing: 1, color: PdfColors.white)),
      );

  pw.Widget ligne(String libelle, String valeur, {double taille = 6.8}) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 2),
        child: pw.RichText(
          text: pw.TextSpan(children: [
            pw.TextSpan(text: '$libelle  ', style: pw.TextStyle(font: gras, fontSize: taille, color: orFonce)),
            pw.TextSpan(text: valeur, style: pw.TextStyle(fontSize: taille, color: encre)),
          ]),
        ),
      );

  pw.Widget rectoArchetype(Archetype a) {
    final f = g.familleDe(a);
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      bandeau(a.famille, f.nom),
      pw.Padding(
        padding: const pw.EdgeInsets.fromLTRB(8, 7, 8, 0),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(a.nom, style: pw.TextStyle(font: titre, fontSize: 16, color: encre)),
          pw.SizedBox(height: 5),
          pw.Text(a.ceQuIlFait, style: pw.TextStyle(font: italique, fontSize: 9, color: encre)),
          pw.SizedBox(height: 10),
          pw.Text(t.t('cartes.montee').toUpperCase(),
              style: pw.TextStyle(font: gras, fontSize: 7, letterSpacing: 1, color: orFonce)),
          pw.SizedBox(height: 4),
          for (final p in g.paliers) ligne('${p.numero}', a.montee[p.id] ?? '', taille: 8.6),
        ]),
      ),
      pw.Spacer(),
      pw.Padding(
        padding: const pw.EdgeInsets.fromLTRB(8, 0, 8, 7),
        child: pw.Text([for (final an in g.animauxDe(a.id)) an.nom].join('  ·  '),
            style: pw.TextStyle(font: titre, fontSize: 10, color: orFonce)),
      ),
    ]);
  }

  pw.Widget rectoAnimal(Animal an) {
    final a = g.archetype(an.archetypeId)!;
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      bandeau(a.famille, a.nom),
      pw.Padding(
        padding: const pw.EdgeInsets.fromLTRB(8, 6, 8, 0),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(an.nom, style: pw.TextStyle(font: titre, fontSize: 14, color: encre)),
          pw.Text('${t.t('statuts.${an.statutDepart.name}')} · ${t.t('cartes.port')} ${an.port}',
              style: pw.TextStyle(fontSize: 6.5, color: orFonce)),
          pw.SizedBox(height: 4),
          pw.Text(an.posture, style: pw.TextStyle(fontSize: 7.2, color: encre)),
          pw.SizedBox(height: 4),
          pw.Text('« ${an.replique} »', style: pw.TextStyle(font: italique, fontSize: 7.2, color: encre)),
          pw.SizedBox(height: 5),
          for (final p in g.paliers)
            if ((an.niveauxCorps[p.id] ?? '').isNotEmpty) ligne('${p.numero}', an.niveauxCorps[p.id]!, taille: 6.2),
        ]),
      ),
    ]);
  }

  pw.Widget verso() => pw.Container(
        color: nuit,
        child: pw.Stack(alignment: pw.Alignment.center, children: [
          pw.Container(
            margin: const pw.EdgeInsets.all(7),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: or, width: 0.8)),
          ),
          pw.Column(mainAxisAlignment: pw.MainAxisAlignment.center, children: [
            pw.Transform.rotate(angle: 0.785398, child: pw.Container(width: 6, height: 6, color: or)),
            pw.SizedBox(height: 6),
            pw.Text(g.nom.toUpperCase(), style: pw.TextStyle(font: titre, fontSize: 19, letterSpacing: 2, color: or)),
            pw.SizedBox(height: 6),
            pw.Container(width: 34, height: 0.8, color: bleu),
            pw.SizedBox(height: 6),
            pw.Text(g.promesse, style: pw.TextStyle(font: italique, fontSize: 8, color: creme)),
          ]),
        ]),
      );

  pw.Widget grille(List<pw.Widget?> cases) => pw.Center(
        child: pw.Column(mainAxisSize: pw.MainAxisSize.min, children: [
          for (var r = 0; r < lignes; r++)
            pw.Row(mainAxisSize: pw.MainAxisSize.min, children: [
              for (var c = 0; c < colonnes; c++)
                pw.Container(
                  width: largeur,
                  height: hauteur,
                  decoration: pw.BoxDecoration(
                    color: cases[r * colonnes + c] == null ? null : PdfColors.white,
                    border: pw.Border.all(color: trait, width: 0.3),
                  ),
                  child: cases[r * colonnes + c],
                ),
            ]),
        ]),
      );

  final rectos = parAnimal
      ? [for (final a in g.archetypes) for (final an in g.animauxDe(a.id)) rectoAnimal(an)]
      : [for (final a in g.archetypes) rectoArchetype(a)];

  final doc = pw.Document(title: '${g.nom} — ${t.t('bibliotheque.entrees.archetypes.titre')}', author: g.nom);
  for (var debut = 0; debut < rectos.length; debut += parPage) {
    final page = rectos.skip(debut).take(parPage).toList();
    final cases = <pw.Widget?>[for (var i = 0; i < parPage; i++) i < page.length ? page[i] : null];
    // Au verso, une carte en colonne c se retrouve en colonne 2 - c.
    final dos = <pw.Widget?>[
      for (var i = 0; i < parPage; i++)
        (i ~/ colonnes) * colonnes + (colonnes - 1 - i % colonnes) < page.length ? verso() : null,
    ];
    doc.addPage(pw.Page(pageFormat: PdfPageFormat.a4, theme: theme, margin: pw.EdgeInsets.zero, build: (_) => grille(cases)));
    doc.addPage(pw.Page(pageFormat: PdfPageFormat.a4, theme: theme, margin: pw.EdgeInsets.zero, build: (_) => grille(dos)));
  }
  return doc.save();
}

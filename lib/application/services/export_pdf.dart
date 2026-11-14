import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../domain/entities/danger.dart';
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
          ),        TableauLivret(:final entetes, :final lignes) => pw.Padding(
            padding: const pw.EdgeInsets.only(top: 4, bottom: 8),
            child: pw.Table(
              columnWidths: const {
                0: pw.FlexColumnWidth(1.1),
                1: pw.FlexColumnWidth(0.9),
                2: pw.FlexColumnWidth(3),
              },
              border: pw.TableBorder(horizontalInside: pw.BorderSide(color: or, width: 0.4)),
              children: [
                pw.TableRow(children: [
                  for (final e in entetes)
                    pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(e, style: pw.TextStyle(font: gras, fontSize: 9.5, color: or))),
                ]),
                for (final l in lignes)
                  pw.TableRow(children: [
                    for (final (i, x) in l.indexed)
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Text(x,
                            style: i == 0
                                ? pw.TextStyle(font: gras, fontSize: 9.5)
                                : i == l.length - 1
                                    ? pw.TextStyle(font: italique, fontSize: 9.5)
                                    : const pw.TextStyle(fontSize: 9.5)),
                      ),
                  ]),
              ],
            ),
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

/// Lit une image du projet (les assets de l'appli ; un fichier dans les tests).
typedef LireImage = Future<Uint8List> Function(String chemin);

Future<Uint8List> _lireAsset(String chemin) async => (await rootBundle.load(chemin)).buffer.asUint8List();

/// Le style commun des cartes à imprimer : fond blanc, filet or arrondi, un
/// liseré à la couleur de la famille, le dé Destiny ; au verso, le dé et
/// « Destiny, rien n'est écrit », cerclés de la couleur de la carte.
class _StyleCartes {
  _StyleCartes._(this.g, this.t, this.polices, this.cube, this.icones, this.photos);

  static Future<_StyleCartes> charger(Grammaire g, TextesDestiny t, PolicesPdf polices, LireImage lire,
      {bool avecPhotos = true}) async {
    Future<pw.ImageProvider?> image(String chemin) async {
      try {
        return pw.MemoryImage(await lire(chemin));
      } catch (_) {
        return null;
      }
    }

    return _StyleCartes._(
      g,
      t,
      polices,
      await image('assets/images/icones_archetypes/de.png'),
      {for (final a in g.archetypes) a.id: await image('assets/images/icones_archetypes/${a.id}.png')},
      {
        if (avecPhotos)
          for (final an in g.animaux) an.id: await image('assets/images/archetypes/${an.id}.jpg'),
      },
    );
  }

  final Grammaire g;
  final TextesDestiny t;
  final PolicesPdf polices;
  final pw.ImageProvider? cube;
  final Map<String, pw.ImageProvider?> icones;
  final Map<String, pw.ImageProvider?> photos;

  late final titre = pw.Font.ttf(polices.titre);
  late final texte = pw.Font.ttf(polices.texte);
  late final gras = pw.Font.ttf(polices.texteGras);
  late final italique = pw.Font.ttf(polices.italique);
  late final theme = pw.ThemeData.withFont(base: texte, bold: gras, italic: italique);
  late final or = _hex(g.directionArtistique.couleurs['or'] ?? '#C9A24A');
  late final brun = _hex(g.directionArtistique.couleurs['or_fonce'] ?? '#8a5f14');
  late final encre = _hex(g.directionArtistique.couleurs['encre'] ?? '#2a2108');
  final gris = _hex('#7d7768');
  final coupe = PdfColors.grey400;

  PdfColor famille(FamilleId f) => _hex(g.famille(f).couleur);

  /// Une petite capitale espacée (« SON DUEL »).
  pw.Widget etiquette(String s, {PdfColor? couleur, double taille = 5.2}) => pw.Text(s.toUpperCase(),
      style: pw.TextStyle(font: gras, fontSize: taille, letterSpacing: 1.1, color: couleur ?? gris));

  /// La carte : fond blanc, filet or, liseré de couleur en haut.
  pw.Widget coque(PdfColor couleur, pw.Widget contenu) => pw.Container(
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(color: or, width: 0.9),
        ),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
          pw.Container(
            height: 3.2,
            decoration: pw.BoxDecoration(
              color: couleur,
              borderRadius: const pw.BorderRadius.only(topLeft: pw.Radius.circular(5.5), topRight: pw.Radius.circular(5.5)),
            ),
          ),
          pw.Expanded(child: contenu),
        ]),
      );

  /// Le dé, en petit, en tête de carte.
  pw.Widget de(double hauteur) => cube == null ? pw.SizedBox(height: hauteur) : pw.Image(cube!, height: hauteur);

  /// L'icône d'un archétype, blanche dans une pastille de sa couleur.
  pw.Widget pastille(String archetypeId, PdfColor couleur, double taille) => pw.Container(
        width: taille,
        height: taille,
        padding: pw.EdgeInsets.all(taille * 0.1),
        decoration: pw.BoxDecoration(color: couleur, shape: pw.BoxShape.circle),
        child: icones[archetypeId] == null ? null : pw.Image(icones[archetypeId]!),
      );

  /// La photo ronde d'un animal, cerclée d'or.
  pw.Widget photo(Animal an, double taille) => pw.Container(
        width: taille,
        height: taille,
        decoration: pw.BoxDecoration(shape: pw.BoxShape.circle, border: pw.Border.all(color: or, width: 0.8)),
        child: photos[an.id] == null
            ? null
            : pw.ClipOval(child: pw.Image(photos[an.id]!, width: taille, height: taille, fit: pw.BoxFit.cover)),
      );

  /// « HAUT », « NEUTRE », « BAS », sur fond clair.
  pw.Widget statut(Statut s) {
    final (fond, encreStatut) = switch (s) {
      Statut.haut => (_hex('#e3f1e8'), _hex('#2f6e4f')),
      Statut.neutre => (_hex('#f8efc8'), _hex('#8a6d14')),
      Statut.bas => (_hex('#ece6f5'), _hex('#5d4b86')),
    };
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 2.5, vertical: 0.6),
      decoration: pw.BoxDecoration(color: fond, borderRadius: pw.BorderRadius.circular(3)),
      child: pw.Text(s.name.toUpperCase(),
          style: pw.TextStyle(font: gras, fontSize: 4.6, letterSpacing: 0.6, color: encreStatut)),
    );
  }

  /// Le verso commun : le dé, « Destiny » et [sousTitre].
  pw.Widget verso(PdfColor couleur, String sousTitre) => pw.Container(
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          borderRadius: pw.BorderRadius.circular(6),
          border: pw.Border.all(color: or, width: 0.9),
        ),
        child: pw.Container(
          margin: const pw.EdgeInsets.all(2.2),
          decoration: pw.BoxDecoration(
            borderRadius: pw.BorderRadius.circular(4.5),
            border: pw.Border.all(color: couleur, width: 0.8),
          ),
          child: pw.Center(
            child: pw.Row(mainAxisSize: pw.MainAxisSize.min, children: [
              de(46),
              pw.SizedBox(width: 9),
              pw.Column(mainAxisSize: pw.MainAxisSize.min, crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                pw.Text(g.nom.toUpperCase(),
                    style: pw.TextStyle(font: titre, fontSize: 16, letterSpacing: 1.6, color: brun)),
                pw.SizedBox(height: 2),
                pw.Text(sousTitre.toUpperCase(),
                    style: pw.TextStyle(font: gras, fontSize: 5.2, letterSpacing: 1.8, color: brun)),
              ]),
            ]),
          ),
        ),
      );

  /// Une planche A4 : [colonnes] × [lignes] cases de [largeur] × [hauteur],
  /// séparées par des traits de coupe en pointillés. Une case vide reste
  /// blanche.
  pw.Widget planche(List<pw.Widget?> cases, {required int colonnes, required int lignes, required double largeur, required double hauteur}) =>
      pw.Center(
        child: pw.Column(mainAxisSize: pw.MainAxisSize.min, children: [
          for (var r = 0; r < lignes; r++)
            pw.Row(mainAxisSize: pw.MainAxisSize.min, children: [
              for (var c = 0; c < colonnes; c++)
                pw.Container(
                  width: largeur,
                  height: hauteur,
                  padding: const pw.EdgeInsets.all(2 * PdfPageFormat.mm),
                  decoration: cases[r * colonnes + c] == null
                      ? null
                      : pw.BoxDecoration(border: pw.Border.all(color: coupe, width: 0.4, style: pw.BorderStyle.dashed)),
                  child: cases[r * colonnes + c],
                ),
            ]),
        ]),
      );

  /// Les rectos par planches, chacune suivie de sa planche de versos, placée
  /// pour une impression recto verso, bord long (une carte en colonne c se
  /// retrouve en colonne colonnes - 1 - c).
  Future<Uint8List> document(
    String nom,
    List<(pw.Widget, pw.Widget)> cartes, {
    required int colonnes,
    required int lignes,
    required double largeur,
    required double hauteur,
  }) {
    final parPage = colonnes * lignes;
    final doc = pw.Document(title: '${g.nom} — $nom', author: g.nom);
    for (var debut = 0; debut < cartes.length; debut += parPage) {
      final page = cartes.skip(debut).take(parPage).toList();
      final rectos = <pw.Widget?>[for (var i = 0; i < parPage; i++) i < page.length ? page[i].$1 : null];
      final versos = <pw.Widget?>[
        for (var i = 0; i < parPage; i++)
          if ((i ~/ colonnes) * colonnes + (colonnes - 1 - i % colonnes) case final j when j < page.length)
            page[j].$2
          else
            null,
      ];
      for (final cases in [rectos, versos]) {
        doc.addPage(pw.Page(
          pageFormat: PdfPageFormat.a4,
          theme: theme,
          margin: pw.EdgeInsets.zero,
          build: (_) => planche(cases, colonnes: colonnes, lignes: lignes, largeur: largeur, hauteur: hauteur),
        ));
      }
    }
    return doc.save();
  }
}

/// Les cartes d'archétypes à imprimer : huit cartes de 98 × 69 mm par page
/// A4 (deux colonnes, quatre lignes). Un recto par archétype (à gauche,
/// l'archétype, son duel et sa montée ; à droite, ses trois vêtements) ou
/// par animal (24 cartes), et après chaque page de rectos, sa page de
/// versos Destiny, pour une impression recto verso (bord long).
Future<Uint8List> cartesArchetypesPdf({
  required Grammaire g,
  required TextesDestiny t,
  required PolicesPdf polices,
  bool parAnimal = false,
  LireImage lireImage = _lireAsset,
}) async {
  final s = await _StyleCartes.charger(g, t, polices, lireImage);
  final encre = s.encre;

  pw.Widget tetiere(Archetype a, PdfColor couleur) => pw.Row(children: [
        s.de(17),
        pw.Spacer(),
        s.etiquette(g.famille(a.famille).nom, couleur: couleur),
      ]);

  pw.Widget nomArchetype(Archetype a, PdfColor couleur, {double taille = 13}) => pw.Row(children: [
        s.pastille(a.id, couleur, taille + 3),
        pw.SizedBox(width: 5),
        pw.Expanded(child: pw.Text(a.nom, style: pw.TextStyle(font: s.titre, fontSize: taille, color: s.brun))),
      ]);

  pw.Widget montee(Archetype a, PdfColor couleur) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        s.etiquette(t.t('cartes.montee')),
        pw.SizedBox(height: 2),
        for (final p in g.paliers)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 0.8),
            child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.SizedBox(
                width: 26,
                child: pw.Text(t.t('cartes.acte', {'n': '${p.numero}'}).toUpperCase(),
                    style: pw.TextStyle(font: s.gras, fontSize: 5.2, letterSpacing: 0.6, color: couleur)),
              ),
              pw.Expanded(child: pw.Text(a.monteeA(p.id), style: pw.TextStyle(fontSize: 6.3, color: encre))),
            ]),
          ),
      ]);

  pw.Widget duel(Archetype a, PdfColor couleur) {
    final d = g.distribution.duelDe(a.id);
    final adv = d == null ? null : g.archetype(d.adversaire(a.id));
    if (d == null || adv == null) return pw.SizedBox();
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      s.etiquette(t.t('cartes.son_duel')),
      pw.SizedBox(height: 1.5),
      pw.RichText(
        text: pw.TextSpan(children: [
          pw.TextSpan(text: a.nom, style: pw.TextStyle(font: s.titre, fontSize: 7.6, color: couleur)),
          pw.TextSpan(
              text: '  ${t.t('cartes.contre').toUpperCase()}  ',
              style: pw.TextStyle(font: s.gras, fontSize: 4.6, letterSpacing: 0.6, color: s.gris)),
          pw.TextSpan(
              text: adv.nom, style: pw.TextStyle(font: s.titre, fontSize: 7.6, color: s.famille(adv.famille))),
        ]),
      ),
      pw.SizedBox(height: 1.5),
      pw.Text(t.t('cartes.duel_phrase', {'mien': d.reflexe(a.id), 'sien': d.reflexe(adv.id)}),
          style: pw.TextStyle(font: s.italique, fontSize: 6.1, color: encre)),
    ]);
  }

  pw.Widget vetement(Animal an, PdfColor couleur) => pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        s.photo(an, 25),
        pw.SizedBox(width: 5),
        pw.Expanded(
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
              pw.Text(an.nom, style: pw.TextStyle(font: s.titre, fontSize: 8.4, color: s.brun)),
              pw.Spacer(),
              pw.Text('${an.port} · ', style: pw.TextStyle(fontSize: 5, color: s.gris)),
              s.statut(an.statutDepart),
            ]),
            pw.SizedBox(height: 1),
            pw.Text('« ${an.replique} »', style: pw.TextStyle(font: s.italique, fontSize: 6.3, color: couleur)),
            if (an.exempleVouloir.isNotEmpty) ...[
              pw.SizedBox(height: 1.2),
              pw.Text(an.exempleVouloir, style: pw.TextStyle(font: s.italique, fontSize: 5.6, color: encre)),
            ],
          ]),
        ),
      ]);

  pw.Widget rectoArchetype(Archetype a) {
    final couleur = s.famille(a.famille);
    final animaux = g.animauxDe(a.id);
    return s.coque(
      couleur,
      pw.Padding(
        padding: const pw.EdgeInsets.fromLTRB(7, 5, 7, 5),
        child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
          pw.Expanded(
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              tetiere(a, couleur),
              pw.SizedBox(height: 3),
              nomArchetype(a, couleur),
              pw.SizedBox(height: 4),
              pw.Text(a.ceQuIlFait, style: pw.TextStyle(font: s.gras, fontSize: 6.9, color: encre)),
              pw.SizedBox(height: 3),
              pw.Spacer(),
              duel(a, couleur),
              pw.SizedBox(height: 2.5),
              pw.Container(height: 0.5, color: s.or),
              pw.SizedBox(height: 2.5),
              montee(a, couleur),
            ]),
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              s.etiquette(t.t('cartes.vetements')),
              pw.SizedBox(height: 2.5),
              for (final (i, an) in animaux.indexed)
                pw.Expanded(
                  child: pw.Container(
                    padding: pw.EdgeInsets.only(top: i == 0 ? 0 : 3),
                    decoration: i == 0
                        ? null
                        : pw.BoxDecoration(
                            border: pw.Border(top: pw.BorderSide(color: s.or, width: 0.4, style: pw.BorderStyle.dotted))),
                    child: vetement(an, couleur),
                  ),
                ),
            ]),
          ),
        ]),
      ),
    );
  }

  pw.Widget rectoAnimal(Animal an) {
    final a = g.archetype(an.archetypeId)!;
    final couleur = s.famille(a.famille);
    return s.coque(
      couleur,
      pw.Padding(
        padding: const pw.EdgeInsets.fromLTRB(7, 5, 7, 5),
        child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
          pw.Expanded(
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              tetiere(a, couleur),
              pw.SizedBox(height: 3),
              nomArchetype(a, couleur, taille: 9),
              pw.SizedBox(height: 5),
              pw.Row(children: [
                s.photo(an, 44),
                pw.SizedBox(width: 6),
                pw.Expanded(
                  child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                    pw.Text(an.nom, style: pw.TextStyle(font: s.titre, fontSize: 13, color: s.brun)),
                    pw.SizedBox(height: 2),
                    pw.Row(children: [
                      pw.Text('${an.port} · ', style: pw.TextStyle(fontSize: 5.5, color: s.gris)),
                      s.statut(an.statutDepart),
                    ]),
                  ]),
                ),
              ]),
              pw.SizedBox(height: 5),
              pw.Text(an.posture, style: pw.TextStyle(fontSize: 6.6, color: encre)),
              pw.Spacer(),
              pw.Text('« ${an.replique} »', style: pw.TextStyle(font: s.italique, fontSize: 7, color: couleur)),
            ]),
          ),
          pw.SizedBox(width: 8),
          pw.Expanded(
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              s.etiquette(t.t('cartes.exemple')),
              pw.SizedBox(height: 2),
              pw.Text(an.exempleVouloir, style: pw.TextStyle(font: s.italique, fontSize: 6.4, color: encre)),
              pw.SizedBox(height: 5),
              pw.Container(height: 0.5, color: s.or),
              pw.SizedBox(height: 4),
              s.etiquette(t.t('cartes.corps_actes')),
              pw.SizedBox(height: 2),
              for (final p in g.paliers)
                if (an.corpsA(p.id).isNotEmpty)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 1.6),
                    child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                      pw.SizedBox(
                        width: 26,
                        child: pw.Text(t.t('cartes.acte', {'n': '${p.numero}'}).toUpperCase(),
                            style: pw.TextStyle(font: s.gras, fontSize: 5.2, letterSpacing: 0.6, color: couleur)),
                      ),
                      pw.Expanded(child: pw.Text(an.corpsA(p.id), style: pw.TextStyle(fontSize: 6, color: encre))),
                    ]),
                  ),
            ]),
          ),
        ]),
      ),
    );
  }

  final promesse = t.t('cartes.promesse');
  final cartes = parAnimal
      ? [
          for (final a in g.archetypes)
            for (final an in g.animauxDe(a.id)) (rectoAnimal(an), s.verso(s.famille(a.famille), promesse)),
        ]
      : [for (final a in g.archetypes) (rectoArchetype(a), s.verso(s.famille(a.famille), promesse))];
  return s.document(t.t('bibliotheque.entrees.archetypes.titre'), cartes,
      colonnes: 2, lignes: 4, largeur: 98 * PdfPageFormat.mm, hauteur: 69 * PdfPageFormat.mm);
}

/// Les cartes de dangers à imprimer, dans le style des cartes d'archétypes :
/// 95 × 55 mm, dix par page A4 (deux colonnes, cinq lignes). Au recto, le
/// danger et ses quatre paliers ; au verso, le dé Destiny cerclé de rouge
/// (on les tire face cachée), placé pour une impression recto verso, bord
/// long. [kids] : le palier 4 des enfants.
Future<Uint8List> cartesDangersPdf({
  required Grammaire g,
  required TextesDestiny t,
  required PolicesPdf polices,
  required List<Danger> dangers,
  bool kids = false,
  LireImage lireImage = _lireAsset,
}) async {
  final s = await _StyleCartes.charger(g, t, polices, lireImage, avecPhotos: false);
  final kidsCouleur = _hex(g.directionArtistique.couleurs['kids'] ?? '#F2C230');
  final rouge = _hex('#A8322D');
  // Le danger monte : de l'or au rouge sombre, palier après palier.
  final teintes = [s.brun, _hex('#B5651D'), _hex('#A8322D'), _hex('#6E1414')];

  pw.Widget recto(Danger d) {
    final paliers = d.paliersPour(kids: kids);
    return s.coque(
      rouge,
      pw.Padding(
        padding: const pw.EdgeInsets.fromLTRB(7, 4, 7, 4),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Row(children: [
            s.de(14),
            pw.SizedBox(width: 4),
            s.etiquette(t.t('cartes.danger'), couleur: rouge),
            pw.Spacer(),
            if (d.kids)
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 0.8),
                decoration: pw.BoxDecoration(color: kidsCouleur, borderRadius: pw.BorderRadius.circular(3)),
                child: pw.Text('KIDS', style: pw.TextStyle(font: s.gras, fontSize: 5.5, color: s.encre)),
              ),
          ]),
          pw.SizedBox(height: 1.5),
          pw.Text(d.name, style: pw.TextStyle(font: s.titre, fontSize: 11, color: s.brun)),
          pw.SizedBox(height: 3),
          for (final p in g.paliers)
            if (p.numero <= paliers.length)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 3.2),
                child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Container(
                    width: 9.5,
                    height: 9.5,
                    margin: const pw.EdgeInsets.only(right: 4),
                    alignment: pw.Alignment.center,
                    decoration: pw.BoxDecoration(color: teintes[p.numero - 1], shape: pw.BoxShape.circle),
                    child: pw.Text('${p.numero}', style: pw.TextStyle(font: s.gras, fontSize: 6, color: PdfColors.white)),
                  ),
                  pw.Expanded(
                    child: pw.RichText(
                      text: pw.TextSpan(children: [
                        pw.TextSpan(
                            text: '${p.nom.toUpperCase()}  ',
                            style: pw.TextStyle(
                                font: s.gras, fontSize: 5.4, letterSpacing: 0.6, color: teintes[p.numero - 1])),
                        pw.TextSpan(text: paliers[p.numero - 1], style: pw.TextStyle(fontSize: 7.9, color: s.encre)),
                      ]),
                    ),
                  ),
                ]),
              ),
        ]),
      ),
    );
  }

  final cartes = [for (final d in dangers) (recto(d), s.verso(rouge, t.t('cartes.danger')))];
  return s.document(t.t('bibliotheque.entrees.dangers.titre'), cartes,
      colonnes: 2, lignes: 5, largeur: 95 * PdfPageFormat.mm, hauteur: 55 * PdfPageFormat.mm);
}

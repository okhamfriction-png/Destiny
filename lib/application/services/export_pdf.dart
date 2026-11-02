import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../domain/grammaire/modeles.dart';
import '../../domain/grammaire/textes.dart';
import '../../domain/troupe/session.dart';

/// Les polices des PDF (les mêmes que l'appli).
class PolicesPdf {
  const PolicesPdf({required this.titre, required this.texte, required this.texteGras, required this.italique});

  final ByteData titre;
  final ByteData texte;
  final ByteData texteGras;
  final ByteData italique;
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
      h(t.t('mise_en_place.objets')),
      for (final o in s.objets)
        if (o.isNotEmpty) pw.Bullet(text: o, style: const pw.TextStyle(fontSize: 10.5)),
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

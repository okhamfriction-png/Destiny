import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../application/livret/livret.dart';
import '../../application/services/export_pdf.dart';
import '../destiny/composants.dart';
import '../destiny/donnees.dart';
import '../destiny/page.dart';
import '../theme/destiny_theme.dart';

/// Le livret de règles : le but, le matériel, les rôles, la mise en place, le
/// déroulé, la fin, les variantes et les règles d'or. Il s'exporte en PDF.
class LivretScreen extends StatefulWidget {
  const LivretScreen({super.key});

  @override
  State<LivretScreen> createState() => _LivretScreenState();
}

class _LivretScreenState extends State<LivretScreen> {
  final Map<String, GlobalKey> _ancres = {for (final id in kSectionsLivret) id: GlobalKey()};
  bool _export = false;

  Future<void> _exporter(Livret livret) async {
    final g = context.grammaire;
    final t = context.textes;
    final messager = ScaffoldMessenger.of(context);
    setState(() => _export = true);
    messager.showSnackBar(SnackBar(content: Text(t.t('livret.export_en_cours'))));
    try {
      final polices = await PolicesPdf.chargerDepuisAssets();
      final octets = await livretPdf(livret: livret, g: g, polices: polices);
      await Printing.sharePdf(bytes: octets, filename: 'destiny-livret-de-regles.pdf');
    } catch (_) {
      messager.showSnackBar(SnackBar(content: Text(t.t('livret.export_echec'))));
    } finally {
      if (mounted) setState(() => _export = false);
    }
  }

  void _allerA(String id) {
    final ctx = _ancres[id]?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = context.grammaire;
    final t = context.textes;
    final c = context.destiny;
    final livret = construireLivret(g, t);
    return Scaffold(
      appBar: AppBar(
        title: Text(livret.titre),
        actions: [
          IconButton(
            tooltip: t.t('livret.exporter'),
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: _export ? null : () => _exporter(livret),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                BandeauAffiche(titre: g.nom.toUpperCase(), surtitre: livret.titre, sousTitre: livret.sousTitre),
                const SizedBox(height: 12),
                Text(t.t('livret.sommaire').toUpperCase(),
                    style: TextStyle(
                        fontFamily: kPoliceTexte,
                        fontSize: 12.5,
                        letterSpacing: 2,
                        fontWeight: FontWeight.w700,
                        color: c.titre)),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final s in livret.sections)
                    ActionChip(label: Text(s.titre), onPressed: () => _allerA(s.id)),
                ]),
                for (final s in livret.sections)
                  KeyedSubtree(
                    key: _ancres[s.id],
                    child: SectionDestiny(titre: s.titre, espace: 22, enfants: [for (final b in s.blocs) BlocLivretVue(b)]),
                  ),
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed: _export ? null : () => _exporter(livret),
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                  label: Text(t.t('livret.exporter')),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Un bloc du livret à l'écran.
class BlocLivretVue extends StatelessWidget {
  const BlocLivretVue(this.bloc, {super.key});

  final BlocLivret bloc;

  @override
  Widget build(BuildContext context) {
    final c = context.destiny;
    return switch (bloc) {
      IntertitreLivret(:final texte) => Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 6),
          child: Text(texte,
              style: TextStyle(fontFamily: kPoliceTexte, fontWeight: FontWeight.w700, fontSize: 16, color: c.texte)),
        ),
      ParagrapheLivret(:final texte, :final italique) => Paragraphe(texte, italique: italique),
      PucesLivret(:final items, :final numerotees) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (var i = 0; i < items.length; i++) Puce(items[i], numero: numerotees ? i + 1 : null),
        ]),
      InfoLivret(:final libelle, :final valeur) => LigneInfo(libelle, valeur),
      EncartLivret(:final texte) => Container(
          margin: const EdgeInsets.only(top: 2, bottom: 10),
          padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
          decoration: BoxDecoration(
            color: c.bleuDestiny.withValues(alpha: c.sombre ? 0.16 : 0.08),
            border: Border(left: BorderSide(color: c.bleuDestiny, width: 3)),
            borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
          ),
          child: Text(texte,
              style: TextStyle(
                  fontFamily: kPoliceTexte, fontSize: 14.5, height: 1.35, fontStyle: FontStyle.italic, color: c.texte)),
        ),
    };
  }
}

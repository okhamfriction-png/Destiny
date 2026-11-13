import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../application/state/reglages_destiny.dart';
import '../../domain/grammaire/lecture.dart';

import '../bibliotheque/archetypes_screen.dart';
import '../bibliotheque/bibliotheque_screen.dart';
import '../destiny/donnees.dart';
import '../destiny/page.dart';
import 'editeur_exemples_vouloir_screen.dart';

/// Le mode admin : la grammaire (sa version, ce qu'elle contient), la liste
/// des archétypes, et l'éditeur des exemples de vouloir. Le reste de la
/// grammaire se change dans son fichier.
class GrammaireAdminScreen extends StatelessWidget {
  const GrammaireAdminScreen({super.key, this.contexteBibliotheque, this.reglages});

  /// Pour modifier les exemples de vouloir.
  final ReglagesDestiny? reglages;

  /// Pour ouvrir les fiches des archétypes.
  final ContexteBibliotheque? contexteBibliotheque;

  /// Relit le fichier de grammaire et le vérifie.
  static Future<List<String>> verifier() async {
    try {
      final brut = jsonDecode(await rootBundle.loadString('assets/data/destiny_grammaire.json'));
      return validerGrammaire(Map<String, dynamic>.from(brut as Map));
    } catch (e) {
      return ['$e'];
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = context.grammaire;
    final t = context.textes;
    String k(String x, [Map<String, String> v = const {}]) => t.t('reglages.$x', v);
    final contenu = <String, int>{
      'archétypes': g.archetypes.length,
      'animaux': g.animaux.length,
      'paliers': g.paliers.length,
      'actes': g.actes.length,
      'règles d\'or': g.reglesDOr.length,
      'dangers': g.dangers.length,
      'lieux': g.lieux.length,
      'œuvres': g.oeuvres.length,
      'grands méchants': g.mechants.length,
      'sbires': g.mechants.fold(0, (n, m) => n + m.sbires.length),
      'figurants prêts': g.lieux.fold(0, (n, l) => n + l.figurants.length),
      'types de figurants': g.figurants.types.length,
      'exercices': g.exercices.length,
    };
    return PageDestiny(
      titre: k('grammaire_titre'),
      enfants: [
        Paragraphe('${g.nom} — ${k('grammaire_version', {'version': g.version})}', gras: true),
        FutureBuilder<List<String>>(
          future: verifier(),
          builder: (context, snap) {
            final erreurs = snap.data;
            if (erreurs == null) return const LinearProgressIndicator();
            if (erreurs.isEmpty) return Paragraphe(k('grammaire_ok'));
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Paragraphe(k('grammaire_erreurs'), gras: true),
              for (final e in erreurs) Puce(e),
            ]);
          },
        ),
        SectionDestiny(titre: k('grammaire_contenu'), enfants: [
          for (final e in contenu.entries) LigneInfo(e.key, '${e.value}'),
        ]),
        if (contexteBibliotheque != null)
          FilledButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => ArchetypesScreen(contexte: contexteBibliotheque!))),
            icon: const Icon(Icons.style_outlined),
            label: Text(t.t('bibliotheque.entrees.archetypes.titre')),
          ),
        if (reglages != null) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            key: const ValueKey('admin_exemples_vouloir'),
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => EditeurExemplesVouloirScreen(reglages: reglages!))),
            icon: const Icon(Icons.edit_note_rounded),
            label: Text(t.t('trouver_vouloir.admin_titre')),
          ),
        ],
      ],
    );
  }
}

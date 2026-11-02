import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show LicenseEntryWithLineBreaks, LicenseRegistry;
import 'package:flutter/services.dart' show rootBundle;
import 'package:url_launcher/url_launcher.dart';

import '../../application/version.dart';
import '../destiny/donnees.dart';
import '../destiny/page.dart';

/// Les licences des polices embarquées (SIL Open Font License 1.1), à
/// enregistrer au démarrage pour la page des licences.
const Map<String, String> kLicencesPolices = {
  'Cinzel': 'assets/fonts/OFL-Cinzel.txt',
  'Montserrat': 'assets/fonts/OFL-Montserrat.txt',
  'Patrick Hand': 'assets/fonts/OFL-PatrickHand.txt',
};

/// Ajoute les licences des polices à la page des licences de l'appli.
void enregistrerLicencesPolices() {
  LicenseRegistry.addLicense(() async* {
    for (final e in kLicencesPolices.entries) {
      try {
        yield LicenseEntryWithLineBreaks([e.key], await rootBundle.loadString(e.value));
      } catch (_) {}
    }
  });
}

/// Les crédits : les polices, les sons d'ambiance (freesound.org) et les
/// logiciels libres.
class CreditsScreen extends StatefulWidget {
  const CreditsScreen({super.key});

  @override
  State<CreditsScreen> createState() => _CreditsScreenState();
}

class _CreditsScreenState extends State<CreditsScreen> {
  List<_Credit> _sons = const [];
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final liste = <_Credit>[];
    for (final chemin in const ['assets/audio/ambiences/attributions.json', 'assets/audio/universes/attributions.json']) {
      try {
        final data = jsonDecode(await rootBundle.loadString(chemin)) as Map<String, dynamic>;
        for (final v in data.values) {
          final m = v as Map<String, dynamic>;
          liste.add(_Credit(
            nom: m['name'] as String? ?? '',
            auteur: m['author'] as String? ?? '',
            licence: m['license'] as String? ?? '',
            url: m['url'] as String? ?? '',
          ));
        }
      } catch (_) {}
    }
    liste.sort((a, b) => a.nom.toLowerCase().compareTo(b.nom.toLowerCase()));
    if (!mounted) return;
    setState(() {
      _sons = liste;
      _chargement = false;
    });
  }

  static String _licenceCourte(String url) {
    final u = url.toLowerCase();
    if (u.contains('publicdomain') || u.contains('zero')) return 'CC0';
    if (u.contains('by-nc')) return 'CC BY-NC';
    if (u.contains('by-sa')) return 'CC BY-SA';
    if (u.contains('/by/')) return 'CC BY';
    if (u.contains('sampling')) return 'Sampling+';
    return 'CC';
  }

  @override
  Widget build(BuildContext context) {
    final g = context.grammaire;
    final t = context.textes;
    String k(String x, [Map<String, String> v = const {}]) => t.t('credits.$x', v);
    return PageDestiny(
      titre: k('titre'),
      enfants: [
        SectionDestiny(titre: k('polices'), espace: 0, enfants: [
          Paragraphe(k('polices_texte')),
          for (final p in t.liste('credits.polices_liste')) Puce(p),
        ]),
        SectionDestiny(titre: k('logiciels'), enfants: [
          Paragraphe(k('logiciels_texte')),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => showLicensePage(
                context: context,
                applicationName: g.nom,
                applicationVersion: kVersionAppli,
              ),
              icon: const Icon(Icons.description_outlined, size: 18),
              label: Text(k('voir_licences')),
            ),
          ),
        ]),
        SectionDestiny(titre: k('sons'), enfants: [
          Paragraphe(k('sons_texte')),
          if (_chargement)
            const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
          else if (_sons.isEmpty)
            Paragraphe(k('aucun'), italique: true)
          else
            for (final s in _sons)
              ElementListe(
                titre: s.nom,
                sousTitre: k('par', {'auteur': s.auteur, 'licence': _licenceCourte(s.licence)}),
                apres: s.url.isEmpty ? null : const Icon(Icons.open_in_new_rounded, size: 18),
                onTap: s.url.isEmpty
                    ? null
                    : () => launchUrl(Uri.parse(s.url), mode: LaunchMode.externalApplication),
              ),
        ]),
      ],
    );
  }
}

class _Credit {
  const _Credit({required this.nom, required this.auteur, required this.licence, required this.url});
  final String nom;
  final String auteur;
  final String licence;
  final String url;
}

import 'dart:convert';

import 'package:flutter/services.dart';

import '../../domain/grammaire/lecture.dart';
import '../../domain/grammaire/modeles.dart';
import '../../domain/grammaire/textes.dart';

/// La grammaire chargée, avec les textes de l'appli et les problèmes trouvés
/// à la validation.
class GrammaireChargee {
  const GrammaireChargee({
    required this.grammaire,
    required this.textes,
    this.erreurs = const [],
  });

  final Grammaire grammaire;
  final TextesDestiny textes;

  /// Problèmes trouvés dans le fichier (vide si tout va bien). L'appli
  /// démarre quand même ; le mode admin les affiche.
  final List<String> erreurs;
}

/// Lit `destiny_grammaire.json`, les données des animaux de l'appli et
/// `destiny_textes.json`, une seule fois.
class GrammaireSource {
  GrammaireSource({Future<String> Function(String chemin)? lire})
      : _lire = lire ?? rootBundle.loadString;

  static const String cheminGrammaire = 'assets/data/destiny_grammaire.json';
  static const String cheminAnimaux = 'assets/data/archetypes.json';
  static const String cheminTextes = 'assets/data/destiny_textes.json';

  final Future<String> Function(String) _lire;
  Future<GrammaireChargee>? _cache;

  Future<GrammaireChargee> charger() => _cache ??= _charger();

  Future<GrammaireChargee> _charger() async {
    final brut = jsonDecode(await _lire(cheminGrammaire)) as Map<String, dynamic>;
    final erreurs = validerGrammaire(brut);
    final animaux = <String, DonneesAnimalAppli>{};
    try {
      final a = jsonDecode(await _lire(cheminAnimaux)) as Map<String, dynamic>;
      for (final e in (a['archetypes'] as List? ?? const [])) {
        final m = Map<String, dynamic>.from(e as Map);
        animaux['${m['id']}'] = DonneesAnimalAppli.depuisJson(m);
      }
    } catch (e) {
      erreurs.add('Données des animaux illisibles : $e');
    }
    var textes = TextesDestiny.vides();
    try {
      textes = TextesDestiny(
          jsonDecode(await _lire(cheminTextes)) as Map<String, dynamic>);
    } catch (e) {
      erreurs.add('Textes de l\'appli illisibles : $e');
    }
    return GrammaireChargee(
      grammaire: lireGrammaire(brut, animauxAppli: animaux),
      textes: textes,
      erreurs: erreurs,
    );
  }
}

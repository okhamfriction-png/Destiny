import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../../domain/entities/exercice.dart';

/// Charge le carnet `assets/data/exercices.json`. Si le fichier manque ou
/// est illisible, rend un carnet vide : les exercices de la grammaire restent.
Future<CarnetExercices> chargerCarnetExercices({AssetBundle? bundle}) async {
  try {
    final brut = await (bundle ?? rootBundle).loadString('assets/data/exercices.json');
    return CarnetExercices.depuisJson(jsonDecode(brut) as Map<String, dynamic>);
  } catch (_) {
    return CarnetExercices.vide;
  }
}

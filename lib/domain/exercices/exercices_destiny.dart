/// Les exercices Destiny du menu Exercices : deux exercices minutés sur la
/// musique d'un lieu (Duo, Impro filée en duo). Et le tirage du danger du
/// spectacle, au DESTINY n°1.
///
/// Ce fichier ne contient que des règles, sans son ni écran : elles se
/// testent seules.
library;

import 'dart:math';

import '../grammaire/modeles.dart' show PalierId;
import '../entities/danger.dart';

/// Les deux exercices de la section Destiny. (Le Trio et le Long form ont
/// été retirés en 2.7.0.)
enum ExerciceDestiny {
  duo(joueurs: 2, idCarnet: 'destiny_duo'),
  improFilee(joueurs: 2, idCarnet: 'destiny_impro_filee');

  const ExerciceDestiny({required this.joueurs, required this.idCarnet});

  /// Le nombre de joueurs.
  final int joueurs;

  /// L'identifiant de l'exercice dans `exercices.json` (sa consigne).
  final String idCarnet;
}

/// Les durées proposées sur l'écran de préparation d'un exercice minuté.
const List<int> kDureesProposeesS = [90, 120, 180, 300, 480];

/// Les réglages des exercices Destiny. Ils ne touchent pas à ceux de la
/// régie du spectacle.
class ReglagesExercicesDestiny {
  ReglagesExercicesDestiny();

  /// La musique tient son volume tant de secondes…
  double maintienS = 20;

  /// …puis descend en tant de secondes…
  double descenteS = 10;

  /// …jusqu'à ce niveau (0 à 1) : 0 par défaut, elle s'arrête.
  double fondMinute = 0;

  /// La durée par défaut de chaque exercice, en secondes.
  Map<ExerciceDestiny, int> dureesS = {
    ExerciceDestiny.duo: 120,
    ExerciceDestiny.improFilee: 180,
  };

  int dureeDe(ExerciceDestiny e) => dureesS[e] ?? ReglagesExercicesDestiny().dureesS[e]!;

  Map<String, dynamic> versJson() => {
        'maintien_s': maintienS,
        'descente_s': descenteS,
        'fond_minute': fondMinute,
        'durees_s': {for (final e in dureesS.entries) e.key.name: e.value},
      };

  /// Lit des réglages enregistrés ; une valeur absente ou illisible garde sa
  /// valeur par défaut.
  static ReglagesExercicesDestiny depuisJson(Map<String, dynamic> j) {
    final r = ReglagesExercicesDestiny();
    double d(String cle, double defaut, double mini, double maxi) =>
        ((j[cle] as num?)?.toDouble() ?? defaut).clamp(mini, maxi);
    r
      ..maintienS = d('maintien_s', r.maintienS, 0, 600)
      ..descenteS = d('descente_s', r.descenteS, 0, 120)
      ..fondMinute = d('fond_minute', r.fondMinute, 0, 1);
    final durees = j['durees_s'];
    if (durees is Map) {
      for (final e in ExerciceDestiny.values) {
        final v = durees[e.name];
        if (v is num && v >= 10) r.dureesS[e] = v.toInt();
      }
    }
    return r;
  }
}

/// Les trois types du dé du danger, dans l'ordre des faces.
enum TypeDanger {
  catastrophe('Catastrophe', 'DESTINY2_CATASTROPHE'),
  thriller('Thriller', 'DESTINY2_THRILLER'),
  survie('Survie / Dilemme', 'DESTINY2_SURVIE');

  const TypeDanger(this.style, this.codeDestiny2);

  /// Le style des dangers de ce type, dans `dangers.json`.
  final String style;

  /// Le son du DESTINY n°2 de ce type, dans le pack audio.
  final String codeDestiny2;

  /// Le type d'un style de `dangers.json` (null : un autre style).
  static TypeDanger? deStyle(String style) {
    final s = style.toLowerCase();
    if (s.contains('catastrophe')) return catastrophe;
    if (s.contains('thriller')) return thriller;
    if (s.contains('survie') || s.contains('dilemme')) return survie;
    return null;
  }
}

/// Le code du son du DESTINY n°2 pour un danger de style [style] (null :
/// style inconnu, on garde le son Destiny habituel).
String? codeDestiny2(String style) => TypeDanger.deStyle(style)?.codeDestiny2;

/// Le code de la cloche de fin d'exercice.
const String kCodeCloche = 'FIN_EXERCICE';

/// Le dé du danger du spectacle (DESTINY n°1) : un type au hasard, puis un
/// danger jouable de ce type (actif, trois niveaux, kids si besoin). Si le
/// type n'a aucun danger, un danger jouable d'un autre type, et son type.
/// [type] impose le type (« Retirer un danger » dans le même type).
({TypeDanger type, Danger? danger}) tirerDangerAuDe(
  List<Danger> dangers, {
  bool kids = false,
  TypeDanger? type,
  String? sauf,
  Random? hasard,
}) {
  final h = hasard ?? Random();
  final jouables = [
    for (final d in dangers)
      if (d.actif && d.paliers.length == PalierId.values.length && (!kids || d.kids)) d,
  ];
  final t = type ?? TypeDanger.values[h.nextInt(TypeDanger.values.length)];
  Danger? piocher(List<Danger> liste) {
    if (liste.isEmpty) return null;
    final autres = liste.length > 1 ? liste.where((d) => d.id != sauf).toList() : liste;
    return autres[h.nextInt(autres.length)];
  }

  final duType = piocher([
    for (final d in jouables)
      if (TypeDanger.deStyle(d.style) == t) d,
  ]);
  if (duType != null || type != null) return (type: t, danger: duType);
  final autre = piocher(jouables);
  return (type: autre == null ? t : TypeDanger.deStyle(autre.style) ?? t, danger: autre);
}

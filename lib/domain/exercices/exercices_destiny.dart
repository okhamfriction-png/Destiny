/// Les exercices Destiny du menu Exercices : trois exercices minutés sur la
/// musique d'un lieu (Duo, Impro filée en duo, Trio) et le long form, avec
/// les trois DESTINY, le dé du danger et le dé des survivants.
///
/// Ce fichier ne contient que des règles, sans son ni écran : elles se
/// testent seules.
library;

/// Les quatre exercices de la section Destiny.
enum ExerciceDestiny {
  duo(joueurs: 2, idCarnet: 'destiny_duo'),
  improFilee(joueurs: 2, idCarnet: 'destiny_impro_filee'),
  trio(joueurs: 3, idCarnet: 'destiny_trio'),
  longForm(joueurs: 4, idCarnet: 'destiny_long_form');

  const ExerciceDestiny({required this.joueurs, required this.idCarnet});

  /// Le nombre de joueurs (le long form : par défaut, de 2 à 8).
  final int joueurs;

  /// L'identifiant de l'exercice dans `exercices.json` (sa consigne).
  final String idCarnet;

  bool get minute => this != longForm;
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

  /// …jusqu'à ce niveau (0 à 1) : 0 pour les exercices minutés (elle
  /// s'arrête)…
  double fondMinute = 0;

  /// …et 5 % pour le long form, aux quatre actes.
  double fondLongForm = 0.05;

  /// La durée par défaut de chaque exercice, en secondes.
  Map<ExerciceDestiny, int> dureesS = {
    ExerciceDestiny.duo: 120,
    ExerciceDestiny.improFilee: 180,
    ExerciceDestiny.trio: 480,
    ExerciceDestiny.longForm: 45 * 60,
  };

  /// Les moments des trois DESTINY du long form, en minutes, pour sa durée
  /// par défaut.
  List<double> momentsDestinyMin = [10, 22, 40];

  int dureeDe(ExerciceDestiny e) => dureesS[e] ?? ReglagesExercicesDestiny().dureesS[e]!;

  Map<String, dynamic> versJson() => {
        'maintien_s': maintienS,
        'descente_s': descenteS,
        'fond_minute': fondMinute,
        'fond_long_form_v2': fondLongForm,
        'durees_s': {for (final e in dureesS.entries) e.key.name: e.value},
        'moments_destiny_min': momentsDestinyMin,
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
      ..fondMinute = d('fond_minute', r.fondMinute, 0, 1)
      ..fondLongForm = d('fond_long_form_v2', r.fondLongForm, 0, 1);
    final durees = j['durees_s'];
    if (durees is Map) {
      for (final e in ExerciceDestiny.values) {
        final v = durees[e.name];
        if (v is num && v >= 10) r.dureesS[e] = v.toInt();
      }
    }
    final moments = j['moments_destiny_min'];
    if (moments is List && moments.length == 3 && moments.every((x) => x is num && x > 0)) {
      r.momentsDestinyMin = [for (final x in moments) (x as num).toDouble()];
    }
    return r;
  }
}

/// Les moments des trois DESTINY (en secondes) pour une durée totale de
/// [dureeS] : ceux de [momentsMin] (prévus pour [dureeReferenceS]) ramenés au
/// prorata, dans l'ordre, chacun dans la durée.
List<int> momentsAuProrata(List<double> momentsMin, int dureeReferenceS, int dureeS) {
  final ratio = dureeReferenceS <= 0 ? 1.0 : dureeS / dureeReferenceS;
  final sortie = <int>[];
  for (final m in momentsMin) {
    var s = (m * 60 * ratio).round();
    if (sortie.isNotEmpty && s <= sortie.last) s = sortie.last + 1;
    sortie.add(s.clamp(1, dureeS > 1 ? dureeS - 1 : 1));
  }
  return sortie;
}

/// Une face du dé des survivants.
sealed class FaceSurvivants {
  const FaceSurvivants();
}

/// « Personne », « 1 survivant », « 2 survivants »… ([nombre] de 0 à N − 1).
class FaceNombre extends FaceSurvivants {
  const FaceNombre(this.nombre);
  final int nombre;

  @override
  bool operator ==(Object other) => other is FaceNombre && other.nombre == nombre;

  @override
  int get hashCode => nombre.hashCode;

  @override
  String toString() => 'FaceNombre($nombre)';
}

/// « Tous ».
class FaceTous extends FaceSurvivants {
  const FaceTous();

  @override
  bool operator ==(Object other) => other is FaceTous;

  @override
  int get hashCode => 1;

  @override
  String toString() => 'FaceTous';
}

/// « Le public décide ».
class FacePublic extends FaceSurvivants {
  const FacePublic();

  @override
  bool operator ==(Object other) => other is FacePublic;

  @override
  int get hashCode => 2;

  @override
  String toString() => 'FacePublic';
}

/// Les faces du dé des survivants pour [protagonistes] joueurs (2 à 8) :
/// Personne, 1, …, N − 1 survivants, Tous, Le public décide.
List<FaceSurvivants> facesSurvivants(int protagonistes) {
  final n = protagonistes.clamp(2, 8);
  return [for (var i = 0; i < n; i++) FaceNombre(i), const FaceTous(), const FacePublic()];
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

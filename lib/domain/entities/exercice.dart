/// Un exercice d'échauffement ou un jeu de théâtre court, venu du carnet
/// `exercices.json` (les thèmes d'avant la grammaire : Échauffement, Statut,
/// Spontanéité, Écoute, Dialogue, Imagination).
class Exercice {
  const Exercice({
    required this.id,
    required this.nom,
    required this.consigne,
    required this.duree,
    required this.categorie,
  });

  final String id;
  final String nom;

  /// Consigne courte (une à deux phrases).
  final String consigne;

  /// Durée conseillée, en secondes.
  final int duree;

  /// Le thème : Échauffement, Statut, Spontanéité, Écoute, Dialogue, Imagination.
  final String categorie;

  factory Exercice.fromJson(Map<String, dynamic> json) => Exercice(
        id: json['id'] as String,
        nom: json['nom'] as String,
        consigne: json['consigne'] as String,
        duree: (json['duree'] as num?)?.toInt() ?? 120,
        categorie: json['categorie'] as String? ?? 'Imagination',
      );
}

/// Le carnet d'exercices : les exercices d'avant la grammaire, les principes
/// d'impro (un par jour) et les virelangues de l'onglet Solo.
class CarnetExercices {
  const CarnetExercices({this.exercices = const [], this.principes = const [], this.virelangues = const []});

  final List<Exercice> exercices;
  final List<String> principes;
  final List<String> virelangues;

  static const vide = CarnetExercices();

  /// Lit le carnet ; une entrée illisible est ignorée, jamais bloquante.
  factory CarnetExercices.depuisJson(Map<String, dynamic> json) {
    final exercices = <Exercice>[];
    for (final e in json['exercices'] as List? ?? const []) {
      try {
        exercices.add(Exercice.fromJson(e as Map<String, dynamic>));
      } catch (_) {}
    }
    List<String> textes(Object? l) => [for (final x in l as List? ?? const []) if (x is String) x];
    return CarnetExercices(
      exercices: exercices,
      principes: textes(json['principes']),
      virelangues: textes(json['virelangues']),
    );
  }

  /// Le principe du jour : le même toute la journée, un autre le lendemain.
  String principeDuJour(DateTime jour) {
    if (principes.isEmpty) return '';
    final n = DateTime(jour.year, jour.month, jour.day).difference(DateTime(2020)).inDays;
    return principes[n % principes.length];
  }
}

/// Les durées en minutes lues dans une durée de la grammaire
/// (« 5 à 10 min » → [5, 10] ; « 30 min avant de jouer » → [30]).
/// Sans nombre lisible : [5].
List<int> minutesDuree(String duree) {
  final n = <int>[];
  for (final m in RegExp(r'\d+').allMatches(duree)) {
    final v = int.parse(m.group(0)!);
    if (v > 0 && v <= 90 && !n.contains(v)) n.add(v);
  }
  return n.isEmpty ? const [5] : n;
}

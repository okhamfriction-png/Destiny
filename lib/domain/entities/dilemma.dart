/// Un dilemme moral (adapté d'un dilemme réel documenté) pour le mode Dilemme.
class Dilemma {
  const Dilemma({
    required this.id,
    required this.nom,
    required this.sourceReelle,
    required this.moteur,
    required this.dangerLie,
    required this.situation,
    required this.choixA,
    required this.choixB,
  });

  final String id;
  final String nom;

  /// Source réelle (auteur/origine + date).
  final String sourceReelle;

  /// Moteur / genre : Sacrifice, Confiance/Trahison, Ressource rare,
  /// Vérité/Mensonge, Tout ou rien.
  final String moteur;

  /// Id du danger lié (banque de dangers).
  final String dangerLie;

  final String situation;

  /// Les deux choix du dilemme.
  final String choixA;
  final String choixB;

  factory Dilemma.fromJson(Map<String, dynamic> j) => Dilemma(
        id: j['id'] as String,
        nom: j['nom'] as String,
        sourceReelle: j['source_reelle'] as String? ?? '',
        moteur: j['moteur'] as String? ?? '',
        dangerLie: j['danger_lie'] as String? ?? '',
        situation: j['situation'] as String? ?? '',
        choixA: j['choix_a'] as String? ?? '',
        choixB: j['choix_b'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nom': nom,
        'source_reelle': sourceReelle,
        'moteur': moteur,
        'danger_lie': dangerLie,
        'situation': situation,
        'choix_a': choixA,
        'choix_b': choixB,
      };
}

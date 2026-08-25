/// Un exercice d'échauffement / jeu de théâtre (module Exercices, adultes).
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

  /// Catégorie : Corps, Voix, Écoute, Imagination.
  final String categorie;

  factory Exercice.fromJson(Map<String, dynamic> json) => Exercice(
        id: json['id'] as String,
        nom: json['nom'] as String,
        consigne: json['consigne'] as String,
        duree: (json['duree'] as num?)?.toInt() ?? 120,
        categorie: json['categorie'] as String? ?? 'Imagination',
      );
}

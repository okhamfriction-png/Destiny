/// Où vivent les fichiers chiffrés de Destiny Note : la branche
/// `destiny-story-data` du dépôt (dossier `notes/`).
library;

/// Un fichier lu, avec son `sha` (pour réécrire sans écraser une version
/// plus récente).
class FichierDistant {
  const FichierDistant({required this.contenu, required this.sha});

  final String contenu;
  final String sha;
}

abstract class DepotNotes {
  /// Le fichier `notes/<chemin>`, ou null s'il n'existe pas.
  Future<FichierDistant?> lire(String chemin);

  /// Écrit `notes/<chemin>` et rend le nouveau `sha`. [sha] : la version
  /// qu'on remplace (null pour un nouveau fichier). Lève [ConflitSha] si le
  /// fichier a changé entre-temps.
  Future<String> ecrire(String chemin, String contenu, {String? sha, required String message});
}

/// Le fichier a changé sur GitHub depuis qu'on l'a lu.
class ConflitSha implements Exception {
  const ConflitSha(this.chemin);

  final String chemin;

  @override
  String toString() => 'Conflit sur $chemin';
}

/// Le token n'est pas (ou plus) valable, ou n'a pas les droits.
class AccesRefuse implements Exception {
  const AccesRefuse(this.statut);

  final int statut;

  @override
  String toString() => 'Accès refusé ($statut)';
}

/// Pas de réseau, ou GitHub ne répond pas.
class HorsLigne implements Exception {
  const HorsLigne([this.detail = '']);

  final String detail;

  @override
  String toString() => 'Hors ligne $detail';
}

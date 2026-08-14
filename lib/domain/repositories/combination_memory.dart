/// Port de persistance pour la mémoire des combinaisons (lieu × danger)
/// déjà tirées, afin de ne pas les répéter avant d'avoir épuisé les autres.
abstract class CombinationMemory {
  /// Clé de combinaison à partir d'un id de lieu et d'un id de danger.
  static String comboKey(String locationId, String dangerId) =>
      '$locationId|$dangerId';

  /// Ensemble des combinaisons déjà utilisées dans le cycle courant.
  Future<Set<String>> usedCombos();

  /// Marque une combinaison comme utilisée.
  Future<void> markUsed(String comboKey);

  /// Numéro du cycle courant (démarre à 1).
  Future<int> currentCycle();

  /// Vide les combinaisons utilisées et incrémente le compteur de cycle.
  /// Retourne le nouveau numéro de cycle.
  Future<int> resetCycle();

  /// Remet tout à zéro : efface les combinaisons utilisées et ramène le
  /// compteur de cycle à 1.
  Future<void> reset();
}

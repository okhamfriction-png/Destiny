import 'danger.dart';
import 'dilemma.dart';
import 'location.dart';
import 'player_assignment.dart';

class Story {
  const Story({
    required this.location,
    required this.danger,
    required this.players,
    required this.cycle,
    required this.usedCount,
    required this.totalCombos,
    this.dilemma,
  });

  final Location location;
  final Danger danger;
  final List<PlayerAssignment> players;

  /// Dilemme tiré (mode Dilemme uniquement).
  final Dilemma? dilemma;

  /// Numéro du cycle courant (incrémenté quand toutes les combinaisons ont
  /// été épuisées).
  final int cycle;

  /// Nombre de combinaisons déjà tirées dans le cycle courant (celle-ci
  /// incluse).
  final int usedCount;

  /// Nombre total de combinaisons possibles pour le mode courant.
  final int totalCombos;
}

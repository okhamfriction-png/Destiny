import 'archetype.dart';

class PlayerAssignment {
  const PlayerAssignment({
    required this.playerIndex,
    required this.archetype,
    required this.role,
  });

  final int playerIndex;
  final Archetype archetype;
  final String role;
}

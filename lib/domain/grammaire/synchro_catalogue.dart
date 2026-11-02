/// Mise à jour du catalogue modifiable avec les données de la grammaire, sans
/// jamais écraser ce que l'utilisateur a modifié lui-même.
///
/// Pour chaque champ suivi (paliers d'un danger, rôles ou espaces d'un lieu),
/// on garde une « référence » : la dernière valeur venue de la grammaire.
/// - valeur actuelle = référence (ou vide) → non modifiée : on la met à jour ;
/// - valeur actuelle ≠ référence → modifiée par l'utilisateur : on la garde ;
/// - élément absent de la grammaire → ajouté par l'utilisateur : intouché ;
/// - élément de la grammaire absent du catalogue → supprimé par l'utilisateur :
///   il ne revient pas.
class ResultatSynchro {
  const ResultatSynchro({
    required this.misesAJour,
    required this.references,
    required this.gardes,
    required this.absents,
  });

  /// Nouvelles valeurs à écrire, par identifiant.
  final Map<String, List<String>> misesAJour;

  /// Nouvelles références (à enregistrer), par identifiant.
  final Map<String, List<String>> references;

  /// Identifiants gardés tels quels parce que modifiés par l'utilisateur.
  final Set<String> gardes;

  /// Identifiants de la grammaire absents du catalogue (supprimés).
  final Set<String> absents;
}

bool _egales(List<String>? a, List<String>? b) {
  if (a == null || b == null) return false;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Synchronise un champ. [actuel] : valeurs du catalogue ; [references] :
/// dernières valeurs venues de la grammaire ; [cible] : valeurs de la
/// grammaire, par identifiant du catalogue.
ResultatSynchro synchroniserChamp({
  required Map<String, List<String>> actuel,
  required Map<String, List<String>> references,
  required Map<String, List<String>> cible,
}) {
  final maj = <String, List<String>>{};
  final refs = <String, List<String>>{...references};
  final gardes = <String>{};
  final absents = <String>{};
  cible.forEach((id, valeur) {
    final courant = actuel[id];
    if (courant == null) {
      absents.add(id);
      return;
    }
    final nonModifie = courant.isEmpty || _egales(courant, references[id]);
    if (nonModifie) {
      if (!_egales(courant, valeur)) maj[id] = valeur;
      refs[id] = valeur;
    } else if (_egales(courant, valeur)) {
      // L'utilisateur avait déjà écrit la même chose : on réaligne.
      refs[id] = valeur;
    } else {
      gardes.add(id);
    }
  });
  return ResultatSynchro(misesAJour: maj, references: refs, gardes: gardes, absents: absents);
}

/// Empreinte stable d'un texte (FNV-1a 32 bits), pour savoir si la grammaire
/// a changé depuis la dernière synchronisation.
String empreinte(String texte) {
  var h = 0x811c9dc5;
  for (final c in texte.codeUnits) {
    h ^= c;
    h = (h * 0x01000193) & 0xffffffff;
  }
  return h.toRadixString(16).padLeft(8, '0');
}

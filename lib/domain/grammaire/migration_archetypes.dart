/// La migration des archétypes d'avant la 2.5 (douze archétypes, deux
/// vêtements chacun) vers les huit d'aujourd'hui, trois vêtements chacun.
///
/// - le Gardien de l'ordre devient le Tyran ;
/// - un archétype supprimé qui a un animal prend l'archétype de cet animal ;
/// - sans animal : Débrouillard → Aidant, Cynique → Dénégateur,
///   Opportuniste → Tyran, Solitaire → Paranoïaque.
///
/// Elle est appliquée à la lecture des données enregistrées (préparations,
/// troupes, séries, spectacles, histoires) : un id qu'elle ne connaît pas
/// est rendu tel quel, elle ne plante jamais.
library;

import 'modeles.dart';

/// Les ids d'archétypes qui n'existent plus, et leur remplaçant quand on ne
/// connaît pas l'animal.
const Map<String, String> archetypesObsoletes = {
  'debrouillard': 'aidant',
  'cynique': 'denegateur',
  'opportuniste': 'tyran',
  'solitaire': 'paranoiaque',
  'gardien_de_l_ordre': 'tyran',
};

/// L'archétype de chacun des 24 animaux (comme dans la grammaire).
const Map<String, String> _archetypeDeLAnimal = {
  'lion': 'leader', 'aigle': 'leader', 'renard': 'leader',
  'ours': 'protecteur', 'loup': 'protecteur', 'cerf': 'protecteur',
  'chien': 'aidant', 'mouton': 'aidant', 'souris': 'aidant',
  'coq': 'alarmiste', 'rat': 'alarmiste', 'chat': 'alarmiste',
  'ane': 'denegateur', 'porc': 'denegateur', 'singe': 'denegateur',
  'paon': 'prophete', 'corbeau': 'prophete', 'hibou': 'prophete',
  'fourmi': 'tyran', 'taureau': 'tyran', 'hyene': 'tyran',
  'lapin': 'paranoiaque', 'serpent': 'paranoiaque', 'vautour': 'paranoiaque',
};

/// Le nouvel id d'un archétype enregistré. [animal] : l'id ou le nom de
/// l'animal choisi (« souris », « Hyène »), vide s'il n'y en a pas.
String migrerArchetype(String id, {String animal = ''}) {
  final remplacant = archetypesObsoletes[id];
  if (remplacant == null) return id;
  if (id == 'gardien_de_l_ordre') return 'tyran';
  final cle = animal.trim().isEmpty ? '' : Grammaire.normaliser(animal);
  return _archetypeDeLAnimal[cle] ?? remplacant;
}

/// Une liste d'ids d'archétypes (sans animal), migrée.
List<String> migrerArchetypes(Iterable<String> ids) => [for (final id in ids) migrerArchetype(id)];

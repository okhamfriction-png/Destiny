/// Les textes de l'appli qui accompagnent la grammaire
/// (`assets/data/destiny_textes.json`) : messages, aide, libellés.
class TextesDestiny {
  TextesDestiny(Map<String, dynamic> donnees) : _d = donnees;

  /// Textes vides (pour les tests ou un chargement raté) : chaque appel rend
  /// une chaîne vide.
  TextesDestiny.vides() : _d = const {};

  final Map<String, dynamic> _d;

  Object? _valeur(String chemin) {
    Object? v = _d;
    for (final cle in chemin.split('.')) {
      if (v is Map) {
        v = v[cle];
      } else {
        return null;
      }
    }
    return v;
  }

  /// Le texte au [chemin] (« distribution.sans_alarmiste »), avec ses
  /// variables `{nom}` remplacées.
  String t(String chemin, [Map<String, String> variables = const {}]) {
    final v = _valeur(chemin);
    var s = v is String ? v : '';
    variables.forEach((k, val) => s = s.replaceAll('{$k}', val));
    return s;
  }

  /// La liste de textes au [chemin].
  List<String> liste(String chemin) {
    final v = _valeur(chemin);
    return v is List ? [for (final x in v) '$x'] : const [];
  }

  /// La table au [chemin].
  Map<String, dynamic> table(String chemin) {
    final v = _valeur(chemin);
    return v is Map ? Map<String, dynamic>.from(v) : const {};
  }

  /// Les éléments (tables) d'une liste au [chemin].
  List<Map<String, dynamic>> tables(String chemin) {
    final v = _valeur(chemin);
    return v is List
        ? [for (final x in v) if (x is Map) Map<String, dynamic>.from(x)]
        : const [];
  }
}

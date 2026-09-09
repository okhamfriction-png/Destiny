class Archetype {
  const Archetype({
    required this.id,
    required this.name,
    required this.traits,
    this.temperament = '',
    this.port = '',
    this.moteur = '',
    this.statut = 'neutre',
    this.intention = '',
    this.niveaux = const [],
  });

  final String id;
  final String name;

  /// Statut de jeu : 'haut', 'bas' ou 'neutre' (couleur du nom à l'affichage).
  final String statut;

  /// Description condensée (rétro-compat + contexte IA) : tempérament · port · moteur.
  final String traits;

  /// Tempérament (personnalité, sans émotion).
  final String temperament;

  /// Port : l'entrée en scène (rendu en italique).
  final String port;

  /// Moteur : l'objectif nominal (rendu en gras).
  final String moteur;

  /// Intention dirigée vers l'autre (le moteur « en jeu »), ex. « dominer, être
  /// le meilleur ». Vide si non renseignée.
  final String intention;

  /// Escalade du moteur en 4 niveaux, calée sur les paliers du danger :
  /// [Masqué, Affleure, Domine, Extrême]. Vide si non renseignée.
  final List<String> niveaux;

  /// Vrai si l'archétype a une grille d'escalade (intention + 4 niveaux).
  bool get aEscalade => niveaux.length == 4;

  /// Retire les marqueurs markdown (`_…_` italique, `**…**` gras).
  static String _clean(Object? v) {
    var s = (v as String? ?? '').trim();
    if (s.startsWith('**') && s.endsWith('**') && s.length >= 4) {
      s = s.substring(2, s.length - 2);
    }
    if (s.startsWith('_') && s.endsWith('_') && s.length >= 2) {
      s = s.substring(1, s.length - 1);
    }
    return s.trim();
  }

  factory Archetype.fromJson(Map<String, dynamic> json) {
    final temperament = _clean(json['temperament']);
    final port = _clean(json['port']);
    final moteur = _clean(json['moteur']);
    // Ancien format : un simple champ « traits ».
    final legacy = (json['traits'] as String?)?.trim();
    final traits = legacy != null && legacy.isNotEmpty
        ? legacy
        : [temperament, port, moteur].where((s) => s.isNotEmpty).join(' · ');
    return Archetype(
      id: json['id'] as String,
      name: json['name'] as String,
      traits: traits,
      temperament: temperament.isNotEmpty ? temperament : (legacy ?? ''),
      port: port,
      moteur: moteur,
      statut: (json['statut'] as String?)?.trim().isNotEmpty == true
          ? (json['statut'] as String).trim()
          : 'neutre',
      intention: (json['intention'] as String? ?? '').trim(),
      niveaux: [
        for (final n in (json['niveaux'] as List? ?? const [])) '$n'.trim()
      ],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'temperament': temperament,
        'port': port,
        'moteur': moteur,
        'statut': statut,
        if (intention.isNotEmpty) 'intention': intention,
        if (niveaux.isNotEmpty) 'niveaux': niveaux,
      };
}

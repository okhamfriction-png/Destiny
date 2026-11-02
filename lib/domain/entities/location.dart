class Location {
  const Location({
    required this.id,
    required this.name,
    required this.roles,
    this.espaces = const [],
    this.rue = false,
    this.actif = true,
  });

  final String id;
  final String name;

  /// Rôles possibles : des métiers pour former le groupe.
  final List<String> roles;

  /// Les espaces du lieu : des coins où jouer sans en sortir.
  final List<String> espaces;

  /// Ancien drapeau du mode Rue (retiré en 2.0). Conservé pour les données.
  @Deprecated('Le mode Rue est retiré en 2.0.')
  final bool rue;

  /// Vrai si le lieu est actif (sinon jamais tiré).
  final bool actif;

  Location copyWith({
    String? id,
    String? name,
    List<String>? roles,
    List<String>? espaces,
    bool? actif,
  }) {
    return Location(
      id: id ?? this.id,
      name: name ?? this.name,
      roles: roles ?? this.roles,
      espaces: espaces ?? this.espaces,
      // ignore: deprecated_member_use_from_same_package
      rue: rue,
      actif: actif ?? this.actif,
    );
  }

  factory Location.fromJson(Map<String, dynamic> json) {
    List<String> ls(Object? v) =>
        [for (final x in (v as List<dynamic>? ?? const [])) x as String];
    return Location(
      id: json['id'] as String,
      name: json['name'] as String,
      roles: ls(json['roles']),
      espaces: ls(json['espaces']),
      rue: json['rue'] as bool? ?? false,
      actif: json['actif'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'roles': roles,
        'espaces': espaces,
        'actif': actif,
      };
}

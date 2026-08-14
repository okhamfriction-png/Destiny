class Location {
  const Location({
    required this.id,
    required this.name,
    required this.roles,
    this.rue = false,
    this.actif = true,
  });

  final String id;
  final String name;
  final List<String> roles;

  /// Vrai si le lieu convient au mode Rue (ouvert, grand ou iconique).
  final bool rue;

  /// Vrai si le lieu est actif (sinon jamais tiré).
  final bool actif;

  Location copyWith({
    String? id,
    String? name,
    List<String>? roles,
    bool? rue,
    bool? actif,
  }) {
    return Location(
      id: id ?? this.id,
      name: name ?? this.name,
      roles: roles ?? this.roles,
      rue: rue ?? this.rue,
      actif: actif ?? this.actif,
    );
  }

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      id: json['id'] as String,
      name: json['name'] as String,
      roles: (json['roles'] as List<dynamic>)
          .map((role) => role as String)
          .toList(growable: false),
      rue: json['rue'] as bool? ?? false,
      actif: json['actif'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'roles': roles,
        'rue': rue,
        'actif': actif,
      };
}

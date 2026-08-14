class Danger {
  const Danger({
    required this.id,
    required this.name,
    required this.style,
    this.rue = false,
    this.theatre = true,
    this.actif = true,
    this.paliers = const [],
  });

  final String id;
  final String name;

  /// Tonalité narrative (Catastrophe, Fantastique, Mystère, ...).
  final String style;

  /// Les 4 paliers d'escalade du danger (style PBTA), du plus léger au climax.
  final List<String> paliers;

  /// Éligible au mode Rue (visuel, vital, immédiat, extérieur).
  final bool rue;

  /// Éligible au mode Théâtre (scène).
  final bool theatre;

  /// Vrai si le danger est actif (sinon jamais tiré).
  final bool actif;

  Danger copyWith({
    String? id,
    String? name,
    String? style,
    bool? rue,
    bool? theatre,
    bool? actif,
    List<String>? paliers,
  }) {
    return Danger(
      id: id ?? this.id,
      name: name ?? this.name,
      style: style ?? this.style,
      rue: rue ?? this.rue,
      theatre: theatre ?? this.theatre,
      actif: actif ?? this.actif,
      paliers: paliers ?? this.paliers,
    );
  }

  factory Danger.fromJson(Map<String, dynamic> json) {
    return Danger(
      id: json['id'] as String,
      name: json['name'] as String,
      style: json['style'] as String? ?? 'Libre',
      // Rétro-compat : ancien champ `fun`.
      rue: json['rue'] as bool? ?? json['fun'] as bool? ?? false,
      theatre: json['theatre'] as bool? ?? true,
      actif: json['actif'] as bool? ?? true,
      paliers: (json['paliers'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList(growable: false) ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'style': style,
        'rue': rue,
        'theatre': theatre,
        'actif': actif,
        'paliers': paliers,
      };
}

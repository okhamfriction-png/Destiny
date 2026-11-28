import '../grammaire/modeles.dart' show PalierId;

class Danger {
  const Danger({
    required this.id,
    required this.name,
    required this.style,
    this.rue = false,
    this.theatre = true,
    this.actif = true,
    this.paliers = const [],
    this.kids = false,
    this.tueKids = '',
  });

  /// Les trois niveaux d'un danger. Un danger enregistré avant la 2.8 en a
  /// quatre : le premier (l'ancien niveau d'avant l'acte 2) est retiré.
  static List<String> niveauxDepuis(List<String> textes) =>
      textes.length > PalierId.values.length ? textes.sublist(textes.length - PalierId.values.length) : textes;

  final String id;
  final String name;

  /// Tonalité narrative (Catastrophe, Fantastique, Mystère, ...).
  final String style;

  /// Les trois niveaux du danger (Il enferme, Il se manifeste, Il tue).
  final List<String> paliers;

  /// Éligible au mode Rue (visuel, vital, immédiat, extérieur).
  final bool rue;

  /// Éligible au mode Théâtre (scène).
  final bool theatre;

  /// Vrai si le danger est actif (sinon jamais tiré).
  final bool actif;

  /// Jouable avec des enfants (venu de la grammaire).
  final bool kids;

  /// Le niveau « Il tue » en mode kids : personne ne meurt.
  final String tueKids;

  /// Les trois niveaux, avec « Il tue » version kids en mode kids.
  List<String> paliersPour({bool kids = false}) => [
        for (var i = 0; i < paliers.length; i++)
          kids && i == PalierId.tue.index && tueKids.isNotEmpty ? tueKids : paliers[i],
      ];

  Danger copyWith({
    String? id,
    String? name,
    String? style,
    bool? rue,
    bool? theatre,
    bool? actif,
    List<String>? paliers,
    bool? kids,
    String? tueKids,
  }) {
    return Danger(
      id: id ?? this.id,
      name: name ?? this.name,
      style: style ?? this.style,
      rue: rue ?? this.rue,
      theatre: theatre ?? this.theatre,
      actif: actif ?? this.actif,
      paliers: paliers ?? this.paliers,
      kids: kids ?? this.kids,
      tueKids: tueKids ?? this.tueKids,
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
      paliers: niveauxDepuis([for (final e in (json['paliers'] as List<dynamic>? ?? const [])) e as String]),
      kids: json['kids'] as bool? ?? false,
      // Rétro-compat : ancien champ `palier4_kids`.
      tueKids: json['tue_kids'] as String? ?? json['palier4_kids'] as String? ?? '',
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
        'kids': kids,
        'tue_kids': tueKids,
      };
}

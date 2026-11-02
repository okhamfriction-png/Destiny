/// Un stade de la grammaire commune d'escalade d'un danger : un mot (le stade)
/// et ce qu'il fait. Les 4 paliers concrets d'un danger suivent cet ordre.
class StadeEscalade {
  const StadeEscalade(this.mot, this.sens);
  final String mot;
  final String sens;
}

/// Ancienne grammaire commune d'escalade (1.x). Obsolète : les noms des
/// paliers viennent maintenant de la grammaire (`Grammaire.paliers`).
@Deprecated('Utiliser Grammaire.paliers.')
const List<StadeEscalade> kStadesEscalade = [
  StadeEscalade('Signale', 'le danger se manifeste, extérieur et diffus'),
  StadeEscalade('Enferme', 'il coupe les sorties : on ne sort plus'),
  StadeEscalade('Envahit', 'il entre et transforme le lieu, touche les corps'),
  StadeEscalade('Supprime', 'il détruit le dernier refuge : survivre ou mourir'),
];

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
    this.palier4Kids = '',
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

  /// Jouable avec des enfants (venu de la grammaire).
  final bool kids;

  /// Le palier 4 en mode kids : personne ne meurt.
  final String palier4Kids;

  /// Les quatre paliers, avec le palier 4 kids en mode kids.
  List<String> paliersPour({bool kids = false}) => [
        for (var i = 0; i < paliers.length; i++)
          kids && i == 3 && palier4Kids.isNotEmpty ? palier4Kids : paliers[i],
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
    String? palier4Kids,
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
      palier4Kids: palier4Kids ?? this.palier4Kids,
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
      kids: json['kids'] as bool? ?? false,
      palier4Kids: json['palier4_kids'] as String? ?? '',
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
        'palier4_kids': palier4Kids,
      };
}

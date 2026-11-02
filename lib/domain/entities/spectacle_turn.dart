import 'dart:convert';

/// Une proposition (mode classique). Le champ [archetype] est masqué à l'écran
/// tant que le joueur n'a pas choisi.
class SpectacleProposition {
  const SpectacleProposition({
    required this.id,
    required this.texte,
    required this.archetype,
    required this.correcte,
  });

  final int id;
  final String texte;
  final String archetype;
  final bool correcte;

  factory SpectacleProposition.fromJson(Map<String, dynamic> j) =>
      SpectacleProposition(
        id: (j['id'] as num?)?.toInt() ?? 0,
        texte: j['texte'] as String? ?? '',
        archetype: j['archetype'] as String? ?? '',
        correcte: j['correcte'] as bool? ?? false,
      );
}

/// Bloc de correction (coach), hors fiction.
class SpectacleCorrection {
  const SpectacleCorrection(
      {required this.defaut, required this.explication, required this.modele});

  final String defaut;
  final String explication;
  final String modele;

  static SpectacleCorrection? fromJson(Object? v) {
    if (v is! Map) return null;
    final j = v.cast<String, dynamic>();
    final d = j['defaut'] as String? ?? '';
    final e = j['explication'] as String? ?? '';
    final m = j['modele'] as String? ?? '';
    if (d.isEmpty && e.isEmpty && m.isEmpty) return null;
    return SpectacleCorrection(defaut: d, explication: e, modele: m);
  }
}

/// Bloc CROW (fin de scène d'Acte 1), hors fiction.
class SpectacleCrow {
  const SpectacleCrow({
    required this.prenom,
    required this.fonction,
    required this.liens,
    required this.objectif,
    required this.where,
    required this.trou,
    required this.moyen,
  });

  final bool prenom;
  final bool fonction;
  final int liens;
  final bool objectif;
  final bool where;
  final String trou;
  final String moyen;

  static SpectacleCrow? fromJson(Object? v) {
    if (v is! Map) return null;
    final j = v.cast<String, dynamic>();
    return SpectacleCrow(
      prenom: j['prenom'] as bool? ?? false,
      fonction: j['fonction'] as bool? ?? false,
      liens: (j['liens'] as num?)?.toInt() ?? 0,
      objectif: j['objectif'] as bool? ?? false,
      where: j['where'] as bool? ?? false,
      trou: j['trou'] as String? ?? '',
      moyen: j['moyen'] as String? ?? '',
    );
  }
}

/// Un tour du Mode Spectacle, parsé depuis le JSON du modèle (tolérant).
class SpectacleTurn {
  const SpectacleTurn({
    required this.phase,
    required this.acte,
    required this.scene,
    required this.palier,
    required this.posees,
    required this.cible,
    required this.didascalie,
    required this.personnage,
    required this.archetype,
    required this.texte,
    required this.correction,
    required this.crow,
    required this.propositions,
    required this.feedback,
    required this.debrief,
    required this.raw,
  });

  final String phase;
  final int? acte;
  final int? scene;
  final int? palier;
  final int? posees;
  final int? cible;
  final String didascalie;
  final String personnage;

  /// Archétype (animal) du personnage qui parle — pour l'icône. Non prononcé.
  final String archetype;
  final String texte;
  final SpectacleCorrection? correction;
  final SpectacleCrow? crow;
  final List<SpectacleProposition> propositions;

  /// Retour libre / confirmation (chaîne ou structure). Rendu tel quel.
  final Object? feedback;

  /// Le débrief positif de la fin (objet), rendu génériquement. Les
  /// anciennes parties avaient un « score » à la place : il est lu ici aussi.
  final Object? debrief;

  /// Map brute complète (repli d'affichage).
  final Map<String, dynamic> raw;

  /// La fin du spectacle : le débrief.
  bool get isFin => phase == 'debrief' || phase == 'score' || debrief != null;
  bool get isDestiny => phase == 'destiny';

  factory SpectacleTurn.fromMap(Map<String, dynamic> j) {
    final rep = j['replique'];
    String personnage = '';
    String texte = '';
    String archetype = '';
    if (rep is Map) {
      personnage = rep['personnage'] as String? ?? '';
      texte = rep['texte'] as String? ?? '';
      archetype = rep['archetype'] as String? ?? '';
    }
    final compteur = j['compteur'];
    int? posees, cible;
    if (compteur is Map) {
      posees = (compteur['posees'] as num?)?.toInt();
      cible = (compteur['cible'] as num?)?.toInt();
    }
    final props = <SpectacleProposition>[];
    final rawProps = j['propositions'];
    if (rawProps is List) {
      for (final p in rawProps) {
        if (p is Map) {
          props.add(SpectacleProposition.fromJson(p.cast<String, dynamic>()));
        }
      }
    }
    return SpectacleTurn(
      phase: j['phase'] as String? ?? 'jeu',
      acte: (j['acte'] as num?)?.toInt(),
      scene: (j['scene'] as num?)?.toInt(),
      palier: (j['palier'] as num?)?.toInt(),
      posees: posees,
      cible: cible,
      didascalie: j['didascalie'] as String? ?? '',
      personnage: personnage,
      archetype: archetype,
      texte: texte,
      correction: SpectacleCorrection.fromJson(j['correction']),
      crow: SpectacleCrow.fromJson(j['crow']),
      propositions: props,
      feedback: j['feedback'],
      debrief: j['debrief'] ?? j['score'],
      raw: j,
    );
  }

  /// Extrait le premier objet JSON d'une réponse (tolère ``` fences et prose).
  static SpectacleTurn? tryParse(String raw) {
    final map = extractJsonObject(raw);
    if (map == null) return null;
    return SpectacleTurn.fromMap(map);
  }
}

/// Extrait le premier objet JSON d'une chaîne (tolère ``` fences et prose).
Map<String, dynamic>? extractJsonObject(String raw) {
  var s = raw.trim();
  if (s.startsWith('```')) {
    s = s.replaceFirst(RegExp(r'^```[a-zA-Z]*\s*'), '');
    final end = s.lastIndexOf('```');
    if (end >= 0) s = s.substring(0, end);
    s = s.trim();
  }
  try {
    final d = jsonDecode(s);
    if (d is Map<String, dynamic>) return d;
  } catch (_) {}
  final start = s.indexOf('{');
  final end = s.lastIndexOf('}');
  if (start >= 0 && end > start) {
    try {
      final d = jsonDecode(s.substring(start, end + 1));
      if (d is Map<String, dynamic>) return d;
    } catch (_) {}
  }
  return null;
}

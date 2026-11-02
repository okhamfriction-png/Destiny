/// Les univers du jeu de rôle (Jouer entre humains) : leurs lieux, leurs
/// méchants et leurs sbires. Les données viennent de `univers.json`,
/// `campagne_lieux.json` et `campagne_mechants.json` ; les méchants d'univers
/// sont « habillés » comme les 24 grands méchants de la grammaire, pour que
/// tous les écrans les traitent de la même façon.
library;

import '../grammaire/modeles.dart';

List<String> _ls(Object? v) => [for (final x in (v as List? ?? const [])) '$x'];
String _s(Object? v) => v is String ? v.trim() : '';

/// Un danger propre à un univers, en quatre paliers (et sa version kids du
/// palier 4).
class DangerUnivers {
  const DangerUnivers({
    required this.id,
    required this.univers,
    required this.nom,
    required this.paliers,
    this.kids = false,
    this.supprimeKids = '',
  });

  final String id;
  final String univers;
  final String nom;

  /// Les quatre phrases, dans l'ordre des paliers.
  final List<String> paliers;
  final bool kids;
  final String supprimeKids;

  /// Les paliers à jouer : en kids, le palier 4 sans mort.
  List<String> paliersPour({bool kids = false}) => [
        for (var i = 0; i < paliers.length; i++)
          i == 3 && kids && supprimeKids.isNotEmpty ? supprimeKids : paliers[i],
      ];

  factory DangerUnivers.depuisJson(Map<String, dynamic> j, {required String univers}) {
    final p = j['paliers'];
    return DangerUnivers(
      id: _s(j['id']),
      univers: univers,
      nom: _s(j['nom']),
      paliers: p is Map
          ? [for (final cle in const ['signale', 'enferme', 'envahit', 'supprime']) _s(p[cle])]
          : _ls(p),
      kids: j['kids'] == true,
      supprimeKids: _s(j['supprime_kids']),
    );
  }
}

/// Un univers : son nom, pour qui, ses lores, ses peuples et ses dangers.
class UniversJeu {
  const UniversJeu({
    required this.id,
    required this.nom,
    required this.adulte,
    required this.kids,
    this.lores = const [],
    this.peuples = const [],
    this.dangers = const [],
  });

  final String id;
  final String nom;
  final bool adulte;
  final bool kids;
  final List<String> lores;
  final List<String> peuples;
  final List<DangerUnivers> dangers;

  bool pour({required bool kids}) => kids ? this.kids : adulte;
}

/// Un espace d'un lieu d'univers.
class EspaceUnivers {
  const EspaceUnivers({required this.nom, this.detail = ''});
  final String nom;
  final String detail;
}

/// Un lieu d'univers, avec ses espaces, les fonctions qu'on peut y tenir et
/// ses figurants prêts à jouer.
class LieuUnivers {
  const LieuUnivers({
    required this.id,
    required this.univers,
    required this.nom,
    this.description = '',
    this.espaces = const [],
    this.roles = const [],
    this.figurants = const [],
  });

  final String id;
  final String univers;
  final String nom;
  final String description;
  final List<EspaceUnivers> espaces;
  final List<String> roles;
  final List<FigurantPret> figurants;

  factory LieuUnivers.depuisJson(Map<String, dynamic> j) {
    final id = _s(j['id']);
    final rolesBruts = j['roles'];
    return LieuUnivers(
      id: id,
      univers: _s(j['univers']),
      nom: _s(j['nom']),
      description: _s(j['description']),
      espaces: [
        for (final e in (j['espaces'] as List? ?? const []))
          if (e is Map) EspaceUnivers(nom: _s(e['nom']), detail: _s(e['detail'])),
      ],
      roles: rolesBruts is String
          ? rolesBruts.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList()
          : _ls(rolesBruts),
      figurants: [
        for (final (i, f) in (j['figurants'] as List? ?? const []).indexed)
          if (f is Map) figurantDepuisJson(Map<String, dynamic>.from(f), idParDefaut: '$id.$i'),
      ],
    );
  }
}

/// Le texte d'un animal (« Âne ») ou son id (« ane ») → l'id.
String _idAnimal(Grammaire? g, String texte) {
  if (texte.isEmpty || g == null) return Grammaire.normaliser(texte);
  return g.animal(texte)?.id ?? g.animalNomme(texte)?.id ?? Grammaire.normaliser(texte);
}

/// Un figurant écrit dans les données (même format que la grammaire).
FigurantPret figurantDepuisJson(Map<String, dynamic> j, {required String idParDefaut, Grammaire? grammaire}) =>
    FigurantPret(
      id: _s(j['id']).isEmpty ? idParDefaut : _s(j['id']),
      nom: _s(j['nom']),
      type: _s(j['type']),
      archetypeId: _s(j['archetype']),
      animalId: _idAnimal(grammaire, _s(j['animal'])),
      veut: _s(j['veut']),
      vientDe: _s(j['vient_de']),
      sait: _s(j['sait']),
      mode: ModePnj.depuisTexte(j['mode'] as String?),
    );

/// Un méchant d'univers, habillé comme un grand méchant, avec ses quatre
/// présages déjà écrits.
class MechantUnivers {
  const MechantUnivers({
    required this.univers,
    required this.mechant,
    this.description = '',
    this.manoeuvres = const [],
    this.presages = const [],
  });

  final String univers;
  final Mechant mechant;
  final String description;
  final List<String> manoeuvres;
  final List<String> presages;

  /// Lit un méchant de `campagne_mechants.json`. Les sbires gardent leurs
  /// manœuvres ; ce qu'ils font pour leur maître est la première.
  factory MechantUnivers.depuisJson(Map<String, dynamic> j, {required bool kids, Grammaire? grammaire}) {
    final id = _s(j['id']);
    final sbires = <Sbire>[];
    for (final (i, x) in (j['sbires'] as List? ?? const []).indexed) {
      if (x is! Map) continue;
      final manoeuvres = _ls(x['manoeuvres']);
      final fait = _s(x['fait']);
      sbires.add(Sbire(
        id: _s(x['id']).isEmpty ? '$id.s$i' : _s(x['id']),
        nom: _s(x['nom']),
        archetypeId: _s(x['archetype']),
        animalId: _idAnimal(grammaire, _s(x['animal'])),
        veut: _s(x['veut']).isEmpty ? _s(x['description']) : _s(x['veut']),
        vientDe: _s(x['vient_de']).isEmpty ? _s(x['description']) : _s(x['vient_de']),
        fait: fait.isNotEmpty ? fait : (manoeuvres.isEmpty ? '' : manoeuvres.first),
        kids: kids,
      ));
    }
    final description = _s(j['description']);
    return MechantUnivers(
      univers: _s(j['univers']),
      description: description,
      manoeuvres: _ls(j['manoeuvres']),
      presages: _ls(j['presages']),
      mechant: Mechant(
        id: id,
        nom: _s(j['nom']),
        archetypeId: _s(j['archetype']),
        animal: _s(j['animal']),
        inspiration: '',
        posture: _s(j['posture']),
        histoire: description,
        veut: _s(j['but']),
        besoin: _s(j['besoin']),
        faille: _s(j['faille']),
        cible: _s(j['cible']),
        offreAuTraitre: _s(j['offre_au_traitre']),
        sbires: sbires,
        kids: kids,
      ),
    );
  }
}

/// Le catalogue du jeu de rôle : univers, lieux, méchants, tons, peuples et
/// propositions de vouloir.
class CatalogueUnivers {
  const CatalogueUnivers({
    this.univers = const [],
    this.lieux = const [],
    this.mechants = const [],
    this.tons = const {},
    this.peuplesParLore = const {},
    this.peuplesParDefaut = const [],
    this.vouloirs = const [],
  });

  static const CatalogueUnivers vide = CatalogueUnivers();

  final List<UniversJeu> univers;
  final List<LieuUnivers> lieux;
  final List<MechantUnivers> mechants;

  /// id → libellé, dans l'ordre.
  final Map<String, String> tons;
  final Map<String, List<String>> peuplesParLore;
  final List<String> peuplesParDefaut;

  /// Des propositions de vouloir (les anciens objectifs de la Campagne).
  final List<String> vouloirs;

  UniversJeu? universDe(String id) {
    for (final u in univers) {
      if (u.id == id) return u;
    }
    return null;
  }

  List<UniversJeu> universPour({required bool kids}) => [for (final u in univers) if (u.pour(kids: kids)) u];

  List<LieuUnivers> lieuxDe(String universId) => [for (final l in lieux) if (l.univers == universId) l];

  List<MechantUnivers> mechantsDe(String universId) => [for (final m in mechants) if (m.univers == universId) m];

  /// Les dangers d'un univers (en kids, seulement les dangers kids).
  List<DangerUnivers> dangersDe(String universId, {bool kids = false}) => [
        for (final d in universDe(universId)?.dangers ?? const <DangerUnivers>[])
          if (!kids || d.kids) d,
      ];

  LieuUnivers? lieu(String id) {
    for (final l in lieux) {
      if (l.id == id) return l;
    }
    return null;
  }

  MechantUnivers? mechantUnivers(String id) {
    for (final m in mechants) {
      if (m.mechant.id == id) return m;
    }
    return null;
  }

  /// Les peuples cohérents avec l'univers et le lore (le premier est le plus
  /// évident).
  List<String> peuplesPour(String universId, String lore) {
    final parLore = peuplesParLore[lore.trim()];
    if (parLore != null && parLore.isNotEmpty) return parLore;
    final u = universDe(universId);
    if (u != null && u.peuples.isNotEmpty) return u.peuples;
    return peuplesParDefaut;
  }

  /// Lit les trois fichiers. Un univers est « kids » quand il est proposé aux
  /// enfants ; ses méchants le sont aussi.
  factory CatalogueUnivers.depuisJson({
    required Map<String, dynamic> univers,
    required Map<String, dynamic> lieux,
    required Map<String, dynamic> mechants,
    Map<String, dynamic>? archetypesCampagne,
    Grammaire? grammaire,
  }) {
    final listeUnivers = [
      for (final u in (univers['univers'] as List? ?? const []))
        if (u is Map)
          UniversJeu(
            id: _s(u['id']),
            nom: _s(u['nom']),
            adulte: u['adulte'] == true,
            kids: u['kids'] == true,
            lores: _ls(u['lores']),
            peuples: _ls(u['peuples']),
            dangers: [
              for (final d in (u['dangers'] as List? ?? const []))
                if (d is Map) DangerUnivers.depuisJson(Map<String, dynamic>.from(d), univers: _s(u['id'])),
            ],
          ),
    ];
    // Un univers proposé aux deux publics (Super-héros) garde des méchants
    // doux : on regarde s'il est proposé aux enfants.
    final kidsParUnivers = {for (final u in listeUnivers) u.id: u.kids};
    return CatalogueUnivers(
      univers: listeUnivers,
      lieux: [
        for (final l in (lieux['lieux'] as List? ?? const []))
          if (l is Map) LieuUnivers.depuisJson(Map<String, dynamic>.from(l)),
      ],
      mechants: [
        for (final m in (mechants['mechants'] as List? ?? const []))
          if (m is Map)
            MechantUnivers.depuisJson(
              Map<String, dynamic>.from(m),
              kids: kidsParUnivers[_s(m['univers'])] ?? false,
              grammaire: grammaire,
            ),
      ],
      tons: {
        for (final t in (univers['tons'] as List? ?? const []))
          if (t is Map) _s(t['id']): _s(t['nom']),
      },
      peuplesParLore: {
        for (final e in ((univers['peuples_par_lore'] as Map?) ?? const {}).entries) '${e.key}': _ls(e.value),
      },
      peuplesParDefaut: _ls(univers['peuples_par_defaut']),
      vouloirs: _ls(archetypesCampagne?['objectifs']),
    );
  }
}

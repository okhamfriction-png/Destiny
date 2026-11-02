/// Le jeu de rôle entre humains, avec les codes des jeux de rôle « propulsés
/// par l'Apocalypse » et la pièce du destin BRAVE / SMART : on choisit sa
/// ligne du destin (BRAVE ou SMART), on lance, et la pièce dit si on l'a
/// suivie. Le bonus, l'aide, le vouloir dit et le pouvoir kids donnent un
/// second lancer ; la gêne en impose un second. Un échec laisse le Maître du
/// destin faire un mouvement, doux aux paliers 1 et 2, dur aux paliers 3
/// et 4.
///
/// Sans interface. Tous les textes des règles viennent de
/// `destiny_textes.json` (section `pbta`) : aucun n'est écrit ici.
library;

import 'dart:math';

import '../grammaire/textes.dart';

/// Les deux faces de la pièce du destin.
enum FacePiece {
  /// L'éclair : la force, le courage, la puissance, la bagarre.
  brave,

  /// Le masque : la perception, l'intelligence, le charisme, la ruse, la
  /// parole.
  smart;

  FacePiece get autre => this == brave ? smart : brave;

  static FacePiece? depuisTexte(String? s) => switch ((s ?? '').trim().toLowerCase()) {
        'brave' => FacePiece.brave,
        'smart' => FacePiece.smart,
        _ => null,
      };
}

/// Comment la pièce se lance pour une action.
enum ModeLancer {
  /// Un seul lancer : il faut la face choisie.
  simple,

  /// Le second lancer (le bonus, l'aide, le vouloir dit, le pouvoir kids) :
  /// une seule face choisie suffit, sur deux lancers.
  secondeChance,

  /// La gêne : deux lancers, et la moindre pièce sur l'autre face fait
  /// échouer.
  gene,
}

/// Le mode d'une action. Le bonus compte quand on agit avec la face de son
/// bonus. Une seconde chance et une gêne s'annulent ; on ne lance jamais plus
/// de deux fois.
ModeLancer modeDuLancer({
  required FacePiece approche,
  FacePiece? bonus,
  bool aide = false,
  bool vouloirDit = false,
  bool pouvoir = false,
  bool gene = false,
}) {
  final chance = approche == bonus || aide || vouloirDit || pouvoir;
  if (chance && gene) return ModeLancer.simple;
  if (chance) return ModeLancer.secondeChance;
  if (gene) return ModeLancer.gene;
  return ModeLancer.simple;
}

/// La force du mouvement du Maître du destin après un échec.
enum GraviteMouvement { doux, dur }

/// Doux aux paliers 1 et 2, dur aux paliers 3 et 4 : le palier du danger de
/// l'épisode donne la gravité.
GraviteMouvement graviteAuPalier(int palier) => palier <= 2 ? GraviteMouvement.doux : GraviteMouvement.dur;

/// Faut-il lancer la pièce encore une fois, après [lancers] ? On s'arrête dès
/// que l'issue est connue.
bool encoreUnLancer(FacePiece approche, ModeLancer mode, List<FacePiece> lancers) {
  if (lancers.isEmpty) return true;
  if (lancers.length >= 2) return false;
  return switch (mode) {
    ModeLancer.simple => false,
    ModeLancer.secondeChance => lancers.first != approche,
    ModeLancer.gene => lancers.first == approche,
  };
}

/// Le résultat d'une action.
class ResultatPiece {
  const ResultatPiece({required this.approche, required this.mode, required this.lancers, required this.palier});

  /// La ligne du destin choisie.
  final FacePiece approche;
  final ModeLancer mode;

  /// Les faces tombées, dans l'ordre (une ou deux).
  final List<FacePiece> lancers;

  /// Le palier du danger au moment du lancer (1 à 4).
  final int palier;

  /// Tu as suivi la ligne du destin.
  bool get reussite => switch (mode) {
        ModeLancer.simple => lancers.isNotEmpty && lancers.first == approche,
        ModeLancer.secondeChance => lancers.contains(approche),
        ModeLancer.gene => lancers.isNotEmpty && lancers.every((f) => f == approche),
      };

  /// La gravité du mouvement du Maître du destin, en cas d'échec.
  GraviteMouvement get gravite => graviteAuPalier(palier);
}

/// Une face au hasard.
FacePiece faceAuHasard(Random hasard) => hasard.nextBool() ? FacePiece.brave : FacePiece.smart;

/// Lance la pièce pour une action : une ou deux fois selon le [mode].
ResultatPiece lancerPiece({
  required FacePiece approche,
  ModeLancer mode = ModeLancer.simple,
  required int palier,
  Random? hasard,
}) {
  final rng = hasard ?? Random();
  final lancers = <FacePiece>[];
  while (encoreUnLancer(approche, mode, lancers)) {
    lancers.add(faceAuHasard(rng));
  }
  return ResultatPiece(approche: approche, mode: mode, lancers: lancers, palier: palier.clamp(1, 4));
}

/// Les cases de la piste de blessures.
const int kCasesBlessure = 3;

/// Un mouvement de joueur : quand il se déclenche, avec quelle approche, et
/// ce que donnent le succès et l'échec (ou, sans pièce, son effet).
class MouvementJoueur {
  const MouvementJoueur({
    required this.id,
    required this.nom,
    required this.quand,
    this.approche = '',
    this.approches = const [],
    this.reussite = '',
    this.echec = '',
    this.effet = '',
    this.kids = false,
  });

  final String id;
  final String nom;

  /// Le déclencheur, « Quand tu… ».
  final String quand;

  /// L'approche, en clair (« SMART. »).
  final String approche;

  /// Les approches possibles, la plus courante d'abord.
  final List<FacePiece> approches;
  final String reussite;
  final String echec;

  /// Ce qu'il fait quand il se joue sans pièce.
  final String effet;

  /// Seulement avec des enfants.
  final bool kids;

  /// Il se joue en lançant la pièce.
  bool get avecPiece => reussite.isNotEmpty && echec.isNotEmpty;
}

/// Un mouvement du Maître du destin.
class MouvementMj {
  const MouvementMj({required this.id, required this.nom, required this.texte, required this.gravite, this.texteKids = ''});

  final String id;
  final String nom;
  final String texte;
  final String texteKids;
  final GraviteMouvement gravite;

  String textePour({bool kids = false}) => kids && texteKids.isNotEmpty ? texteKids : texte;
}

/// Les règles du jeu de rôle, lues dans les textes de l'appli.
class ReglesPbta {
  const ReglesPbta({
    this.mouvements = const [],
    this.agenda = const [],
    this.principes = const [],
    this.mouvementsMj = const [],
    this.blessuresAdultes = const [],
    this.blessuresKids = const [],
    this.bonusSuggeres = const {},
  });

  final List<MouvementJoueur> mouvements;
  final List<String> agenda;
  final List<String> principes;
  final List<MouvementMj> mouvementsMj;
  final List<String> blessuresAdultes;
  final List<String> blessuresKids;

  /// Le bonus proposé pour chaque archétype (le joueur décide).
  final Map<String, FacePiece> bonusSuggeres;

  /// Les mouvements des joueurs, sans ceux des enfants pour les adultes.
  List<MouvementJoueur> mouvementsPour({required bool kids}) => [for (final m in mouvements) if (kids || !m.kids) m];

  MouvementJoueur? mouvement(String id) {
    for (final m in mouvements) {
      if (m.id == id) return m;
    }
    return null;
  }

  List<MouvementMj> mouvementsMjDe(GraviteMouvement g) => [for (final m in mouvementsMj) if (m.gravite == g) m];

  /// Les trois cases de blessures (en kids, personne ne meurt).
  List<String> blessures({required bool kids}) => kids ? blessuresKids : blessuresAdultes;

  /// Le libellé de la case atteinte (vide sans blessure).
  String etatBlessure(int cases, {required bool kids}) {
    final l = blessures(kids: kids);
    if (cases <= 0 || l.isEmpty) return '';
    return l[(cases - 1).clamp(0, l.length - 1)];
  }

  FacePiece? bonusSuggere(String archetypeId) => bonusSuggeres[archetypeId];

  /// Lit la section `pbta` des textes.
  factory ReglesPbta.depuis(TextesDestiny t) {
    List<FacePiece> faces(Object? v) => [
          for (final x in (v as List? ?? const []))
            if (FacePiece.depuisTexte('$x') case final f?) f,
        ];
    String s(Object? v) => v is String ? v.trim() : '';
    MouvementMj mj(Map<String, dynamic> m, GraviteMouvement g) =>
        MouvementMj(id: s(m['id']), nom: s(m['nom']), texte: s(m['texte']), texteKids: s(m['kids']), gravite: g);
    return ReglesPbta(
      mouvements: [
        for (final m in t.tables('pbta.mouvements'))
          MouvementJoueur(
            id: s(m['id']),
            nom: s(m['nom']),
            quand: s(m['quand']),
            approche: s(m['approche']),
            approches: faces(m['approches']),
            reussite: s(m['reussite']),
            echec: s(m['echec']),
            effet: s(m['effet']),
            kids: m['kids'] == true,
          ),
      ],
      agenda: t.liste('pbta.agenda'),
      principes: t.liste('pbta.principes'),
      mouvementsMj: [
        for (final m in t.tables('pbta.mouvements_mj.doux')) mj(m, GraviteMouvement.doux),
        for (final m in t.tables('pbta.mouvements_mj.durs')) mj(m, GraviteMouvement.dur),
      ],
      blessuresAdultes: t.liste('pbta.blessures.adultes'),
      blessuresKids: t.liste('pbta.blessures.kids'),
      bonusSuggeres: {
        for (final e in t.table('pbta.bonus_suggere').entries)
          if (FacePiece.depuisTexte('${e.value}') case final f?) e.key: f,
      },
    );
  }
}

/// Deux ou trois mouvements du Maître du destin à proposer après un échec,
/// de la gravité donnée par le palier.
List<MouvementMj> suggestionsMj(ReglesPbta regles, GraviteMouvement gravite, {int combien = 3, Random? hasard}) {
  final pool = [...regles.mouvementsMjDe(gravite)]..shuffle(hasard ?? Random());
  return pool.take(combien).toList();
}

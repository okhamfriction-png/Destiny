import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Une section du Guide Destiny (titre + corps de texte éditable).
class GuideSection {
  const GuideSection({
    required this.id,
    required this.title,
    required this.body,
  });

  final String id;
  final String title;
  final String body;

  GuideSection copyWith({String? title, String? body}) => GuideSection(
        id: id,
        title: title ?? this.title,
        body: body ?? this.body,
      );
}

/// Contenu du Guide Destiny : 10 sections, texte par défaut fourni, éditable
/// (admin) et persisté. C'est la référence permanente pour apprendre / réviser.
class GuideContent extends ChangeNotifier {
  GuideContent() {
    _sections = List.of(_defaults);
    _load();
  }

  static const _kKey = 'guide_overrides_v1';

  late List<GuideSection> _sections;
  List<GuideSection> get sections => List.unmodifiable(_sections);

  GuideSection? sectionById(String id) {
    for (final s in _sections) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// Édite une section (réservé à l'admin côté UI).
  Future<void> updateSection(String id, {String? title, String? body}) async {
    final i = _sections.indexWhere((s) => s.id == id);
    if (i < 0) return;
    _sections[i] = _sections[i].copyWith(title: title, body: body);
    notifyListeners();
    await _save();
  }

  /// Restaure le texte d'origine d'une section (ou de tout le guide si null).
  Future<void> resetToDefault([String? id]) async {
    if (id == null) {
      _sections = List.of(_defaults);
    } else {
      final def = _defaults.firstWhere((s) => s.id == id);
      final i = _sections.indexWhere((s) => s.id == id);
      if (i >= 0) _sections[i] = def;
    }
    notifyListeners();
    await _save();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kKey);
      if (raw == null) return;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      _sections = [
        for (final def in _defaults)
          if (map[def.id] is Map<String, dynamic>)
            def.copyWith(
              title: (map[def.id] as Map<String, dynamic>)['title'] as String?,
              body: (map[def.id] as Map<String, dynamic>)['body'] as String?,
            )
          else
            def,
      ];
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // On ne persiste que ce qui diffère du défaut (guide léger + migrable).
      final map = <String, dynamic>{};
      for (final s in _sections) {
        final def = _defaults.firstWhere((d) => d.id == s.id);
        if (s.title != def.title || s.body != def.body) {
          map[s.id] = {'title': s.title, 'body': s.body};
        }
      }
      await prefs.setString(_kKey, jsonEncode(map));
    } catch (_) {}
  }

  // --------------------------------------------------------------- défauts
  static final List<GuideSection> _defaults = [
    const GuideSection(
      id: 's1',
      title: '1. Qu\'est-ce que Destiny',
      body: '''Destiny est un théâtre d'improvisation dramatique long form (~45 minutes). Pas de comédie : on cherche l'émotion vraie, la tension, le drame.

On ne vient pas écrire des histoires. On vient les VIVRE.

Quatre personnages forts, liés entre eux, poursuivent leur désir sous un danger qui monte et les enferme. Le public est le destin : il choisit, il intervient, il fait basculer le monde. Chaque représentation est unique et ne se rejoue jamais.''',
    ),
    const GuideSection(
      id: 's2',
      title: '2. La colonne vertébrale',
      body: '''Tout Destiny tient dans une seule chaîne :

ARCHÉTYPE → OBJECTIF → RÔLE-OUTIL → POUSSÉE À L'EXCÈS → ÉMOTION VÉCUE → ÉMOTION TRANSMISE

• L'archétype donne l'objectif. Tu es Lion, donc tu veux régner. Le désir découle de ta nature.
• Le rôle est l'outil. Médecin, commandant, serveur : pas ton but, ton levier.
• Le danger réoriente, jamais il ne change l'archétype.
• La poursuite obstinée te fait sombrer dans l'excès. Cet excès vécu se transmet au public. C'est ça, le drame.

LA DISTINCTION LA PLUS IMPORTANTE : l'objectif vient de l'ARCHÉTYPE, jamais du RÔLE.
✗ « Je suis médecin donc je soigne » → une fonction. Personnage passif.
✓ « Je suis Porc, je veux jouir de cette crise, mon rôle de médecin est l'outil » → un désir. Personnage moteur.''',
    ),
    const GuideSection(
      id: 's3',
      title: '3. Les archétypes',
      body: '''Un archétype se lit en trois champs :
• TEMPÉRAMENT (qui je suis, stable) — vrai au repos, ne bouge pas pendant la scène.
• PORT (comment j'entre, un mot) — la façon d'occuper l'espace ; c'est le statut rendu visible, joué avant la première réplique.
• MOTEUR (ce qui m'aimante) — ce que je veux jusqu'au bout. Croisé avec le danger, il génère l'objectif concret.

RÈGLE ABSOLUE : l'émotion n'est JAMAIS dans l'archétype. Elle naît du danger. Un Loup n'est pas « violent » : il devient violent au palier 3 quand sa meute est menacée. Le moteur poussé à l'excès, sous le danger, devient la faille du personnage — elle se joue, elle ne s'écrit pas.''',
    ),
    const GuideSection(
      id: 's4',
      title: '4. Les statuts',
      body: '''Le statut crée la relation. On ne donne pas de lien écrit (« tu es mon frère ») : on pose un écart de statut de départ, et le lien émerge en jouant. Un lien, c'est un statut avec une histoire.

• Le statut est une transaction permanente, automatique dans la vie. Ce qui est DIT compte moins que le statut JOUÉ.
• MICRO-ÉCART : joue légèrement au-dessus ou en dessous de ton partenaire, pas caricatural. L'écart énorme = comédie ; le demi-cran = drame réaliste. On vise le demi-cran.
• Le malaise vient d'un statut non réglé.
• Statut face à l'environnement ≠ statut face aux personnes (le danger est un statut d'environnement).

MICRO-SIGNAUX (le statut passe par le corps) :
• « Euh » en début de phrase = bas (interruptible). « Euh » au milieu = haut (tient la parole).
• Tête immobile = haut (Hamlet, l'officier). Tête qui bouge = bas.
• Regard tenu = haut. Regard qui fuit puis revient = bas.

RÈGLE D'OR : le statut peut et doit pouvoir bouger dans la scène, mais c'est la FICTION qui fait bouger le statut, pas le contraire. Une bascule justifiée en fiction, jamais mécanique.''',
    ),
    const GuideSection(
      id: 's5',
      title: '5. Les relations (CROW)',
      body: '''CROW est une grille pour vérifier qu'une scène est complète — PAS un texte à réciter. Réciter CROW produit du plaqué (« Bob, mon frère, nous voici chez Wal-Mart »). Les cases se découvrent en jouant.

• C — CHARACTER : archétype (donné) + prénom + fonction dans le lieu.
• R — RELATIONSHIP : née de l'écart de statut.
• O — OBJECTIVE : ce que je veux, coloré par mon moteur.
• W — WHERE : donné (le lieu). (+ spécifique Destiny : où en est le danger, comment mon corps y réagit.)

NOURRIR SANS RÉCITER : l'anecdote partagée (« tu te souviens quand on… ») pose relation et passé d'un coup, joué et pas annoncé.

ANCRER LES PRÉNOMS : dire le prénom de l'autre une réplique sur deux. Un prénom rend le personnage réel et réutilisable à l'Acte 3 (« dis-lui, Pierre… »).''',
    ),
    const GuideSection(
      id: 's6',
      title: '6. La structure en 3 actes',
      body: '''Le spectacle démarre in media res : le danger gronde déjà. Chaque acte ajoute une couche, mais on n'en pilote qu'une à la fois.

ACTE 1 — POSER
Quatre scènes-duos reliées par le monde (pas la causalité). Boucle : J1-J2, puis J3-J4, puis J2-J3, puis J4-J1 (referme l'acte). Le premier nommé démarre haut, le lien émerge de l'écart. Du ET, tension sans conflit. LE DANGER RESTE AU PALIER 1 TOUT L'ACTE 1 (il gronde, il ne monte pas) — pour créer le contraste.

ACTE 2 — RÉAGIR
Le danger monte. Causalité (MAIS/DONC). Formule unique : le danger monte DONC un lien ne peut plus attendre DONC un personnage agit sur ce lien. Une scène = un lien = un mouvement. On ne crée aucun lien neuf. À la fin, tous les liens sont armés à bloc.

ACTE 3 — CONVERGER
Le danger au maximum réclame le prix. Les liens explosent ou se dénouent. Chacun ferme son propre arc. C'est seulement ici qu'on peut s'emparer du danger. Clôture : « Et c'est ainsi que… »

Principe de Tchekhov : tout ce qui explose à l'Acte 3 doit avoir été chargé à l'Acte 1.''',
    ),
    const GuideSection(
      id: 's7',
      title: '7. Le danger',
      body: '''Le danger vient du lieu. Ce n'est pas un ennemi à abattre : c'est un pressuriseur qui ENFERME et divise. C'est un compte à rebours : il empire toujours, ne redescend jamais.

• 4 PALIERS PHYSIQUES (sensations, pas intensité abstraite). Le palier 2 introduit toujours l'enfermement : une issue se coupe, on ne part plus librement. Le palier 4 ouvre le « plus rien à perdre » qui libère la parole.
• Seul le danger initial s'incrémente. Les dangers ajoutés élargissent le monde sans monter le compteur.
• BASCULE SYNCHRONISÉE : à chaque cran, les corps passent au palier suivant ensemble, en silence. Le corps d'abord, l'émotion libre par-dessus.

RÈGLE D'OR : les personnages SUBISSENT le danger, ne le causent JAMAIS, et ne peuvent s'en emparer qu'à l'Acte 3.

Deux causalités à tresser : DONC relationnel (il a tué ma mère DONC je dois le tuer) + DONC du danger (le pont s'effondre DONC il faut choisir qui sort).''',
    ),
    const GuideSection(
      id: 's8',
      title: '8. Le rituel et les 3 Destinys',
      body: '''1. Le public choisit : nombre de joueurs, lieu, puis archétypes un par un.
2. Présentation des personnages.
3. Musique du Commencement + marche muette (~30 s, on se cherche du regard, deux sortent, deux restent).
4. Le danger demandé en dernier, sur des personnages déjà incarnés.
5. Noir. In media res, tension haute d'emblée, danger au palier 1.

LES 3 DESTINYS (« DESTINY » lancé par le régisseur) :
• Destiny 1 ≈ 10 min — clôt l'Acte 1 (le danger monte au palier 2).
• Destiny 2 ≈ 22 min — cœur de l'Acte 2.
• Destiny 3 ≈ 35 min — ouvre l'Acte 3.

On ne sort JAMAIS du personnage. Le public est la voix du destin : le personnage entend une voix, la ressent, et le public répond DANS LA FICTION (« le sol tremble »), pas en jargon.''',
    ),
    const GuideSection(
      id: 's9',
      title: '9. Les principes de jeu',
      body: '''• MONTRER, PAS EXPLIQUER. Ce qui compte se joue.
• ÉMOTION RÉELLE, PILOTÉE. On ne mime pas l'émotion, on en mobilise une vraie et on la canalise. Ressentir au maximum, montrer au minimum. Jamais surjouer.
• INCARNER, PAS SURJOUER. Incarner = être le personnage. Surjouer = le montrer. On choisit toujours être.
• LA NOURRICE. Chaque réplique donne à l'autre (un passé, un enjeu, quelque chose à perdre). Le 50/50 : une info bien dite, puis le silence.
• TENIR SON ARCHÉTYPE. Le Serpent reste Serpent ; seuls les statuts varient.
• NE JAMAIS FORCER UN PARTENAIRE. On fait une offre, libre à lui de la prendre.
• QUOI QU'IL ARRIVE, ON JOUE. L'incohérence est une matière ; on l'intègre par un DONC.''',
    ),
    const GuideSection(
      id: 's10',
      title: '10. Le dé du destin',
      body: '''À chaque Destiny, le dé peut tomber. Il ne génère pas des ingrédients au hasard : il FRAPPE, dans l'esprit « le public est le destin ». La difficulté monte avec les spectacles.

Répartition :
• 4 faces ARCHÉTYPE — le public AJOUTE un archétype à un personnage (jamais ne remplace). Le personnage doit visiblement bifurquer dans la minute, sinon le public se sent lésé.
• 1 face DANGER — le danger initial monte d'un cran de plus, ou un danger secondaire s'ajoute (sans incrémenter le compteur).
• 1 face DESTIN — le public remplit un trou annoncé en début de spectacle. Options :
   – Quelqu'un que l'un de vous aime apparaît, et il est en danger.
   – Quelqu'un que l'un de vous croyait mort est là, vivant.
   – Il n'y a plus qu'une issue, pour un seul d'entre vous.
   – L'un de vous détient, sans le savoir, ce qui peut tous vous sauver ou tous vous perdre.
   – Le plus faible d'entre vous prend le pouvoir de décider pour tous.
   – L'un de vous a menti sur quelque chose d'essentiel, il doit l'avouer maintenant.

LE LIEU NE FAIT PAS PARTIE DU DÉ (changer de lieu casse le huis clos). Il est posé au début et reste fixe.''',
    ),
  ];
}

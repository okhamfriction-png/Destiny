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

/// Contenu du Guide Destiny : 15 sections (10 fondamentales + 5 « Le système
/// par les films »), texte par défaut fourni, éditable (admin) et persisté.
/// C'est la référence permanente pour apprendre / réviser.
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
    const GuideSection(
      id: 's11',
      title: '11. Les statuts à l\'œuvre (films)',
      body: '''━━━ PARTIE II — LE SYSTÈME PAR LES FILMS ━━━
Les cinq sections qui suivent montrent la méthode à l'œuvre dans des œuvres connues. Facultatif : ça nourrit le jeu, ça ne remplace rien. À picorer, pas à apprendre.

LE STATUT N'EST PAS CE QU'ON DIT, C'EST CE QU'ON JOUE. Ces scènes le montrent mieux que toute théorie :

• GAME OF THRONES — Tywin dépèce le cerf. Il parle à Jaime sans le regarder, les mains dans les entrailles de l'animal. Statut ultra-haut sans un mot plus fort qu'un autre : il joue haut face à l'environnement, tout lui appartient. Personne n'a besoin qu'on lui dise qui commande.

• LES AFFRANCHIS — l'entrée au Copacabana (plan-séquence). Henry passe par les cuisines, distribue des billets, on lui installe une table devant la scène. Il ne dit presque rien : le statut est joué par l'espace et la réaction des autres. Karen tombe amoureuse dans ce plan — c'est le statut qui la fait tomber, pas une réplique.

• LES AFFRANCHIS — « Funny how? » Tommy fait basculer le statut en une seconde, et personne ne sait si c'est un jeu. Malaise absolu = statut illisible. Toute la table est mal à l'aise parce que personne ne sait quel statut jouer.

• LE ROI LION — Scar (Serpent) démarre bas : il se faufile, il esquive. Mufasa (Lion) est haut : le roi, la force, le droit. Puis Scar renverse (« la nature m'a doté d'intelligence, toi de la force… ») et il sort en statut haut, laissant le roi sans réplique. Preuve que le statut se joue dans la FICTION, pas dans l'archétype : le Lion peut être bas, et c'est ça le drame.

• TAXI DRIVER — « You talkin' to me? » Travis s'entraîne à jouer haut face à un miroir : un statut avec un environnement, sans partenaire.

LEÇON : le statut circule, il n'appartient à personne. Un roi peut être bas face à un sujet, jamais face à son palais. Le micro-écart (un demi-cran) fait le réalisme ; le grand écart fait la comédie.''',
    ),
    const GuideSection(
      id: 's12',
      title: '12. L\'objectif : moteur × danger',
      body: '''L'objectif n'est jamais abstrait : il naît du croisement MOTEUR (de l'archétype) × DANGER. Sans danger, « je veux le pouvoir » est vague. Avec un danger qui enferme, ça devient concret et jouable maintenant. Deux pistes par cas — on en choisit une en 3 secondes, ou on en invente une 3e du même esprit.

• SERPENT (le contrôle) · avocat, commissariat — Une preuve l'incrimine. → Faire accuser un autre avant la fin de l'interrogatoire ; ou retourner l'enquêteur contre sa hiérarchie.

• LION (le règne) · capitaine, sous-marin — Une mutinerie se prépare. → Mater le meneur en public pour briser la révolte ; ou lancer une mission qui force tous à me suivre.

• SOURIS (oser malgré tout) · gardien, prison — On me force à choisir un camp. → Trouver à qui obéir sans être tenu responsable ; ou disparaître, et craquer quand c'est impossible.

• OURS (protéger les siens) · infirmier, hôpital — Ordre d'évacuer en laissant un patient. → Cacher mon patient et le défendre ; ou forcer le médecin à le sauver d'abord.

• RAT (le profit) · adjoint, mairie — Un audit surprise va tout révéler. → Faire porter le chapeau au maire ; ou vendre ce que je sais au camp qui gagnera.

• COQ (la conquête) · directeur, école — Un scandale menace ma réputation. → Me mettre en scène en sauveur ; ou écraser celui qui pourrait me faire de l'ombre.

• HIBOU (avoir raison) · médecin, vaisseau — Panne mortelle, personne ne m'écoute. → Prouver que j'avais raison quitte à laisser empirer ; ou prendre le contrôle, seul à comprendre.

• MOUTON (l'abri du plus fort) · steward, avion — Le commandant donne un ordre dangereux. → Trouver vite quel fort suivre ; ou obéir même si absurde, et se figer sous la pression.

• RENARD (le jeu qui gagne) · agent, aéroport — Attentat annoncé, fermeture totale. → Monnayer ma sortie contre une info ; ou négocier avec les deux camps pour garder une issue.

• TAUREAU (s'imposer) · vigile, boîte de nuit — Début d'émeute. → Imposer l'ordre par la force ; ou désigner un coupable et foncer dessus.

• CORBEAU (qu'on le craigne) · notaire, manoir — Héritage contesté, un mort suspect. → Pousser les héritiers à s'entredéchirer ; ou faire chanter celui qui cache, sous couvert de conseil.

• PAON (la gloire) · marié, mariage — Un ex débarque avec un secret. → Étouffer le scandale pour que la fête reste parfaite ; ou retourner l'assemblée contre l'ex pour rester admiré.

RÈGLE : le moteur donne la couleur, le danger donne l'urgence. L'objectif est toujours le moteur rendu concret par la menace — jamais tiré du rôle.''',
    ),
    const GuideSection(
      id: 's13',
      title: '13. Les 24 archétypes incarnés',
      body: '''3 références par archétype (univers variés), pour que chacun en connaisse au moins une. Le point commun : aucun ne surjoue son animal. Ils sont intenses parce qu'ils poursuivent un objectif à fond, pas parce qu'ils en rajoutent. L'archétype est stable (tempérament, port, moteur) ; l'émotion monte avec le danger.

• AIGLE (le sommet) — Daenerys (GoT) · Miranda Priestly (Le Diable s'habille en Prada) · Erwin (Attack on Titan)
• ÂNE (la paix, à son rythme) — Forrest Gump · Woody (Toy Story) · Samsagace têtu (LOTR)
• CERF (l'honneur) — Ned Stark (GoT) · Atticus Finch · Itachi (Naruto)
• CHAT (la fascination) — Catwoman · Han Solo · Yoruichi (Bleach)
• CHIEN (la fidélité) — Samwise (LOTR) · Dwight (The Office) · Hachiko
• COQ (la conquête) — Michael Scott (The Office) · Gaston · Endeavor (MHA)
• CORBEAU (qu'on le craigne) — Hannibal Lecter · Le Joker (Dark Knight) · Light Yagami (Death Note)
• FOURMI (l'ordre) — Skyler White (Breaking Bad) · Mrs Weasley (HP) · Iroh (Avatar)
• HIBOU (avoir raison) — Tywin Lannister (GoT) · Gus Fring (Breaking Bad) · Yoda
• HYÈNE (la curée) — Joffrey (GoT) · Biff (Retour vers le futur) · Hidan (Naruto)
• LAPIN (plaire à tous) — Tommen (GoT) · George McFly · Hinata début (Naruto)
• LION (le règne) — Aragorn (LOTR) · Maximus (Gladiator) · Mufasa (Le Roi Lion)
• LOUP (la meute) — Tony Soprano · Anton Chigurh (No Country) · Vegeta (Dragon Ball)
• MOUTON (l'abri du plus fort) — Theon début (GoT) · les villageois (western) · Krillin (Dragon Ball)
• OURS (protéger les siens) — Hagrid (HP) · John Coffey (La Ligne verte) · Baloo
• PAON (la gloire) — Jordan Belfort (Loup de WS) · Lockhart (HP) · Mr Satan (Dragon Ball)
• PORC (la jouissance) — Donnie (Loup de WS) · Mr Creosote (Monty Python) · le Roi gonflé
• RAT (le profit) — Littlefinger (GoT) · Gollum (LOTR) · traîtres de cour
• RENARD (le jeu qui gagne) — Saul Goodman · Tyrion (GoT) · Robin des Bois Disney
• SERPENT (le contrôle) — John Doe (Seven) · Iago (Othello) · Aizen (Bleach)
• SINGE (le rire) — Jack Sparrow · Le Joker (Ledger, chaos) · Hisoka (HxH)
• SOURIS (oser malgré tout) — Bilbo début · Chihiro début · Neville début (HP)
• TAUREAU (s'imposer) — The Hound (GoT) · Rocky · All Might (MHA)
• VAUTOUR (ce qui reste) — Walter White fin (Breaking Bad) · Gordon Gekko (Wall Street) · Doflamingo (One Piece)

NOTE : Donnie, Tyrion, John Doe, Gus Fring ne font jamais une vanne ni une grimace. Ils sont à fond dans leur objectif — c'est l'intensité du désir qui crée l'humour, la terreur, l'émotion. Certains se débattent (Walter White : Serpent ou Vautour ?) : en débattre en répétition aiguise l'œil de toute la troupe.''',
    ),
    const GuideSection(
      id: 's14',
      title: '14. La grammaire ABT (grandes œuvres)',
      body: '''MAIS / DONC, jamais ET PUIS (règle de Trey Parker). Chaque scène est une conséquence (DONC) ou un retournement (MAIS) de la précédente. Schémas simplifiés — voir la mécanique, pas résumer l'œuvre.

• BREAKING BAD (pilote) — Un prof apprend qu'il a un cancer. DONC il cuisine de la drogue. MAIS son ancien élève est dans le milieu. DONC ils s'associent. MAIS un dealer les menace. DONC il doit tuer. Chaque scène pousse la précédente.

• GAME OF THRONES (le fil Stark) — Le roi demande à Ned d'être sa Main. MAIS Ned découvre un secret sur les héritiers. DONC il enquête. MAIS on l'avertit de se taire. DONC il agit par honneur. MAIS il est trahi et exécuté. L'archétype (Cerf, moteur l'honneur) le mène à sa perte.

• LE LOUP DE WALL STREET — Il découvre l'argent facile. DONC il monte son arnaque. MAIS le FBI s'intéresse à lui. DONC il fuit en avant. MAIS ses proches lâchent. DONC la chute. Le moteur Paon (la gloire) poussé à l'excès est le moteur du récit.

• ATTACK ON TITAN (prémisse) — L'humanité vit derrière des murs. MAIS un mur tombe. DONC le héros perd sa mère. DONC il jure vengeance. MAIS chaque vérité aggrave tout.

TEST : à chaque scène, est-ce un DONC (conséquence) ou un MAIS (retournement) de ce qui précède ? Si c'est un « et puis » qui ouvre autre chose sans cause, c'est une faute de récit.''',
    ),
    const GuideSection(
      id: 's15',
      title: '15. Le danger qui enferme (7 films)',
      body: '''Le danger Destiny est un compte à rebours qui ENFERME : posé tôt, il empire toujours, ne redescend jamais, et il coupe les issues — sinon les personnages fuiraient. Attention : ce n'est pas « la suite des événements ». C'est le MÊME danger qui s'aggrave et qui enferme.

• ALIEN — la créature est à bord → elle élimine un membre → plus aucune zone sûre → la traque s'inverse → un seul survivant. Huis clos parfait : personne ne sort, le danger unique monte.

• TITANIC — la coque est touchée → l'eau gagne les ponts → pas assez de canots, on est piégés → le bateau se brise → tout sombre. Irréversible dès la 1re minute ; l'enfermement (au milieu de l'océan) libère les vérités.

• 12 HOMMES EN COLÈRE — un juré doute → le doute gagne → les certitudes se fissurent → le groupe se déchire → le verdict bascule. Le danger n'est pas physique : c'est le doute. Une pièce fermée, une pression qui monte : le plus proche de Destiny.

• THE THING — un truc a pris un des nôtres → on ne sait plus qui → on se verrouille ensemble dans la base → la paranoïa dévore → on s'entretue. L'enfermement + la défiance : le danger fait sortir ce que chacun cachait.

• JURASSIC PARK — une clôture lâche → un prédateur s'échappe → la traque dans le parc → plus aucun lieu sûr → le parc est perdu. Toujours le même danger, jamais résolu.

• WALKING DEAD — la horde est là → elle force l'abri → l'abri devient intenable → la fuite tourne mal → plus aucun refuge. Ils sont trop, ça empire, on est cernés.

• LE DÎNER DE CONS — un quiproquo → un mensonge pour le couvrir → la situation déraille → chaque rattrapage empire → catastrophe. Même mécanique, en comédie : le mensonge enferme aussi sûrement qu'un mur.

LEÇON : un danger, posé tôt, qui monte sans se résoudre et coupe les issues. Palier 2 = une sortie se ferme ; palier 4 = plus rien à perdre, la vérité sort. Si tu sais faire monter UN danger qui enferme, tu sais faire Destiny.''',
    ),
    const GuideSection(
      id: 's16',
      title: '16. Quand tu ne sais plus quoi faire',
      body: '''Tu ne sais plus quoi dire ? Ne cherche pas une idée neuve. Appuie sur une relation.

En trois temps :
(1) Va vers une relation qui existe déjà — pas une nouvelle, une que l'Acte 1 a posée.
(2) Sers-toi du danger pour la faire bouger : le danger qui monte est ta raison d'agir (« le feu bloque la sortie, DONC je ne peux plus me taire, DONC je te dis la vérité »).
(3) Fais bouger la relation d'un cran : resserre-la, fissure-la, ou révèle quelque chose.

Exemples :
• Perdu dans une scène ? Regarde qui est en face, ce qu'il représente pour toi, appuie dessus (« Ça fait dix ans que je te couvre, et tu me lâches maintenant ? »).
• Le danger monte et tu ne sais qu'en faire ? Transforme-le en pression sur un lien (« On va peut-être mourir ici, alors autant que tu saches : c'est moi qui ai payé tes études »).
• Un blanc dans le groupe ? Ressors une cartouche de l'Acte 1 (« Dis-lui, toi, pourquoi tu n'es pas venu à l'enterrement »).

Règle en une phrase : quand tu es perdu, monte le danger et appuie sur une relation existante. Tu ne te tromperas jamais.''',
    ),
  ];
}

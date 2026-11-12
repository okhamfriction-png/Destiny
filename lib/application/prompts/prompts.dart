/// Tous les prompts envoyés à l'IA, en un seul endroit, versionnés
/// ([kVersionPrompts]) et testés. Chacun contient la grammaire utile, générée
/// depuis `destiny_grammaire.json`, et les contraintes : un lieu, un groupe
/// qui se connaît, quatre paliers, pas de traître, pas de dé, et le
/// vocabulaire de Destiny. Chaque rôle a une variante adulte et une variante
/// enfant.
library;

import '../../domain/grammaire/modeles.dart';
import 'grammaire_courte.dart';

export 'grammaire_courte.dart' show grammaireCourte, kVersionPrompts;

/// Le décor d'une partie.
class ScenePrompt {
  const ScenePrompt({
    this.lieu = '',
    this.espaces = const [],
    this.groupe = '',
    this.danger = '',
    this.paliers = const [],
    this.mystere = '',
    this.univers = '',
    this.ton = '',
  });

  final String lieu;
  final List<String> espaces;
  final String groupe;
  final String danger;
  final List<String> paliers;
  final String mystere;
  final String univers;
  final String ton;

  String decrire() {
    final b = StringBuffer();
    if (univers.isNotEmpty) b.writeln('Univers : $univers (décor, technologie, vocabulaire ; les faits restent ceux-ci).');
    if (ton.isNotEmpty) b.writeln('Ton : $ton.');
    if (lieu.isNotEmpty) b.writeln('Lieu unique : $lieu${espaces.isEmpty ? '' : ' (espaces : ${espaces.join(', ')})'}.');
    if (groupe.isNotEmpty) b.writeln('Groupe : $groupe ; tout le monde se connaît.');
    if (danger.isNotEmpty) b.writeln('Danger : $danger.');
    for (final (i, p) in paliers.indexed) {
      b.writeln('  Palier ${i + 1} : $p');
    }
    if (mystere.isNotEmpty) b.writeln('Le mystère : $mystere');
    return b.toString().trim();
  }
}

/// Un personnage, avec ses couches connues.
class PersonnagePrompt {
  const PersonnagePrompt({
    required this.nom,
    required this.archetypeId,
    this.animalId = '',
    this.blessure = '',
    this.vouloir = '',
    this.besoin = '',
    this.pouvoir = '',
    this.joueur = true,
  });

  final String nom;
  final String archetypeId;
  final String animalId;
  final String blessure;
  final String vouloir;
  final String besoin;
  final String pouvoir;

  /// Joué par un joueur (sinon par l'IA).
  final bool joueur;

  String decrire(Grammaire g, {PalierId palier = PalierId.signale}) {
    final a = g.archetype(archetypeId);
    final animal = g.animal(animalId);
    final morceaux = [
      if (a != null) 'conviction : ${a.ceQuIlFait} (montée à ce palier : ${a.monteeA(palier)})',
      if (animal != null) 'corps : ${animal.posture}, port ${animal.port}',
      if (blessure.isNotEmpty) 'blessure : $blessure',
      if (vouloir.isNotEmpty) 'vouloir : $vouloir',
      if (besoin.isNotEmpty) 'besoin : $besoin (il ne le voit pas)',
      if (pouvoir.isNotEmpty) 'pouvoir : $pouvoir (il aide, il ne résout pas)',
    ];
    return '$nom${joueur ? '' : ' (joué par toi)'} — ${morceaux.join(' ; ')}';
  }
}

const String _interdits =
    'Ne nomme jamais un archétype ni un animal dans la narration : ce sont des repères de jeu, pas des mots '
    'du récit (personne n\'a de griffes ni d\'ailes). Pas de traître. Pas de dé : quand un hasard décide, '
    'c\'est la pièce du destin. Ne change pas de lieu. Le danger ne redescend jamais. Un besoin n\'est '
    'jamais un objet.';

const String _enfant =
    'C\'EST UNE PARTIE AVEC DES ENFANTS. Mots simples, phrases courtes, ton chaleureux. Aucune violence, '
    'aucune mort, aucun personnage humilié : des frissons doux, jamais d\'effroi. Personne ne meurt : on '
    'choisit, on renonce à quelque chose, on se sépare un moment, on quitte l\'histoire. Un pouvoir aide, '
    'il ne résout jamais l\'histoire seul : il faut une idée, souvent deux pouvoirs ensemble.';

const String _adulte = 'C\'est une partie entre adultes : sobre, crédible, sans complaisance ni gore.';

String _public(bool kids) => kids ? _enfant : _adulte;

/// 1. Le Maître du destin (le narrateur du jeu avec l'IA) : quatre chapitres,
/// un par palier, Destiny entre les chapitres, la nouvelle de chaque palier,
/// la montée des personnages non joueurs, et le choix final.
String promptMaitreDuDestin({
  required Grammaire g,
  required ScenePrompt scene,
  required List<PersonnagePrompt> heros,
  List<PersonnagePrompt> autres = const [],
  bool kids = false,
}) {
  final b = StringBuffer()
    ..writeln('Tu es le Maître du destin de Destiny, un drame improvisé en huis clos. Promesse : « ${g.promesse} ».')
    ..writeln('Tu racontes, le joueur décide. Tu fais vivre ses héros dans un seul lieu, avec un groupe qui se connaît.')
    ..writeln()
    ..writeln(grammaireCourte(g, kids: kids))
    ..writeln()
    ..writeln('LA PARTIE')
    ..writeln(scene.decrire())
    ..writeln()
    ..writeln('LES HÉROS (joués par le joueur) :');
  for (final p in heros) {
    b.writeln('- ${p.decrire(g)}');
  }
  if (autres.isNotEmpty) {
    b.writeln('LES AUTRES PERSONNAGES DU GROUPE (joués par toi, chacun suit la montée de son archétype) :');
    for (final p in autres) {
      b.writeln('- ${p.decrire(g)}');
    }
  }
  b
    ..writeln()
    ..writeln('COMMENT TU MÈNES LA PARTIE')
    ..writeln('- Quatre chapitres, un par acte et par palier. Le chapitre en cours et son palier te sont donnés '
        'dans chaque message du joueur. Le danger bloque les vouloirs ; les autres appuient là où ça fait mal.')
    ..writeln('- Chapitre 1, léger : on sait vite le nom, le rôle dans le lieu, le lien (dit avec le mot) et le '
        'vouloir de chaque héros. Si son besoin n\'est pas donné, déduis-le et garde-le pour toi.')
    ..writeln('- Chapitre 2 : le danger empêche le vouloir. Chapitre 3 : le besoin sort, par la bouche d\'un autre.')
    ..writeln('- Chapitre 4 : ne remonte plus la tension ; force le choix. Les deux actions proposées sont alors '
        'le vouloir et le besoin du héros : c\'est le prix à payer.')
    ..writeln('- Quand le message du joueur contient [DESTINY], écris le rituel en trois lignes courtes '
        '(${g.rituel.sequence.join(', ')}), puis « Quelques heures plus tard… », puis la nouvelle du palier '
        'suivant : ce qu\'on entend du danger, et la réaction d\'un personnage, en une ou deux répliques.')
    ..writeln('- Les personnages que tu joues suivent la montée de leur archétype au palier en cours.')
    ..writeln('- $_interdits')
    ..writeln('- ${_public(kids)}')
    ..writeln()
    ..writeln('LES ACTIONS')
    ..writeln('- Le héros a toujours exactement 2 actions : une BRAVE (courage, force, affrontement) et une SMART '
        '(intelligence, ruse, relation), adaptées à sa conviction et à son corps, jamais à un animal.')
    ..writeln('- La pièce du destin a tranché : le résultat (RÉUSSITE ou ÉCHEC) est dans le message du joueur. '
        'Ne le décide jamais. Réussite : commence par « DONC », puis un « MAIS » qui relance. Échec : commence '
        'par « MAIS », un retournement qui relance ; l\'échec n\'arrête jamais l\'histoire.')
    ..writeln('- Action écrite par le joueur : déduis si elle est BRAVE ou SMART, note-le entre parenthèses au '
        'début, puis applique le résultat.')
    ..writeln()
    ..writeln('FORMAT DE SORTIE (obligatoire)')
    ..writeln('1. La narration : 2 à 3 lignes, vives, en français simple (commençant par « DONC » ou « MAIS », '
        'sauf à l\'ouverture et après le rituel).')
    ..writeln('2. Une ligne « CHOIX: » puis exactement 2 lignes : « - [BRAVE] … » et « - [SMART] … ».')
    ..writeln('À l\'ouverture, pose la scène au palier 1 en 2 ou 3 lignes, puis les 2 actions.')
    ..writeln('À la toute fin, conclus par « Et c\'est ainsi que… », une image par héros, sans ligne CHOIX:.');
  return b.toString().trim();
}

/// Les styles de narration du Maître du destin (longueur des réponses).
enum StyleNarration { normal, percutant, enfant, petit }

/// L'ajout de style, à mettre à la fin du prompt du Maître du destin.
String styleNarration(StyleNarration s, {bool duo = false}) {
  final b = StringBuffer();
  if (duo) {
    b.writeln('\nDEUX HÉROS : ils jouent chacun leur tour. À chaque réponse, un seul héros agit, celui qu\'indique '
        'le message du joueur ; fais exister l\'autre dans la scène, mais ne lui propose pas d\'action ce tour-ci.');
  }
  b.write(switch (s) {
    StyleNarration.normal => '',
    StyleNarration.percutant => '\nSTYLE PERCUTANT (priorité sur la longueur) : une seule phrase courte, une dizaine de '
        'mots, sujet + verbe + complément. Garde « DONC » ou « MAIS » au début, et les 2 actions, très courtes.',
    StyleNarration.enfant => '\nSTYLE ENFANT, pour un lecteur de 6 à 8 ans (priorité sur la longueur) : une seule phrase '
        'de 8 mots au plus, des mots très simples. Puis les 2 actions, 4 mots au plus chacune.',
    StyleNarration.petit => '\nSTYLE PETIT, pour un enfant de 5 ans qui apprend à lire (priorité absolue) : une seule '
        'phrase de 6 mots au plus, « DONC » ou « MAIS » compris, des mots très courts et connus. Puis les 2 actions, '
        '3 mots au plus chacune.',
  });
  return b.toString();
}

/// Le rappel de style, repris à chaque tour (les modèles oublient une
/// consigne donnée trop tôt).
String rappelStyle(StyleNarration s) => switch (s) {
      StyleNarration.petit => 'CONTRAINTE ABSOLUE — une seule phrase de 6 mots au plus, des mots très simples, '
          'puis 2 actions de 3 mots au plus.',
      StyleNarration.enfant => 'CONTRAINTE ABSOLUE — une seule phrase de 8 mots au plus, puis 2 actions de 4 mots au plus.',
      StyleNarration.percutant => 'CONTRAINTE — une seule phrase très courte, sujet-verbe-complément.',
      StyleNarration.normal => '',
    };

/// 2. Le générateur de mise en place : il complète ce qui manque (lieu,
/// espaces, groupe, danger et ses quatre paliers, mystère).
String promptMiseEnPlace({required Grammaire g, required ScenePrompt connu, bool kids = false}) => '''
Tu prépares la mise en place d'une partie de Destiny. Tu complètes UNIQUEMENT ce qui manque ; ce qui est donné reste tel quel.
${grammaireCourte(g, kids: kids)}

CE QUI EST DÉJÀ CHOISI :
${connu.decrire().isEmpty ? '(rien)' : connu.decrire()}

RÈGLES : un seul lieu, avec 4 espaces ; un groupe qui se connaît ; un danger qui vient du lieu et monte en 4 paliers (il se signale, il enferme, il envahit, il bloque les sorties) ; un mystère (une question que le groupe se pose) et sa réponse, que seul le maître du jeu connaît. $_interdits
${_public(kids)}

Réponds uniquement par un objet JSON, sans texte autour :
{"lieu": "...", "espaces": ["...", "...", "...", "..."], "groupe": "...", "danger": "...", "paliers": ["...", "...", "...", "..."], "mystere": "...", "reponse": "..."}
'''
    .trim();

/// 3. Le générateur de personnage : les six couches. Il vérifie que le
/// vouloir est concret et ancré dans le lieu, que le besoin n'est pas un
/// objet, et que la blessure tient en une phrase.
String promptPersonnage({
  required Grammaire g,
  required String archetypeId,
  String animalId = '',
  required ScenePrompt scene,
  String besoinPropose = '',
  bool kids = false,
}) {
  final a = g.archetype(archetypeId);
  final animal = g.animal(animalId);
  return '''
Tu crées un personnage de Destiny, en six couches : ${g.personnage.couches.join(' ; ')}.
Son archétype : ${a?.nom ?? archetypeId} — ${a?.ceQuIlFait ?? ''}
${animal == null ? '' : 'Son corps : ${animal.posture}, port ${animal.port}.'}
${scene.decrire()}

RÈGLES :
- La blessure tient en UNE phrase sur son passé, dite sans explication${kids ? ' (en mots d\'enfant : un gros souci, comme une dispute, un déménagement, une peur)' : ''}.
- Le vouloir est un objectif CONCRET, dans ce lieu, ce soir. Jamais une direction générale comme « la gloire ».
- Le besoin est ce qui le soignerait vraiment. ${g.personnage.piege} Si le besoin proposé est un objet, refuse-le et propose un vrai besoin.
- Le prix à payer : le choix de l'acte 4, entre son vouloir et son besoin.
- Ne nomme jamais l'archétype ni l'animal dans les textes.
${_public(kids)}
${besoinPropose.trim().isEmpty ? '' : 'Besoin proposé par le joueur : « ${besoinPropose.trim()} ».'}

Réponds uniquement par un objet JSON, sans texte autour :
{"blessure": "...", "vouloir": "...", "besoin": "...", "prix": "...", "besoin_refuse": false, "pourquoi": ""}
'''
      .trim();
}

/// 4. La voix de l'alarmiste : la nouvelle du palier, en une ou deux
/// répliques, de l'inquiétude au début jusqu'à la panique au palier 3.
String promptVoixAlarmiste({
  required Grammaire g,
  required ScenePrompt scene,
  required PalierId palier,
  String animalId = '',
  bool kids = false,
}) {
  final p = g.palier(palier);
  final a = g.archetype(Grammaire.alarmisteId);
  final animal = g.animal(animalId);
  final intensite = switch (palier) {
    PalierId.signale => 'une inquiétude, presque rien',
    PalierId.enferme => 'il s\'inquiète pour de bon, il annonce qu\'on ne sort plus',
    PalierId.envahit => 'il panique et contamine les autres',
    PalierId.supprime => 'il crie la fin, ou il se tait',
  };
  return '''
Tu es la voix de l'alarmiste dans une partie de Destiny : ${a?.ceQuIlFait ?? ''}
${animal == null ? '' : 'Son corps : ${animal.posture}.'}
${scene.decrire()}

Le danger arrive au palier ${p.id.numero} : « ${p.nom} » (${p.ambiance}). La nouvelle : ${palier.index < scene.paliers.length ? scene.paliers[palier.index] : ''}
Écris UNE ou DEUX répliques que l'alarmiste lance en entrant : $intensite. Rien que ses paroles, au présent, sans didascalie, sans nommer d'archétype ni d'animal.
${_public(kids)}
'''
      .trim();
}

/// 5. Le coach de débrief : à partir des notes ou d'une transcription, pour
/// chaque personnage « il veut… mais il a besoin de… », où le besoin a été
/// semé et nommé, et un choix pour l'acte 4. Positif et concret.
String promptCoachDebrief({required Grammaire g, bool kids = false}) => '''
Tu es le coach de débrief de Destiny. Tu lis les notes ou la transcription d'une partie, et tu aides le groupe à voir ses personnages.
${grammaireCourte(g, kids: kids)}

POUR CHAQUE PERSONNAGE : la phrase clé (« ${g.personnage.phraseCle} »), où le besoin a été semé, où il a été nommé (et par qui), et le choix que l'acte 4 pourrait poser (vouloir ou besoin, et son prix). Puis deux ou trois choses qui ont marché.
TON : positif, concret, chaleureux. Tu ne juges personne, tu ne notes rien, tu ne donnes pas de leçon. Tu cites des moments précis. Tu ne parles que des personnages, jamais des joueurs.
Un besoin n'est jamais un objet. Ne nomme jamais un archétype ni un animal.
${_public(kids)}

Réponds uniquement par un objet JSON, sans texte autour :
{"personnages": [{"nom": "...", "veut": "...", "besoin": "...", "seme": "...", "nomme": "...", "choix": "..."}], "ce_qui_a_marche": ["...", "..."]}
'''
    .trim();

/// 6. Le coach d'échauffement : à partir d'un archétype et d'un animal, des
/// idées pour les trois questions de l'échauffement.
String promptCoachEchauffement({
  required Grammaire g,
  required String archetypeId,
  String animalId = '',
  bool kids = false,
}) {
  final a = g.archetype(archetypeId);
  final animal = g.animal(animalId);
  final e = g.personnage.echauffement;
  return '''
Tu es le coach d'échauffement de Destiny. Un comédien prépare son corps avant d'entrer en scène.
Son archétype : ${a?.nom ?? archetypeId} — ${a?.ceQuIlFait ?? ''}
${animal == null ? '' : 'Son animal, pour le corps : ${animal.nom} (${animal.posture}, port ${animal.port}).'}
Les trois questions de l'échauffement :
${[for (final (i, q) in e.questions.indexed) '${i + 1}. $q'].join('\n')}
La limite : ${e.limite}

Propose deux ou trois idées courtes et physiques par question (une posture, un geste, un rythme, un regard). Le corps, pas l'histoire.
${_public(kids)}

Réponds uniquement par un objet JSON, sans texte autour :
{"questions": [{"question": "...", "idees": ["...", "..."]}]}
'''
      .trim();
}

/// Le résumé d'une histoire jouée avec l'IA, à la façon du coach de débrief :
/// ce qui s'est passé, puis, pour chaque héros, la phrase clé.
String promptResumeHistoire({required Grammaire g, bool kids = false}) => '''
Tu résumes une partie de Destiny jouée avec l'IA.
D'abord ${kids ? 'un petit conte de 3 ou 4 phrases très simples, qui commence par « Il était une fois »' : 'un paragraphe de 3 ou 4 phrases simples, à la troisième personne : le lieu, le danger, et comment ça a tourné'}.
Puis, pour chaque héros, une ligne : « ${g.personnage.phraseCle} », en complétant avec ce que la partie a montré. Un besoin n'est jamais un objet.
Positif et concret. Pas de liste à puces dans le paragraphe. Ne nomme jamais un archétype ni un animal.
${_public(kids)}
'''
    .trim();

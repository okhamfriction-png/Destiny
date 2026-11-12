# Journal de la refonte 2.0

Un bilan à la fin de chaque phase : ce qui a été fait, ce qui reste, les tests et les décisions à prendre.

---

## Phase 1 — Données et domaine ✅

### Ce qui a été fait

- **Le fichier de grammaire est branché.** Il est lu au démarrage, vérifié (12 archétypes, 24 animaux uniques, montées complètes, 4 paliers par danger, références croisées des œuvres et des exemples), puis transformé en objets typés (`lib/domain/grammaire/`). Si le fichier est abîmé, l'appli démarre quand même et liste les problèmes.
- **Un fichier de textes complémentaires** (`assets/data/destiny_textes.json`) contient les textes de l'appli qui ne sont pas dans ta grammaire : messages de distribution, contrôle du besoin, lexique, outils de jeu de Mark, module traître, mode enfant, portes de « Jouer ». Ton fichier de grammaire reste intact, et tu peux le remplacer par une nouvelle version sans rien perdre.
- **Les animaux** combinent ta grammaire (archétype, famille, réplique, posture, statut de départ, port) et les données de l'appli (tempérament, les 4 niveaux qui deviennent « le corps à chaque palier »). L'ancien moteur et l'ancienne intention sont conservés, marqués obsolètes, et jamais exposés.
- **La distribution** :
  - elle refuse un groupe sans alarmiste, sans l'une des trois familles, ou avec un archétype en double, et l'explique en une phrase ;
  - elle propose une correction qui rend le groupe valide ;
  - le tirage équilibré respecte toujours les règles à 4, 5 et 6, garde les archétypes imposés et le leader s'il est demandé ;
  - les 4 exemples tout prêts sont lisibles.
- **Les paliers** : chaque Destiny monte d'un palier, jamais au-delà du quatrième, jamais en arrière. Le premier Destiny est repéré comme le figé du besoin. La montée de l'archétype et le corps de l'animal sont donnés à chaque palier, avec le geste de l'acte (Dire, Fixer, Bloquer, Nommer, Choisir).
- **Le contrôle du besoin** : « J'ai besoin d'argent », « un prêt » ou « sa maison » sont signalés comme des vouloirs. « Faire confiance », « oser parler » ou « se laisser aider » passent. Les listes de mots sont dans le fichier de textes.
- **Les trois chronos de base** : 20 min (Destiny à 8, 15, 18), 30 min (10, 18, 27), 45 min (10, 25, 40).
- **Le catalogue lit maintenant ses textes dans la grammaire** :
  - phrases courtes des paliers ;
  - 4 espaces par lieu, avec les 8 sous-espaces gardés en réserve ;
  - rôles des lieux.
  Les identifiants de l'appli sont gardés, pour les images, les ambiances et la mémoire des tirages.
- **La migration du catalogue** (SQLite version 4 → 5) :
  - une ligne que tu n'as pas modifiée reçoit les nouveaux textes ;
  - une ligne modifiée par toi est gardée ;
  - un élément supprimé ne revient pas ;
  - un élément ajouté n'est pas touché.

  Elle se relance toute seule à chaque nouvelle version de la grammaire, et elle laisse un rapport : ce qui a été mis à jour, ce qui a été gardé. Une photo des textes 1.5.7 (`assets/data/migration/catalogue_1_5_7.json`) sert seulement à reconnaître tes modifications.
- **Correctif de sécurité des campagnes** : si les campagnes enregistrées ne peuvent pas être lues, l'appli n'écrit plus rien par-dessus. Avant, une erreur de lecture pouvait toutes les effacer.

### Tests

**79 tests passent** (Flutter 3.41.9) :
- les 27 anciens ; l'ancien test des paliers est remplacé ;
- 52 nouveaux : grammaire et validation d'un fichier abîmé, distribution (300 tirages vérifiés à 4, 5 et 6), paliers et chronos, contrôle du besoin, synchronisation du catalogue, et migration d'une vraie base SQLite 1.5.7.

L'analyse statique est inchangée : aucune erreur, les mêmes 12 remarques qu'avant.

### Ce qui reste (prévu plus tard)

- La migration des **campagnes** se fera en phase 5, avec le nouveau modèle de campagne. Aujourd'hui, aucun personnage de campagne n'est enregistré : il n'y a rien à perdre.
- Les écrans ne montrent pas encore tout ça. C'est l'objet des phases 2 à 7.

### Décisions

Aucune nouvelle décision bloquante. Une seule chose à valider quand tu auras le temps : les **noms d'archétypes en mode enfant**, que j'ai proposés dans `destiny_textes.json` (par exemple « celui qui dit que tout va bien » pour le dénégateur, « le blagueur » pour le cynique).

---

## Phase 1 bis — Grammaire 2.1 : série, méchants, sbires, figurants, kids ✅

Tu m'as envoyé la grammaire 2.1 et deux cahiers des charges (refonte v2, et la mise à jour série et kids). Je les intègre à la 2.0.

### Ce qui a été fait

- **La grammaire 2.1 remplace la 2.0.** Archétypes, paliers, dangers et lieux sont inchangés. Neuf répliques d'animaux sont retouchées (par exemple « La loi, c'est moi ! » pour le taureau, « Tous pour un, un pour tous ! » pour le mouton). Elle ajoute :
  - la **série** (épisode, saison, série, les 7 règles du méchant, le registre et ses 10 catégories) ;
  - les **24 grands méchants**, deux par archétype, chacun avec son animal à lui, son histoire, son vouloir, son besoin, sa faille, sa cible et son offre au traître ;
  - leurs **48 sbires**, jouables : chacun a un archétype et un animal des comédiens ;
  - les **figurants** : deux modes (figurant, sbire), huit types, et **trois figurants prêts à jouer par lieu** ;
  - le **mode kids** : le sigle, 6 règles, des pouvoirs, 16 méchants, 24 dangers avec un palier 4 sans mort, 35 lieux, et des répliques kids pour le loup, le corbeau et le renard.
- **Tout est lu, typé et vérifié.** La validation contrôle par exemple qu'un sbire ou un figurant a bien un animal de son archétype, qu'un méchant kids a sa version kids, et qu'un danger kids a son palier 4 kids.
- **Le catalogue reçoit les drapeaux kids** (24 dangers, 35 lieux) et le palier 4 kids des dangers. Comme pour les textes, cela se fait sans toucher à tes modifications, y compris sur une base 1.5.7. Le rapport signale aussi les éléments du catalogue sans équivalent dans la grammaire : aujourd'hui, il n'y en a aucun.

### Tests

**88 tests passent**, dont 9 nouveaux sur la série, les méchants, les sbires, les figurants et le mode kids. Aucune erreur d'analyse.

### Questions (fichier « série et kids »)

1. **Chrono kids** : je propose un 4ᵉ chrono de base de **24 minutes, Destiny à 6, 12 et 18**, pour les épisodes kids (20 à 30 minutes). D'accord ?
2. **La consigne enfant de l'IA** dit aujourd'hui « aucune peur ». Certains méchants kids donnent de petits frissons, comme la Dame blanche ou le Seigneur des brumes. Je propose de la remplacer par : « des frissons doux, jamais d'effroi ». D'accord ?
3. **Les 42 méchants d'univers** gardent leur place. Je leur proposerai un archétype chacun (phase 5), à valider avant de l'appliquer.
4. **Les présages des 24 méchants** : je propose qu'ils soient écrits par l'IA à la création de la saison, puis validés ou réécrits par le maître du jeu. Sans IA, le maître du jeu les écrit lui-même, guidé par les quatre paliers.

---

## Phase 2 — Design system ✅

### Ce qui a été fait

- **Les polices** Cinzel (700, 900) et Montserrat (400 à 700, avec l'italique) sont embarquées dans l'appli, avec leur licence libre (OFL) dans `assets/fonts/`.
- **Le thème Destiny** (`lib/presentation/theme/destiny_theme.dart`) :
  - un mode sombre (fond nuit, titres or) et un mode clair (cartes blanches sur fond crème, filets dorés) ;
  - toutes les couleurs sont lues dans la direction artistique de la grammaire : nuit, or, crème, encre, couleurs et teintes claires des familles, bleu Destiny, couleurs des statuts, sigle KIDS ;
  - une extension de thème (`DestinyCouleurs`) donne ces couleurs à tous les écrans ;
  - la frise des paliers va de l'or clair vers la braise. C'est un dégradé d'intensité, qu'on ne confond pas avec le rouge de la famille Fissure.

  L'appli entière utilise maintenant ce thème. L'ancien thème violet est supprimé.
- **Les composants, à réutiliser partout** (`lib/presentation/destiny/`) :
  - le sigle KIDS, la puce de famille, la pastille de statut, le médaillon d'animal cerclé d'or (il respecte le réglage réaliste, vectoriel ou minimal), l'encart de réplique, le bandeau façon affiche et la frise des quatre paliers ;
  - la **carte d'archétype** en trois variantes (par archétype, par animal, kids) et son **dos** (le dé Destiny et « Rien n'est écrit », dans un contour épais de la couleur de la famille). La source d'une réplique n'apparaît jamais sur une carte.
- **L'animation Destiny** se déroule dans cet ordre :
  1. le tonnerre (éclair et secousse ; c'est là que joue le son Destiny, qui contient le rire) ;
  2. la lumière bleue ;
  3. le figé : l'écran derrière devient flou et gris. Au premier figé, le rappel « il veut… mais il a besoin de… » s'affiche ;
  4. l'ellipse (« Quelques heures plus tard… ») ;
  5. la carte du nouveau palier, avec la nouvelle à souffler à l'alarmiste et le geste de l'acte.

  La régie peut sauter une étape. Si « réduire les animations » est activé, il n'y a ni secousse ni flou, et le rituel est plus court.
- **Tous les libellés** de ces composants viennent des fichiers de données. Aucun texte de grammaire n'est écrit dans le code.

### Tests

**102 tests passent** :
- 6 rendus de référence : carte d'archétype en sombre et en clair, carte d'animal, carte kids, dos de carte, frise des paliers ;
- des tests de contenu : la carte montre la réplique mais jamais sa source, la carte kids montre la réplique kids et le sigle ;
- deux tests du déroulé du rituel, en normal et en animations réduites.

### À savoir

- **Les anciens écrans** prennent déjà les couleurs et les polices du nouveau thème, mais gardent leur mise en page. Ils seront remplacés aux phases 3 à 7.
- Les images des animaux s'affichent dans l'appli. Les rendus de test utilisent le visuel « minimal », qui ne dépend pas du chargement des images.

---

## Phase 3 — Bibliothèque ✅

### Ce qui a été fait

La **Bibliothèque** remplace le Guide Destiny et les deux catalogues (dangers, archétypes). On l'ouvre avec l'icône livre en haut de l'écran. Elle compte douze entrées :

- **Les règles du spectacle** : les 8 règles d'or telles quelles, la frise des 4 paliers (et ce que fait l'archétype à chacun), les 4 actes et leurs consignes, le rituel Destiny et le premier figé, la distribution à 4, 5 et 6 avec les 4 exemples, l'échauffement et ses trois questions.
- **Archétypes** : les 12 cartes rangées par famille, avec un filtre. La fiche détaillée donne :
  - les deux animaux, avec posture, port, tempérament, statut, la réplique **et sa source**, et le corps à chaque palier ;
  - l'exemple des six directions ;
  - les personnages d'œuvres qui ont cet archétype, avec un lien vers l'œuvre ;
  - les deux méchants reflets.
- **Animaux** : les 24. Chaque fiche montre la carte, la réplique et sa source, la réplique kids quand elle est différente, le corps à chaque palier et la montée.
- **Vouloir et besoin** : les trois cartes, le piège, « détecter, pas jouer », la phrase des débriefs, la chaîne, les six couches, le tableau acte par acte et les six directions.
- **Dangers** : ceux du catalogue que tu joues (avec tes modifications), avec recherche, filtre kids et frise des paliers. Les dangers kids montrent aussi leur palier 4 kids.
- **Lieux** : leurs 4 espaces, les autres coins (les anciens sous-espaces), les rôles et **les trois figurants** du lieu. Recherche et filtre kids.
- **Œuvres** : les 21 œuvres et les 3 scènes, filtrables par catégorie et par archétype, avec l'avertissement « c'est notre lecture, et la fiche raconte la fin ». Chaque fiche a le lieu, le groupe, le danger, la frise des paliers, les personnages (archétype et animal en couleur, vouloir, besoin, face au danger, choix) et la leçon pour Destiny.
- **Grands méchants** : les 24 cartes avec leurs règles (le reflet, l'ombre, la faille…), filtrables par archétype et en kids. Chaque **sbire se joue depuis sa fiche** : la carte de son animal, ce qu'il veut, d'où il vient, ce qu'il fait.
- **Figurants** : les deux modes, les huit types (ce qu'il est, ce qu'il veut, comment le jouer, à quoi il sert), les règles, et le tableau des trois figurants par lieu. Chaque figurant se joue aussi depuis sa fiche.
- **Mode kids** : le principe, les 6 règles, des idées de pouvoirs, le palier 4 sans mort, et l'épisode, la saison et la série.
- **Outils de jeu** (les mains occupées, le sous-texte, les silences, la règle des 20 %) et **Les mots de Destiny** (le lexique).

Tous les textes viennent de la grammaire ou du fichier de textes. Les couleurs de famille apparaissent partout : cartes, puces, liserés, filtres.

### Tests

**113 tests passent** :
- les 11 nouveaux tests ouvrent chaque page de la Bibliothèque et vérifient son contenu : règles d'or, filtres, recherche, fiches, sources des répliques, figurants, méchants et sbires ;
- un nouveau rendu de référence : la carte du méchant.

### À savoir

L'ancien Guide reste joignable depuis le chrono TOP, et l'ancien catalogue depuis les Réglages, jusqu'à leur remplacement aux phases 4 et 7.

---

## Phase 4 — Navigation et mode Troupe ✅

### Ce qui a été fait

- **Trois onglets** : Jouer, Troupe et Exercices. L'appli **s'ouvre sur Troupe**. En haut à droite, quatre petits boutons : Bibliothèque, Musique (la bibliothèque des morceaux), Réglages et le son.
- **L'onglet Troupe** :
  - l'accueil, avec la promesse et, un jour sur deux, la règle d'or du jour ou la réplique du jour ;
  - le bouton « Préparer un spectacle » (ou « Reprendre », s'il y en a un en cours) ;
  - les entrées vers Jouer, la Bibliothèque, les Exercices et l'Historique.
- **Le déroulé complet d'un spectacle** (ou d'une répétition) :
  1. **Préparer** : spectacle ou répétition, avec ou sans enfants, 4, 5 ou 6 joueurs et leurs prénoms. La distribution se fait par choix concerté, tirage équilibré ou exemple tout prêt. L'appli refuse une distribution déséquilibrée, dit pourquoi en une phrase et propose une correction en un geste. Chaque joueur choisit son animal parmi les deux de son archétype.
  2. **Échauffement** : la carte de chaque joueur (en version kids si besoin), les trois questions, la limite (« le corps, pas l'histoire ») et un minuteur de 30 minutes.
  3. **Avant d'entrer en scène** : un écran qui donne envie de jouer, avec les règles d'or, les quatre paliers et la phrase des débriefs. Aucune critique.
  4. **La mise en place** :
     - trois lieux et trois dangers tirés pour le vote à main levée, ou un choix libre ;
     - le groupe, avec des suggestions, et deux liens tirés de l'antisèche ;
     - les trois objets, le mystère et sa réponse ;
     - le chrono (20, 30 ou 45 min).

     En mode kids, seuls les lieux et dangers kids sont proposés, avec le palier 4 kids.
  5. **La régie** :
     - un gros chrono et l'acte en cours ;
     - le **bouton Destiny**, réservé à la régie : il lance le rituel, fait monter le palier et affiche la nouvelle à souffler à l'alarmiste. Il se déclenche aussi tout seul aux minutes prévues, selon le réglage (automatique, manuel ou les deux) ;
     - au premier figé, le rappel de fixer le besoin ;
     - la frise des paliers ;
     - à chaque acte, le geste (Dire, Bloquer, Nommer, Choisir) et ses consignes ;
     - pour chaque joueur, ce que fait son archétype à ce palier et ce que fait le corps de son animal ;
     - les objets et le mystère ;
     - à l'acte 4, le dilemme du danger ;
     - les moments forts notés avec l'heure (« 23:10 : … ») ;
     - la régie son.

     **Les musiques** : celle du début, le son de chaque Destiny (tonnerre et rire), l'ambiance après le 2ᵉ Destiny et la musique de fin. Elles sont gardées dans les réglages ; l'écran pour les choisir arrive en phase 7.
  6. **Le débrief**, pour chaque personnage :
     - la phrase du groupe, face à celle choisie au premier figé, avec le rappel si le besoin ressemble à un objet ;
     - le choix de l'acte 4 et le prix payé.

     On y note aussi ce qui a marché.
  7. **L'historique** des spectacles et répétitions, avec la fiche de chacun et son **export en PDF**.
- **Retiré**, comme convenu :
  - l'ancien Générateur et ses modes Histoire, Rue, Spin-off et Dilemme ;
  - le chrono TOP et son dé (poids, faces, cartes Destin) ;
  - le dé 3D ;
  - l'ancien Guide et l'ancien Suivi de répétition ;
  - l'ancien catalogue en lecture seule (la Bibliothèque le remplace, y compris dans les Réglages) ;
  - la bulle « moteur ».

  **Aucune donnée n'est effacée** : les anciens tirages et l'ancien suivi restent enregistrés dans le téléphone.

### Tests

**119 tests passent**, dont 6 nouveaux sur le mode Troupe :
- relecture d'une session ;
- historique et session en cours ;
- protection d'une sauvegarde illisible ;
- réglages gardés, et reprise des anciens réglages de son ;
- fiche PDF ;
- **un spectacle complet de bout en bout** : préparer, échauffement, mise en place, régie avec Destiny, note, débrief.

### Ce qui reste (prévu plus tard)

- Générer les objets et le mystère avec l'IA (phase 6).
- L'écran des réglages Destiny : chronos, musiques des quatre moments, rituel (phase 7).
- L'export PDF des cartes d'archétypes (phase 7, avec le livret).
- La vue « salle », à projeter pendant le spectacle (proposée, à faire si tu la veux).

### Question

**Les niveaux de corps de cinq animaux contredisent leur nouvel archétype.** Ils décrivent encore leur ancien moteur :

| Animal | Nouvel archétype | Ancien moteur | Exemple (palier 2) |
|---|---|---|---|
| Rat | Alarmiste | le profit | « réclame, marchande, ne lâche rien de ce qui lui revient » |
| Coq | Alarmiste | la conquête | « veut plaire à tout prix, transforme chaque échange en conquête » |
| Lapin | Paranoïaque | plaire à tous | « fuit les tensions, dit oui à tout » |
| Mouton | Aidant | l'abri du plus fort | « cherche la protection du plus fort » |
| Hibou | Débrouillard | avoir raison | « corrige les autres, impose son analyse » |

Je propose de réécrire leurs quatre niveaux pour leur nouvel archétype, et de te les soumettre avant de les mettre dans l'appli. D'accord ?

**Réponse (2 novembre)** : « Adapte tout. » C'est fait en phase 5 (voir ci-dessous).

---

## Phase 5 — Jouer entre humains : épisode, saison, série ✅

La Campagne devient la **Série**, avec le vocabulaire de la télé.

### Ce qui a été fait

- **Tes quatre réponses** :
  - **les 42 méchants d'univers** ont chacun un archétype ; les 12 archétypes sont présents, chez les adultes comme chez les enfants (tableau dans `DECISIONS.md`) ;
  - **pas de chrono kids** : avec des enfants, « Sans chrono » est choisi d'office, et le maître du jeu lance Destiny quand il veut ;
  - **la consigne enfant de l'IA** dit « des frissons doux, jamais d'effroi » ; un personnage ne meurt pas, il quitte l'histoire. Même règle dans l'IA du jeu ;
  - **le corps du rat, du coq, du lapin, du mouton et du hibou** est réécrit pour leur archétype. L'ancienne version reste dans le fichier.
- **Jouer → Entre humains** :
  - deux portes : **Nouvel épisode** et **Nouvelle saison** ;
  - les deux séries les plus récentes, pour reprendre en un geste ;
  - **Mes séries**, avec le sigle KIDS et la ligne « où on en est ».
- **Un épisode** (le one-shot) :
  - le public (adultes ou avec des enfants), l'univers (ou Destiny sans univers), le lore, le ton, le contexte ;
  - les réglages de la série : traître (désactivé), registre (activé), combat, pièce du destin ;
  - **les personnages, gardés toute la série** : un archétype et un animal par joueur, avec une distribution équilibrée. À moins de quatre joueurs, l'alarmiste est joué par le maître du jeu. Chacun a aussi un nom, sa place dans le lieu, son peuple, sa blessure et son besoin (le contrôle « jamais un objet » est actif). En kids, chacun a son pouvoir, avec des idées ;
  - **la préparation** :
    - le lieu : ceux de l'univers, puis ceux de Destiny, avec leurs espaces, et la sortie de l'épisode précédent en rappel ;
    - le groupe, le danger et ses quatre paliers (en kids, le palier 4 sans mort), les trois objets et le mystère ;
    - le vouloir de chacun, avec des idées ;
    - les figurants du lieu et les sbires ;
    - ce qu'on ressort du registre ;
    - le chrono : 20, 30, 45 minutes, ou sans ;
    - le micro ;
  - **le jeu** :
    - le chrono ou pas, **Destiny et son rituel** (comme en Troupe), la frise des paliers, et les rappels acte par acte (fixer le besoin au premier figé, le nommer à l'acte 3, choisir à l'acte 4) ;
    - l'escalade ;
    - les personnages et leur montée à ce palier, les figurants et les sbires ;
    - les outils : le combat (cœurs, malus, bonus), la pièce du destin, la régie son et les notes ;
  - **le bilan** :
    - le choix de chacun (vouloir ou besoin), le prix payé, et si le besoin a été nommé ;
    - qui a quitté l'histoire, et qui est passé au service du méchant ;
    - la sortie du palier 4 (le lieu suivant) ;
    - ce qui a marché, la phrase qu'on garde, le registre ;
    - le résumé IA, avec le texte exact qui part, sans prénoms.
- **Faire la suite** : depuis la fiche d'un épisode, il devient le **premier d'une saison**. Son danger était le premier coup du méchant.
- **Une saison** :
  - on choisit le protagoniste visé, et l'appli propose ses **méchants reflets** (même archétype) : les grands méchants, puis ceux de l'univers. En kids, seulement les méchants kids. On peut aussi tirer au hasard ;
  - **les quatre présages** : ceux d'un méchant d'univers sont déjà écrits ; sinon l'IA les propose, ou le maître du jeu les écrit, guidé par les quatre paliers. Il les valide ;
  - **épisodes 1 à 3** : le méchant reste dans l'ombre. Sa carte est consultable par le maître du jeu ; les marches de l'escalade sont jouées par ses sbires et par le danger ;
  - **épisode 4** : le final. Le méchant apparaît en personne, avec sa faille ;
  - **en fin de saison** : ce que le méchant laisse, et ceux qui ont payé leur besoin peuvent changer d'archétype ;
  - **saison suivante** : nouveau méchant, nouveau besoin. En kids, ceux qui avaient quitté l'histoire reviennent.
- **Le traître** (si on l'active) : le méchant recrute un joueur, au hasard, jamais sa cible ni le personnage du maître du jeu. **L'écran caché** demande « Personne d'autre ne regarde ? », montre l'offre, puis « J'accepte » ou « Je refuse ». Il se révèle à l'épisode 3.
- **Les figurants et les sbires** :
  - un tableau en jeu, avec l'interrupteur figurant / sbire (couleur et icône) ;
  - le bouton **Jouer** ouvre la fiche jouable, avec la carte de l'animal ;
  - le geste **« Il a accepté l'offre »** fait basculer un figurant, et le registre le note ;
  - l'aide-mémoire des 8 types ;
  - ceux qui ont quitté l'histoire ne reviennent pas.
- **Le registre** :
  - un écran par série, rangé par catégorie, qu'on peut corriger, compléter et **exporter en PDF** ;
  - il se remplit au bilan, par l'IA et par l'appli (sorties, bascules, traître, sortie du lieu, héritage) ;
  - il passe d'une saison à l'autre.
- **Les données des univers** (écrites avec trois agents, puis vérifiées par un script) :
  - les **42 méchants d'univers** ont maintenant une posture, un animal à eux, un besoin, une faille, une cible (le reflet) et une offre au traître ;
  - leurs **70 sbires** ont un archétype et un animal des comédiens, ce qu'ils veulent, d'où ils viennent et ce qu'ils font ; ils sont jouables ;
  - les **42 lieux d'univers** ont chacun trois figurants (un aide, un témoin, une victime ou assimilés) ;
  - les univers, les lores, les peuples et les tons sont sortis du code (`univers.json`).
- **La migration** : les anciennes campagnes deviennent des séries, une seule fois.
  - Les clés v1 restent intactes. Une série supprimée ne revient pas.
  - Chaque épisode joué est gardé, marqué « Ancienne campagne » : intitulé, phrase, ce qui a marché, transcription, morts et blessés.
  - Les sbires tombés retrouvent l'id de leur sbire.
- **Le ménage** : l'ancienne Campagne est supprimée, à savoir ses 4 écrans, son store, ses entités, son constructeur, ses visuels, le cube de dé animé et le test du constructeur. Les fichiers de données restent.
- **Sur téléphone** : les parcours de la Série et du mode Troupe sont testés à 390 px de large. Les débordements trouvés sont corrigés, y compris trois dans le mode Troupe de la phase 4 (frise du rituel, bascule kids, choix du débrief).

### Tests

**146 tests passent** (l'ancien test du constructeur de campagne est parti avec son code). Les nouveaux tests :
- le modèle, le catalogue des univers, le reflet, l'escalade (le méchant n'apparaît pas avant l'épisode 4), les figurants, la distribution à 1 à 8 joueurs, le traître, les suggestions du registre ;
- la migration : rien ne se perd, la continuité passe aux ids, et en kids personne n'est mort ;
- **la vie privée** : aucun prénom ne part vers l'IA (résumé, présages, ressortis), et le registre n'en garde aucun, même si l'IA en répète un ;
- **un parcours complet, à 390 px de large** : épisode, Destiny, bilan, « Faire la suite », méchant reflet, présages, épisode 2 dans l'ombre avec ses sbires ;
- **l'écran caché du traître** ;
- chaque texte des écrans de la Série existe dans le fichier de textes.

### Décisions que j'ai prises (à revoir si tu veux)

1. **Les dangers d'un épisode** sont ceux de Destiny (38, filtrés en kids), quel que soit l'univers. Les lieux, eux, viennent de l'univers puis de Destiny.
2. **Les données des univers** (méchants, sbires, figurants) sont écrites. Relis-les quand tu veux : elles sont dans `campagne_mechants.json` et `campagne_lieux.json`. Quatorze méchants d'univers n'avaient qu'un sbire ; je n'en ai pas inventé d'autre.
3. **Hors saison**, un épisode peut avoir un méchant (facultatif). C'est l'ancienne règle : ses sbires agissent d'abord, il prend les deux dernières marches.
4. **Les anciens épisodes de campagne** restent « hors saison ». Pour continuer une ancienne campagne, on crée les personnages, puis la saison 1.

### Ce qui reste (prévu plus tard)

- Les prompts du Maître du destin et l'IA du jeu (phase 6), dont « habiller » un des 24 grands méchants dans un univers.
- Les réglages par défaut dans l'écran Réglages : public, traître, registre (phase 7).
- Le livret de règles : Série, Méchants, Sbires, Figurants, Mode kids (phase 7).

### Questions

1. **Des dangers propres à chaque univers ?** Je peux écrire, pour chacun des 21 univers, 3 dangers à 4 paliers (avec leur version kids). Aujourd'hui, on prend ceux de Destiny.
2. **Les méchants d'univers dans la Bibliothèque ?** Aujourd'hui, elle montre les 24 grands méchants. Je peux y ajouter les 42 méchants d'univers, rangés par univers.

**Réponses (2 novembre)** : « Oui, enchaîne, et oui aux deux questions. » Les dangers d'univers et les méchants d'univers dans la Bibliothèque sont faits en phase 6.

---

## Phase 6 — Jouer avec l'IA, et les prompts ✅

### Ce qui a été fait

- **Tes deux réponses** :
  - **chaque univers a ses 3 dangers**, avec leurs 4 paliers et leur version kids (63 dangers, écrits avec trois agents puis vérifiés par un script). À la préparation d'un épisode, ils sont proposés avant ceux de Destiny ;
  - **la Bibliothèque montre les 42 méchants d'univers**, rangés par univers, avec leurs sbires, leurs quatre présages, et les filtres par archétype et KIDS.
- **Les prompts sont réunis dans un seul dossier**, `lib/application/prompts/`.
  - Ils sont **versionnés** (2.0.0) et **testés**.
  - Chacun contient la grammaire en version courte, **générée depuis le fichier de grammaire** : rien n'est recopié à la main.
  - Les six rôles sont là : le **Maître du destin**, la **mise en place**, le **personnage** (il refuse un besoin qui est un objet), la **voix de l'alarmiste**, le **coach de débrief** et le **coach d'échauffement**.
  - On y trouve aussi le Spectacle IA et les consignes de l'assistant de la Série.
  - Chaque rôle a sa version adulte et sa version enfant (« des frissons doux, jamais d'effroi »).
  - Les règles sont dans chaque prompt : un lieu, un groupe qui se connaît, quatre paliers, pas de traître, pas de dé, et on ne nomme jamais un archétype ni un animal.
- **L'histoire avec l'IA** (le chat) :
  - on choisit l'un des **12 archétypes**, puis l'un de ses **deux animaux** (la carte s'affiche), et si on veut une blessure et un vouloir ;
  - les autres membres du groupe sont joués par l'IA, avec une distribution équilibrée ; s'il n'y a pas d'alarmiste parmi les héros, l'IA en joue un ;
  - le lieu et le danger viennent du catalogue de Destiny (en kids, seulement les lieux et les dangers kids) ;
  - **quatre chapitres**, un par palier. **Destiny tombe entre deux chapitres** : l'éclair, le tonnerre, puis la nouvelle de l'alarmiste. Au dernier chapitre, les deux actions sont le choix final, le vouloir ou le besoin ;
  - **la pièce du destin** tranche chaque action : le mot « dés » a disparu. « La pièce est plus dure après Destiny » (deux réussites) devient une option, désactivée par défaut ;
  - le résumé suit le coach de débrief : ce qui s'est passé, puis « Ce que tu veux, c'est… mais ce dont tu as besoin, c'est… » pour chaque héros ;
  - les anciennes histoires se relisent, mais ne se reprennent pas.
- **Le spectacle avec l'IA** :
  - quatre personnages tirés en distribution équilibrée, chacun avec son archétype et son animal ;
  - **quatre actes**, et **Destiny se lance avec un bouton**, quand on veut ;
  - **un débrief positif à la place de la note sur 100** : l'histoire, ton personnage, la phrase clé, ce qui a marché, une seule piste pour la prochaine fois ;
  - CROW reste, comme outil du coach ;
  - le **Spin-off** est retiré, comme tu l'avais décidé ;
  - un mode enfant ;
  - une partie commencée avec les anciens prompts n'est pas reprise, et l'écran le dit.
- **L'IA dans le jeu entre humains** (facultative ; sans clé, les boutons n'apparaissent pas) :
  - en Troupe, **« Proposer les objets et le mystère »** à la mise en place ; elle ne remplit que ce qui est vide ;
  - en Troupe, **« Des idées pour le corps »** à l'échauffement, pour chaque comédien ;
  - en Troupe, **« Demander au coach »** au débrief. Les prénoms des comédiens ne partent pas : on envoie « Personnage 1 », « Personnage 2 »… On peut reprendre ses phrases là où c'est vide ;
  - en Série, **« Souffler la nouvelle à l'alarmiste »** quand c'est le maître du jeu qui joue l'alarmiste.
- **Le service d'IA est corrigé** :
  - les **modèles Claude** sont à jour : Claude Opus 5.5 par défaut, puis Sonnet 5.5, Haiku 5.5, Fable 5.1, etc. ;
  - les réponses ne sont plus tronquées : 16 000 jetons au lieu de 1 024 ;
  - une réponse refusée par l'IA donne un message clair ;
  - OpenAI ne reçoit plus de température imposée (les modèles de raisonnement la refusaient).
- **Le ménage** :
  - **retirés** : l'ancien prompt du maître du jeu, l'ancien prompt du Spectacle (avec son Spin-off), le générateur d'histoire (et son test), l'ancienne entité « archétype = animal », sa lecture et ses visuels ;
  - **fichiers de données gardés** : `archetypes.json` sert toujours au corps des animaux.

### Tests

**169 tests passent**. Les nouveaux :
- les **prompts** : la grammaire courte vient du fichier ; chaque rôle contient ses règles ; il n'y a plus aucune trace de l'ancienne grammaire (« Résultat des dés », « moteur », « 3 actes », les anciens noms des paliers) ; les versions adulte et enfant diffèrent ;
- **l'histoire avec l'IA** : 4 chapitres égaux, Destiny entre les chapitres, la pièce qui tranche, le prompt gardé avec sa version, les anciennes histoires en lecture seule ;
- **le spectacle avec l'IA** : une distribution valide, Destiny par le bouton, l'ancienne partie ignorée ;
- **l'IA du jeu** : la mise en place, l'échauffement, le coach, la voix de l'alarmiste, et une réponse illisible qui ne casse rien ;
- **les écrans de l'histoire et du spectacle, à 390 px de large** : deux débordements corrigés.

### Décisions que j'ai prises (à revoir si tu veux)

1. **L'effort des modèles Claude est réglé sur « bas »** (`low`) : le jeu demande des réponses vives, et les résumés et propositions sont courts.
2. **Le repli automatique quand Claude décline une demande** est activé sur les modèles qui l'acceptent (Opus 5.5, Sonnet 5.5, Fable 5.1, Opus 5). L'IA réessaie alors sur un autre modèle, sans que tu aies rien à faire. Claude Haiku 5.5 n'a pas de repli : en cas de refus, l'appli affiche un message.
3. **Les univers et les tons** du chat et du Spectacle restent ceux de leurs écrans. Je les relierai à `univers.json` en phase 7, avec la relecture des textes.

### Ce qui reste (phase 7)

- Les Réglages : retirer les poids du dé de l'écran Apparence, l'écran des réglages Destiny (chronos, musiques, rituel, distribution, traître, public par défaut), le thème clair, sombre ou automatique.
- Le tutoriel, l'« À propos » et les exercices parlent encore du dé.
- Le livret de règles, l'export PDF des cartes, les éditeurs, la relecture des textes.

---

## Phase 7 — Réglages, exercices, accueil, livret, textes ✅

### Ce qui a été fait

- **Les Réglages** sont réorganisés en cinq parties : Destiny, IA, Apparence, Données et Aide.
  - **Destiny** (nouvel écran) :
    - les **chronos** de 20, 30 et 45 minutes se modifient (durée et minute de chaque Destiny), avec un retour aux valeurs par défaut. Un chrono incohérent est refusé, avec une phrase qui dit pourquoi ;
    - le **déclenchement** : automatique, manuel par la régie, ou les deux ;
    - le **rituel** : la lumière bleue, la durée du figé, le texte de l'ellipse, les rappels ;
    - **les quatre musiques** (début, son de Destiny, ambiance de l'acte 2, fin), la musique de chaque Destiny, et les musiques importées ;
    - la **distribution** par défaut, le **jeu de rôle** (kids, traître, registre, combat, pièce, évolution d'archétype), l'échauffement et les cartes.
  - **Apparence** : le thème **sombre, clair ou comme le téléphone**, les visuels des cartes, la taille et l'écriture manuscrite du texte de l'histoire. Les poids du dé ont disparu.
  - **Données** : les éditeurs, l'antisèche des relations, les détails des lieux, et le rapport de synchro du catalogue.
  - **Mode admin** : la vérification de la grammaire (les comptes, les erreurs éventuelles) et la lecture des archétypes.
- **Les Exercices** :
  - **trois nouveaux onglets, CROW, Lieu et Destiny**, à côté des anciens thèmes, qui restent tels quels ;
  - chaque thème s'ouvre sur **son principe**, une phrase de Mark Jane, et son explication ;
  - chaque exercice a **sa fiche** : le but, les consignes, les exemples, la question du débrief, la variante, la source, et le **badge « Avec Mark Jane »** pour ceux de la séance du 27 octobre ;
  - un **chrono** réglé sur la durée conseillée (« 5 à 10 min » propose 5 et 10 min) ;
  - les **cartes à tirer** (les dix visions du monde de « Trois phrases ») : une carte au hasard, jamais deux fois la même de suite ;
  - un lien **« Revoir la notion dans la Bibliothèque »** ;
  - l'écran suit le thème clair ou sombre, et le dé de l'onglet Solo est remplacé par une icône « au hasard ».
- **Découvrir Destiny** : **quatre écrans au premier lancement**, tirés de la grammaire :
  1. la promesse ;
  2. le lieu et le groupe ;
  3. le danger en quatre paliers, puis le rituel Destiny ;
  4. les personnages : l'archétype, l'animal, le vouloir et le besoin.

  On peut les passer, et les revoir depuis la Bibliothèque et les Réglages. Ils remplacent l'ancien tutoriel (« l'appli lance les dés »).
- **Le livret de règles**, en tête de la Bibliothèque, avec un sommaire :
  - le but, le matériel, les rôles ;
  - la mise en place : lieu et groupe, liens, danger, objets et mystère, distribution, animaux, personnage, échauffement ;
  - le déroulé : les quatre actes, le rituel, la nouvelle de l'alarmiste, la montée des archétypes, les cinq gestes (Dire, Fixer, Bloquer, Nommer, Choisir) ;
  - la fin : le choix de l'acte 4, le prix payé, le débrief ;
  - les variantes : 4, 5 ou 6 joueurs, la Série, les méchants, les sbires, les figurants, le registre, le traître, le mode kids ;
  - les règles d'or, rappelées à la fin.

  **Chaque règle vient de la grammaire** : je n'en ai ajouté aucune. Il **s'exporte en PDF** (7 pages). Il remplace l'ancienne page « Les règles du spectacle ».
- **Les cartes d'archétypes à imprimer** (Bibliothèque › Archétypes, bouton imprimante) :
  - un recto **par archétype** (12 cartes) ou **par animal** (24 cartes) ;
  - un verso Destiny ;
  - neuf cartes de 63 × 88 mm par page A4, placées pour une impression recto verso (bord long).
- **Les éditeurs**, refaits au nouveau design :
  - **lieux et dangers** : les espaces et les rôles d'un lieu, les quatre paliers d'un danger **nommés comme dans la grammaire** (les anciens « Palier 4 — climax, survie » ont disparu), le palier 4 en version kids, le sigle KIDS, et « proposé à la mise en place » ;
  - **les dilemmes de l'acte 4** : le « moteur » s'appelle maintenant **« genre »** à l'écran (le fichier garde l'ancien nom). L'ancienne mention du « mode Dilemme » a disparu.
- **À propos, Crédits et Contact** sont refaits :
  - **À propos** montre la version (2.0.0) et ce qu'on fait dans l'appli, sans le Générateur ni le dé ;
  - **Crédits** : les trois polices sous **licence SIL Open Font License 1.1** (Cinzel, Montserrat, Patrick Hand), les sons de freesound.org, et un bouton vers les licences des logiciels libres. Les textes des licences des polices sont embarqués dans l'appli.
- **Les univers de l'histoire et du spectacle avec l'IA** viennent maintenant de `univers.json`, comme ceux de la Série.
- **Le ménage** : l'ancien tutoriel, les anciens éditeurs, l'ancien écran des exercices, la page « Les règles du spectacle », la mémoire des combinaisons, le dépôt d'histoires et l'écran de base de données sont retirés. Le son « dé » n'est plus proposé dans les réglages (une ancienne sauvegarde qui le choisissait le joue encore).

### Tests

**205 tests passent** (169 à la fin de la phase 6). Les nouveaux :
- **les réglages** : un chrono se modifie, un chrono incohérent est refusé, le thème clair se garde, les réglages tiennent sur un téléphone, sans le dé ;
- **les exercices** : les anciens thèmes intacts (32 exercices, 50 virelangues), le principe du jour stable sur la journée, un carnet abîmé qui ne bloque rien, les durées lues en minutes, chaque exercice relié à une notion de la Bibliothèque, la fiche (cartes, débrief, chrono, lien), chaque fiche tient sur un téléphone ;
- **le livret** : huit sections dans l'ordre, chaque règle d'or, chaque palier, les cinq gestes, les règles des méchants et du mode kids présents tels quels, ni « dé » ni « sidéré », le PDF ;
- **les cartes à imprimer** : 4 pages par archétype, 6 par animal ;
- **Découvrir Destiny** : les quatre écrans, et il ne revient pas une fois vu ; au premier lancement, il s'affiche, et « Passer » mène à Troupe ;
- **les éditeurs** : un lieu créé avec ses espaces et KIDS, un danger dont les paliers portent les noms de la grammaire, les dilemmes sans « moteur » ;
- **À propos, Crédits, Contact** : sur un téléphone, sans le dé ;
- **chaque texte utilisé par les nouveaux écrans existe** dans `destiny_textes.json` (un test lit le code et vérifie chaque clé).

### Décisions que j'ai prises (à revoir si tu veux)

1. **Les 20 exercices sont lus dans la grammaire**, sans être recopiés dans `exercices.json` : le fichier de grammaire reste la seule source. À l'écran, ils sont bien trois onglets de plus, à côté des anciens.
2. **L'ordre des onglets** : les six anciens thèmes (Échauffement d'abord), puis CROW, Lieu, Destiny, puis Solo.
3. **Chaque exercice renvoie à une page de la Bibliothèque** (par exemple « Trois phrases » → Vouloir et besoin ; « Le lieu en quatre paliers » → Dangers). La table est dans le code, et un test vérifie que les 20 y sont.
4. **Le livret remplace la page « Les règles du spectacle »** : il contient tout ce qu'elle disait, et plus. Les phrases de présentation (le but, le matériel, les rôles) reprennent ton cahier des charges, mot pour mot quand c'était possible.
5. **Découvrir Destiny compte comme « vu » dès qu'on le ferme**, même sans aller au bout.
6. **Les tons** de l'histoire et du spectacle avec l'IA restent les leurs (Aventure, Humour, Drame…) : ce sont des genres d'histoire, différents des tons de la Série (Drôle, Aventureux, Enquête…).

### Ce qui reste (phase 8)

- L'accessibilité (tailles de texte, lecteurs d'écran, contrastes du thème clair) et la régie sans réseau.
- Le ménage du vieux code qui reste (les visuels des anciennes entités, les anciens écrans de l'histoire et du spectacle avec l'IA encore en thème sombre).
- La documentation (`FEATURES.md`, README, fiche Play Store), la version web, la version 2.0.0+20 et le changelog en français.

### Question

**Le logo de l'appli est un cube**, avec un lieu, des masques et un éclair sur ses faces. On peut le lire comme un dé. Je l'ai gardé : c'est l'icône de l'appli et le dos des cartes. Veux-tu le garder, ou faut-il prévoir un nouveau logo (par exemple l'éclair seul, ou le losange doré) ?

---

## Phase 8 — Finitions, version 2.0.0+20 ✅

### Ce qui a été fait

- **La version 2.0.0+20** : le `pubspec.yaml` et l'écran À propos disent la même chose, et un test le vérifie.
- **Le changelog en français**, `CHANGELOG.md`, écrit pour les comédiens, les troupes et les parents : ce qui change, ce qui disparaît, et « rien n'est perdu ».
- **Un vrai bug trouvé et corrigé** : le fichier `univers.json` n'était pas déclaré dans les fichiers de l'appli. Sur un téléphone, le catalogue des 21 univers (leurs lieux, figurants, dangers et méchants) ne se serait pas chargé. Les tests ne le voyaient pas, parce qu'ils lisent les fichiers directement. Il est déclaré, et **un nouveau test vérifie que chaque fichier lu par l'appli est bien embarqué**. C'est la version web qui l'a révélé.
- **L'accessibilité** :
  - chaque bouton-icône a un nom, lu par les lecteurs d'écran (14 en manquaient) ;
  - les couleurs du texte ont un contraste d'au moins 4,5, en clair comme en sombre. Le bleu Destiny et le nom des familles étaient un peu justes : ils sont éclaircis en sombre et assombris en clair, seulement quand ils colorent du texte ;
  - avec des caractères 60 % plus grands, sur un téléphone de 390 px, les écrans principaux tiennent. Trois débordements trouvés et corrigés : les cadres à liseré (le liseré suit maintenant le contenu), le bas de Découvrir Destiny, et la pastille d'une famille ;
  - « Réduire les animations » calme le rituel, et suit aussi le réglage du téléphone.
- **Hors ligne** : un test vérifie que la régie, le rituel et la Série n'importent jamais le service d'IA ni le réseau. **La version web embarque maintenant son moteur d'affichage**, au lieu de le télécharger chez Google à chaque visite.
- **Le ménage** : les visuels des anciennes entités et la fenêtre de détails d'un lieu sont retirés ; les images des lieux et des dangers ne sont plus embarquées (**5,6 Mo de moins**), mais restent dans le dépôt.
- **La documentation** : le README, `docs/FEATURES.md` (refait entièrement pour la 2.0) et la fiche Play Store (descriptions courte et longue, section « Data safety », modèle de politique de confidentialité qui parle de l'IA).
- **La version web** est recompilée dans `docs/app`, et vérifiée dans un navigateur (Découvrir Destiny, Troupe, Exercices, Bibliothèque). Cinq captures de la 2.0 sont dans `docs/store_assets/screens_2_0/`, et dans `FEATURES.md`.
- **Sur ordinateur et sur la version web**, les listes et les onglets se font maintenant glisser à la souris : sans ça, les onglets CROW, Lieu et Destiny restaient hors de portée.

### Tests

**216 tests passent** (205 à la fin de la phase 7). Les nouveaux :
- les contrastes, en clair et en sombre ;
- aucun bouton-icône sans nom ;
- la régie, le rituel et la Série sans réseau ;
- Troupe, Découvrir Destiny, la Bibliothèque, le livret, les Exercices, une fiche, les Réglages et À propos, avec un texte agrandi de 60 % ;
- chaque fichier lu par l'appli est embarqué ;
- la version 2.0.0+20, et le changelog qui commence par la 2.0.0.

### Décisions que j'ai prises (à revoir si tu veux)

1. **Les écrans de l'histoire et du spectacle avec l'IA, de la Musique et de la configuration de l'IA** gardent leur thème sombre d'origine, même en thème clair : ils fonctionnent, et les refaire entièrement au nouveau design serait un gros chantier. Leurs boutons ont maintenant tous un nom.
2. **Les images des lieux et des dangers** ne sont plus dans l'appli (plus rien ne les affichait), mais je ne les ai pas effacées du dépôt.
3. **La version web** n'utilise plus le CDN de Google : un peu plus lourde à publier, mais autonome.
4. **Le Data safety** de la fiche Play Store et le modèle de politique de confidentialité disent maintenant que les modes IA envoient le texte de jeu au fournisseur choisi. La page en ligne `docs/privacy.html` n'est **pas** modifiée : c'est un texte légal, je te laisse valider.

### Ce qui reste, hors de ce que je peux faire ici

- Les captures pour le Play Store, sur un vrai téléphone.
- La publication : construire le `.aab` signé et l'envoyer sur la Console.
- Fusionner la branche `claude/destiny-story-2-refonte-cyw02u` dans `main`, pour que GitHub Pages serve la nouvelle version web.

### Questions

1. **La politique de confidentialité en ligne** (`docs/privacy.html`) ne parle pas des modes IA. Je propose le texte du § 6 de `docs/play_store_listing.md`. Je l'applique ?
2. **Les images des lieux et des dangers** : je les efface du dépôt, ou je les montre dans la Bibliothèque (pages Lieux et Dangers) ?
3. **Le logo en forme de cube** (question de la phase 7) : on le garde ?

---

## Après la phase 8 — « Enchaîne, n'attends pas mon go » ✅

### Ce qui a été fait

- **Tous les écrans suivent maintenant le thème clair ou sombre.** Il y avait encore huit écrans forcés en sombre. Je les ai passés au nouveau design avec deux agents, chacun dans sa copie du projet, puis j'ai fusionné leur travail :
  - l'**histoire avec l'IA** et le **spectacle avec l'IA** ;
  - la **configuration de l'IA**, la **Musique** et la **régie son** ;
  - l'**antisèche des relations**, les **détails des lieux**, les **archives**.

  Leurs textes sont dans `destiny_textes.json` (sections `histoire_ia`, `spectacle_ia`, `ia_config`, `musique`, `relations`, `details_lieux`, `archives`). Le fichier qui forçait le thème sombre est retiré.
- **Quelques défauts corrigés au passage** :
  - taper la clé d'IA déclenchait une erreur à chaque lettre (en mode développeur) ;
  - le cadre d'une fiche de lieu ne pouvait pas s'afficher (bordure arrondie non uniforme) ;
  - l'erreur au lancement d'une nouvelle histoire ne s'affichait jamais ;
  - le badge « 2 réussites requises » s'affichait à chaque chapitre, même sans l'option.
- **Petits changements d'affichage** :
  - dans la liste des histoires, un seul menu (Résumé, Archiver, Supprimer) remplace trois petits boutons qui coupaient les titres ;
  - chaque histoire montre son univers, son lieu et son danger ;
  - « Jeton API » devient « La clé d'API » ;
  - « Paramètres » devient « Réglages » partout.
- **La politique de confidentialité** (`docs/privacy.html`) est à jour :
  - les modes IA, facultatifs, envoient le texte de jeu au fournisseur choisi. L'appli propose **Anthropic, OpenAI et Google** : les docs n'en citaient que deux ;
  - en troupe et en Série, les prénoms des comédiens ne partent jamais. Dans l'histoire avec l'IA, seul le nom donné au héros part ;
  - la transcription passe par la reconnaissance vocale du téléphone (Google ou Apple). Les docs disaient à tort « sur l'appareil » ; l'appli, elle, ne garde aucun son ;
  - le mode kids est mentionné.
- **Le Play Store** :
  - huit captures au format 9:16 (1080 × 1920) dans `docs/store_assets/play_store_2_0/` ;
  - la bannière refaite pour la 2.0.
- **La version web** est recompilée avec tous ces écrans, et vérifiée en thème clair dans un navigateur.

### Tests

**243 tests passent** (216 à la fin de la phase 8). Les nouveaux vérifient :
- chaque écran porté, à 390 px, en clair et en sombre, avec ses actions principales ;
- que chaque texte utilisé existe ;
- qu'aucune couleur sombre n'est restée en dur ;
- qu'il n'y a plus d'écran forcé en sombre.

### Décisions que j'ai prises (sans attendre ton go)

1. **La politique de confidentialité** : j'ai appliqué le texte proposé, corrigé sur les trois points ci-dessus. Elle sera en ligne dès que la branche sera fusionnée dans `main`.
2. **Le logo cube** est gardé.
3. **Les images des lieux et des dangers** restent dans le dépôt, sans être embarquées dans l'appli.
4. **Les effets plein écran** de l'histoire avec l'IA (réussite, échec, orage) gardent leurs couleurs propres dans les deux thèmes.

---

## 2.0.1 — Préparer en un geste ✅

### Ton retour

« Les noms, tu peux oublier en spectacle et en répétition. Par défaut, répétition. Quand on tire, je veux directement le lieu, le danger avec les images comme avant, et en dessous les quatre archétypes en contracté avec leurs deux animaux. Des boutons info à tous les niveaux. Et là, je n'arrive même pas à appuyer sur le bouton : il est grisé. »

### Ce qui a été fait

- **Le bouton grisé** venait de l'obligation de choisir un animal pour chaque joueur. Ce choix est maintenant facultatif : sans choix, l'échauffement montre l'archétype et ses deux animaux, et la régie fonctionne déjà sans animal.
- **Préparer**, en spectacle comme en répétition :
  - la répétition par défaut ;
  - plus aucun prénom (ils restent dans la Série, côté Jouer) ;
  - un grand bouton **« Tirer »** qui donne d'un seul geste le lieu, le danger et la distribution. À l'arrivée, tout est déjà tiré ;
  - le lieu et le danger en vignettes, avec leur image, un bouton pour en tirer un autre et un bouton « i » pour leur fiche ;
  - chaque archétype en version compacte : son nom, ce qu'il fait, ses deux animaux. Il y a un bouton « i » pour l'archétype et pour chaque animal, et un bouton pour changer l'archétype ;
  - le mode de distribution en puces (« Tirage équilibré » ne se coupe plus en deux).
- **Les images des lieux et des dangers** sont de nouveau embarquées.
- **Version 2.0.1+21**, pour que GitHub publie une nouvelle release avec le nouvel APK.

### Tests

**253 tests passent**. Les nouveaux vérifient :
- l'arrivée sur Préparer : répétition, tout est tiré, aucun champ de prénom ;
- le passage à l'échauffement sans animal ;
- le choix d'un animal, qui se défait ;
- « Tirer », « Un autre lieu » et « Un autre danger » ;
- les quatre boutons info ;
- le mode kids ;
- l'écran à 390 px avec un texte agrandi, en clair et en sombre.

---

## 2.0.1 (suite) — Plus lisible, et le jeu de rôle façon PbtA ✅

### Tes retours

- « Améliore l'UX : c'est trop moche, on n'y voit rien, c'est pas clair comparé à avant. »
- « La partie Jouer, c'est du jeu de rôle : il faut les codes PbtA. Retire les univers, le ton et la place dans le lieu pour la partie entre humains. »
- La pièce : « BRAVE ou SMART. Le joueur choisit sa ligne. Si la pièce tombe sur l'autre face, c'est un échec. Les personnages ont un bonus en BRAVE ou en SMART : ils lancent deux fois. »

### Ce qui a été fait (deux agents en parallèle, puis fusion)

- **Le visuel** :
  - le texte est en Montserrat, plus gros ; Cinzel ne sert plus qu'aux grands titres ;
  - les cartes sont pleines, sur un fond moins brun ;
  - chaque entrée a une couleur et une icône sur une pastille ;
  - les sélections sont dorées, à la place du bleu terne ;
  - les intitulés de section sont plus grands ;
  - le thème clair est revu ;
  - les contrastes et les débordements sont testés.
- **Le jeu de rôle entre humains** :
  - la pièce BRAVE / SMART et le bonus à deux lancers ;
  - neuf mouvements des joueurs ;
  - l'agenda, les huit principes et les mouvements du Maître du destin (doux ou durs selon le palier), dans une aide du MJ en quatre onglets ;
  - deux horloges, et trois cases de blessures ;
  - plus d'univers, de ton, de lore, de peuple ni de place dans le lieu ;
  - les lieux et les dangers viennent du catalogue de Destiny, avec leurs images ; le méchant de saison est l'un des 24 grands méchants ;
  - les anciennes sauvegardes se lisent toujours ;
  - les modes IA gardent leurs univers.
- **Le workflow de l'APK** ne se lance plus à chaque envoi : seulement sur un tag, à la main, ou quand le message du commit contient la balise prévue pour ça. On teste la version web d'abord.

### Tests

**278 tests passent**.
- Le moteur de la pièce : la bonne face, l'autre face, le bonus, l'aide, la gêne, la gravité selon le palier.
- Les blessures : en kids, jamais la mort.
- Les écrans du jeu de rôle, en clair, en sombre et avec un texte agrandi.
- Les tests de vie privée sont toujours verts.

### À confirmer avec toi

1. **Le bonus suggéré** pour chaque archétype (le joueur choisit toujours) :
   - BRAVE pour le leader, le protecteur, le dénégateur, le gardien de l'ordre et le solitaire ;
   - SMART pour les sept autres.
2. **Un mouvement « Soigner »** a été ajouté : il efface une case de blessure.
3. **« Hors jeu »** : le personnage ne quitte l'histoire que si on le coche au bilan.
4. **Le lieu et le danger** de l'épisode sont tirés tout seuls en arrivant sur la préparation, comme en Troupe.
5. **Deux réglages retirés** : « combat par défaut » et « pièce par défaut » ne servaient plus à rien.

---

## 2.0.1 (fin) — La régie, des rectangles, un vrai noir ✅

### Ton retour

« Des petits rectangles avec une bulle d'infos plutôt que les grandes cartes. Les musiques et les tablettes de régie dès le début du spectacle. Voir les 3 Destiny dans le minuteur, pouvoir les modifier, les lancer plus tôt ou plus tard. Et l'UX : le noir est trop gris, va vers un vrai noir, façon IntelliJ ou VS Code. »

### Ce qui a été fait

- **La palette** :
  - en sombre, un fond quasi noir et neutre, des cartes anthracite, un texte blanc cassé et un gris secondaire lisible ; plus de teinte brune ni d'ombre ;
  - en clair, un fond gris très pâle et des cartes blanches ;
  - l'or reste pour les titres, les sélections et les boutons principaux.
- **La régie** :
  - le panneau du chrono reste fixé en haut : le temps restant, la frise des trois Destiny, le temps avant le prochain, « −1 min » et « +1 min », et le réglage de tous les Destiny restants ;
  - le bouton DESTINY marche dans tous les modes de déclenchement ; il était grisé en mode automatique ;
  - la tablette son ;
  - le lieu et le danger avec leur bulle d'info.
- **Les rectangles compacts** (archétype, puis l'animal s'il est choisi, et une bulle « i ») à l'échauffement, avant d'entrer en scène, à la régie, au débrief et dans la fiche du spectacle.
- **La mise en place** : le groupe est tiré d'office, et « Lever le rideau » ne demande plus que le lieu et le danger.

### Tests

**297 tests passent**. Les nouveaux portent sur :
- les règles de décalage d'un Destiny ;
- les trois repères ;
- le bouton DESTINY en mode automatique ;
- la tablette son, et son comportement quand le son est coupé ;
- les bulles d'info ;
- chaque écran Troupe en clair et en sombre, avec un texte agrandi.

## Publication de la 2.0.1 (APK)

La version web a été mise en ligne dans une page Claude pour être essayée avant l'APK. Elle comprend les images, les sons de la régie, les musiques et les ambiances. Les pages Claude refusent le format des fichiers son : dans cette copie de test seulement, ils ont été renommés dans un format accepté. Le dépôt n'a pas changé.

Validée par l'utilisateur, la 2.0.1 part en APK : le workflow crée la release v2.0.1 et la marque comme dernière version.

Au passage, la transcription vocale passe la langue et la durée d'écoute par les options d'écoute du paquet, au lieu des deux paramètres dépréciés. Le comportement ne change pas, et l'analyse ne signale plus rien.

## 2.0.2 : la régie dès l'échauffement

### La demande

Capture de l'échauffement sur téléphone : « Y'a pas la régie, les musiques, lieu, danger, Destiny etc. »

La régie existait, avec le chrono, les Destiny, la tablette son, le lieu et le danger. Mais elle n'arrivait qu'après l'échauffement, « Avant d'entrer en scène » et la mise en place, et aucun écran ne le disait. Le minuteur d'échauffement, de 30 minutes, ressemblait en plus au chrono du spectacle.

### Ce qui a été fait

- **Le fil des étapes** (`FilEtapes`), en haut de Préparer, de l'échauffement, d'« Avant d'entrer en scène » et de la mise en place :
  - il montre l'étape en cours, et la régie se détache en bleu ;
  - un appui mène à l'étape voulue (`allerAEtape`) ;
  - depuis Préparer, on n'avance que si la distribution est jouable ;
  - la régie n'a pas de fil : un appui par erreur arrêterait le chrono.
- **Ce qui manque est rempli d'office** :
  - en quittant Préparer, le spectacle prend le chrono des réglages ;
  - avant la régie, le groupe est tiré s'il est vide ;
  - à la mise en place, le chrono choisi va dans la session dès qu'on le choisit.
- **À l'échauffement** :
  - le lieu et le danger ;
  - la tablette son de la régie (`TabletteSon`, partagée) ;
  - la frise des trois Destiny prévus ;
  - « Aller directement à la régie » ;
  - le minuteur nommé « Temps d'échauffement ».

### Tests

Cinq nouveaux tests :
- ce que montre l'échauffement, et la musique qu'on y lance ;
- le fil vers la régie, avec le groupe tiré d'office ;
- le bouton « Aller directement à la régie » ;
- le chrono des réglages en quittant la préparation ;
- le chrono de la mise en place écrit tout de suite.

## 2.0.2 : plus d'objets

### La demande

« Retire toute la logique d'objet de l'application, jeu de rôle et règles. »

### Ce qui a été retiré

Les trois objets du lieu, partout où ils étaient une règle du jeu.

- **La grammaire** :
  - les consignes des actes 1 et 4 (« Les trois objets sont touchés », « Un des objets sert dans la scène finale ») ;
  - la montée du débrouillard au palier 4, qui parlait de « l'objet du début » ;
  - la catégorie « objets » du registre, et les objets dans la règle de la série et dans « ce que le méchant laisse » ;
  - la faille de l'Immortel, qui renvoyait aux trois objets : l'objet où il a caché sa mort est maintenant « quelque part dans le lieu » ;
  - l'exercice « Les trois objets » : il reste 19 exercices.
- **Les textes** :
  - les objets de la mise en place ;
  - « Objets et mystère » à la régie, qui devient « Le mystère » ;
  - le mouvement doux du Maître du destin « Utiliser un objet du lieu » ;
  - l'aide du registre et de l'héritage du méchant ;
  - « Proposer les objets et le mystère (IA) », qui devient « Proposer le mystère (IA) ».
- **Les écrans** :
  - la mise en place, la régie et la fiche d'un spectacle ;
  - la préparation et le jeu d'un épisode de série ;
  - le livret et le PDF d'un spectacle.
- **L'IA** : le prompt de la mise en place ne demande plus d'objets. Le numéro des prompts ne change pas : les prompts du spectacle avec l'IA sont les mêmes, et le changer effacerait les parties en cours.
- **La fiche du hibou** (`archetypes.json`) ne parle plus de « l'objet du début ».

### Ce qui reste

- **Le mystère et sa réponse.**
- **Les objets de tous les jours** dans les descriptions (un figurant qui « apporte un objet, une clé ou un savoir », un danger où « un objet tombe »), et les exercices d'impro avec des objets imaginaires.
- **Le contrôle du besoin** (« un besoin n'est jamais un objet ») : c'est une autre règle.

### Les anciennes données

Rien n'est perdu.
- Les objets déjà notés restent dans les sauvegardes des spectacles et des épisodes : ils sont relus et réécrits, mais plus montrés.
- Dans le registre, l'ancienne catégorie « objet » est gardée en fin de liste :
  - les entrées déjà notées s'affichent et se corrigent ;
  - on n'en crée plus ;
  - elles ne sont plus proposées à ressortir, ni par l'appli ni par l'IA.

### Tests

**304 tests passent.** Un test vérifie que la grammaire, les textes et les fiches des animaux ne parlent plus des objets du lieu. Un autre vérifie qu'une ancienne session avec des objets ne les montre plus à la mise en place ni à la régie, mais les garde dans sa sauvegarde.

## 2.0.2 : la régie son dans un bouton, l'heure des Destiny

### La demande

« La régie prend trop de place : juste un bouton régie qui ouvre tout le son dans une pop-up qu'on peut fermer. Et le minuteur : qu'on voie les Destiny, à quel timing. »

### Ce qui a été fait

- **La régie son** :
  - la tablette n'est plus dans la page ;
  - à la régie, un bouton carré « Son » est à côté de DESTINY, dans le panneau du chrono qui reste en haut ;
  - à l'échauffement, c'est un bouton « Régie son », qui dit aussi ce qui joue ;
  - le bouton ouvre la tablette dans une fenêtre (`ouvrirRegieSon`). On la ferme avec la croix, en la glissant vers le bas ou en touchant à côté. Le chrono continue.
  - l'icône du mixeur, en haut de la régie, disparaît : « Tout le mixeur » est dans la fenêtre.
- **L'heure des Destiny** : sous chaque repère de la frise, l'heure prévue, ou celle où le Destiny a été lancé.
  - Deux heures ne se chevauchent jamais et restent dans la frise (`FriseDestiny.placerHeures`), même avec des Destiny très proches.
  - C'est la même frise à la régie, à l'échauffement et à la mise en place.

### Tests

**307 tests passent**, dont trois nouveaux :
- la fenêtre de la régie son s'ouvre et se ferme ;
- un Destiny lancé montre l'heure où il l'a été ;
- les heures ne se chevauchent pas.

Le test de la frise vérifie aussi les heures prévues sous les repères, et les tests de la régie son ouvrent d'abord la fenêtre.

## 2.0.2 : l'échauffement épuré, les Destiny qu'on fait glisser, les réactions au danger

### Les demandes

- Sur trois captures de l'échauffement (les boutons du bas, « Régie son », les trois questions) : « Retire tout ça. »
- Sur la frise : « On doit pouvoir bouger manuellement sur la ligne le timing des Destiny. »
- Sur les personnages de l'échauffement : « Ajoute sur les archétypes les 4 étapes de réaction au danger. »

### Ce qui a été fait

- **L'échauffement** garde le fil des étapes, le minuteur, le lieu et le danger, les personnages et la frise des Destiny. Ce qui a été retiré :
  - les trois questions et leur encadré ;
  - le bouton « Régie son » (il reste à la régie) ;
  - la phrase d'aide sous la frise ;
  - « Avant d'entrer en scène » et « Aller directement à la régie ». Le fil des étapes mène à la mise en place et à la régie.
  L'écran « Avant d'entrer en scène » n'avait plus d'accès : il est retiré, avec ses textes. L'intro de l'échauffement ne parle plus des trois questions.
- **Les réactions au danger** (`ReactionsArchetype`) : sous chaque archétype, sa montée de la grammaire pour les quatre paliers, numérotée dans la couleur du palier.
- **Faire glisser un Destiny** (`FriseDestiny`, maintenant avec un état) :
  - une seule zone de geste pour toute la frise ;
  - au début du geste, on prend le repère sous le doigt. Si deux repères sont collés, on prend celui de gauche quand on va à gauche, et celui de droite quand on va à droite ;
  - le repère avance à la minute près. Les règles sont celles de « −1 min » et « +1 min » (`refusDestiny`) : jamais un Destiny déjà lancé, ni avant le chrono, ni à côté du précédent ou du suivant, ni après la fin ;
  - un geste trop rapide s'arrête à la minute permise la plus proche du doigt ;
  - à la souris, le curseur devient une double flèche ;
  - un lecteur d'écran a « plus tard » et « plus tôt ».
- **La mise en place** reconnaît le chrono de la session à sa durée : des Destiny déplacés à la main restent. « Lever le rideau » ne réécrit plus le chrono.

### Tests

**310 tests passent**. Les nouveaux portent sur :
- le glisser à l'échauffement : sans dépasser le suivant ni le précédent, et enregistré ;
- les Destiny déplacés gardés jusqu'à la régie ;
- le glisser à la régie, où un Destiny lancé ne bouge plus ;
- les quatre réactions de chaque archétype ;
- ce qui a disparu de l'échauffement.

Le parcours complet du spectacle passe maintenant par le fil des étapes.

## 2.0.2 : les fiches en fenêtre, changer d'archétype à l'échauffement

### La demande

« Les boutons info doivent ouvrir une pop-up, et garder la possibilité, dans la Troupe, de changer manuellement d'archétype. »

### Ce qui a été fait

- **Les fiches en fenêtre** (`ouvrirEnFenetre`, dans `page.dart`) :
  - les bulles « i » ouvrent la fiche du lieu, du danger, de l'archétype ou de l'animal dans une fenêtre qui couvre presque tout l'écran ;
  - c'est le cas dans la Troupe (Préparer, l'échauffement, la mise en place, la régie, le débrief, la fiche d'un spectacle) et dans la préparation d'un épisode de série ;
  - la page ouverte en fenêtre (`EnFenetre`) a une croix à droite au lieu d'une flèche de retour ;
  - l'écran d'en dessous reste en place : le chrono de la régie continue.
  - Dans la Bibliothèque, les listes ouvrent toujours les fiches en pleine page : ce sont des lectures, pas des bulles d'info.
- **Changer d'archétype** :
  - le choix des douze archétypes, par famille, est partagé entre Préparer et l'échauffement (`choisirArchetype`) ;
  - à l'échauffement, chaque archétype a son bouton « ⇄ » à côté de la bulle « i » ;
  - l'animal repart à zéro ;
  - si la distribution n'est plus équilibrée (plus d'alarmiste, par exemple), un message le dit, sans bloquer.

### Un test instable corrigé

« Un spectacle de bout en bout » échouait environ une fois sur sept. Le groupe tiré d'office à la mise en place s'écrit aussi dans le champ texte. Quand le tirage tombait sur « une famille », le premier de la liste, le test trouvait ce texte deux fois. Il vise maintenant le bouton du groupe. L'appli n'était pas en cause.

### Tests

**313 tests passent**, trois fois de suite. Les nouveaux portent sur :
- la fiche en fenêtre, avec l'écran et le chrono qui restent dessous ;
- le changement d'archétype à l'échauffement ;
- le message quand la distribution n'est plus équilibrée.

## 2.0.3 : une musique par acte, une régie plus légère

### La demande

Sur deux captures (le dessous de la frise, puis la fenêtre de la régie son) : « Retire cette ligne, et un bouton pour retirer la régie. Fais que je puisse paramétrer chaque son à chaque acte, donc après chaque Destiny, dans les paramètres. »

### Ce qui a été fait

- **Une musique par acte** (`ReglagesDestiny.musiquesActes`, `musiqueActe`, `changerMusiqueActe`) :
  - acte 1 au début du chrono, puis l'acte n + 1 15 secondes après le n-ième Destiny, à la régie comme dans la Série ;
  - « Aucune » laisse jouer ce qui joue ;
  - les anciens réglages sont repris : le début devient l'acte 1, l'ambiance d'après le 2ᵉ Destiny l'acte 3, la fin l'acte 4 ; rien après le 1er Destiny, comme avant ;
  - les anciennes clés restent écrites, pour une version plus ancienne ;
  - dans les Réglages (Destiny, « Les musiques »), quatre lignes, une par acte.
- **La tablette son** : une tuile par acte (à défaut de réglage : le début, l'ambiance du lieu, puis la fin), l'ambiance du lieu, le son de Destiny, Stop et le mixeur.
- **Le bouton « Son » se retire** : un interrupteur dans les Réglages (`regieSon`). Éteint, le bouton disparaît du panneau du chrono, et DESTINY prend toute la largeur.
- **Le panneau du chrono** perd le compte à rebours, « dernier acte », « −1 min / +1 min » et la feuille « Régler les Destiny ». On fait glisser les Destiny sur la frise. Le code et les textes qui ne servaient plus sont retirés.
- **Le retard** : quand le chrono a passé l'heure du prochain Destiny sans qu'il soit lancé (déclenchement à la main), son heure passe en rouge sur la frise, et un lecteur d'écran l'annonce.

### Tests

**314 tests passent.** Les quatre tests des boutons « ±1 min » et de la feuille de réglage sont retirés : le glisser applique les mêmes règles, et ses tests les couvrent. Les nouveaux portent sur :
- la musique de chaque acte après chaque Destiny, avec « Aucune » ;
- la reprise des anciennes musiques ;
- les quatre lignes et l'interrupteur dans les Réglages ;
- la régie sans bouton « Son » ;
- l'heure en rouge quand le prochain Destiny est en retard.

## 2.1.0 : le jeu de rôle commence par le mode, adulte ou enfant

### La demande

Après la relecture des deux prompts mis à jour (refonte 2.0 et Série/kids) :
- les blessures façon PbtA restent ;
- les univers restent pour l'IA seulement ;
- et pour les enfants : « Faut pas l'interrupteur, faut un mode. Le mode théâtre, tu peux laisser tel quel ; tu mets pas le mode enfant dans le mode théâtre. Dans le mode jeu de rôle, tu fais deux modes : quand on commence, tu choisis le mode enfant ou le mode adulte, et après, en fonction, tu fais les trucs. »

### Ce qui a été fait

- **L'onglet Jouer** s'ouvre sur deux grandes cartes, **Adulte** et **Enfant (KIDS)**.
- **`JeuDeRoleScreen`** : le jeu de rôle dans un mode (`PublicSerie`, déjà le public des séries). Un bandeau (`BandeauMode`) rappelle le mode en haut de l'écran. On y trouve :
  - le nouvel épisode et la nouvelle saison ;
  - les séries récentes de ce mode, et « Mes séries », filtrées sur ce mode ;
  - l'histoire et le spectacle avec l'IA.
- **Le mode suit partout, sans être redemandé** :
  - `CreerSerieScreen` et `SeriesScreen` le reçoivent : plus de puces « Pour qui ? » ;
  - `ChatScreen(kids:)` cache le choix adulte/enfant et ne montre que les histoires du mode ;
  - `SpectacleScreen(kids:)` règle le spectacle sur le mode et cache son interrupteur.
  Appelés sans mode, ces deux écrans gardent leur choix d'avant.
- **Le théâtre se joue en adulte** :
  - Préparer n'a plus d'interrupteur kids, ni la mise en place de sigle ;
  - une ancienne session marquée kids repasse en adulte en s'ouvrant ;
  - le réglage « Public par défaut » est retiré, son champ est gardé.
- **Version 2.1.0** : elle reprend la 2.0.3 (une musique par acte, la régie plus légère), jamais publiée en APK.

### En attente

La nouvelle dramaturgie des prompts n'est pas encore faite : les liens dits avec le mot, l'acte 2 en ascenseur, l'acte 4 où le danger prend d'abord, les 9 règles d'or, « Répondre », le débrief et les paliers 4. Elle renvoie à un fichier de données plus récent (`liens`, `acte_2`, `acte_4`, `jeu_de_role`), qui n'a pas encore été fourni.

### Tests

**317 tests passent.** Les nouveaux portent sur :
- les deux cartes de Jouer, et l'IA qui suit le mode ;
- la création d'une série en mode enfant, sans le redemander, et la liste filtrée ;
- le théâtre sans interrupteur kids ;
- l'ancienne session kids qui repasse en adulte.


## 2.2.0 : la régie son du spectacle, une vraie table de régie

### La demande

Une conduite son automatique quand le pack audio du spectacle est là (`/Volumes/ShikaZero/Spectacle`) : une musique par lieu et par acte, le bruitage du danger au bon palier, enchaînés sur le son Destiny. Le pack n'est pas dans l'appli (180 Mo, et ça grossit) : on l'importe. Puis : « La régie, rends-la plus sexy, comme une vraie régie : un vrai pop-up avec une vraie table de régie, des boutons, des logos pour voir plus vite le son à mettre, rangés par catégorie. »

### Ce qui a été fait

- **Le manifeste** du pack (`assets/data/destiny_audio.json`) : familles, lieux, sons, dangers, REVEAL, remplacements. Ses ids sont ceux de l'appli (un test le vérifie).
- **La résolution**, en Dart pur (`lib/domain/son/`) :
  - une musique : le nom attendu cherché partout (comparé en NFC, les noms de macOS sont en NFD), puis le fichier du manifeste, puis la musique de la famille, sinon le silence ;
  - un bruitage : le fichier choisi, ou son remplaçant (MONITEUR → COEUR ; HELICO → rien).
  Dart n'a pas de normalisation Unicode : une table de recomposition, générée par Python, couvre les lettres latines accentuées.
- **`PackAudio`** : l'import (zip lu en flux, ou dossier), dans `destiny_pack/` du dossier documents, sans `Sonniss GDC 2026` ; le bilan ; sur le web, le pack est lu à côté de l'appli (`destiny_pack/index.json`), pour répéter dans un navigateur.
- **`ConduiteSon`** : cinq lecteurs (musique, Destiny, bruitage A, bruitage B, stinger), des fondus par pas de 50 ms, des séquences numérotées qu'on annule sans son orphelin (pause, sortie de la régie, son coupé).
- **La table de régie** (`lib/presentation/regie_son/`) : conduite, tranches, banques par catégorie. Elle remplace la tablette son ; sans régie son branchée, ses pads jouent comme l'ancienne tablette.
- **Les réglages** (`ReglagesRegieSon`, à part de ceux de Destiny) et deux écrans : le pack, la régie son (dont la banque de sons et le banc d'essai).

### Choix pris sans Marouane

- Le palier 4 s'appelle « Supprime » dans l'appli : la conduite ne regarde que le numéro du palier.
- Un manifeste importé avec le pack remplace celui de l'appli s'il est au moins aussi récent.
- Sur Android, un dossier partagé n'est pas toujours lisible : le .zip est conseillé à l'écran.
- La séquence Destiny part au tonnerre du rituel ; le son Destiny arrive après le fondu de sortie de la musique (2 s, réglable).


### La suite, après un essai dans le navigateur

- **3 joueurs au spectacle** : une composition à 3 dans la grammaire (l'alarmiste, un qui tient, un qui se fissure) ; les exemples tout prêts perdent leur archétype « interprète » en plus de l'alarmiste. Le jeu de rôle reste de 4 à 6.
- **Groupe et mystère retirés du spectacle** (mise en place, régie) ; leurs champs restent dans la session.
- **La régie** : « Pour la régie », le mystère et les moments forts retirés ; trois cadres (lieu et danger, paliers, archétypes).
- **La table de régie en pop-up**, avec un mini-chrono (`PiloteSpectacle`) : le temps, l'acte, pause et DESTINY, mis à jour chaque seconde.
- **La carte de l'acte** se ferme seule après 10 s sans action (`ReglagesRituel.fermetureAuto`) ; un toucher relance le compte.
- **La musique** : plus de boucle par défaut (nouvelle clé `boucle_v2`) ; atténuation progressive réglable (30 s, 50 % → 0 à la fin du morceau, durée lue dans le manifeste ou le lecteur) ; musique d'échauffement avec son minuteur. « Quand je lance le minuteur, la musique ne se lance pas » visait le minuteur d'échauffement, qui n'en avait pas.

### Le jeu et la régie en pop-up

- **Le fil des étapes** : Préparer, Jeu (l'ancien échauffement), Régie. Une session à la mise en place ou à la régie reprend au jeu.
- **`SpectacleEnCours`** : le chrono, les Destiny, le rituel et la conduite son sortent de la régie et vivent avec l'écran du jeu. La régie (`ouvrirRegieEnPopup`) ne fait que le montrer : la fermer n'arrête rien. Ouverte seule (tests), elle tient son propre spectacle.
- **Le jeu** : la barre du spectacle (chrono, acte, pause, DESTINY) et « Ouvrir la régie », la section des paliers du danger ; plus de flèche de retour (`PageDestiny.retour`), le retour du téléphone demande confirmation.
- **La grande croix** : `PageDestiny.fermer`, un bouton « Fermer » en or, à la place de la flèche.
- **Terminer** : la session passe à « terminée » et l'on revient à l'accueil ; le débrief n'est plus proposé (l'écran reste pour les anciennes sessions).

### La régie, c'est la table

- **« Régie » ouvre directement la table de régie** (son mini-chrono a DESTINY) : l'ancienne régie en pop-up faisait doublon avec le jeu. « Terminer » (sans « et débriefer ») et le dilemme de l'acte 4 passent sur le jeu. L'écran `RegieScreen` reste, mais l'appli ne l'ouvre plus.
- **L'ouverture** : la musique de l'acte 1 d'abord (son d'ouverture « aucun » par défaut, nouvelle clé `son_ouverture_v2`) ; le bruitage du palier part à la fin **naturelle** de la musique (`bruitageFinMusique`, acte 1 par défaut). Toute intervention de la régie sur la musique (Destiny, Stop, autre pad) l'annule.
- **Texte très agrandi** : trois lignes de la table débordaient (titres de section, paliers de « Ce danger », étape en cours) ; leur texte se replie maintenant.

### L'ouverture, puis l'ambiance ; la table réordonnée

- Après la musique d'un acte (et son bruitage), l'ambiance du lieu (`assets/audio/ambiences/<lieu>.m4a`, une par lieu du manifeste) tourne en fond, à 15 %, sans atténuation progressive (`ambianceApresMusique`, `volumeAmbiance`).
- La musique de l'échauffement passe à « aucune » par défaut (clé `musique_echauffement_v2`) : le début de l'histoire, c'est la musique de l'acte 1.
- La table : conduite, banques (onglets sur plusieurs lignes, Émotions juste après Ce danger), puis le mixeur (ex-« Tranches »).

### Le minuteur lance l'histoire ; deux banques ; une courbe par acte

- **Le minuteur du jeu** lance l'ouverture (musique de l'acte 1, puis bruitage, puis ambiance) ; la conduite retient qu'elle est ouverte (`ConduiteSon.ouverte`), le chrono du spectacle ne la rejoue pas, et la pause du minuteur ne coupe pas la musique de l'histoire.
- **Deux banques** seulement : *Ce danger* et *Émotions* (les autres étaient de trop). Les catégories restent pour la couleur et l'icône des sons du danger.
- **La courbe de volume par acte** remplace l'atténuation progressive globale : `courbes` (repères temps → volume) et `finAZero` (0 % à la fin du morceau, durée du manifeste ou du lecteur) ; le volume suit les repères en ligne droite, par pas de 250 ms. Le silence avant la musique est retiré de la séquence Destiny.

### Tests

**342 tests passent.** Les nouveaux portent sur la résolution (propre, famille, NFD, absent), les bruitages (vide, remplacement, « Autre »), l'import, le bilan du vrai pack, les séquences avec un faux lecteur (ordre, annulation, son coupé) et la table dans la régie. Les 7 tests de rendu des cartes échouaient déjà avant (images de référence d'une autre machine).

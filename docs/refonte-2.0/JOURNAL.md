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

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

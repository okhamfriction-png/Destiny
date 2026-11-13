# DestinyStory — Les fonctionnalités

> Application Flutter (Android, iOS, web) pour l'**improvisation dramatique**, avec la grammaire de Destiny.
> Tout fonctionne **hors ligne**, à partir des fichiers de l'appli et d'une base locale. Seuls les modes « avec l'IA » demandent une clé d'API.
>
> Version documentée : **2.3.0** — voir le [CHANGELOG](../CHANGELOG.md).

## Aperçu

| Découvrir Destiny | Le danger et le rituel | Troupe |
|:---:|:---:|:---:|
| ![Découvrir Destiny](store_assets/screens_2_0/01_decouvrir.png) | ![Le danger et le rituel](store_assets/screens_2_0/02_danger_et_rituel.png) | ![Troupe](store_assets/screens_2_0/03_troupe.png) |
| **Exercices : Destiny** | **Bibliothèque** | |
| ![Exercices](store_assets/screens_2_0/04_exercices_destiny.png) | ![Bibliothèque](store_assets/screens_2_0/05_bibliotheque.png) | |

> *Captures de la version web 2.0.0, en thème sombre.*

---

## 1. Vue d'ensemble

**La promesse : rien n'est écrit.** Un lieu, un groupe qui se connaît, un danger qui monte en quatre paliers (porté par la régie : musiques et bruitages), et Destiny entre les actes. Au spectacle, **quatre comédiens et un figurant**. Chaque personnage a un **archétype** (sa conviction face au danger : acte par acte, il est **tenté de**…), un **animal** (son vêtement et son statut de départ), un **vouloir** (ici, ce soir, qui dépend de l'autre) et un **besoin**. À l'acte 4, il paie le prix : il choisit entre son vouloir et son besoin. Les cartes donnent des directions, pas des prisons.

Trois onglets en bas de l'écran :

| Onglet | Pour quoi faire |
|---|---|
| **Jouer** | Le jeu de rôle entre humains (épisode, saison, série), ou une partie avec l'IA. |
| **Troupe** | Préparer, jouer et débriefer un spectacle ou une répétition. L'appli s'ouvre ici. |
| **Exercices** | Des échauffements et des jeux de théâtre, chronométrés. |

En haut à droite : la **Bibliothèque**, la **Musique**, les **Réglages** et le **son**.

**Le design** suit la direction artistique de la grammaire : la nuit et l'or, Cinzel pour les titres, Montserrat pour le texte. Trois couleurs pour les trois familles (vert : elles tiennent le groupe ; bleu : elles interprètent le danger ; rouge : elles fissurent le groupe), le bleu Destiny pour le rituel, et le sigle jaune **KIDS** sur tout ce qui se joue avec des enfants. Thème **sombre**, **clair**, ou celui du téléphone.

---

## 2. Découvrir Destiny et les tutos

Au premier lancement (et une fois après la 2.3.0), cinq écrans simples, **sur la Troupe seulement**, tous tirés de la grammaire :
1. la promesse : quatre comédiens et un figurant, un lieu, un danger en quatre actes ;
2. Préparer : le lieu et le danger donnés par le public, les archétypes attribués à l'avance, le chrono ;
3. le jeu : l'échauffement qui lance la musique de l'acte 1, les quatre paliers, le rituel Destiny et la suite de la régie son ;
4. la régie : la table de régie, DESTINY, Terminer ; le danger vient de la régie ;
5. les personnages : les trois familles, le vouloir et le besoin, des directions pas des prisons.

On peut les passer, et les revoir depuis la Bibliothèque ou les Réglages. **Le jeu de rôle a son propre tuto**, à la première visite (un épisode comme un spectacle, le cœur et le cerveau, le grand méchant, le compte rendu de l'IA), que le bouton « ? » rouvre. Les exercices n'en ont pas.

---

## 3. Troupe : le spectacle

L'accueil montre la promesse et, tirée au hasard à chaque ouverture, une règle d'or ou la réplique du jour. Puis :

1. **Préparer** : spectacle ou répétition, 3, 4, 5 ou 6 joueurs.
   - La distribution se fait par choix concerté, tirage équilibré ou exemple tout prêt.
   - Chaque famille est représentée ; on choisit des archétypes qui s'opposent dans leur réflexe. L'alarmiste est facultatif au spectacle (le danger vient de la régie). Une distribution déséquilibrée est signalée, avec une phrase qui dit pourquoi et une correction en un geste.
   - Chaque joueur choisit son animal parmi les deux de son archétype. Sous les deux animaux, en italique, un **exemple de vouloir** dans la manière de l'animal choisi (« Exemple de vouloir : « Je veux qu'il me rende les 300 euros qu'il me doit. » » pour le Rat) : un exemple à adapter au lieu et au partenaire, jamais une consigne. Il change avec l'animal ; en mode kids, c'est l'exemple des enfants.
2. **Le jeu** (l'écran qui porte le spectacle, sans flèche de retour) : le chrono et DESTINY, les paliers du danger, la carte de chaque joueur, les trois questions (« Comment je me tiens ? »…), la limite (« le corps, pas l'histoire ») et un minuteur, qui lance l'histoire : la musique de l'acte 1.
3. **Avant d'entrer en scène** : les règles d'or, les quatre paliers et la phrase des débriefs. Aucune critique.
4. **La régie** : la table de régie, en pop-up par-dessus le jeu (sa croix ramène au jeu, le spectacle continue). Le jeu montre aussi :
   - un gros chrono et l'acte en cours, puis trois cadres : le lieu et le danger, les paliers du danger, les archétypes à ce palier ;
   - le **bouton Destiny**, réservé à la régie. Il se déclenche aussi tout seul aux minutes prévues, selon le réglage ;
   - le rituel en plein écran : le tonnerre, le rire du destin, la lumière bleue, le ralenti (on ne se fige plus : on joue au ralenti en glissant vers son archétype, avec la question de l'acte : qui je suis, ce que je risque de perdre, ce que je suis prêt à sacrifier), l'ellipse ; puis la nouvelle du palier (à faire entendre par la régie son, ou à souffler au figurant), qui se ferme seule après 10 secondes sans action ;
   - au premier figé, le rappel de fixer le besoin ;
   - pour chaque joueur, ce que fait son archétype et le corps de son animal à ce palier ;
   - à l'acte 4, le dilemme du danger ;
   - la **table de régie**, en pop-up avec le chrono et DESTINY : la conduite du spectacle, les banques de sons et le mixeur. La **conduite son** a deux enchaînements, au choix dans la régie son :
     - **fluide** (par défaut) : un seul bouton, « Destiny ». Le son Destiny part tout de suite et la musique d'avant sort dessous en 2 s ; la musique du nouvel acte monte pendant les 10 dernières secondes du Destiny et arrive à son maximum quand le rire se termine, avec le bruitage du nouveau palier (et le REVEAL à l'acte 3) ; jeu muet 15 s au maximum, puis la musique redescend en 3 s à son niveau de fond et tourne en boucle jusqu'au Destiny suivant. À l'ouverture, la musique de l'acte 1 part à son maximum, 30 s, puis redescend. Un repère en grand dit où l'on en est, avec le temps qui reste : « Destiny — ralenti », « Musique — jeu muet », « Fond — on parle » ;
     - **classique** : le son Destiny, la musique de l'acte, puis à sa fin le bruitage du danger au palier de l'acte, puis l'ambiance du lieu à 15 % jusqu'au Destiny suivant. Avec le pack audio importé, chaque lieu a ses musiques et chaque danger ses bruitages ; sans pack, ce sont les musiques choisies dans les réglages et l'ambiance du lieu, sans bruitage. Un seul pad s'allume : ce qui joue.
5. **Terminer**, en bas du jeu : le spectacle est rangé dans l'historique, et l'on revient à l'accueil.
6. **L'historique** des spectacles et des répétitions, chacun exportable en **PDF**.

---

## 4. Jouer entre humains : la Série

- **L'épisode** : un lieu, un groupe, un danger en quatre paliers, quatre actes. Il se suffit à lui-même. **« Faire la suite »** en fait le premier épisode d'une saison.
- **La saison** : quatre épisodes et un **méchant** qui agit dans l'ombre. Chaque danger est l'un de ses coups ; on voit d'abord ses **deux sbires** ; il n'apparaît qu'à l'épisode 4, et on le vainc par sa **faille**. Le besoin du personnage appartient à la saison : fixé à l'épisode 1, nommé à l'épisode 3, payé au final.
- **La série** enchaîne les saisons. Entre deux saisons, un personnage qui a payé son besoin peut changer d'archétype.
- **21 univers** (12 pour adultes, 10 pour enfants, Super-héros est des deux) avec leurs lores, leurs peuples, leurs lieux, leurs **figurants** (trois par lieu), leurs **dangers** (trois par univers) et leurs **méchants**.
- **Les figurants et les sbires** : deux modes distincts. Un figurant peut basculer en sbire, et c'est noté au registre.
- **Le registre** garde les figurants, les sbires, les lieux, les secrets, les promesses, les morts (adultes seulement), le traître et ce que le méchant a laissé. Au début d'un épisode, l'IA peut proposer deux ou trois éléments à ressortir. Il ne contient **jamais les prénoms des joueurs**, seulement les personnages. Il s'exporte en PDF.
- **Aussi simple que le théâtre** (depuis la 2.2.0) : Préparer, le Jeu, la Régie, la même table de régie et la même conduite son. Chaque personnage a deux pistes : le **cœur** (en forme, blessé, mort) et le **cerveau** (lucide, ébranlé, au bord de la folie, fou). Plus de traître, de pièce du destin ni de cases de blessure.
- **Le compte rendu de l'IA** à la fin de chaque épisode, depuis la transcription ou la trame de l'épisode et les notes du maître du jeu.
- **La transcription** (facultative) : la reconnaissance vocale du téléphone écrit la scène pour aider au résumé ; l'appli ne garde aucun son, et l'on voit ce qui part avant tout envoi à l'IA.

### Le mode kids

Le jeu de rôle commence par le choix du mode, **adulte** ou **enfant** : tout le reste suit (les séries, les lieux, les dangers, les méchants, les règles et l'IA). Le théâtre se joue toujours en adulte.

- Seuls les éléments marqués **KIDS** sont proposés : lieux, dangers, méchants, sbires.
- Chaque enfant choisit **un pouvoir**, gardé toute la saison. Il aide, il ne résout jamais tout seul.
- **Personne ne meurt** : au palier 4, on renonce à quelque chose, ou on se sépare un moment.
- Le parent tient le destin : il lance le danger, fait les présages, joue les sbires et les figurants.

---

## 5. Jouer avec l'IA

Facultatif : il faut une clé d'API (Anthropic, OpenAI ou Google), à régler dans **Réglages › IA**. Les prompts sont réunis dans `lib/application/prompts/`, versionnés et testés ; chacun contient la grammaire en version courte, générée depuis le fichier.

- **L'histoire avec l'IA** : on choisit son archétype, son animal, et si on veut une blessure et un vouloir. L'IA joue les autres, avec une distribution équilibrée. Quatre chapitres, un par palier ; **Destiny tombe entre deux chapitres**. La **pièce du destin** tranche chaque action. Au dernier chapitre, on choisit : le vouloir ou le besoin. Le résumé suit le coach de débrief.
- **Le spectacle avec l'IA** : quatre personnages tirés en distribution équilibrée, quatre actes, Destiny avec un bouton, et un **débrief positif** : l'histoire, ton personnage, la phrase clé, ce qui a marché, une piste pour la prochaine fois. Les règles du sparring : l'IA ne coupe jamais l'acte, relève aussi les fautes d'impro avec un conseil concret, accepte les perches, ne narre pas le danger ; l'acte 1 reste léger, la sidération de l'acte 3 est un temps.
- Les univers viennent de `univers.json`. Chaque mode a sa version **enfant** : des frissons doux, jamais d'effroi.
- Modèles Claude proposés : Opus 5.5 (par défaut), Sonnet 5.5, Haiku 5.5, Fable 5.1, et les précédents.

---

## 6. Exercices

- **Les thèmes du carnet** : Échauffement, Statut, Spontanéité, Écoute, Dialogue, Imagination, avec **le principe du jour**.
- **Les 21 exercices de la grammaire** (dont « La scène 1 en duo » et « Le test du mobil-home »), en trois thèmes, chacun ouvert par son principe :
  - **CROW** (qui, avec qui, pour quoi, où) ;
  - **Lieu** (un seul lieu, bien installé) ;
  - **Destiny** (le danger, les archétypes, le prix à payer).

  Chaque fiche donne le but, les consignes, des exemples, la question du débrief, la variante et la source, avec le badge **« Avec Mark Jane »**. Elle propose un chrono réglé sur la durée conseillée, des **cartes à tirer** au hasard, et un lien vers la notion dans la Bibliothèque.
- **Solo** : 50 virelangues, avec un tirage au hasard.
- Chaque exercice se joue au **chrono**, avec une célébration à la fin. Sans score.

---

## 7. La Bibliothèque

- **Découvrir Destiny** (les quatre écrans du début).
- **Le livret de règles** : le but, le matériel, les rôles (quatre comédiens, le figurant, la régie), la mise en place (ce que donne le public), le déroulé (les actes, le rituel et la suite de la régie son, chaque acte reprend le précédent, planter pour payer), la fin, les variantes (Série, méchants, sbires, figurants, registre, mode kids) et les dix règles d'or. Chaque règle vient de la grammaire. La mise en place a une partie **« Trouver son vouloir »** : la formule, les trois tests, ce qui ne marche pas, pourquoi c'est important, la manière que donne le vêtement, et le tableau des 24 exemples. Une **version enfants** (le bouton en haut) donne la formule « aujourd'hui » et les exemples des enfants. **Export PDF**, dans les deux versions.
- **Les archétypes** : « des directions, pas des prisons ». Les 12, rangés en trois familles, avec ce qu'ils sont tentés de faire acte par acte, leurs deux animaux, leurs modèles dans les œuvres et leurs méchants reflets. **Cartes à imprimer en PDF** : un recto par archétype (12 cartes) ou par animal (24 cartes), un verso Destiny, neuf cartes de 63 × 88 mm par page.
- **Les animaux** : les 24, avec leur port, leur posture, leur statut de départ, leur réplique (et sa version kids) et leur corps à chaque palier.
- **Vouloir et besoin** : les trois tests d'un bon vouloir (ici, ce soir ; il dépend de l'autre ; le danger peut l'empêcher), le piège (« un besoin n'est jamais un objet »), planter pour payer, le vouloir avoué (Succession), les six couches du personnage et la phrase clé ; et **« Trouver son vouloir »** (la formule, les trois tests, ce qui ne marche pas, pourquoi, le vêtement qui donne la manière, et un exemple par animal). La page Animaux et chaque fiche d'animal montrent aussi son exemple de vouloir.
- **Les dangers** et **les lieux**, avec leurs paliers, leurs espaces, leurs rôles et leurs figurants.
- **Les œuvres** : des séries, des pièces et des films lus avec la grammaire.
- **Les méchants** : les 24 grands méchants et ceux des 21 univers, avec leurs sbires et leurs présages.
- **Les figurants** (dont le figurant du spectacle), **le mode kids**, **les outils de jeu** (ceux de Mark Jane, puis ceux des séances de novembre : accepter les perches, planter pour payer) et **les mots de Destiny** (ce qu'on dit, et ce qu'on ne dit plus).

---

## 8. Musique et régie son

- **La Musique** : les pistes classées par catégorie (Émotions, Lieux, Ambiances, Thèmes, Univers), avec un lecteur. La catégorie **Spectacle** donne, pour chacun des 40 lieux, ses musiques des actes 1 à 4 et son ambiance ; une icône par musique (même icône, même musique : 21 musiques pour 40 lieux), et à l'écoute les actes s'enchaînent, puis le lieu suivant.
- **La régie son du spectacle** (Réglages) : l'enchaînement fluide ou classique et tous ses temps (montée pendant le Destiny, maximum après le Destiny et à l'ouverture, descente, niveau de fond par acte, décalage du bruitage, atténuation sous le bruitage, sortie de la musique d'avant), la musique de chaque acte, le son Destiny, le bruitage du danger, le REVEAL, la banque de sons et un banc d'essai qui rejoue l'ouverture et les trois Destiny.
- **La régie son** : un mixeur accessible pendant le jeu, avec la lecture en boucle et le volume.
- **Chaque acte a sa musique**, dans les Réglages : celle de l'acte 1 part au début du chrono, puis celle de l'acte suivant 15 secondes après chaque Destiny. S'y ajoutent le son de Destiny et, si on veut, une musique importée à chaque Destiny. On peut importer ses propres musiques, et retirer le bouton « Son » de la régie.

---

## 9. Réglages

- **Destiny** : les chronos (durée et minute de chaque Destiny, retour aux valeurs par défaut), le déclenchement (automatique, manuel ou les deux), le rituel (lumière bleue, durée du figé, texte de l'ellipse, rappels), les musiques, la distribution par défaut, le jeu de rôle (traître, registre, combat, pièce, évolution d'archétype), l'échauffement, les cartes.
- **IA** : le fournisseur, le modèle et la clé.
- **Apparence** : le thème (sombre, clair, comme le téléphone), les visuels des cartes, la taille et l'écriture manuscrite du texte de l'histoire.
- **Données** : les lieux et les dangers (espaces, rôles, quatre paliers nommés comme dans la grammaire, palier 4 en version kids, sigle KIDS), les détails des lieux, l'antisèche des relations, les **dilemmes de l'acte 4**, et le rapport de synchronisation avec la grammaire.
- **Mode admin** : la vérification de la grammaire, la lecture des archétypes, et l'éditeur des **exemples de vouloir** (adulte et enfants, pour chaque animal ; un champ vidé reprend le texte de la grammaire).
- **Aide** : Découvrir Destiny, Me contacter, Crédits (dont les licences des polices), À propos.

---

## 10. Accessibilité

- L'appli suit la **taille de texte du téléphone** ; les écrans principaux sont testés avec des caractères 60 % plus grands, sur un téléphone de 390 px de large.
- Chaque bouton a un **nom lu par les lecteurs d'écran**.
- Les couleurs du texte ont un **contraste d'au moins 4,5** en clair comme en sombre.
- **« Réduire les animations »** calme le rituel (le réglage du téléphone est aussi suivi).
- L'écran reste allumé pendant le jeu.

---

## 11. Confidentialité et données

- **Hors ligne** par défaut. La régie, le rituel et la Série ne dépendent jamais du réseau.
- Seuls les modes IA envoient du texte, avec la clé de l'utilisateur, au fournisseur choisi (Anthropic, OpenAI ou Google). En troupe et en Série, les prénoms des comédiens ne partent pas ; le registre ne garde que des personnages. Dans l'histoire avec l'IA, seul le nom donné au héros part.
- La transcription passe par la reconnaissance vocale du système (Google ou Apple) ; l'appli ne garde aucun son, seulement le texte, sur l'appareil.
- **Rien n'est perdu à la mise à jour** : les anciennes campagnes deviennent des séries, les anciennes histoires se relisent, les lieux et dangers modifiés sont gardés, une sauvegarde illisible n'est jamais écrasée.
- Politique de confidentialité : [`privacy.html`](privacy.html).

---

## 12. Build et publication

- **Android** : `flutter build appbundle --release` (Google Play) ou `flutter build apk --release`.
- **Web** : `flutter build web --release --base-href /Destiny/app/`, copié dans `docs/app` (GitHub Pages).
- **CI/CD** : [`cicd_setup.md`](cicd_setup.md). **Fiche Play Store** : [`play_store_listing.md`](play_store_listing.md).

# Décisions de la refonte 2.0

Tes réponses du 2 novembre 2026, notées telles que je les ai comprises. Elles priment sur les deux versions du cahier des charges. Pour tout ce qui n'est pas tranché ici, j'applique les propositions de l'audit (`ETAPE-0-audit-et-plan.md`).

## Navigation

- **Trois onglets** : **Jouer**, **Troupe**, **Exercices**.
- L'appli **s'ouvre sur Troupe**.
- **Bibliothèque** et **Réglages** deviennent de petits boutons en haut de l'écran.
- L'onglet Musique disparaît. Les musiques restent accessibles par la **régie son**, gardée telle quelle et disponible partout où l'on joue.

## Jouer

On y entre par deux portes, comme aux échecs ou dans FIFA (avec ses potes, ou contre l'ordinateur) :

1. **Entre humains** : un maître du jeu humain, aidé par l'appli (chrono, musiques, régie, fiches).
   - **Histoire** : un one shot, une histoire complète en 4 actes.
   - **Saison** : quand on appuie sur « Faire la suite », l'histoire devient une saison. Les épisodes sont rangés ensemble.
   - **Campagne** : une saison avec un grand danger qui revient d'épisode en épisode.
2. **Avec l'IA** : l'IA mène le jeu. Le Spectacle IA, qui servait à créer une histoire avec l'IA, passe ici.

Tout doit rester clair pour le maître du jeu, avec la musique et la régie son.

## Chronos

Trois chronos de base, modifiables dans les Réglages et gardés tant qu'on ne les change pas :

| Chrono | Destiny 1 | Destiny 2 | Destiny 3 |
|---|---|---|---|
| 20 min | 8 min | 15 min | 18 min |
| 30 min | 10 min | 18 min | 27 min |
| 45 min | 10 min | 25 min | 40 min |

## Musiques

Les quatre moments sont paramétrables dans les Réglages et **gardés jusqu'à ce qu'on les change** :
1. la musique du début ;
2. le son de chaque Destiny ;
3. l'ambiance après le 2ᵉ Destiny ;
4. la musique de fin.

Une musique importée reste possible à chaque Destiny.

**Le rire du destin** : il est déjà dans le son Destiny (`DestinyStorm`). Aucun nouveau fichier.

## Données

- **Le fichier de grammaire fait foi.** On met tout à jour avec ses données, à chaque nouvelle version du fichier :
  - les phrases courtes des paliers ;
  - les 4 espaces de chaque lieu, affichés en premier ; les 8 sous-espaces actuels restent dessous comme réserve d'idées.
- Ce que tu as modifié toi-même dans l'appli n'est jamais écrasé.
- Les identifiants techniques des dangers et des lieux restent ceux de l'appli. Ils ne s'affichent jamais, et ils relient les images, les ambiances sonores et la mémoire des tirages. Le rapprochement avec le fichier se fait par le nom.

## Animaux

- **Les 24 animaux, partout** : spectacle, jeu de rôle, mode enfant.
- La tortue, le dauphin, l'éléphant et la pie (anciens animaux de la Campagne) ne sont plus utilisés.

## Le traître

- Il **n'existe pas** dans la grammaire.
- Dans le jeu de rôle, c'est une **option facultative**, désactivée par défaut, réglable dans les Réglages ou au moment de préparer la partie : « Ajouter un personnage avec l'étiquette traître, au hasard : oui ou non ».

## Exercices

On **garde** tous les exercices actuels et on **ajoute** les 20 nouveaux (CROW, Lieu, Destiny). Un ancien exercice ne serait remplacé que s'il contredisait la nouvelle grammaire, ce qui ne devrait pas arriver.

## Ce qui est retiré

- **Le dé**, sous toutes ses formes de spectacle : le dé DESTINY, ses poids, ses faces, ses cartes, son affichage, le dé 3D.
- **Les modes Rue et Spin-off** du Générateur, et le Spin-off du Spectacle IA.
- **Le Générateur** sous sa forme actuelle : le tirage passe dans Troupe et dans Jouer.
- **Tout le code inutile**, et les tests qui ne servent plus. On repart sur une base propre.

Les **données** que tu as déjà enregistrées (anciennes histoires, parties, tirages) ne sont pas effacées. Elles restent lisibles, marquées « ancienne grammaire ».

## Ce que je garde du jeu de rôle (outils du maître du jeu)

- Le combat (cœurs), les malus et bonus.
- La **pièce du destin** BRAVE / SMART. C'est une pièce, pas un dé.
- La réussite ou l'échec d'une action dans le jeu avec l'IA est tirée avec cette même pièce. Le mot « dé » disparaît.

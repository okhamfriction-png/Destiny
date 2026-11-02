# Addendum : deux versions du cahier des charges

Tu m'as envoyé deux versions du cahier des charges :
- **V1**, la première : « version actuelle 1.5.7+19 », avec l'inventaire exhaustif (0 bis), les réglages (2.12), le livret de règles (2.13) et 20 exercices en trois thèmes. C'est sur elle que repose l'audit (`ETAPE-0-audit-et-plan.md`).
- **V2**, la seconde : « version actuelle 1.5.0 ». Elle est plus courte.

L'audit de l'étape 0 reste valable pour les deux : il a été fait sur le code, qui ne change pas. Cette page liste seulement ce qui diffère et ce que ça change au plan. **Il me faut savoir quelle version fait foi (D27).**

## Ce qui est identique

- Toute la grammaire (§ 1), à un détail près : la V2 n'a pas le module traître (voir plus bas).
- La DA, l'accueil, la Bibliothèque, le mode Troupe, les rôles de l'IA, le générateur, les textes, les exports, le mode public et le hors ligne (§ 2.1 à 2.4, 2.6, 2.8 à 2.11).
- Le modèle de données et la migration des campagnes (§ 3.1 à 3.3).
- Les phases et les critères d'acceptation.
- **Les 11 exercices de la V2 sont tous dans les 20 du fichier de grammaire**, avec les mêmes consignes.

## Ce qui diffère

| Sujet | V1 | V2 | Ce que ça change |
|---|---|---|---|
| **Navigation** | Garder les 4 onglets (Générateur → Troupe, Musique, Histoire, Scène) + Bibliothèque dans l'en-tête | Jouer, Troupe, Bibliothèque, Exercices, Réglages | Voir D28 ci-dessous |
| **Dangers et lieux** | Le catalogue de l'appli reste la référence (plus riche, modifiable) ; la grammaire en est une copie à comparer | La grammaire est la source pour tout, dangers et lieux compris | Change D1 à D3 (annexe A). Avec la V2, les textes de la grammaire remplacent ceux du catalogue, **sauf ceux que tu as modifiés dans l'appli** : je ne les écrase dans aucun cas |
| **Traître** | Module facultatif du jeu, désactivé par défaut | Disparaît complètement | Avec la V2 : pas de module, pas de réglage |
| **Exercices** | Trois onglets de plus (CROW, Lieu, Destiny), sans toucher aux thèmes existants | « Remplace ou enrichis » | Je recommande d'enrichir dans tous les cas : les 32 exercices actuels et les virelangues sont gardés |
| **Réglages (2.12)**, **livret de règles (2.13)**, **3 règles de campagne**, **Rue et Spin-off**, **cartes Destin**, **catalogue et mémoire (3.4, 3.5)**, **inventaire exhaustif (0 bis)** | Présents | Absents | Absents ne veut pas dire refusés. Je les garde, sauf avis contraire |
| Chemin du fichier | `assets/data/` (« par exemple ») | `assets/grammar/` (« par exemple ») | Aucun impact. Je le range où tu préfères |
| Version | 2.0.0+20 | 2.0.0 | Même chose : le Play Store exige un numéro de build supérieur à 19, donc ce sera 2.0.0+20 |

## D27 — Quelle version fait foi ?

Je recommande **la V1, en y reprenant de la V2 la navigation si tu la préfères (D28)**. La V1 est la plus complète. Elle connaît l'état réel du dépôt (1.5.7+19) et protège mieux tes modifications du catalogue.

## D28 — Navigation, si tu choisis celle de la V2

| Onglet (V2) | Contenu |
|---|---|
| **Jouer** | Accueil (règle ou réplique du jour), Histoire avec l'IA, Campagnes, Spectacle IA en solo, Tirage rapide (générateur), formats courts |
| **Troupe** | Préparer, échauffement, avant d'entrer, régie et bouton Destiny, débrief, historique |
| **Bibliothèque** | Archétypes, animaux, dangers, lieux, œuvres, vouloir et besoin, livret, outils de jeu, lexique |
| **Exercices** | Les 6 thèmes actuels, Solo, et CROW, Lieu, Destiny |
| **Réglages** | Section Destiny, Apparence, Catalogue, IA, Données, À propos |

**L'onglet Musique disparaît** dans cette version. Les morceaux restent accessibles par la régie son (bouton présent dans Troupe, Jouer et les campagnes), qui contient déjà toutes les pistes. Si tu tiens à un onglet Musique, il faut renoncer à l'un des cinq, ou passer Réglages dans l'en-tête comme aujourd'hui.

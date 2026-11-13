# DestinyStory

Application Flutter (Android, iOS, web) pour l'**improvisation dramatique** avec la grammaire de Destiny : un lieu, un groupe qui se connaît, un danger qui monte en quatre paliers, et Destiny entre les actes. **Rien n'est écrit.**

Tout fonctionne **hors ligne**. Seuls les modes « avec l'IA » demandent une clé d'API (Anthropic, OpenAI ou Google), celle de l'utilisateur.

> 📖 Les fonctionnalités en détail : [`docs/FEATURES.md`](https://github.com/okhamfriction-png/Destiny/blob/claude/regie-son-spectacle/docs/FEATURES.md) · Les nouveautés : [`CHANGELOG.md`](https://github.com/okhamfriction-png/Destiny/blob/claude/regie-son-spectacle/CHANGELOG.md)

## Installer l'appli

DestinyStory est une appli personnelle : elle n'est ni sur l'App Store, ni en accès public sur le Play Store. Voici comment l'installer.

### Sur Android : l'APK

1. Sur le téléphone ou la tablette, ouvrir la page de la dernière version : **https://github.com/okhamfriction-png/Destiny/releases/latest**
2. Dans « Assets », toucher **`DestinyStory-vX.Y.Z.apk`** pour le télécharger. Il pèse environ 560 Mo, car les musiques et les bruitages du spectacle sont dedans : passer en Wi-Fi.
3. Ouvrir le fichier téléchargé, depuis la notification ou l'appli Fichiers. La première fois, Android demande d'**autoriser l'installation depuis cette source** (Chrome ou Fichiers) : Paramètres → autoriser → revenir en arrière.
4. Toucher **Installer**, puis **Ouvrir**.

**Mettre à jour** : refaire les mêmes étapes avec le nouvel APK. Il s'installe par-dessus l'ancien, et l'historique et les réglages sont gardés.

> Si l'appli a été installée par le **Play Store** (test fermé, réservé aux testeurs invités), il faut la mettre à jour par le Play Store. Android refuse l'APK de GitHub par-dessus, parce que le Play Store signe l'appli avec une autre clé. Pour passer de l'un à l'autre, il faut désinstaller l'appli, ce qui efface ses données.

### Sur iPhone et iPad : l'appli web

Il n'y a pas d'appli iOS à installer : il faudrait un compte développeur Apple et Xcode pour la signer. La même appli tourne dans Safari, sur l'écran d'accueil comme une vraie appli.

1. Ouvrir **https://okhamfriction-png.github.io/Destiny/app/** dans **Safari** (pas Chrome, qui ne sait pas l'ajouter à l'écran d'accueil sur iPhone).
2. Toucher le bouton **Partager** (le carré avec la flèche), puis **Sur l'écran d'accueil**, puis **Ajouter**.
3. Lancer DestinyStory depuis son icône : elle s'ouvre en plein écran, sans la barre de Safari.

**Mettre à jour** : rien à faire. La nouvelle version se charge toute seule à l'ouverture. Si l'ancienne s'affiche encore, fermer l'appli (balayer vers le haut) et la rouvrir.

> L'appli web a besoin d'Internet : les musiques se chargent quand on les joue. Les données (historique, réglages) restent dans le téléphone, liées à cette icône. Supprimer l'icône ou effacer les données de Safari les efface aussi.

L'appli web marche aussi sur un ordinateur, dans n'importe quel navigateur, à la même adresse.

## Lancer le projet

1. Installer Flutter **3.41.9** (la version de `pubspec.lock`).
2. Dans le dossier du projet :
   - `flutter pub get`
   - `flutter run`
   - `flutter test` (les tests vérifient aussi les écrans à 390 px de large).

> Sur desktop, SQLite passe par `sqflite_common_ffi`. Sur iOS et macOS, lancer `pod install` au premier build.

## En bref

- **Troupe** : préparer un spectacle ou une répétition, l'échauffement, la mise en place, la régie avec le bouton Destiny, le débrief et l'historique (PDF).
- **Jouer** : entre humains (épisode, saison, série, avec méchants, sbires, figurants et registre ; mode kids), ou avec l'IA (une histoire, ou un spectacle).
- **Exercices** : les thèmes du carnet, les 20 exercices de la grammaire (CROW, Lieu, Destiny) et les virelangues.
- **Bibliothèque** : Découvrir Destiny, le livret de règles (PDF), les archétypes et leurs animaux (cartes à imprimer), les dangers, les lieux, les œuvres, les méchants, les figurants, le mode kids, les outils de jeu et le lexique.
- **Réglages** : les chronos et le rituel, les musiques, la distribution, le jeu de rôle, l'apparence (thème clair ou sombre), l'IA et les éditeurs.

## La grammaire, source unique

- `assets/data/destiny_grammaire.json` (v2.1) contient toute la grammaire : familles, archétypes, animaux, paliers, actes, rituel, distribution, personnage, dangers, lieux, œuvres, Série, méchants, figurants, mode kids, exercices.
- `assets/data/destiny_textes.json` contient tous les textes de l'interface. Aucun texte de la grammaire n'est écrit dans le code ; un test vérifie que chaque clé utilisée existe.
- `assets/data/univers.json`, `campagne_lieux.json` et `campagne_mechants.json` décrivent les univers du jeu de rôle.

## Architecture

- `lib/domain` : la grammaire (`grammaire/`), la Série (`serie/`), la Troupe (`troupe/`), les entités du catalogue.
- `lib/application` : l'état (réglages, séries, troupe, IA), les prompts versionnés (`prompts/`), le livret, les exports PDF, l'audio.
- `lib/infrastructure` : la lecture des fichiers, le catalogue SQLite, les sauvegardes.
- `lib/presentation` : le design system (`destiny/`, `theme/`), puis un dossier par partie (`troupe/`, `serie/`, `jouer/`, `exercices/`, `bibliotheque/`, `reglages/`, `accueil/`).

La refonte 2.0 est racontée phase par phase dans [`docs/refonte-2.0/JOURNAL.md`](https://github.com/okhamfriction-png/Destiny/blob/claude/regie-son-spectacle/docs/refonte-2.0/JOURNAL.md), avec les décisions dans [`DECISIONS.md`](https://github.com/okhamfriction-png/Destiny/blob/claude/regie-son-spectacle/docs/refonte-2.0/DECISIONS.md).

## Publication

- **Android** : `.aab` (Google Play) et `.apk`. Pousser un tag `vX.Y.Z` lance le workflow `.github/workflows/apk.yml`, qui compile l'APK et le joint à la release. Voir les [Releases](https://github.com/okhamfriction-png/Destiny/releases).
- **Web** : `flutter build web --release --no-web-resources-cdn`, copier `build/web` dans `docs/app`, puis mettre `<base href="./">` dans `docs/app/index.html` : la version web marche alors sur GitHub Pages comme depuis n'importe quel chemin (par exemple raw.githack.com pour tester une branche).
- **CI/CD** : [`docs/cicd_setup.md`](https://github.com/okhamfriction-png/Destiny/blob/claude/regie-son-spectacle/docs/cicd_setup.md) · **Fiche Play Store** : [`docs/play_store_listing.md`](https://github.com/okhamfriction-png/Destiny/blob/claude/regie-son-spectacle/docs/play_store_listing.md).

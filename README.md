# DestinyStory

Application Flutter (Android, iOS, web) pour l'**improvisation dramatique** avec la grammaire de Destiny : un lieu, un groupe qui se connaît, un danger qui monte en quatre paliers, et Destiny entre les actes. **Rien n'est écrit.**

Tout fonctionne **hors ligne**. Seuls les modes « avec l'IA » demandent une clé d'API (Anthropic ou OpenAI), celle de l'utilisateur.

> 📖 Les fonctionnalités en détail : [`docs/FEATURES.md`](docs/FEATURES.md) · Les nouveautés : [`CHANGELOG.md`](CHANGELOG.md)

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

La refonte 2.0 est racontée phase par phase dans [`docs/refonte-2.0/JOURNAL.md`](docs/refonte-2.0/JOURNAL.md), avec les décisions dans [`DECISIONS.md`](docs/refonte-2.0/DECISIONS.md).

## Publication

- **Android** : `.aab` (Google Play) et `.apk`. Voir les [Releases](https://github.com/okhamfriction-png/Destiny/releases).
- **Web** : `flutter build web --release --base-href /Destiny/app/`, puis copier `build/web` dans `docs/app` (GitHub Pages).
- **CI/CD** : [`docs/cicd_setup.md`](docs/cicd_setup.md) · **Fiche Play Store** : [`docs/play_store_listing.md`](docs/play_store_listing.md).

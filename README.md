# DestinyStory

Application Flutter (Android + iOS) pour l'**improvisation théâtrale** : générer des situations,
mener des histoires suivies et animer des ateliers, à partir de fichiers JSON locaux et d'une base
SQLite. Fonctionne **hors‑ligne** ; seuls les modes « IA » nécessitent une clé d'API.

> 📖 **Documentation complète des fonctionnalités : [`docs/FEATURES.md`](docs/FEATURES.md)**

## Lancer le projet

1. Installer Flutter SDK
2. Dans le dossier du projet :
   - `flutter pub get`
   - `flutter run`

> Sur desktop (macOS/Windows/Linux), SQLite est initialisé via `sqflite_common_ffi`. Sur iOS/macOS, lancer `pod install` (CocoaPods) lors du premier build pour les plugins natifs (`sqflite`, `audioplayers`, `path_provider`).

## Fonctionnalités (survol)

Quatre univers accessibles depuis la barre de navigation :

- **Générateur** — tire un lieu, un danger (avec son style) et distribue archétypes + rôles ;
  chrono « TOP » avec 3 DESTINY, dé animé et musique scénarisée. Modes *Histoire (Théâtre)*,
  *Rue* et *Spin-off*. Mémoire anti‑répétition (SQLite).
- **Musique** — ambiances et musiques ; régie son (mixeur) accessible en jeu.
- **Histoire** — mode **IA** (interactif) ou **Campagne** (sans IA) : 21 univers, peuples,
  méchant récurrent, escalade, gestion de combat par le meneur, pièce du destin.
- **Scène** — **Spectacle (IA)** solo ou **Exercices** de théâtre par thème.

Le détail complet (écrans, réglages, confidentialité, etc.) est dans
[`docs/FEATURES.md`](docs/FEATURES.md).

## Architecture

- `lib/domain` : entités, repositories abstraits (`StoryRepository`, `CombinationMemory`), use cases.
- `lib/application` : état UI, services applicatifs (random, audio, transcription, assistants).
- `lib/infrastructure` : datasource JSON, mémoire SQLite, implémentations de repository.
- `lib/presentation` : écrans (générateur, histoire/campagne, scène, réglages…), navigation, widgets,
  visuels et thème.

## Données locales

Les catalogues sont dans `assets/data/` — notamment :
- `locations.json` — lieux + rôles, `dangers.json` — dangers (+ `style`, éligibilité `fun` au mode Rue),
- `archetypes.json` — archétypes animaux (avec statut de jeu),
- `campagne_lieux.json`, `campagne_mechants.json`, `campagne_archetypes.json` — catalogue Campagne,
- `exercices.json` — exercices de théâtre par thème.

Les sons sont dans `assets/audio/` et `assets/music/`.

## Publication

- **Android** : `.aab` (Google Play) et `.apk` (installation directe) — voir les
  [Releases](https://github.com/okhamfriction-png/Destiny/releases).
- **CI/CD** : [`docs/cicd_setup.md`](docs/cicd_setup.md) · **Fiche Play Store** :
  [`docs/play_store_listing.md`](docs/play_store_listing.md).

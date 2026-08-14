# Destiny

Application Flutter (iOS + Android) pour générer des situations d'improvisation théâtrale à partir de fichiers JSON locaux.

## Lancer le projet

1. Installer Flutter SDK
2. Dans le dossier du projet :
   - `flutter pub get`
   - `flutter run`

> Sur desktop (macOS/Windows/Linux), SQLite est initialisé via `sqflite_common_ffi`. Sur iOS/macOS, lancer `pod install` (CocoaPods) lors du premier build pour les plugins natifs (`sqflite`, `audioplayers`, `path_provider`).

## Fonctionnalités

- **Générateur** : tire un lieu, un danger (avec son style) et distribue archétypes + rôles aux joueurs. Chaque entrée est illustrée par une vignette générée localement (dégradé + icône / emoji).
- **Modes de jeu** :
  - *Théâtre* : tout est permis (40 lieux × 40 dangers).
  - *Rue* : uniquement les dangers « fun » (rien de déprimant), tous les lieux.
- **Mémoire SQLite** : les combinaisons lieu × danger déjà tirées ne reviennent pas tant que toutes les autres n'ont pas été vues ; un compteur de cycle s'incrémente à chaque épuisement.
- **Dés** (style 3D) : un dé à 6 faces classique et un dé « catégorie » à 3 faces (Danger / Lieu / Archétype).
- **Minuteur** : 3 préréglages (3 s, 3 min, 5 min) + durée personnalisée, avec lecture du son DestinyStorm à une fréquence configurable (et à la fin du décompte).

## Architecture

- `lib/domain`: entités, repositories abstraits (`StoryRepository`, `CombinationMemory`), use case
- `lib/application`: état UI, services applicatifs (random, audio)
- `lib/infrastructure`: datasource JSON, mémoire SQLite, impl repository
- `lib/presentation`: écrans (générateur, dés, minuteur), shell de navigation, widgets, visuels, thème

## Données locales

Les données sont dans `assets/data/` :
- `locations.json` — 40 lieux + rôles
- `dangers.json` — 40 dangers + `style` + `fun` (éligibilité au mode Rue)
- `archetypes.json` — archétypes animaux

Le son est dans `assets/audio/DestinyStorm.wav`.

# Cœur Rust

L'interface reste en **Flutter**. Une partie de la logique pure est écrite en **Rust** dans
`rust/` et appelée depuis Dart via [flutter_rust_bridge](https://cjycode.com/flutter_rust_bridge/)
2.11.1. Le même code Rust tourne sur Android et sur iPhone.

## Ce qui est en Rust

| Rust (`rust/src/`) | Remplace / miroir de (Dart) |
|---|---|
| `generator.rs` — tirage d'une histoire (lieu, danger, archétypes, rôles), cycle anti-répétition des dangers, mode Dilemme | `GenerateStoryUseCase`, `RandomPickerService` |
| `escalade.rs` — `orchestrer`, `horaires_des_presages`, `borner` | `lib/domain/usecases/constructeur_episode.dart` |
| `api/destiny.rs` — surface exposée à Dart (fonctions synchrones) | — |

Rust ne fait **aucune I/O**. Dart lit le catalogue (JSON / SQLite) et la mémoire, les passe à
Rust, puis applique la `MemoryUpdate` renvoyée (`resetCycle`, `markUsed`) à sa
`CombinationMemory` SQLite.

Côté Dart :
- `lib/infrastructure/rust/rust_core.dart` charge la librairie native (`RustCore.init()`).
- `lib/infrastructure/rust/rust_generate_story_usecase.dart` est branché dans `main.dart`.
- `lib/src/rust/` contient les liaisons **générées** : ne pas les éditer à la main.

**Repli automatique** : sur le web, ou si la librairie native ne se charge pas, le tirage
passe par l'implémentation Dart d'origine. Rien ne change pour l'utilisateur.

`ConstructeurEpisode.construire` n'est pas porté : ses tirages dépendent de `dart:math`
`Random(seed)`. Un autre générateur donnerait d'autres compositions, et les épisodes des
campagnes en cours changeraient.

## Prérequis de build (Android / iOS)

Le build Flutter compile maintenant le Rust (via cargokit dans `rust_builder/`). Sur la
machine de build (ton Mac, runner auto-hébergé compris) :

```sh
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh   # installe rustup
rustup target add aarch64-linux-android armv7-linux-androideabi x86_64-linux-android i686-linux-android
rustup target add aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios
```

Android a aussi besoin du **NDK** (Android Studio → SDK Manager → SDK Tools → NDK).
Ensuite `flutter run` / `flutter build appbundle` / `flutter build ios` fonctionnent comme
avant. Le premier build est plus long (compilation Rust).

## Modifier le cœur Rust

1. Modifier `rust/src/…` (les fonctions exposées sont dans `rust/src/api/`).
2. Regénérer les liaisons :
   ```sh
   cargo install flutter_rust_bridge_codegen --version 2.11.1 --locked   # une fois
   flutter_rust_bridge_codegen generate
   ```
3. Tests :
   ```sh
   (cd rust && cargo test && cargo build --release)
   flutter test test/rust_core_test.dart   # passe par la vraie librairie Rust
   ```
   `test/rust_core_test.dart` charge `rust/target/release/librust_lib_destiny.*`. Il vérifie
   le cycle des dangers, le mode Dilemme, et que Rust et Dart calculent **exactement** les
   mêmes horaires de présages. Sans le `cargo build --release`, ces tests sont sautés.

## Différence de comportement

Avec plus de joueurs que d'archétypes disponibles, le Dart levait `RangeError`. Le Rust
complète avec des archétypes répétés.

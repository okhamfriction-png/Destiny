# Destiny Studio

Montage semi-automatique des spectacles d'impro **Destiny** : ingest des rushes (DJI 4K + LRF,
micros-cravates, export DaVinci), analyse (synchro, transcription, carte des micros,
chuchotements de coulisses, musique), propositions de montages, édition dans une timeline,
rendu et export vers le NAS. Le cahier des charges complet est dans [`CLAUDE.md`](CLAUDE.md).

Tout montage est un fichier `project.json` lisible : Claude Code le génère ou le modifie via
`destiny-cli`, Marouene le retouche dans l'application, et inversement.

## Arborescence

```
studio/
├── crates/destiny-core/     cœur Rust partagé (CLI + app)
│   └── src/
│       ├── project.rs       schéma project.json (serde → TypeScript via ts-rs, JSON Schema via schemars)
│       ├── sync.rs          timeline maîtresse 25 i/s, découpe aux frontières DJI, auto-sync par corrélation
│       ├── audio.rs         WAV, enveloppes RMS, dB, corrélation croisée FFT
│       ├── mics.rs          carte des micros, gates (fondus 40 ms), détection des chuchotements
│       ├── asr.rs           VAD + whisper (feature `asr`), transcripts horodatés
│       ├── captions.rs      dictionnaire de corrections, calage mot à mot, blocs de sous-titres
│       ├── music.rs         énergie 100 ms, onsets, coups, creux, calage du coup final
│       ├── ass.rs           ASS des shorts (kicker, bandeau hook, tag, sous-titres, CTA)
│       ├── render_a.rs      moteur A : filtergraph ffmpeg en un seul passage
│       ├── mixer.rs         mixage Rust (voix gatées, musique + ducking, SFX procéduraux)
│       ├── verify.rs        contrôles après rendu (durée, son non muet, loudness)
│       ├── nas.rs           copie NAS avec reprise + md5
│       ├── history.rs       undo/redo et patchs RFC 6902
│       ├── propose.rs       propositions de shorts, pics de rétention YouTube
│       └── ingest.rs        classement, ffprobe, proxies, planches contact, projet initial
├── crates/destiny-cli/      binaire `destiny-cli`
│       ├── render_b/        moteur B : project.json → composition HTML/GSAP + plaques ffmpeg (trailers, reels)
│       └── moments.rs       moments forts (rires, cris, « Destin ! »)
├── renderer/                rendu headless Chromium image par image (Node + playwright-core)
├── src-tauri/               shell Tauri 2 (commandes, jobs avec progression, « Demander à Claude »)
├── src/                     front Svelte 5 / SvelteKit (SPA) ; src/lib/bindings = types générés
├── assets/fonts/            Anton, Montserrat SemiBold, Cinzel (OFL)
├── schema/project.schema.json
└── examples/                serpent (référence réelle), synthetic (rushes factices de test)
```

## Prérequis (Mac)

```sh
# ffmpeg-full et non ffmpeg : la formule ffmpeg de Homebrew (9.x) n'a ni libass ni freetype,
# donc ni le filtre `ass` (moteur A) ni `drawtext` (planches contact). ffmpeg-full est keg-only :
# destiny-cli et l'app la trouvent d'eux-mêmes dans $(brew --prefix)/opt/ffmpeg-full.
brew install ffmpeg-full node
# Rust : rustup (https://rustup.rs) ou `brew install rust`, pas les deux.
# Moteur B sans Chrome installé : le Chromium headless de Playwright
(cd renderer && npm install && npx playwright-core install chromium)
# transcription locale (features asr / metal) : cmake + un modèle ggml whisper
brew install cmake onnxruntime
curl -L -o ~/models/ggml-large-v3-turbo.bin https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo.bin
# VAD Silero (sinon VAD d'énergie) ; onnxruntime est chargé dynamiquement
curl -L -o ~/models/silero_vad.onnx https://github.com/snakers4/silero-vad/raw/master/src/silero_vad/data/silero_vad.onnx
export DESTINY_SILERO=~/models/silero_vad.onnx
export ORT_DYLIB_PATH=$(brew --prefix onnxruntime)/lib/libonnxruntime.dylib
cargo build --release -p destiny-cli --features metal   # whisper sur le GPU
```

## Commandes

```sh
(cd renderer && npm install)                 # moteur B (trailers) ; Chrome/Chromium requis (DESTINY_CHROMIUM, sinon Playwright)
cargo test                                   # cœur + CLI (régénère src/lib/bindings/*.ts)
cargo build --release -p destiny-cli         # la CLI
npm install && npm run tauri dev             # l'application
```

CLI (JSON sur stdout, progression sur stderr) :

```sh
destiny-cli ingest "/Volumes/ShikaZero/Spectacle/8 Octobre 2026" --project-dir ~/DestinyStudio/8-octobre --sheets
destiny-cli sync ~/DestinyStudio/8-octobre/project.json --write          # cale les micros sur la caméra
destiny-cli analyze ~/DestinyStudio/8-octobre/project.json --from 5200 --to 5400 --model ~/models/ggml-large-v3-turbo.bin
destiny-cli gates   ~/DestinyStudio/8-octobre/project.json presence.json # {"m2": [[5266.8, 5327.3]], …}
destiny-cli analyze … --measure-gates                                  # réduction du bruit de coulisses (dB)
destiny-cli propose ~/DestinyStudio/8-octobre/project.json --from 5264.6 --to 5327.1 \
    --transcript ~/DestinyStudio/8-octobre/.cache/transcript_5200-5400.json \
    --kicker "SCÈNE 4/25" --hook "UN IMMENSE SERPENT AUX YEUX VERTS" --punch-at 5266 \
    --out ~/DestinyStudio/8-octobre/serpent.json
destiny-cli snapshot ~/DestinyStudio/8-octobre/serpent.json --at 1,15,40
destiny-cli render   ~/DestinyStudio/8-octobre/serpent.json --out /tmp/serpent.mp4
destiny-cli export   ~/DestinyStudio/8-octobre/serpent.json                # livraison + NAS (reprise, md5)
destiny-cli peaks    project.json --csv retention.csv --offset 4570 --transcript t.json --out-dir pics/
destiny-cli render   examples/trailer/project.json --out /tmp/trailer.mp4  # moteur B (trailer_v/h, reel_bm)
destiny-cli compose  examples/trailer/project.json --out-dir /tmp/comp     # composition HTML seule (aperçu live)
destiny-cli moments  project.json --from 5200 --to 5400 --transcript t.json  # rires, cris, « Destin ! »
destiny-cli music    "Music/Ritual Pulse.m4a"                              # coups, creux, coup le plus fort
destiny-cli patch    serpent.json patch.json                               # patch RFC 6902 validé
```

Variables d'environnement : `DESTINY_NAS_ROOT` (défaut `/Volumes/ShikaZero`), `DESTINY_FONTS`,
`DESTINY_FFMPEG` / `DESTINY_FFPROBE`, `DESTINY_SILERO`, `DESTINY_CLAUDE_BIN`, `DESTINY_ROOT`,
`DESTINY_CHROMIUM`, `DESTINY_RENDERER`, `DESTINY_NODE`, `DESTINY_RENDER_WORKERS` (1 = rendu bit à bit reproductible).

## Tester sans les vrais rushes

```sh
examples/synthetic/make_media.sh                      # caméra DJI factice + LRF + 2 micros (dont chuchotements)
destiny-cli ingest examples/synthetic/media --project-dir /tmp/syn --sheets
destiny-cli sync /tmp/syn/project.json --write --window 30   # retrouve le décalage de 0,37 s caché dans les médias
destiny-cli analyze /tmp/syn/project.json --from 3 --to 123  # chuchotements de m2 détectés vers 63–75 s
destiny-cli propose /tmp/syn/project.json --from 4 --to 37 --transcript examples/synthetic/transcript.json \
    --kicker "SCÈNE 4/25" --hook "UN IMMENSE SERPENT AUX YEUX VERTS" --out /tmp/syn/short.json
destiny-cli snapshot /tmp/syn/short.json --at 1,7,15,25
```

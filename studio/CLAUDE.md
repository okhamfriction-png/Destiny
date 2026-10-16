# « Destiny Studio »
### Application de montage semi-automatique (Rust + Svelte) pour les spectacles d'impro Destiny

> Ce document décrit **tout** ce que l'assistant de montage faisait jusqu'ici dans Cowork (outils, réglages, règles artistiques, pièges rencontrés), pour que l'application le reproduise — avec en plus une vraie timeline où Marouene garde la main avant publication.
>
> L'état d'avancement du code est tenu à jour à la fin de ce fichier (§12).

---

## 0. Rôle et objectif

Tu es l'ingénieur principal d'une application desktop appelée **Destiny Studio**.
Utilisateur unique : Marouene, créateur et directeur artistique de *Destiny*, spectacle d'improvisation long format joué à La Divine Comédie (Paris 9e). Il est développeur (Java/Angular, Android/Kotlin), il lira le code.

L'application doit :

1. **Ingérer** les rushes d'un spectacle ou d'une répétition (caméra 4K DJI + fichiers proxy `.LRF` + micros-cravates séparés + export DaVinci éventuel).
2. **Analyser** : transcription horodatée, qui parle sur quel micro, qui est en scène, moments forts, coups de musique.
3. **Proposer automatiquement** des montages (shorts verticaux, reels, trailers 16:9) dans la direction artistique Destiny.
4. **Montrer le résultat** dans une timeline type CapCut : prévisualisation, déplacer/couper/rallonger des séquences, changer les textes, re-caler la musique.
5. **Exporter** en qualité livraison (vertical 1080×1920 et horizontal 1920×1080) puis ranger les fichiers sur le NAS.
6. Rester **pilotable par Claude Code** : tout montage est un fichier JSON lisible ; l'agent peut générer/modifier ce JSON, l'humain retouche dans l'UI, et inversement.

Rien n'est publié automatiquement : la publication est toujours une action manuelle de Marouene.

---

## 1. Stack imposée

| Couche | Choix | Pourquoi |
|---|---|---|
| Shell desktop | **Tauri 2** | Rust natif + front web léger, accès fichiers/NAS |
| Backend | **Rust** (tokio, serde, anyhow, rayon) | pipeline, jobs longs, ffmpeg, analyse audio |
| Front | **Svelte 5 + SvelteKit (mode SPA) + TypeScript** | timeline réactive |
| Vidéo | **ffmpeg / ffprobe** appelés en sous-processus (pas de bindings au départ) | robuste, déjà validé |
| Transcription | **whisper.cpp** via `whisper-rs` (modèle `large-v3-turbo` ou `small` int8) + **Silero VAD** (ONNX via `ort`) | équivalent local de ce qui était utilisé (sherpa-onnx whisper + silero) |
| Audio DSP | Rust : `hound`, `rubato` (rééchantillonnage), `realfft` | enveloppes, corrélations, mixage |
| Motion design | **Deux moteurs** (voir §6) : (A) filtergraph ffmpeg + sous-titres ASS pour les shorts ; (B) compositions HTML/GSAP rendues en headless Chromium (HyperFrames ou rendu maison) pour les trailers | c'est exactement ce qui marchait |
| Stockage projet | dossier projet + `project.json` + cache `/.cache` (proxies, waveforms, transcriptions) | versionnable, éditable par l'agent |

Contraintes machine : Mac avec NAS monté sur `/Volumes/ShikaZero`. Le NAS est **lent en écriture** (~1 Mo/s observé sur de gros fichiers, lecture rapide) → écrire les rendus en local puis copier en fin de job, avec reprise (`append`/vérification md5).

---

## 2. Les sources (réalité du terrain, à gérer telles quelles)

Dossier type : `/Volumes/ShikaZero/Spectacle/8 Octobre 2026/`

- `DJI_2026..._000N_D_P004.MP4` : caméra plan large **4K 3840×2160, 25 i/s**, h264, fichiers de ~26–28 min qui se suivent.
- `DJI_..._000N_D_P004.LRF` : **proxy 1280×720 HEVC** du même fichier, parfaitement synchrone. **Toujours utiliser les LRF pour l'analyse, les vignettes, la prévisualisation** (décodage 4K ≈ 3,4× plus lent que le temps réel sur le Mac : 45 s de 4K = 2 min 30).
- `TX0x_MIC0yy_..._orig.wav` : **micros-cravates individuels** (un par comédien, 48 kHz), fichiers de 30 min. Plusieurs pistes en parallèle.
- `Spectacle 8 octbre 2026.mov` : export DaVinci de toute la soirée (4K, 2 h 12, audio = mixage de tous les micros, **y compris ceux des comédiens en coulisses**).
- `Music/*.m4a` : musiques de Marouene (générées Suno), ex. *Ritual Pulse*, *Final Impact*, *Final Hit*, *Clockwork Omen*, *Triumph of the Heart*.
- Captures d'écran des avis Billet Réduc (PNG).

### Synchronisation
Une timeline maîtresse en **frames à 25 i/s** : chaque fichier source a un `rec` (frame de début sur la timeline) et un `start/end`. Exemple réel :
```json
{"f":"DJI_20261008201106_0004_D_P004.MP4","track":1,"rec":170453,"start":0,"end":28869,"type":"av"}
{"f":"TX00_MIC017_20261008_194419_orig.wav","track":2,"rec":130284,"start":0,"end":45000,"type":"a"}
```
Temps fichier = `t_timeline − rec/25`. Prévoir un **auto-sync** : corrélation croisée des enveloppes RMS (fenêtres 10 ms) entre chaque micro et l'audio caméra → décalage au centième (observé : ≤ 20 ms une fois calé).

Prévoir aussi le mapping **timeline vidéo publiée → timeline source** (ex. la vidéo YouTube du spectacle commence à 4570 s du `.mov`) pour importer les **pics de rétention YouTube** (voir §5.4).

---

## 3. Modèle de données (`project.json`) — le contrat entre l'agent, l'UI et le moteur

Tout le reste de l'app découle de ce schéma. Le définir en Rust (`serde`) **et** en TypeScript (généré avec `ts-rs` ou `specta`), valider avec JSON Schema.

```jsonc
{
  "version": 1,
  "format": { "w": 1080, "h": 1920, "fps": 30 },          // ou 1920x1080 25/30
  "preset": "short_scene",                                // short_scene | reel_bm | trailer_v | trailer_h
  "sources": [ { "id": "cam4", "path": "...", "proxy": "...LRF", "rec": 170453 } ],
  "mics": [ { "id": "m2", "path": "...wav", "rec": 130284, "actor": "pink_jacket" } ],
  "tracks": [
    { "id": "v0", "kind": "video", "items": [
      { "id": "c1", "src": "cam4", "in": 6779.3, "out": 6801.6, "at": 0.0,
        "crop": { "cx": 0.55, "cy": 0.50, "zoom": 1.6 },     // recadrage normalisé
        "fx": { "punch": true, "flash": true, "push": 0.06 } } ] },
    { "id": "a_voice", "kind": "voice", "items": [ /* même découpe, + gates micros */ ] },
    { "id": "a_music", "kind": "music", "items": [ { "file": "Ritual Pulse.m4a", "at": 0, "offset": 0, "gain_env": [[0,0.45],[54.5,0.62],[83.1,1.0]] } ] },
    { "id": "a_sfx", "kind": "sfx", "items": [ { "type": "snap", "at": 2.1, "gain": 0.45 } ] },
    { "id": "g_text", "kind": "graphics", "items": [
      { "type": "hook", "at": 0, "dur": 1.6, "lines": ["ILS N’ONT RIEN RÉPÉTÉ.", "LE PUBLIC MET 10/10."] },
      { "type": "reviews_txt", "at": 1.6, "dur": 5.0, "items": [["EXCELLENT ET INNOVANT !","Paul"]] },
      { "type": "end_card", "at": 83.6, "dur": 5.55, "variant": "undated" } ] },
    { "id": "subs", "kind": "captions", "items": [ { "start": 1.08, "end": 2.39, "text": "C'est pour toi ? Y a quelqu'un ?" } ] }
  ],
  "mic_gates": { "m2": [[5266.8, 5327.3]], "m4": [[0, 1e9]], "m3": [] },  // temps source
  "markers": { "music_hits": [55.9, 83.6], "cuts": [14.0] },
  "export": { "targets": ["nas:/Spectacle/8 Octobre 2026/Shorts pics YouTube/"] }
}
```

Règles :
- Tous les temps des items de timeline sont **en secondes de la vidéo finale** ; `in/out` en **secondes source**.
- Chaque modification dans l'UI réécrit `project.json` (undo/redo = historique de patchs JSON).
- Exposer une **CLI** `destiny-cli` (même crate) : `analyze`, `propose`, `render`, `snapshot --at 1,15,40`, `export`. Claude Code pilote l'app via cette CLI + le JSON.

---

## 4. Pipeline d'analyse (jobs Rust, avec progression dans l'UI)

1. **Ingest** : ffprobe de tout, création des proxies manquants (720p, `-preset ultrafast`), vignettes toutes les 2,5 s (planche contact 8 colonnes, horodatée — c'était l'outil n°1 pour « voir » qui est en scène).
2. **Audio** : extraire chaque micro en mono 16 kHz pour l'ASR et 48 kHz pour le mix.
3. **VAD** Silero (seuil silence 0,25–0,3 s, segment min 0,15–0,2 s, max 7–8 s).
4. **Transcription** whisper (langue `fr`) segment par segment ; garder un niveau dB par segment. Prévoir un **dictionnaire de corrections** par projet (l'ASR se trompe : « sonnette d'Allah » → « sonnette d'alarme », « morture » → « morsure », noms des personnages : Jean, Gérard, Bérangère, Osmo…).
5. **Carte des micros** : RMS par micro toutes les 0,5 s + « micro dominant ». Ça permet de savoir qui parle.
6. **Présence en scène** : à partir des vignettes (au départ, saisie manuelle assistée : l'utilisateur coche qui est en scène sur la planche contact ; plus tard détection de personnes, ex. YOLO via `ort`).
7. **Chuchotements de coulisses** (exigence explicite de Marouene) : un comédien hors scène garde son micro ouvert → chuchotements dans le mix. Règle : **on ne mixe que les micros des comédiens en scène** (gates par intervalle, fondus 40 ms). Résultat mesuré : −15 dB sur le bruit de coulisses. Heuristique de détection automatique à proposer dans l'UI : micro dominant mais faible (−45…−30 dB), voisement faible, alors que les autres micros sont silencieux → segment suspect surligné en orange dans la timeline.
8. **Musique** : enveloppe d'énergie (fenêtres 100 ms) + **onsets** (dérivée positive du dB) → liste des « coups » forts et des creux (ex. *Ritual Pulse* 89,2 s : creux 54–55,8 s, coup 55,9 s, section calme 78–83 s, coup final 83,6 s).
9. **Moments forts** : rire du public (pic large bande sur micro caméra), cris, changements de destin (son de la porte / « Destin ! »), plus import des **pics de rétention YouTube** (§5.4).

---

## 5. Les formats à produire (presets) — direction artistique exacte

### Charte commune
- Couleurs : fond `#0b0907`, texte `#f3ede4`, or `#e6b446`, or clair `#f7dc8a`. Dégradé or des titres : `linear-gradient(180deg,#fbe7a6 0%,#e6b446 45%,#a8701e 75%,#e9c060 100%)`.
- Polices : **Cinzel 900/700** (titres, citations), **Montserrat SemiBold** (labels en capitales, interlettrage .32em), **Anton** (shorts « scène » et sous-titres dynamiques).
- Étalonnage commun appliqué à toutes les images caméra (filtre ffmpeg exact) :
  `split[g0][g1];[g1]curves=all='0/0 0.72/0 1/1',gblur=sigma=26,colorchannelmixer=rr=1:gg=0.6:bb=0.25[h];[g0][h]blend=all_mode=screen:all_opacity=0.18,curves=all='0/0 0.10/0.03 0.30/0.20 0.55/0.50 0.80/0.82 1/0.97',colorbalance=rs=-0.08:gs=-0.01:bs=0.08:rm=0.03:bm=-0.03:rh=0.08:gh=0.02:bh=-0.08,eq=saturation=0.9,vignette=angle=PI/3.6`
- Chaque plan vidéo : léger zoom continu de 1 → 1,06 sur sa durée ; « punch » à l'entrée (échelle 1,09 → 1 en 0,6 s) ; flash blanc chaud `#fff3dc` 0,22 s entre plans de montage.
- Grain léger à l'export : `noise=alls=3:allf=t`.
- 16:9 : bandes noires cinéma de 131 px en haut et en bas → **aucun texte en dehors de la zone 131–949 px** (bug réel corrigé : hook et carte finale coupés).

### 5.1 Preset `short_scene` (shorts « scène » verticaux, moteur A)
Mise en page « group » : fond = image floutée et assombrie (boxblur, luminosité −0,18, saturation 0,8) ; vidéo 16:9 en bande au centre (1080×608, zoom de base 1,2, y = centre − 60).
- En haut : **kicker** jaune (ex. « LE PLUS REVU · 1/3 », « SCÈNE 4/25 ») ; **bandeau noir** avec le **hook** en Anton capitales (2 lignes max, 20 car./ligne), qui reste tout le short.
- Sous le bandeau : **tag jaune** « AUCUNE DE CES RÉPLIQUES N'A ÉTÉ ÉCRITE », qui bascule à 6 s sur « IMPRO DESTINY · RIEN N'EST ÉCRIT ».
- Sous-titres dynamiques Anton 118 px, blocs de 1 à 3 mots (≤ 16 car., coupure sur ponctuation ou pause > 0,45 s), mot actif en jaune grossi à 112 %, mots-clés d'emphase en rouge.
- Calage mot à mot : temps du segment réparti au prorata des lettres, pondéré par l'enveloppe d'énergie de la voix.
- Punch-in (zoom 1,2) sur le moment fort.
- CTA final 4 s dans un bloc rouge : « VIENS VOIR DESTINY — LIEN EN BIO » (ou « SUITE : SCÈNE 5/25 »).
- Barre de progression jaune en bas.
- Son : voix seule, compresseur + `loudnorm I=-16 TP=-1.5`, pas de musique.

### 5.2 Preset `trailer_v` / `trailer_h` (bandes-annonces musicales, moteur B)
Structure validée par Marouene (dans cet ordre, sans chevauchement de phases) :
1. **Hook 1,5–2 s** : scène forte + texte en Cinzel (« ILS N’ONT RIEN RÉPÉTÉ. / LE PUBLIC MET 10/10. »), 2e ligne en or qui arrive à +0,5 s.
2. **Preuve sociale** : 10/10 + 5 étoiles + 3–4 citations stylisées qui claquent sur les onsets de la musique, **puis** les **vraies captures** Billet Réduc (preuve), une à une.
3. **Concept** : les 3 cartes du public (Le lieu / Le danger / Les archétypes) qui se retournent, avec **Marouene en fond** (plan k06, luminosité 0,5) ; puis **le dé** (« Trois fois dans la soirée / LE PUBLIC LANCE LE DÉ / Un nouvel archétype… ou un danger. ») ; puis la constellation des archétypes.
4. **Meilleurs moments** (flash entre chaque plan), éventuellement 2 avis de plus au milieu.
5. **La bascule** posée sur le gros coup de la musique : carte « ET TOUT / BASCULE. » pendant le creux, puis « Destin ! » → le public crie le danger (« Le bâtiment s'effondre ! », voix du public remontée) avec tags « LE DANGER » « EFFONDREMENT » → le chaos.
6. **Fin** : « PERSONNE NE CONNAÎT LA FIN » (balayage lumineux), **0,5 s de silence total**, puis **carte finale** exactement sur le coup le plus fort de la musique.
7. Carte finale : DESTINY (or + reflet), « RIEN N’EST ÉCRIT. », puis soit la date (« JEUDI 22 OCTOBRE · 19H30 / 2 rue Saulnier · Paris 9e / NEUF EUROS · TRENTE PLACES »), soit la version sans date (« PROCHAINES DATES SUR BILLET RÉDUC / La Divine Comédie · Paris 9e / PLACES DÈS 9,95 € »), et le bouton « VIENS AVEC QUELQU’UN. ». Coupe franche à la fin (pas de fondu au noir).

Durées : vertical ≤ 45 s ; YouTube 16:9 ≈ 1 min 30 (la musique *Ritual Pulse* fait 89,2 s : calée à 0, bascule sur 55,9 s, carte finale sur 83,6 s).

### 5.3 Preset `reel_bm` (reels « meilleurs moments »)
Phases **strictement séparées** (retour de Marouene : « trop brouillon » quand tout se superposait) :
hook 2 s → **phase avis** (badge 10/10 en haut à gauche + 4 cartes d'avis qui arrivent en 2 s autour de l'image, restent ensemble, partent ensemble, jusqu'à ~6,8 s) → **phase règles** seule (pastilles en bas, une par une, 1,9 s chacune : « 1 Le public choisit le lieu », « 2 … le danger », « 3 Chaque comédien devient un animal », « 4 3 fois, le public lance le dé », « 0 texte, 0 répétition ») → scènes sans rien par-dessus → fin, silence, carte sans date.

### 5.4 Preset `retention_peaks` (shorts sur les pics YouTube)
Entrée : captures ou export CSV de la courbe de rétention YouTube + offset de la vidéo publiée.
Conversion pixel → temps si capture (axe 0 → durée), fenêtre = montée du pic → redescente, puis découpe sur des frontières de répliques, suppression des silences > 3 s et des changements de décor muets, gates micros anti-chuchotements, preset `short_scene` avec kicker « LE PLUS REVU · n/3 ».

---

## 6. Moteurs de rendu

### Moteur A — ffmpeg + ASS (shorts)
Construire en Rust : (1) le filtergraph (fond flou, bande vidéo, zooms, barre de progression), (2) un fichier **ASS** pour hook/tag/sous-titres/CTA (animations `\t`, `\fscx`, `\alpha`, dessins `\p1`). Un seul passage ffmpeg, `libx264 -crf 20`, AAC 192k, `+faststart`.

### Moteur B — compositions HTML/GSAP (trailers)
Ce qui était utilisé : **HyperFrames** (npm `hyperframes`, CLI `npx hyperframes render --quality delivery`, rendu headless Chromium image par image, timeline GSAP en pause, entièrement « seekable », aucune animation non déterministe). Une composition = `index.html` où chaque élément a `class="clip"`, `data-start`, `data-duration`, `data-track-index`.
Dans Destiny Studio : un **générateur Rust** transforme `project.json` → `index.html` + assets (clips, plaques, polices, images d'avis), puis lance le rendu. Le même HTML sert de **prévisualisation live** dans le front Svelte (iframe + `timeline.seek(t)`), ce qui donne un aperçu exact image par image sans re-rendu.
Bibliothèque de scènes à porter (une fonction par scène, paramétrable) : `clip`, `hook`, `reviews_txt`, `reviews` (captures), `quotes`, `mech` (3 cartes), `dice` (cube 3D CSS), `constellation`, `card` (styles fade/stamp), `tags`, `lower` (nom + rôle), `ring`, `fin`, `black`, `end_card`, `flash`.
L'audio n'est **pas** rendu par le navigateur : il est mixé en Rust (§7) puis multiplexé avec ffmpeg.

---

## 7. Mixage audio (Rust)

- Voix : somme des micros **gatés** (§4.7), gain 0,8, fondus 20 ms aux coupes ; normalisation RMS par clip.
- Musique : placée avec un offset choisi pour que **le coup le plus fort tombe sur la carte finale** (`offset = hit − F`), ou calée à 0 si la musique couvre toute la durée ; enveloppe de gain (0,45 sous le hook, 0,62 sous les explications, montée à 1,0 à partir de la bascule, 1,15 sur la carte finale).
- **Ducking** : la musique baisse de 55 % sous la voix (enveloppe 120 ms).
- SFX procéduraux (snap, whoosh, tom, gong, braam, sub drop, impact final) posés par la timeline (cues).
- Silence total de 0,5 s avant la carte finale, coupe franche à la fin (fondu 10 ms).
- Mastering : compresseur doux + `loudnorm I=-14 TP=-1.2 LRA=9` (trailers), `I=-16` (shorts voix).
- **Garde-fou** (bug réel) : si la fenêtre de normalisation est vide, ne pas diviser par zéro → NaN → vidéo muette. Toujours vérifier après rendu que le son n'est pas silencieux (niveau moyen > −40 dB) et refuser l'export sinon.

---

## 8. Interface (Svelte)

1. **Bibliothèque** : spectacles/répétitions, état des analyses, planches contact.
2. **Explorateur de spectacle** : transcription défilante synchronisée, carte des micros (heatmap par comédien), présence en scène, courbe de rétention YouTube superposée, musique avec ses coups.
3. **Propositions** : cartes de montages proposés (preset, durée, hook proposé, moments utilisés) → « Ouvrir dans l'éditeur ».
4. **Éditeur** (cœur, type CapCut) :
   - Aperçu au format final (vertical ou 16:9), lecture/scrub image par image.
   - Timeline multipistes : vidéo, voix, musique (forme d'onde + marqueurs de coups), SFX, graphismes, sous-titres.
   - Glisser, couper (`S`), rallonger, supprimer avec raccord, aimantation sur les coups de musique et les débuts de répliques.
   - Panneau de propriétés : textes du hook/kicker/tag/CTA, recadrage (cx, cy, zoom) avec poignées, micros ouverts/fermés sur l'intervalle, avis choisis, variante de carte finale.
   - Sous-titres éditables en ligne, avec correction propagée au dictionnaire.
   - Bouton « Demander à Claude » : ouvre une consigne texte, l'agent (Claude Code / API) renvoie un patch JSON appliqué et annulable.
5. **Export** : file de rendus, progression, vérifications automatiques (durée, son non muet, loudness, images clés), copie sur le NAS avec reprise et contrôle md5.

---

## 9. Pièges connus (à coder dès le départ)

- Décodage 4K lent → proxies partout, 4K seulement à l'export final et seulement sur les intervalles utilisés (`-ss` avant `-i`).
- Sur le NAS : écriture lente, suppression parfois interdite ; écrire en local puis copier, et reprendre une copie interrompue avec `tail -c +N >> fichier` + md5.
- Un segment qui chevauche deux fichiers source doit être découpé à la frontière.
- La caméra DJI change de fichier toutes les ~27 min (`rec` différent).
- Bandes 16:9 : zone texte sûre 131–949 px.
- Hook trop long → 2 lignes max ; CTA qui se coupe mal → le raccourcir plutôt que réduire la police.
- Ne jamais tuer un processus avec un motif qui apparaît dans sa propre ligne de commande (`pkill -f`) : utiliser les PID.
- Toutes les animations doivent être déterministes (pas de `Math.random` au rendu : graine fixe).

---

## 10. Ordre de construction (jalons, chacun livrable et testé)

1. Squelette Tauri + Svelte, schéma `project.json` (Rust + TS), CLI `destiny-cli`.
2. Ingest + proxies + planches contact + synchro par corrélation.
3. Transcription (whisper + VAD) + carte des micros + dictionnaire de corrections.
4. Moteur A (shorts scène) : rendu identique au style actuel à partir d'un JSON écrit à la main. Test de référence : « Un immense serpent aux yeux verts » (source 5264,6 → 5327,1 s).
5. Gates micros + détection des chuchotements + vérification −15 dB.
6. Éditeur timeline (vidéo + voix + sous-titres) avec aperçu.
7. Moteur B (HTML/GSAP) + bibliothèque de scènes + aperçu live dans l'iframe.
8. Mixage musical (coups, ducking, silence, carte sur le coup final).
9. Propositions automatiques (presets §5) + import des pics YouTube.
10. Bouton « Demander à Claude » (patchs JSON) + export NAS.

Pour chaque jalon : tests Rust (`cargo test`), un projet d'exemple dans `examples/`, et des captures `snapshot --at` relues avant de passer au suivant.

---

## 11. Règles de travail pour toi (Claude Code)

- Pose une question seulement si une décision appartient vraiment à Marouene ; sinon choisis le réglage par défaut décrit ici et note-le.
- Ne publie jamais rien sur un réseau social ; l'export s'arrête au fichier.
- Ne mets jamais d'identifiants ou de clés dans le code.
- Explique chaque choix d'architecture en une phrase dans le commit.

---

## 12. État d'avancement et repères dans le code

Voir `README.md` (commandes, arborescence) ; ce paragraphe liste les **choix par défaut** pris
sans Marouene, à remettre en question si besoin :

- Le studio vit dans `studio/` du dépôt Destiny (l'app Flutter DestinyStory occupe la racine).
- `rec` est un nombre **fractionnaire** de frames : l'auto-sync cale au centième, une frame (40 ms) ne suffit pas.
- `mic_gates` et `markers.cuts` côté source sont en **secondes de la timeline maîtresse** (l'exemple du §3 —
  gate m2 5266,8 → 5327,3 pour la scène 5264,6 → 5327,1 — est sur cette échelle).
- Jaune des shorts = or clair de la charte `#f7dc8a` ; rouge d'emphase/CTA = `#e0352b` (`style.rs`).
- Le CTA final des shorts s'ajoute **après** la scène (4 s de suite de la scène, réaction du public) au lieu
  de masquer la chute ; les sous-titres s'arrêtent au CTA.
- Transcription : sans la feature `asr`, la VAD d'énergie donne les segments de parole sans texte ; whisper
  et Silero s'activent avec `cargo build --features asr` (modèle ggml passé par `--model`, Silero par `DESTINY_SILERO`).

### Jalons (état au 16 octobre 2026)

| Jalon | État |
|---|---|
| 1. Squelette, schéma, CLI | fait (`cargo test`, `npm run check/test`, `npm run tauri dev`) |
| 2. Ingest, proxies, planches, synchro | fait ; synchro vérifiée sur médias synthétiques (0,37 s retrouvé à 1 ms) |
| 3. Transcription, carte des micros, dictionnaire | fait ; Silero vérifié, whisper compilé mais pas encore testé avec un modèle |
| 4. Moteur A | fait sur médias synthétiques ; test de référence « serpent » à rejouer sur le vrai `.mov` |
| 5. Gates, chuchotements, mesure | fait ; le −15 dB est à mesurer sur la vraie soirée |
| 6. Éditeur timeline | fait (aperçu approché + « Image exacte » par snapshot) |
| 7. Moteur B | fait ; mise en page spécifique `reel_bm` (badge 10/10, pastilles de règles) à faire |
| 8. Mixage musical | fait (coups, ducking, silence, carte sur le coup final) |
| 9. Propositions | `short_scene` et pics YouTube (CSV ou capture) ; propositions trailer/reel automatiques à faire |
| 10. « Demander à Claude », export NAS | fait |

Reste aussi : forme d'onde musique et présence en scène dans l'UI, seuils des moments forts à
calibrer sur un vrai spectacle, renderer Node à embarquer dans le bundle macOS.

#!/usr/bin/env python3
"""Récupère un thème musical BOUCLABLE par univers d'histoire depuis
freesound.org (licences CC0 + Attribution uniquement = commercialisable), le
rend « seamless » par crossfade, et l'encode en m4a dans
assets/audio/universes/. Écrit un manifest + des attributions.

Token dans FREESOUND_TOKEN (jamais écrit dans le dépôt). Relançable (skip des
fichiers déjà présents).
"""
import array
import json
import os
import re
import socket
import ssl
import subprocess
import tempfile
import time
import urllib.parse
import urllib.request
import wave

socket.setdefaulttimeout(30)
SSL_CTX = ssl.create_default_context()
SSL_CTX.check_hostname = False
SSL_CTX.verify_mode = ssl.CERT_NONE

TOKEN = os.environ.get("FREESOUND_TOKEN", "").strip()
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "universes")
UA = "Destiny/1.0 (improv app)"
API = "https://freesound.org/apiv2/search/text/"
MAX_SEC = 55          # longueur max avant boucle
XFADE_SEC = 1.6       # durée du fondu enchaîné pour boucler proprement

# On exclut la VOIX (pas les instruments) : c'est de la musique.
VOCAL = {"voice", "voices", "vocal", "vocals", "singing", "sing", "sings",
         "speech", "rap", "lyrics", "spoken", "talking", "acapella",
         "a-cappella", "choir", "vocaloid"}

# On exclut les bruitages (on veut de la MUSIQUE, pas un effet).
SFX = {"beam", "laser", "weapon", "gun", "explosion", "ui", "interface",
       "button", "foley", "footstep", "door", "beep", "glitch", "whoosh",
       "impact", "hit", "click", "alarm", "siren", "machine", "robot",
       "engine", "sfx", "effect", "effects", "sound-effect", "stone",
       "ray", "blaster", "spaceship", "controlroom"}

# Indices que c'est bien de la musique.
MUSIC_HINT = {"music", "melody", "theme", "soundtrack", "bgm", "tune",
              "chiptune", "synth", "piano", "guitar", "orchestral", "ambient",
              "beat", "groove", "harp", "strings", "lofi", "jazz", "8-bit",
              "8bit", "song"}

# (id fichier, titre affiché, requêtes)
UNIVERSES = [
    ("contemporain", "Contemporain", ["lofi loop", "chill instrumental loop", "ambient piano loop"]),
    ("policier", "Policier", ["noir jazz loop", "detective theme", "suspense loop"]),
    ("high_fantasy", "High Fantasy", ["fantasy game music loop", "epic 8-bit adventure", "medieval fantasy loop"]),
    ("shonen", "Shonen", ["anime action music loop", "jrpg battle theme", "energetic orchestral loop"]),
    ("science_fiction", "Science-Fiction", ["sci-fi music loop", "synthwave music loop", "space ambient music"]),
    ("dark_fantasy", "Dark Fantasy", ["dark fantasy loop", "dungeon music loop", "gothic game loop"]),
    ("cyberpunk", "Cyberpunk", ["cyberpunk loop", "dark synthwave loop", "neon city loop"]),
    ("horreur", "Horreur", ["horror ambient loop", "creepy music loop", "scary drone loop"]),
    ("post_apo", "Post-apocalyptique", ["post apocalyptic loop", "dark ambient loop", "wasteland loop"]),
    ("steampunk", "Steampunk", ["steampunk loop", "mechanical waltz loop", "clockwork music"]),
    ("super_heros", "Super-héros", ["heroic orchestral loop", "epic action music loop", "triumphant theme"]),
    ("historique", "Historique", ["medieval music loop", "celtic loop", "historical game loop"]),
    ("conte_fees", "Conte de fées", ["fairy tale loop", "music box loop", "magical cute loop"]),
    ("dessin_anime", "Dessin animé", ["cartoon happy music loop", "cheerful chiptune music", "playful comedy music"]),
    ("manga_rigolo", "Manga rigolo", ["funny anime loop", "cute jrpg loop", "chibi music loop"]),
    ("animaux_parlent", "Animaux qui parlent", ["cute animal theme loop", "playful ukulele loop", "happy whistle loop"]),
    ("pirates", "Pirates", ["pirate music loop", "sea shanty instrumental loop", "adventure sea loop"]),
    ("espace_rigolo", "Espace rigolo", ["cute chiptune music loop", "happy 8-bit music", "playful synth music loop"]),
    ("monde_magique", "Monde magique", ["magical music box loop", "enchanted harp music", "dreamy fantasy music"]),
    ("sous_la_mer", "Sous la mer", ["calm underwater music", "peaceful ambient music loop", "dreamy water music"]),
    ("chevaliers_dragons", "Chevaliers & dragons", ["medieval fantasy loop", "knight theme loop", "castle game music"]),
]


def api_get(u):
    req = urllib.request.Request(u, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=25, context=SSL_CTX) as r:
        return json.load(r)


def search(term):
    q = urllib.parse.urlencode({
        "query": term,
        "filter": 'duration:[8 TO 120] license:("Creative Commons 0" OR "Attribution")',
        "fields": "id,name,duration,license,previews,tags,username",
        "sort": "score", "page_size": "15", "token": TOKEN,
    })
    return api_get(f"{API}?{q}").get("results", [])


def _tokens(res):
    toks = set(re.split(r"[^a-z0-9]+", res.get("name", "").lower()))
    toks |= {t.lower() for t in res.get("tags", [])}
    return toks


def choose(results):
    # Ni voix, ni bruitage, avec preview.
    good = [r for r in results
            if r.get("previews") and not (_tokens(r) & VOCAL)
            and not (_tokens(r) & SFX)]
    if not good:
        return None
    # Priorité : ce qui a un indice « musique », puis l'ordre de pertinence.
    for r in good:
        if _tokens(r) & MUSIC_HINT:
            return r
    return good[0]


def curl(url, dest):
    r = subprocess.run(["curl", "-sS", "-m", "150", "--retry", "2", "-A", UA,
                        "-o", dest, url], capture_output=True)
    return r.returncode == 0 and os.path.exists(dest) and os.path.getsize(dest) > 8000


def afconvert(src, dst, args):
    return subprocess.run(["afconvert", *args, src, dst],
                          capture_output=True).returncode == 0


def crossfade_loop(pcm_in, pcm_out):
    with wave.open(pcm_in, "rb") as w:
        fr = w.getframerate()
        params = w.getparams()
        data = array.array("h")
        data.frombytes(w.readframes(w.getnframes()))
    if len(data) > fr * MAX_SEC:
        data = data[:int(fr * MAX_SEC)]
    n = len(data)
    d = min(int(fr * XFADE_SEC), n // 3)
    if d < 200:
        out = data
    else:
        out = array.array("h", data[:n - d])
        for i in range(d):
            g = i / d
            v = data[i] * g + data[n - d + i] * (1 - g)
            out[i] = int(max(-32768, min(32767, v)))
    with wave.open(pcm_out, "wb") as o:
        o.setparams(params)
        o.setnframes(0)
        o.writeframes(out.tobytes())


def process(url, out_m4a):
    with tempfile.TemporaryDirectory() as td:
        raw = os.path.join(td, "raw.mp3")
        pcm = os.path.join(td, "pcm.wav")
        looped = os.path.join(td, "loop.wav")
        if not curl(url, raw):
            return False
        if not afconvert(raw, pcm, ["-f", "WAVE", "-d", "LEI16@44100", "-c", "1"]):
            return False
        crossfade_loop(pcm, looped)
        return afconvert(looped, out_m4a, ["-f", "m4af", "-d", "aac", "-b", "112000"])


def main():
    if not TOKEN:
        raise SystemExit("FREESOUND_TOKEN manquant.")
    os.makedirs(OUT, exist_ok=True)
    attr_path = os.path.join(OUT, "attributions.json")
    attributions = json.load(open(attr_path)) if os.path.exists(attr_path) else {}

    done = []
    for uid, title, terms in UNIVERSES:
        dest = os.path.join(OUT, f"{uid}.m4a")
        if os.path.exists(dest):
            done.append((uid, title))
            print(f"{uid}: déjà présent", flush=True)
            continue
        picked = None
        for term in terms:
            try:
                picked = choose(search(term))
            except Exception as e:
                print(f"    ! search {uid} « {term} »: {e}", flush=True)
                picked = None
            if picked:
                break
            time.sleep(0.2)
        if not picked:
            print(f"{uid}: aucun résultat", flush=True)
            continue
        url = picked["previews"].get("preview-hq-mp3") or \
            picked["previews"].get("preview-lq-mp3")
        try:
            if process(url, dest):
                done.append((uid, title))
                attributions[uid] = {
                    "freesound_id": picked["id"], "name": picked["name"],
                    "author": picked["username"], "license": picked["license"],
                    "url": f"https://freesound.org/s/{picked['id']}/",
                }
                print(f"{uid}: OK  #{picked['id']} {round(picked['duration'])}s "
                      f"« {picked['name'][:40]} »", flush=True)
            else:
                print(f"{uid}: échec traitement", flush=True)
        except Exception as e:
            print(f"    ! process {uid}: {e}", flush=True)

    with open(attr_path, "w", encoding="utf-8") as f:
        json.dump(attributions, f, ensure_ascii=False, indent=2)
    entries = [{"file": f"audio/universes/{u}.m4a", "title": t, "loop": True}
               for u, t in done]
    entries.sort(key=lambda e: e["title"].lower())
    with open(os.path.join(OUT, "manifest.json"), "w", encoding="utf-8") as f:
        json.dump({"universes": entries}, f, ensure_ascii=False, indent=2)
    print(f"\nTotal : {len(done)} / {len(UNIVERSES)}", flush=True)


if __name__ == "__main__":
    main()

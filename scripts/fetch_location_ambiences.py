#!/usr/bin/env python3
"""Télécharge de VRAIS sons d'ambiance (licences libres, Wikimedia Commons)
pour chaque lieu, les raccourcit (~14 s) et les compresse en m4a dans
assets/audio/ambiences/. Ignore l'OGG (non décodable par afconvert).

Usage : python3 scripts/fetch_location_ambiences.py
"""
import json
import os
import re
import ssl
import subprocess
import tempfile
import time
import urllib.parse
import urllib.request
import wave

SSL_CTX = ssl.create_default_context()
SSL_CTX.check_hostname = False
SSL_CTX.verify_mode = ssl.CERT_NONE

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "ambiences")
UA = "DestinyApp/1.0 (educational improv app; okhamfriction@gmail.com)"
API = "https://commons.wikimedia.org/w/api.php"
TRIM_SECONDS = 150  # ~2 min 30 (bouclé) : vraie ambiance immersive
MAX_BYTES = 30_000_000
MIN_BYTES = 45_000  # évite les bips très courts, garde les vraies ambiances
OK_EXT = ("mp3", "wav", "flac")  # afconvert ne décode pas l'ogg

# Mots qui trahissent de la PAROLE / de la musique → on rejette (on veut de
# l'ambiance de fond, pas des voix ni des morceaux).
SPEECH = {
    "announcement", "radio", "applause", "interview", "speech", "voice",
    "talk", "song", "anthem", "hymn", "choir", "orchestra", "band", "music",
    "lecture", "conversation", "dialog", "dialogue", "presentation",
    "commentary", "narration", "reading", "podcast", "broadcast", "news",
    "sermon", "prayer", "chant", "opera", "singing", "vocal", "spoken",
    "recitation", "monologue", "audiobook",
}

TERMS = {
    "aeroport": ["airport ambience", "airport atmosphere", "airport hall ambience"],
    "laboratoire": ["laboratory ambience", "server room ambience",
                    "machine room ambience", "computer room ambience"],
    "hotel_luxe": ["hotel lobby ambience", "lobby ambience", "reception ambience"],
    "ferme": ["farm ambience", "farmyard ambience", "countryside ambience"],
    "bunker_militaire": ["machine room ambience", "ventilation ambience",
                         "generator ambience", "industrial hum"],
    "bibliotheque": ["library ambience", "reading room ambience",
                     "quiet room ambience"],
    "usine": ["factory ambience", "industrial ambience", "machine room ambience"],
    "restaurant_gastronomique": ["restaurant ambience", "cafe ambience",
                                 "dining ambience"],
    "commissariat": ["office ambience", "room tone office",
                     "quiet office ambience"],
    "centre_commercial": ["shopping mall ambience", "mall ambience",
                          "shopping centre ambience"],
    "zoo": ["zoo ambience", "jungle ambience", "tropical birds ambience"],
    "musee": ["museum ambience", "gallery ambience", "quiet hall ambience"],
    "camping": ["forest night ambience", "crickets night ambience",
                "campfire ambience"],
    "plateau_tele": ["studio ambience", "crowd ambience", "audience murmur"],
    "boite_nuit": ["nightclub ambience", "club ambience", "dance floor ambience"],
    "base_spatiale": ["engine room ambience", "spaceship ambience",
                      "machine room ambience", "sci-fi room tone"],
    "bureau": ["office ambience", "room tone office"],
    "palais_presidentiel": ["large hall ambience", "grand hall ambience",
                            "empty hall reverb"],
    "manoir_abandonne": ["haunted house ambience", "wind house ambience",
                         "creaky house ambience"],
    "prison": ["prison ambience", "jail ambience", "corridor ambience"],
    "stade": ["stadium ambience", "stadium crowd ambience",
              "sports crowd ambience"],
    "refuge_montagne": ["mountain wind ambience", "wind ambience",
                        "blizzard ambience"],
    "banque": ["office ambience", "bank hall ambience", "room tone"],
    "aquarium": ["underwater ambience", "aquarium ambience", "bubbles ambience"],
    "avion": ["airplane cabin ambience", "aircraft cabin ambience",
              "jet cabin ambience"],
    "port_maritime": ["harbour ambience", "seaside ambience", "port ambience",
                      "seagulls ambience"],
    "eglise": ["church ambience", "cathedral ambience", "church bells"],
    "salle_sport": ["gym ambience", "gymnasium ambience", "fitness ambience"],
    "foret": ["forest ambience", "forest birds ambience"],
    "sous_marin": ["submarine ambience", "engine room ambience",
                   "sonar ambience"],
    "metro": ["subway ambience", "metro station ambience",
              "underground ambience"],
    "navire_croisiere": ["ship ambience", "ship engine ambience",
                         "boat ambience"],
    "universite": ["campus ambience", "university ambience",
                   "lecture hall ambience"],
    "hopital": ["hospital ambience", "hospital corridor ambience",
                "medical ward ambience"],
    "ecole": ["schoolyard ambience", "playground ambience", "school ambience"],
    "supermarche": ["supermarket ambience", "store ambience",
                    "shopping mall ambience"],
    "casino": ["casino ambience", "casino floor ambience",
               "slot machines ambience"],
    "theatre": ["theatre ambience", "auditorium ambience",
                "concert hall ambience"],
    "tribunal": ["courtroom ambience", "large hall ambience", "hall reverb"],
    "station_service": ["highway ambience", "road traffic ambience",
                        "traffic ambience"],
}


def api_get(params):
    qs = urllib.parse.urlencode(params)
    req = urllib.request.Request(f"{API}?{qs}", headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=25, context=SSL_CTX) as r:
        return json.load(r)


def find_audio(term):
    time.sleep(0.4)  # politesse envers l'API (évite le throttling)
    for attempt in range(3):
        try:
            data = api_get({
                "action": "query", "format": "json",
                "generator": "search", "gsrnamespace": "6", "gsrlimit": "20",
                "gsrsearch": f"{term} filetype:audio",
                "prop": "imageinfo", "iiprop": "url|mime|size",
            })
            break
        except Exception as e:
            if attempt == 2:
                print(f"    ! recherche « {term} » : {e}")
                return None
            time.sleep(1.5)
    pages = (data.get("query") or {}).get("pages") or {}
    cands = []
    for p in pages.values():
        ii = (p.get("imageinfo") or [{}])[0]
        mime, size, url = ii.get("mime", ""), ii.get("size", 0), ii.get("url")
        if not url:
            continue
        name = urllib.parse.unquote(url.rsplit("/", 1)[-1]).lower()
        ok_ext = name.rsplit(".", 1)[-1] in OK_EXT
        tokens = set(re.split(r"[^a-z]+", name))  # mots entiers
        has_speech = bool(tokens & SPEECH)
        if (ok_ext and not has_speech and mime.startswith("audio/")
                and MIN_BYTES <= size <= MAX_BYTES):
            cands.append((size, url))
    # On préfère le fichier le PLUS gros (donc le plus long) = vraie ambiance.
    cands.sort(reverse=True)
    return cands[0][1] if cands else None


def download(url, dest):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=60, context=SSL_CTX) as r:
        data = r.read()
    with open(dest, "wb") as f:
        f.write(data)


def afconvert(src, dst, args):
    return subprocess.run(["afconvert", *args, src, dst],
                          capture_output=True).returncode == 0


def trim_wav(src, dst, seconds):
    with wave.open(src, "rb") as w:
        fr = w.getframerate()
        n = min(w.getnframes(), int(fr * seconds))
        params = w.getparams()
        frames = w.readframes(n)
    with wave.open(dst, "wb") as o:
        o.setparams(params)
        o.setnframes(0)
        o.writeframes(frames)


def process(url, out_m4a):
    with tempfile.TemporaryDirectory() as td:
        raw = os.path.join(td, "raw." + url.lower().rsplit(".", 1)[-1])
        pcm = os.path.join(td, "pcm.wav")
        trimmed = os.path.join(td, "trim.wav")
        download(url, raw)
        if not afconvert(raw, pcm, ["-f", "WAVE", "-d", "LEI16@44100", "-c", "1"]):
            return False
        trim_wav(pcm, trimmed, TRIM_SECONDS)
        return afconvert(trimmed, out_m4a, ["-f", "m4af", "-d", "aac", "-b", "64000"])


def existing(aid):
    return os.path.exists(os.path.join(OUT, f"{aid}.m4a"))


def main():
    os.makedirs(OUT, exist_ok=True)
    done = []
    for aid, terms in TERMS.items():
        if existing(aid):
            done.append(aid)
            print(f"{aid}: déjà présent")
            continue
        got = False
        for term in terms:
            url = find_audio(term)
            if not url:
                continue
            try:
                if process(url, os.path.join(OUT, f"{aid}.m4a")):
                    done.append(aid)
                    print(f"{aid}: OK  « {term} »")
                    got = True
                    break
            except Exception as e:
                print(f"    ! {aid} ({term}): {e}")
        if not got:
            print(f"{aid}: ÉCHEC")

    # Manifeste (id -> nom FR depuis locations.json) pour le menu Musique.
    loc_path = os.path.join(os.path.dirname(__file__), "..", "assets", "data",
                            "locations.json")
    names = {}
    try:
        locs = json.load(open(loc_path, encoding="utf-8"))
        for l in (locs["locations"] if isinstance(locs, dict) else locs):
            names[l["id"]] = l["name"]
    except Exception as e:
        print("!! locations.json:", e)
    entries = [
        {"file": f"audio/ambiences/{a}.m4a", "title": names.get(a, a),
         "loop": True}
        for a in done
    ]
    entries.sort(key=lambda e: e["title"].lower())
    with open(os.path.join(OUT, "manifest.json"), "w", encoding="utf-8") as f:
        json.dump({"ambiences": entries}, f, ensure_ascii=False, indent=2)

    print("\n=== ids Dart (lieux avec ambiance) ===")
    print(", ".join(f"'{a}'" for a in sorted(done)))
    print(f"\nTotal : {len(done)} / {len(TERMS)}  (manifest écrit)")


if __name__ == "__main__":
    main()

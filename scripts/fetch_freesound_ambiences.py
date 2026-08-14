#!/usr/bin/env python3
"""Télécharge de vraies ambiances de lieux depuis freesound.org (previews mp3,
CC), les raccourcit (~2 min 30) et les compresse en m4a dans
assets/audio/ambiences/. Reprend là où il s'est arrêté (skip des fichiers déjà
présents) — relançable en plusieurs fois.

Le token freesound est lu dans la variable d'environnement FREESOUND_TOKEN
(jamais écrit dans le dépôt).

Usage : FREESOUND_TOKEN=xxx python3 scripts/fetch_freesound_ambiences.py
"""
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
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "ambiences")
UA = "Destiny/1.0 (improv app)"
API = "https://freesound.org/apiv2/search/text/"
TRIM_SECONDS = 150

SPEECH = {
    "speech", "voice", "voices", "talking", "talk", "conversation", "dialog",
    "dialogue", "interview", "podcast", "narration", "reading", "song",
    "music", "singing", "vocal", "vocals", "rap", "announcement", "spoken",
    "story", "audiobook", "words", "chant", "sermon", "prayer", "musicians",
    "orchestra", "band", "choir", "concert", "guitar", "piano", "drum",
}

TERMS = {
    "aeroport": ["airport ambience", "airport terminal ambience"],
    "laboratoire": ["laboratory ambience", "science lab ambience", "server room ambience"],
    "hotel_luxe": ["hotel lobby ambience", "luxury hotel ambience", "lobby ambience"],
    "ferme": ["farm ambience", "farmyard ambience"],
    "bunker_militaire": ["bunker ambience", "machine room ambience", "underground hum"],
    "bibliotheque": ["library ambience"],
    "usine": ["factory ambience", "industrial ambience"],
    "restaurant_gastronomique": ["restaurant ambience", "fine dining ambience"],
    "commissariat": ["police station ambience", "office ambience"],
    "centre_commercial": ["shopping mall ambience", "mall ambience"],
    "zoo": ["zoo ambience"],
    "musee": ["museum ambience"],
    "camping": ["campsite ambience", "forest night ambience", "camping ambience"],
    "plateau_tele": ["tv studio ambience", "studio audience ambience"],
    "boite_nuit": ["disco ambience", "dance club crowd", "party crowd ambience", "club crowd"],
    "base_spatiale": ["spaceship ambience", "space station ambience", "sci-fi room tone"],
    "bureau": ["office ambience"],
    "palais_presidentiel": ["ballroom ambience", "castle hall ambience", "cathedral hall reverb", "large marble hall"],
    "manoir_abandonne": ["abandoned house ambience", "haunted mansion ambience", "creepy house ambience"],
    "prison": ["prison ambience", "jail ambience"],
    "stade": ["stadium ambience", "stadium crowd ambience"],
    "refuge_montagne": ["mountain hut ambience", "alpine wind ambience", "mountain wind"],
    "banque": ["bank ambience", "office ambience"],
    "aquarium": ["underwater bubbles ambience", "fish tank bubbles", "underwater ambience", "scuba diving underwater"],
    "avion": ["airplane cabin ambience", "plane cabin ambience"],
    "port_maritime": ["harbor ambience", "port ambience", "harbour seaside"],
    "eglise": ["church ambience", "cathedral ambience"],
    "salle_sport": ["gym ambience", "fitness club ambience"],
    "foret": ["forest ambience"],
    "sous_marin": ["submarine ambience", "submarine engine room"],
    "metro": ["subway ambience", "metro ambience"],
    "navire_croisiere": ["cruise ship ambience", "ship interior ambience"],
    "universite": ["university ambience", "campus ambience", "lecture hall ambience"],
    "hopital": ["hospital ambience"],
    "ecole": ["school ambience", "classroom ambience", "schoolyard ambience"],
    "supermarche": ["supermarket ambience", "grocery store ambience"],
    "casino": ["casino ambience", "casino floor ambience"],
    "theatre": ["theatre ambience", "auditorium ambience"],
    "tribunal": ["courtroom ambience", "courthouse ambience"],
    "station_service": ["gas station ambience", "highway ambience"],
}


def lic_rank(url):
    u = (url or "").lower()
    if "publicdomain" in u or "zero" in u:
        return 0
    if "/by/" in u:
        return 1
    if "/by-nc/" in u:
        return 2
    return 3


def search(term):
    q = urllib.parse.urlencode({
        "query": term,
        # Uniquement CC0 et Attribution (utilisables commercialement) — pas de NC.
        "filter": 'duration:[45 TO 600] license:("Creative Commons 0" OR "Attribution")',
        "fields": "id,name,duration,license,previews,tags,username",
        "sort": "score", "page_size": "15", "token": TOKEN,
    })
    req = urllib.request.Request(f"{API}?{q}", headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=25, context=SSL_CTX) as r:
        return json.load(r).get("results", [])


def is_speech(res):
    toks = set(re.split(r"[^a-z]+", res.get("name", "").lower()))
    toks |= {t.lower() for t in res.get("tags", [])}
    return bool(toks & SPEECH)


def choose(results):
    # On GARDE l'ordre de pertinence de l'API (sort=score). On prend le 1er
    # résultat sans parole, avec preview, d'une durée raisonnable.
    for r in results:
        if r.get("previews") and not is_speech(r) and 45 <= r["duration"] <= 420:
            return r
    for r in results:
        if r.get("previews") and not is_speech(r):
            return r
    return None


def curl_download(url, dest):
    r = subprocess.run(
        ["curl", "-sS", "-m", "150", "--retry", "2", "-A", UA, "-o", dest, url],
        capture_output=True)
    return r.returncode == 0 and os.path.exists(dest) and os.path.getsize(dest) > 20000


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
        raw = os.path.join(td, "raw.mp3")
        pcm = os.path.join(td, "pcm.wav")
        trimmed = os.path.join(td, "trim.wav")
        if not curl_download(url, raw):
            return False
        if not afconvert(raw, pcm, ["-f", "WAVE", "-d", "LEI16@44100", "-c", "1"]):
            return False
        trim_wav(pcm, trimmed, TRIM_SECONDS)
        return afconvert(trimmed, out_m4a,
                         ["-f", "m4af", "-d", "aac", "-b", "72000"])


def existing(aid):
    return os.path.exists(os.path.join(OUT, f"{aid}.m4a"))


def main():
    if not TOKEN:
        raise SystemExit("FREESOUND_TOKEN manquant.")
    os.makedirs(OUT, exist_ok=True)
    attr_path = os.path.join(OUT, "attributions.json")
    attributions = {}
    if os.path.exists(attr_path):
        try:
            attributions = json.load(open(attr_path))
        except Exception:
            attributions = {}

    done = []
    for aid, terms in TERMS.items():
        if existing(aid):
            done.append(aid)
            print(f"{aid}: déjà présent", flush=True)
            continue
        picked = None
        for term in terms:
            try:
                res = search(term)
            except Exception as e:
                print(f"    ! search {aid} « {term} »: {e}", flush=True)
                continue
            picked = choose(res)
            if picked:
                break
            time.sleep(0.2)
        if not picked:
            print(f"{aid}: aucun résultat", flush=True)
            continue
        url = picked["previews"].get("preview-lq-mp3") or \
            picked["previews"].get("preview-hq-mp3")
        try:
            if process(url, os.path.join(OUT, f"{aid}.m4a")):
                done.append(aid)
                attributions[aid] = {
                    "freesound_id": picked["id"],
                    "name": picked["name"],
                    "author": picked["username"],
                    "license": picked["license"],
                    "url": f"https://freesound.org/s/{picked['id']}/",
                }
                print(f"{aid}: OK  #{picked['id']} {round(picked['duration'])}s "
                      f"« {picked['name'][:40]} »", flush=True)
            else:
                print(f"{aid}: échec traitement", flush=True)
        except Exception as e:
            print(f"    ! process {aid}: {e}", flush=True)

    # Attributions (crédits).
    with open(attr_path, "w", encoding="utf-8") as f:
        json.dump(attributions, f, ensure_ascii=False, indent=2)

    # Manifeste (nom FR depuis locations.json).
    loc_path = os.path.join(os.path.dirname(__file__), "..", "assets", "data",
                            "locations.json")
    names = {}
    try:
        locs = json.load(open(loc_path, encoding="utf-8"))
        for l in (locs["locations"] if isinstance(locs, dict) else locs):
            names[l["id"]] = l["name"]
    except Exception:
        pass
    entries = [{"file": f"audio/ambiences/{a}.m4a", "title": names.get(a, a),
                "loop": True} for a in done]
    entries.sort(key=lambda e: e["title"].lower())
    with open(os.path.join(OUT, "manifest.json"), "w", encoding="utf-8") as f:
        json.dump({"ambiences": entries}, f, ensure_ascii=False, indent=2)

    print(f"\nTotal : {len(done)} / {len(TERMS)}", flush=True)


if __name__ == "__main__":
    main()

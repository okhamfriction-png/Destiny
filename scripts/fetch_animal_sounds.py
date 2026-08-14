#!/usr/bin/env python3
"""Télécharge de VRAIS cris d'animaux (licences libres) depuis Wikimedia
Commons vers assets/audio/animals/. Choisit, par archétype, un fichier audio
court. Affiche un récap (id -> fichier) à coller dans le code Dart.

Usage : python3 scripts/fetch_animal_sounds.py
"""
import json
import os
import ssl
import urllib.parse
import urllib.request

# Python sur macOS n'a pas toujours les certificats : contexte non vérifié.
SSL_CTX = ssl.create_default_context()
SSL_CTX.check_hostname = False
SSL_CTX.verify_mode = ssl.CERT_NONE

OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "animals")
UA = "DestinyApp/1.0 (educational improv app; contact: okhamfriction@gmail.com)"
API = "https://commons.wikimedia.org/w/api.php"

# id d'archétype -> termes de recherche (du plus précis au plus générique)
ANIMALS = {
    "aigle": ["bald eagle call", "eagle call", "eagle sound"],
    "ane": ["donkey bray", "donkey sound"],
    "cerf": ["red deer roar", "stag bellow", "elk bugle", "deer call"],
    "chat": ["cat meowing", "domestic cat", "kitten meow", "cat meow"],
    "chien": ["domestic dog bark", "puppy bark", "dog barking", "dog"],
    "coq": ["rooster crow", "cock crow"],
    "corbeau": ["common raven call", "crow call", "raven sound"],
    "fourmi": [],  # pas de cri
    "hibou": ["owl hoot", "tawny owl call", "owl call"],
    "hyene": ["spotted hyena whoop", "hyena call", "Crocuta crocuta"],
    "lapin": ["rabbit squeal", "European rabbit", "rabbit distress"],
    "lion": ["lion roaring", "Panthera leo roar", "lion male roar", "lion"],
    "loup": ["wolf howl", "gray wolf howl"],
    "mouton": ["sheep bleat", "sheep baa"],
    "ours": ["brown bear growl", "bear roar", "bear sound"],
    "paon": ["Indian peafowl call", "peacock cry", "peafowl call"],
    "porc": ["pig grunt", "pig oink", "domestic pig"],
    "rat": ["brown rat", "rat vocalization", "rat squeak"],
    "renard": ["red fox call", "fox scream", "fox sound"],
    "serpent": ["snake hiss", "rattlesnake"],
    "singe": ["macaque vocalization", "gibbon call", "chimpanzee pant hoot",
              "monkey call"],
    "souris": ["mouse squeak", "mouse sound"],
    "taureau": ["bull bellow", "cattle moo", "cow moo"],
    "vautour": ["vulture sound", "griffon vulture"],
}

MAX_BYTES = 1_700_000
MIN_BYTES = 2_000


def existing(aid):
    for ext in ("mp3", "ogg", "wav"):
        if os.path.exists(os.path.join(OUT, f"{aid}.{ext}")):
            return f"{aid}.{ext}"
    return None


def api_get(params):
    qs = urllib.parse.urlencode(params)
    req = urllib.request.Request(f"{API}?{qs}", headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=25, context=SSL_CTX) as r:
        return json.load(r)


def find_audio(term):
    """Retourne (url, mime, size) du meilleur fichier audio pour `term`."""
    try:
        data = api_get({
            "action": "query", "format": "json",
            "generator": "search", "gsrnamespace": "6", "gsrlimit": "20",
            "gsrsearch": f"{term} filetype:audio",
            "prop": "imageinfo", "iiprop": "url|mime|size",
        })
    except Exception as e:
        print(f"    ! recherche échouée: {e}")
        return None
    pages = (data.get("query") or {}).get("pages") or {}
    cands = []
    for p in pages.values():
        ii = (p.get("imageinfo") or [{}])[0]
        mime = ii.get("mime", "")
        size = ii.get("size", 0)
        url = ii.get("url")
        if url and mime.startswith("audio/") and MIN_BYTES <= size <= MAX_BYTES:
            cands.append((size, url, mime))
    cands.sort()  # plus petit d'abord (clip court)
    return cands[0] if cands else None


def download(url, dest):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=40, context=SSL_CTX) as r:
        data = r.read()
    with open(dest, "wb") as f:
        f.write(data)
    return len(data)


def main():
    os.makedirs(OUT, exist_ok=True)
    result = {}
    for aid, terms in ANIMALS.items():
        if not terms:
            print(f"{aid}: (pas de cri) -> synthèse")
            continue
        have = existing(aid)
        if have:
            result[aid] = have
            print(f"{aid}: déjà présent ({have})")
            continue
        got = None
        for term in terms:
            hit = find_audio(term)
            if hit:
                size, url, mime = hit
                ext = url.rsplit(".", 1)[-1].lower()
                if ext not in ("ogg", "oga", "wav", "mp3"):
                    continue
                if ext == "oga":
                    ext = "ogg"
                dest = os.path.join(OUT, f"{aid}.{ext}")
                try:
                    n = download(url, dest)
                    result[aid] = f"{aid}.{ext}"
                    print(f"{aid}: OK  {term}  ({n//1024} Ko, {ext})")
                    got = True
                    break
                except Exception as e:
                    print(f"    ! download échoué ({term}): {e}")
        if not got:
            print(f"{aid}: ÉCHEC -> synthèse")

    print("\n=== MAP Dart (id -> fichier) ===")
    for aid in ANIMALS:
        if aid in result:
            print(f"    '{aid}': '{result[aid]}',")
    print("\nTotal réels:", len(result), "/", len(ANIMALS))


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Prépare le pack audio embarqué dans l'appli Android.

    python3 tool/pack_embarque.py [racine_pack]

Copie les fichiers du pack (« Musiques Destiny » et « Bruitages », sans
« Sonniss GDC 2026 », comme le serveur de régie web) et son manifeste dans le
module Play Asset Delivery `android/destiny_pack` (livré à l'installation, avec
l'appli, mais hors de la limite de 200 Mo du module de base).

Les fichiers sont renommés (`f/<empreinte>.<ext>`) : pas d'accent ni d'espace
dans les chemins des assets. `index.json` fait le lien chemin du pack → fichier.
Le dossier produit n'est pas versionné (gros binaires) : sans lui, l'appli se
construit sans pack embarqué.
"""

import hashlib
import json
import os
import shutil
import sys
import unicodedata

ICI = os.path.dirname(os.path.abspath(__file__))
PACK = sys.argv[1] if len(sys.argv) > 1 else "/Volumes/ShikaZero/Spectacle"
SORTIE = os.path.join(ICI, "..", "android", "destiny_pack", "src", "main", "assets",
                      "flutter_assets", "assets", "pack")
DOSSIERS = ["Musiques Destiny", "Bruitages"]
IGNORES = ["Bruitages/Sonniss GDC 2026"]
AUDIO = {".mp3", ".m4a", ".ogg", ".wav", ".aac", ".flac", ".opus"}
MANIFESTE = "Pack audio DestinyStory/destiny_audio_manifest.json"


def nfc(s):
    return unicodedata.normalize("NFC", s)


def ignore(relatif):
    r = nfc(relatif)
    return any(r == i or r.startswith(i + "/") for i in IGNORES)


def fichiers():
    trouves = []
    for d in DOSSIERS:
        for racine, dossiers, noms in os.walk(os.path.join(PACK, d)):
            rel = os.path.relpath(racine, PACK).replace(os.sep, "/")
            if ignore(rel):
                dossiers[:] = []
                continue
            for n in noms:
                if n.startswith("._") or os.path.splitext(n)[1].lower() not in AUDIO:
                    continue
                trouves.append(nfc(f"{rel}/{n}"))
    return sorted(trouves)


def main():
    if not os.path.isdir(PACK):
        sys.exit(f"Pack introuvable : {PACK} (le NAS est-il monté ?)")
    liste = fichiers()
    if not liste:
        sys.exit("Aucun fichier audio dans le pack.")
    if os.path.isdir(SORTIE):
        shutil.rmtree(SORTIE)
    os.makedirs(os.path.join(SORTIE, "f"))
    table = {}
    total = 0
    for rel in liste:
        ext = os.path.splitext(rel)[1].lower()
        nom = "f/" + hashlib.sha1(rel.encode("utf-8")).hexdigest()[:16] + ext
        source = os.path.join(PACK, unicodedata.normalize("NFD", rel))
        if not os.path.isfile(source):
            source = os.path.join(PACK, rel)
        shutil.copyfile(source, os.path.join(SORTIE, nom))
        total += os.path.getsize(source)
        table[rel] = nom
    with open(os.path.join(SORTIE, "index.json"), "w", encoding="utf-8") as f:
        json.dump({"fichiers": table}, f, ensure_ascii=False)
    m = os.path.join(PACK, MANIFESTE)
    if os.path.isfile(m):
        shutil.copyfile(m, os.path.join(SORTIE, "destiny_audio_manifest.json"))
    print(f"{len(table)} fichiers ({total / 1e6:.0f} Mo) → {os.path.normpath(SORTIE)}"
          + ("" if os.path.isfile(m) else " (sans manifeste)"))


if __name__ == "__main__":
    main()

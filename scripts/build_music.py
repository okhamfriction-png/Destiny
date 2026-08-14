#!/usr/bin/env python3
"""Compresse les musiques de Sound/ en AAC (~96 kbps) dans assets/music/,
tronque les ambiances longues à 4 min (lecture bouclée), et écrit
assets/music/manifest.json (titre + catégorie + boucle).

Outils : afconvert (natif macOS) + module wave (stdlib). Résumable.
"""
import json
import os
import re
import subprocess
import wave

ROOT = os.path.join(os.path.dirname(__file__), "..")
SRC = os.path.join(ROOT, "Sound")
OUT = os.path.join(ROOT, "assets", "music")
TMP = "/tmp/destiny_music"
BITRATE = "96000"
TRIM_SECONDS = 240
TRIM_THRESHOLD = 360  # au-delà, on tronque

ATM_TITLES = {
    "Beach": "Plage", "Blizzard": "Blizzard", "Cave": "Grotte", "City": "Ville",
    "Forest": "Forêt", "Rain": "Pluie", "Sewers": "Égouts", "Ship": "Navire",
    "Swamp": "Marais", "Tavern": "Taverne", "Thunderstorm": "Orage",
    "Volcano": "Volcan",
}
EMO_TITLES = {
    "Climax": "Climax", "Colere": "Colère", "Emerveillement": "Émerveillement",
    "Joie": "Joie", "Mystere": "Mystère", "Nostalgie": "Nostalgie",
    "Peur": "Peur", "Receuillement": "Recueillement", "Surprise": "Surprise",
    "Tension": "Tension", "Trahison": "Trahison", "Traque": "Traque",
    "Tristesse": "Tristesse",
}
THEME_TITLES = {
    "01.Commencement": "Commencement",
    "02.ConclusionAinsiQue": "Conclusion",
    "Ashen Oath - AI Music": "Ashen Oath",
    "DestinyStorm": "Destiny Storm",
}


def safe_name(stem):
    s = stem.strip().lower()
    s = re.sub(r"[^a-z0-9]+", "_", s).strip("_")
    return s


def duration(path):
    try:
        out = subprocess.run(["afinfo", path], capture_output=True, text=True).stdout
        m = re.search(r"estimated duration:\s*([0-9.]+)", out)
        return float(m.group(1)) if m else 0.0
    except Exception:
        return 0.0


def decode_to_wav(src, dst):
    subprocess.run(
        ["afconvert", "-f", "WAVE", "-d", "LEI16@44100", src, dst],
        check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    )


def trim_wav(src, dst, seconds):
    with wave.open(src, "rb") as w:
        fr = w.getframerate()
        params = w.getparams()
        frames = w.readframes(int(seconds * fr))
    with wave.open(dst, "wb") as o:
        o.setparams(params)
        o.writeframes(frames)


def encode(src_wav, dst):
    subprocess.run(
        ["afconvert", "-f", "m4af", "-d", "aac", "-b", BITRATE, src_wav, dst],
        check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
    )


def meta(stem):
    if stem.startswith("ATM_"):
        key = stem[4:].strip()
        return "Ambiances", ATM_TITLES.get(key, key)
    if stem.startswith("EMO_"):
        m = re.match(r"([A-Za-z]+)(\d*)", stem[4:])
        base, num = m.group(1), m.group(2)
        title = EMO_TITLES.get(base, base)
        return "Émotions", f"{title} {num}".strip()
    return "Thèmes", THEME_TITLES.get(stem, stem)


def main():
    os.makedirs(OUT, exist_ok=True)
    os.makedirs(TMP, exist_ok=True)
    entries = []
    files = sorted(os.listdir(SRC))
    for fname in files:
        src = os.path.join(SRC, fname)
        if not os.path.isfile(src):
            continue
        stem, ext = os.path.splitext(fname)
        ext = ext.lower()
        if ext not in (".wav", ".m4a", ".mp3"):
            continue
        category, title = meta(stem.strip())
        out_name = safe_name(stem) + ".m4a"
        out_path = os.path.join(OUT, out_name)
        dur = duration(src)
        loop = stem.strip().startswith("ATM_")
        long_track = loop or dur > TRIM_THRESHOLD

        if not os.path.exists(out_path):
            try:
                if long_track:
                    if ext == ".wav":
                        trimmed = os.path.join(TMP, "trim.wav")
                        trim_wav(src, trimmed, TRIM_SECONDS)
                    else:
                        full = os.path.join(TMP, "full.wav")
                        decode_to_wav(src, full)
                        trimmed = os.path.join(TMP, "trim.wav")
                        trim_wav(full, trimmed, TRIM_SECONDS)
                        os.remove(full)
                    encode(trimmed, out_path)
                    os.remove(trimmed)
                else:
                    if ext == ".wav":
                        encode(src, out_path)
                    else:
                        tmp = os.path.join(TMP, "in.wav")
                        decode_to_wav(src, tmp)
                        encode(tmp, out_path)
                        os.remove(tmp)
                print(f"OK  {out_name}  [{category}] {title}", flush=True)
            except Exception as exc:  # noqa: BLE001
                print(f"ERREUR  {fname}: {exc}", flush=True)
                continue
        entries.append({
            "file": f"music/{out_name}",
            "title": title,
            "category": category,
            "loop": loop,
        })

    # Ordre des catégories pour l'affichage.
    order = {"Ambiances": 0, "Émotions": 1, "Thèmes": 2}
    entries.sort(key=lambda e: (order.get(e["category"], 9), e["title"]))
    with open(os.path.join(OUT, "manifest.json"), "w") as fh:
        json.dump({"tracks": entries}, fh, ensure_ascii=False, indent=2)

    total = sum(
        os.path.getsize(os.path.join(OUT, f))
        for f in os.listdir(OUT) if f.endswith(".m4a")
    )
    print(f"\n{len(entries)} pistes · {total/1e6:.1f} Mo total")


if __name__ == "__main__":
    main()

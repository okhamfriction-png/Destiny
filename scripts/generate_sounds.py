#!/usr/bin/env python3
"""Synthétise 3 effets sonores en WAV (44.1 kHz, 16-bit mono) dans
assets/audio/ : story_epic.wav, coin.wav, dice.wav. Aucune dépendance
externe (stdlib `wave`). Relancer pour regénérer.
"""
import math
import os
import random
import struct
import wave

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")


def write_wav(name, samples):
    peak = max(1e-9, max(abs(s) for s in samples))
    gain = 0.9 / peak
    path = os.path.join(OUT, name)
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        frames = bytearray()
        for s in samples:
            v = int(max(-1.0, min(1.0, s * gain)) * 32767)
            frames += struct.pack("<h", v)
        w.writeframes(frames)
    print(f"OK  {name}  ({len(samples)/SR:.2f}s)")


def story_epic():
    """Arpège majeur ascendant + nappe + shimmer : épique et positif."""
    dur = 2.0
    n = int(SR * dur)
    buf = [0.0] * n
    notes = [130.81, 261.63, 329.63, 392.00, 523.25, 659.25]  # C maj sur 2 oct.
    for i, f in enumerate(notes):
        onset = i * 0.10
        for k in range(n):
            lt = k / SR - onset
            if lt < 0:
                continue
            atk = min(1.0, lt / 0.02)
            dec = math.exp(-lt * 1.1)
            s = math.sin(2 * math.pi * f * lt) + 0.5 * math.sin(2 * math.pi * f * 1.003 * lt)
            buf[k] += 0.28 * atk * dec * s
    # Shimmer aigu avec vibrato sur la fin.
    fh = 1046.5
    for k in range(n):
        t = k / SR
        if t < 0.55:
            continue
        lt = t - 0.55
        vib = 1 + 0.005 * math.sin(2 * math.pi * 5 * lt)
        buf[k] += 0.12 * math.exp(-lt * 0.9) * math.sin(2 * math.pi * fh * vib * lt)
    return buf


def coin():
    """Tintement métallique de pièce : partiels inharmoniques, double ping."""
    dur = 0.45
    n = int(SR * dur)
    buf = [0.0] * n
    partials = [(1975, 1.0), (2637, 0.7), (3136, 0.5), (4200, 0.3)]
    for onset in (0.0, 0.075):
        for k in range(n):
            lt = k / SR - onset
            if lt < 0:
                continue
            dec = math.exp(-lt * 13)
            s = sum(a * math.sin(2 * math.pi * f * lt) for f, a in partials)
            buf[k] += 0.5 * dec * s
    return buf


def dice():
    """Cliquetis de dé : quelques impulsions de bruit + thud final."""
    dur = 0.5
    n = int(SR * dur)
    buf = [0.0] * n
    random.seed(7)
    for onset in (0.0, 0.06, 0.11, 0.20, 0.27):
        amp = random.uniform(0.5, 1.0)
        start = int(onset * SR)
        clen = int(SR * 0.03)
        for j in range(clen):
            k = start + j
            if k >= n:
                break
            dec = math.exp(-(j / SR) * 120)
            noise = random.uniform(-1, 1)
            tone = math.sin(2 * math.pi * 900 * (j / SR))
            buf[k] += amp * dec * (0.7 * noise + 0.3 * tone)
    # Thud grave de repos.
    start = int(0.27 * SR)
    for j in range(n - start):
        t = j / SR
        buf[start + j] += 0.5 * math.exp(-t * 18) * math.sin(2 * math.pi * 180 * t)
    return buf


def crack():
    """Bris de verre : transitoire aigu + éclats + thud grave (échec)."""
    dur = 0.7
    n = int(SR * dur)
    buf = [0.0] * n
    random.seed(11)
    # Éclatement initial.
    for j in range(n):
        t = j / SR
        dec = math.exp(-t * 24)
        noise = random.uniform(-1, 1)
        hi = math.sin(2 * math.pi * 3200 * t)
        buf[j] += dec * (0.8 * noise + 0.2 * hi)
    # Éclats secondaires.
    for onset in (0.06, 0.12, 0.18, 0.26, 0.34, 0.42):
        start = int(onset * SR)
        amp = random.uniform(0.4, 0.9)
        clen = int(SR * 0.045)
        ftone = random.uniform(1500, 4200)
        for j in range(clen):
            k = start + j
            if k >= n:
                break
            dec = math.exp(-(j / SR) * 55)
            noise = random.uniform(-1, 1)
            tone = math.sin(2 * math.pi * ftone * (j / SR))
            buf[k] += amp * dec * (0.6 * noise + 0.4 * tone)
    # Thud grave.
    for j in range(n):
        t = j / SR
        buf[j] += 0.4 * math.exp(-t * 15) * math.sin(2 * math.pi * 120 * t)
    return buf


def shine():
    """Éclat lumineux ascendant et brillant (réussite, façon Hearthstone)."""
    dur = 0.9
    n = int(SR * dur)
    buf = [0.0] * n
    notes = [523.25, 659.25, 783.99, 1046.5, 1318.5]  # do mi sol do mi
    for i, f in enumerate(notes):
        onset = i * 0.05
        for k in range(n):
            lt = k / SR - onset
            if lt < 0:
                continue
            atk = min(1.0, lt / 0.005)
            dec = math.exp(-lt * 3.0)
            s = math.sin(2 * math.pi * f * lt) + 0.4 * math.sin(2 * math.pi * 2 * f * lt)
            buf[k] += 0.22 * atk * dec * s
    # Traîne scintillante.
    for k in range(n):
        t = k / SR
        vib = 1 + 0.004 * math.sin(2 * math.pi * 7 * t)
        buf[k] += 0.08 * math.exp(-t * 2.0) * math.sin(2 * math.pi * 2093 * vib * t)
    return buf


def thunder():
    """Coup de foudre : claquement sec puis grondement grave (montée du danger)."""
    dur = 1.8
    n = int(SR * dur)
    buf = [0.0] * n
    random.seed(23)
    # Claquement de l'éclair.
    for j in range(n):
        t = j / SR
        dec = math.exp(-t * 28)
        buf[j] += dec * 0.9 * random.uniform(-1, 1)
    # Grondement grave (bruit passe-bas modulé).
    rumble = 0.0
    for j in range(n):
        t = j / SR
        noise = random.uniform(-1, 1)
        rumble += (noise - rumble) * 0.02  # passe-bas une cellule
        env = math.exp(-t * 1.4) * (0.6 + 0.4 * math.sin(2 * math.pi * 3 * t))
        buf[j] += 1.2 * env * rumble
    return buf


def epic_hit(n):
    """Coup orchestral épique : sub-boom + accord de cuivres + cymbale."""
    buf = [0.0] * n
    random.seed(5)
    # Sub boom.
    for k in range(n):
        t = k / SR
        buf[k] += 0.9 * math.exp(-t * 5) * math.sin(2 * math.pi * 55 * t)
    # Accord de cuivres (do majeur), timbre riche en harmoniques.
    for f in (130.81, 164.81, 196.00, 261.63):
        for k in range(n):
            t = k / SR
            atk = min(1.0, t / 0.05)
            env = atk * math.exp(-t * 2.2)
            s = sum((1.0 / h) * math.sin(2 * math.pi * f * h * t) for h in range(1, 6))
            buf[k] += 0.10 * env * s
    # Cymbale (bruit).
    for k in range(n):
        t = k / SR
        buf[k] += 0.16 * math.exp(-t * 3) * random.uniform(-1, 1) * min(1.0, t / 0.02)
    return buf


def _roar(n):
    buf = [0.0] * n
    random.seed(1)
    for k in range(n):
        t = k / SR
        base = 120 * (1 + 0.3 * math.exp(-t * 2.2))
        am = 0.5 + 0.5 * math.sin(2 * math.pi * 28 * t)
        s = sum((1.0 / h) * math.sin(2 * math.pi * base * h * t) for h in range(1, 8))
        env = min(1.0, t / 0.05) * math.exp(-t * 1.6)
        buf[k] = env * (0.7 * s * am + 0.3 * random.uniform(-1, 1))
    return buf


def _howl(n):
    buf = [0.0] * n
    dur = n / SR
    for k in range(n):
        t = k / SR
        p = t / dur
        f = 300 + 260 * math.sin(math.pi * p)
        vib = 1 + 0.02 * math.sin(2 * math.pi * 6 * t)
        env = min(1.0, t / 0.1) * min(1.0, (dur - t) / 0.25)
        s = math.sin(2 * math.pi * f * vib * t) + 0.4 * math.sin(2 * math.pi * 2 * f * vib * t)
        buf[k] = 0.7 * env * s
    return buf


def _bird(n):
    buf = [0.0] * n
    random.seed(3)
    for onset in (0.0, 0.2, 0.4):
        f0 = random.uniform(900, 1600)
        clen = int(SR * 0.15)
        for j in range(clen):
            k = int(onset * SR) + j
            if k >= n:
                break
            t = j / SR
            f = f0 * (1 + 0.5 * math.exp(-t * 20))
            env = min(1.0, t / 0.005) * math.exp(-t * 8)
            buf[k] += 0.7 * env * (math.sin(2 * math.pi * f * t) + 0.3 * random.uniform(-1, 1))
    return buf


def _squeak(n):
    buf = [0.0] * n
    for onset in (0.0, 0.1, 0.2):
        clen = int(SR * 0.06)
        for j in range(clen):
            k = int(onset * SR) + j
            if k >= n:
                break
            t = j / SR
            f = 2200 + 1500 * math.exp(-t * 30)
            env = min(1.0, t / 0.003) * math.exp(-t * 22)
            buf[k] += 0.6 * env * math.sin(2 * math.pi * f * t)
    return buf


def _hiss(n):
    buf = [0.0] * n
    dur = n / SR
    prev = 0.0
    for k in range(n):
        t = k / SR
        noise = random.uniform(-1, 1)
        hp = noise - prev
        prev = noise
        env = min(1.0, t / 0.08) * min(1.0, (dur - t) / 0.2)
        buf[k] = 0.45 * env * hp
    return buf


def _bray(n):
    buf = [0.0] * n
    seg = n // 2
    for k in range(n):
        t = k / SR
        f = 380 if k < seg else 180
        s = math.sin(2 * math.pi * f * t) + 0.3 * math.sin(2 * math.pi * 2 * f * t)
        rasp = 1 + 0.4 * math.sin(2 * math.pi * 45 * t)
        env = min(1.0, t / 0.03)
        buf[k] = 0.5 * env * s * rasp
    return buf


def beast(call_fn, dur=1.7):
    """Révélation d'archétype : coup épique + cri de la créature par-dessus."""
    n = int(SR * dur)
    buf = epic_hit(n)
    call = call_fn(int(SR * (dur - 0.35)))
    off = int(SR * 0.35)
    for j, v in enumerate(call):
        if off + j < n:
            buf[off + j] += v
    return buf


def reveal():
    """Révélation d'archétype : gros tambour taïko (boum-boum) + coup de foudre."""
    dur = 1.7
    n = int(SR * dur)
    buf = [0.0] * n
    random.seed(9)
    # Deux gros coups de tambour.
    for onset in (0.0, 0.28):
        start = int(onset * SR)
        for j in range(n - start):
            t = j / SR
            f = 55 + 130 * math.exp(-t * 9)  # attaque haute -> grave
            env = math.exp(-t * 6)
            click = math.exp(-t * 130) * random.uniform(-1, 1)
            buf[start + j] += 0.9 * env * math.sin(2 * math.pi * f * t) + 0.35 * click
    # Coup de foudre par-dessus : claquement + grondement.
    for j in range(n):
        t = j / SR
        buf[j] += 0.45 * math.exp(-t * 26) * random.uniform(-1, 1)
    rumble = 0.0
    for j in range(n):
        t = j / SR
        noise = random.uniform(-1, 1)
        rumble += (noise - rumble) * 0.02
        buf[j] += 0.7 * math.exp(-t * 1.7) * rumble
    return buf


def main():
    os.makedirs(OUT, exist_ok=True)
    write_wav("story_epic.wav", story_epic())
    write_wav("coin.wav", coin())
    write_wav("dice.wav", dice())
    write_wav("crack.wav", crack())
    write_wav("shine.wav", shine())
    write_wav("thunder.wav", thunder())
    write_wav("reveal.wav", reveal())


if __name__ == "__main__":
    main()

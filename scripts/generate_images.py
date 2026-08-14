#!/usr/bin/env python3
"""Génère les images d'entités via l'API Images d'OpenAI (gpt-image-1),
les redimensionne (512px JPEG via `sips`) et les enregistre dans
assets/images/{locations,dangers,archetypes}/{id}.jpg.

Usage :
  OPENAI_API_KEY=sk-... python3 scripts/generate_images.py
Options (env) :
  IMAGE_MODEL    (def: gpt-image-1 ; fallback possible: dall-e-3)
  IMAGE_QUALITY  (def: medium ; dall-e-3: standard|hd)
  ONLY           (def: all ; ex: "dangers" ou "locations,dangers")

Le script est RÉSUMABLE : il saute les fichiers déjà présents. En cas
d'erreur (rate limit, etc.), relancez-le simplement.
"""
import base64
import json
import os
import subprocess
import sys
import tempfile
import time

API_KEY = os.environ.get("OPENAI_API_KEY")
MODEL = os.environ.get("IMAGE_MODEL", "gpt-image-1")
QUALITY = os.environ.get("IMAGE_QUALITY", "medium")
ONLY = os.environ.get("ONLY", "all")
SIZE = "1024x1024"
OUT_ROOT = os.path.join(os.path.dirname(__file__), "..", "assets", "images")

LOCATIONS = {
    "aeroport": "an airport terminal",
    "laboratoire": "a science research laboratory",
    "hotel_luxe": "a luxury hotel lobby",
    "ferme": "a rural farm",
    "bunker_militaire": "a military bunker",
    "bibliotheque": "an old library full of books",
    "usine": "an industrial factory floor",
    "restaurant_gastronomique": "an elegant fine dining restaurant",
    "commissariat": "a police station",
    "centre_commercial": "a large shopping mall",
    "zoo": "a zoo",
    "musee": "a natural history museum hall with a large dinosaur skeleton and visitors",
    "camping": "a campsite with tents in nature",
    "plateau_tele": "a television studio set",
    "boite_nuit": "a nightclub dance floor",
    "base_spatiale": "a futuristic space station interior",
    "bureau": "a corporate office workplace",
    "palais_presidentiel": "a grand presidential palace",
    "manoir_abandonne": "an abandoned haunted mansion",
    "prison": "a prison cell block",
    "stade": "a packed sports stadium",
    "refuge_montagne": "a mountain refuge hut in the snow",
    "banque": "a bank interior",
    "aquarium": "a public aquarium with glass tanks",
    "avion": "the interior cabin of an airplane in flight, passengers and seats",
    "port_maritime": "a maritime harbor port",
    "eglise": "a church interior with stained glass",
    "salle_sport": "a fitness gym",
    "foret": "a deep forest",
    "sous_marin": "the interior control room of a submarine, crew and instruments",
    "metro": "a subway station and train",
    "navire_croisiere": "a cruise ship deck",
    "universite": "a university campus hall",
    "hopital": "a hospital corridor",
    "ecole": "a school classroom",
    "supermarche": "a supermarket aisle",
    "casino": "a casino gaming floor",
    "theatre": "a theater stage with red curtains",
    "tribunal": "a courtroom",
    "station_service": "a gas station at night",
}

DANGERS = {
    "tempete": "a violent storm with lightning and wind",
    "inondation": "a sudden flood, rising water everywhere",
    "tremblement_terre": "an earthquake cracking the ground, buildings shaking",
    "soleil_grossit": "the sun swelling enormous in the sky, everything scorching, blinding burning heat",
    "soleil_eteint": "the sun going dark, creeping cold and ice taking over",
    "air_irrespirable": "the air becoming unbreathable, people gasping, heavy hazy atmosphere",
    "murs_referment": "the walls closing in, a shrinking crushing room",
    "gouffre": "a chasm suddenly opening in the ground, people at the crumbling edge",
    "maladie_contagieuse": "a fast spreading epidemic outbreak, panic",
    "brume_etrange": "an eerie maddening fog rolling in",
    "nuage_toxique": "a creeping toxic gas cloud spreading",
    "verrouillage": "everything locking down, heavy sealed doors, trapped inside",
    "ia_controle": "a rogue AI taking control, glowing screens and red warning lights",
    "noir_total": "total pitch black darkness with a single faint light",
    "reaction_chimique": "a gas leak about to explode, sparks near a hissing valve",
    "bombe_retardement": "a place about to self-destruct, countdown timer and alarms",
    "raz_de_maree": "a giant tidal wave tsunami towering and approaching",
    "incendie": "a raging fire with flames",
    "volcan": "an erupting volcano spewing lava",
    "tornade": "a powerful tornado tearing through",
    "invasion_creature": "a monstrous creature stalking and hunting people",
    "zombies": "a spooky halloween horror scene, eerie undead silhouettes shambling through fog at night, no gore no blood",
    "meute": "a pack of feral animals unleashed and charging",
    "monstre_geant": "a colossal giant monster towering over a city",
    "essaim": "a massive menacing swarm of insects",
    "requin": "a menacing shark attacking in the water",
    "braquage": "an armed robbery heist in progress",
    "prise_otage": "a tense hostage situation",
    "tueur_en_serie": "an ominous serial killer scene",
    "emeute_hostile": "a violent hostile riot crowd",
    "traques": "being hunted, fleeing pursuers in the dark",
    "siege_arme": "war breaking out, soldiers and explosions",
    "naufrage": "a shipwreck sinking in a stormy sea",
    "crash_exterieur": "a plane crash with smoke and debris",
    "perdus_nature": "lost in the vast wild wilderness",
    "invasion_alien": "an alien invasion, UFOs over a city",
    "robots_rebelle": "rebelling robots rising up against humans",
    "jeu_mortel": "a deadly game, a sinister trap arena",
}

ARCHETYPES = {
    "aigle": "a majestic eagle with a proud, commanding, ambitious gaze",
    "ane": "a stubborn donkey with a goofy, playful, easygoing expression",
    "cerf": "a noble deer stag, dignified, upright and proud",
    "chat": "a sly charming cat with a mysterious, smug, slightly cruel smile",
    "chien": "a friendly loyal dog, joyful, brave and eager",
    "coq": "a vain rooster strutting confidently, arrogant and boastful",
    "corbeau": "a mysterious dark raven with a cunning, brooding stare",
    "fourmi": "a small hardworking ant, serious and determined",
    "hibou": "a wise owl with a knowing, studious, know-it-all expression",
    "hyene": "a cruel hyena with a wicked, mocking grin",
    "lapin": "a cheerful playful rabbit, lively and eager to please",
    "lion": "a dominant majestic lion, regal, charismatic and commanding",
    "loup": "a fierce wolf with an intense, fierce yet loyal gaze",
    "mouton": "a meek gentle sheep, cautious, friendly and a follower",
    "ours": "a powerful protective bear, big, strong and calm",
    "paon": "a flamboyant peacock showing off its feathers, vain and sociable",
    "porc": "a jolly hedonistic pig at a feast, festive and greedy",
    "rat": "a sly greedy rat with a sneaky, mean little look",
    "renard": "a cunning charming fox with a clever, seductive grin",
    "serpent": "a cold calculating snake with a piercing, scheming, cynical stare",
    "singe": "a mischievous monkey laughing and joking playfully",
    "souris": "a brave little mouse, cheerful and bold",
    "taureau": "an imposing powerful bull, fierce and unstoppable",
    "vautour": "a lanky cynical vulture with a mocking, sardonic look",
}

BASE_STYLE = (
    "Photorealistic cinematic photograph, about 80% photoreal with only a slight "
    "artistic cinematic stylization, realistic lighting textures and materials, "
    "sharp focus, high detail, vibrant yet natural colors, bright and clearly lit. "
    "Not a painting, not cartoon, no painterly brushstrokes. "
    "No text, no title, no logo, no watermark, no caption, no border."
)


def prompt_for(kind, subject):
    if kind == "archetypes":
        # Portrait de personnage expressif, fond uni coloré -> bien distinct.
        return (
            f"{BASE_STYLE} An expressive photorealistic close-up wildlife portrait "
            f"of {subject}. Strong personality and clear emotion on the face, "
            "bright vivid lighting, colorful simple background, realistic fur and "
            "feather detail."
        )
    if kind == "dangers":
        # Scène dramatique dynamique -> bien distinct.
        return (
            f"{BASE_STYLE} A dramatic dynamic cinematic scene evoking {subject}. "
            "Strong sense of action and tension, but colorful and clearly lit."
        )
    # Lieu : plan large d'environnement, lumière propre au lieu.
    return (
        f"{BASE_STYLE} A wide establishing environment shot of {subject}. "
        "Lighting, colors and atmosphere that naturally fit this specific place "
        "(bright and lively where it should be, dim only where it truly should be)."
    )


def generate(prompt):
    payload = {"model": MODEL, "prompt": prompt, "size": SIZE, "n": 1, "quality": QUALITY}
    if not MODEL.startswith("gpt-image"):
        payload["response_format"] = "b64_json"  # dall-e-3 et compat.
    # On passe par `curl` : l'urllib de certains Python macOS n'a pas les
    # certificats CA et échoue en SSL, alors que curl utilise ceux du système.
    bf = tempfile.NamedTemporaryFile("w", suffix=".json", delete=False)
    json.dump(payload, bf)
    bf.close()
    try:
        out = subprocess.run(
            [
                "curl", "-s", "-X", "POST",
                "https://api.openai.com/v1/images/generations",
                "-H", f"Authorization: Bearer {API_KEY}",
                "-H", "Content-Type: application/json",
                "-d", f"@{bf.name}",
            ],
            capture_output=True, text=True, timeout=300,
        )
    finally:
        os.remove(bf.name)
    data = json.loads(out.stdout or "{}")
    if "data" not in data:
        raise RuntimeError(data.get("error", {}).get("message", out.stdout[:300]))
    return base64.b64decode(data["data"][0]["b64_json"])


def main():
    if not API_KEY:
        sys.exit("OPENAI_API_KEY manquant.")
    sets = {"locations": LOCATIONS, "dangers": DANGERS, "archetypes": ARCHETYPES}
    only = None if ONLY == "all" else set(ONLY.split(","))
    done = skipped = errors = 0
    for kind, mapping in sets.items():
        if only and kind not in only:
            continue
        out_dir = os.path.join(OUT_ROOT, kind)
        os.makedirs(out_dir, exist_ok=True)
        for id_, subject in mapping.items():
            out_jpg = os.path.join(out_dir, f"{id_}.jpg")
            if os.path.exists(out_jpg):
                skipped += 1
                continue
            try:
                png = generate(prompt_for(kind, subject))
            except Exception as exc:  # noqa: BLE001
                errors += 1
                print(f"ERREUR  {kind}/{id_}: {exc}", flush=True)
                time.sleep(2)
                continue
            tmp_png = os.path.join(out_dir, f"{id_}.png")
            with open(tmp_png, "wb") as fh:
                fh.write(png)
            subprocess.run(
                ["sips", "-Z", "512", "--setProperty", "format", "jpeg", tmp_png, "--out", out_jpg],
                check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            )
            os.remove(tmp_png)
            done += 1
            print(f"OK      {kind}/{id_}.jpg ({done} générées)", flush=True)
            time.sleep(1)
    print(f"\nTerminé : {done} générées, {skipped} déjà présentes, {errors} erreurs.")


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Sert la version web de DestinyStory avec le pack audio du spectacle, pour
répéter la régie son dans un navigateur, en local.

    python3 tool/serveur_regie_web.py [port] [racine_pack] [dossier_web]

- /destiny_pack/index.json : la liste des fichiers audio de « Musiques Destiny »
  et « Bruitages » (sans « Sonniss GDC 2026 »), lus sur place (le NAS) ;
- /destiny_pack/destiny_audio_manifest.json : le manifeste du pack ;
- /destiny_pack/<chemin> : le fichier lui-même ;
- tout le reste : la version web compilée (build/web).

Rien n'est copié dans le build. Le pack reste privé : ne pas publier ce
serveur ni le pack (la version web de docs/app n'en a pas, et c'est voulu).
Le port vient de $PORT s'il est défini (aperçu du Browser de Claude).
"""
import http.server
import json
import mimetypes
import os
import sys
import unicodedata
import urllib.parse

ICI = os.path.dirname(os.path.abspath(__file__))
PORT = int(os.environ.get("PORT") or (sys.argv[1] if len(sys.argv) > 1 else 8095))
PACK = sys.argv[2] if len(sys.argv) > 2 else "/Volumes/ShikaZero/Spectacle"
WEB = sys.argv[3] if len(sys.argv) > 3 else os.path.join(ICI, "..", "build", "web")
DOSSIERS = ["Musiques Destiny", "Bruitages"]
IGNORES = ["Bruitages/Sonniss GDC 2026"]
AUDIO = {".mp3", ".m4a", ".ogg", ".wav", ".aac", ".flac", ".opus"}
MANIFESTE = "Pack audio DestinyStory/destiny_audio_manifest.json"
PREFIXE = "/destiny_pack/"

mimetypes.add_type("audio/ogg", ".ogg")
mimetypes.add_type("audio/mp4", ".m4a")


def nfc(s):
    return unicodedata.normalize("NFC", s)


def ignore(relatif):
    r = nfc(relatif)
    return any(r == i or r.startswith(i + "/") for i in IGNORES)


def index():
    fichiers = []
    for d in DOSSIERS:
        for racine, dossiers, noms in os.walk(os.path.join(PACK, d)):
            rel = os.path.relpath(racine, PACK).replace(os.sep, "/")
            if ignore(rel):
                dossiers[:] = []
                continue
            for n in noms:
                if n.startswith("._") or os.path.splitext(n)[1].lower() not in AUDIO:
                    continue
                fichiers.append(f"{rel}/{n}")
    return sorted(fichiers)


class Gestionnaire(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=WEB, **kwargs)

    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def _envoyer(self, code, corps, type_):
        self.send_response(code)
        self.send_header("Content-Type", type_)
        self.send_header("Content-Length", str(len(corps)))
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(corps)

    def _fichier_pack(self, relatif):
        reel = os.path.realpath(os.path.join(PACK, relatif))
        racine = os.path.realpath(PACK)
        rel = os.path.relpath(reel, racine).replace(os.sep, "/")
        dans_un_dossier = any(nfc(rel).startswith(d + "/") for d in DOSSIERS)
        if not reel.startswith(racine + os.sep) or not dans_un_dossier or ignore(rel) or not os.path.isfile(reel):
            self._envoyer(404, b"introuvable", "text/plain; charset=utf-8")
            return
        taille = os.path.getsize(reel)
        type_ = mimetypes.guess_type(reel)[0] or "application/octet-stream"
        debut, fin = 0, taille - 1
        plage = self.headers.get("Range")
        if plage and plage.startswith("bytes="):
            a, _, b = plage[6:].partition("-")
            debut = int(a) if a else 0
            fin = int(b) if b else taille - 1
            self.send_response(206)
            self.send_header("Content-Range", f"bytes {debut}-{fin}/{taille}")
        else:
            self.send_response(200)
        self.send_header("Content-Type", type_)
        self.send_header("Accept-Ranges", "bytes")
        self.send_header("Content-Length", str(fin - debut + 1))
        self.end_headers()
        if self.command == "HEAD":
            return
        with open(reel, "rb") as f:
            f.seek(debut)
            reste = fin - debut + 1
            while reste > 0:
                bloc = f.read(min(65536, reste))
                if not bloc:
                    break
                try:
                    self.wfile.write(bloc)
                except (BrokenPipeError, ConnectionResetError):
                    return
                reste -= len(bloc)

    def do_GET(self):
        chemin = urllib.parse.urlparse(self.path).path
        if not chemin.startswith(PREFIXE):
            return super().do_GET()
        relatif = urllib.parse.unquote(chemin[len(PREFIXE):])
        if relatif == "index.json":
            corps = json.dumps({"fichiers": index()}, ensure_ascii=False).encode("utf-8")
            return self._envoyer(200, corps, "application/json; charset=utf-8")
        if relatif == "destiny_audio_manifest.json":
            m = os.path.join(PACK, MANIFESTE)
            if os.path.isfile(m):
                with open(m, "rb") as f:
                    return self._envoyer(200, f.read(), "application/json; charset=utf-8")
            return self._envoyer(404, b"introuvable", "text/plain; charset=utf-8")
        return self._fichier_pack(relatif)

    def log_message(self, format, *args):
        pass


if __name__ == "__main__":
    if not os.path.isdir(PACK):
        print(f"Pack introuvable : {PACK} (le NAS est-il monté ?)", file=sys.stderr)
    print(f"DestinyStory + pack audio : http://127.0.0.1:{PORT}  (pack : {PACK})")
    http.server.ThreadingHTTPServer(("127.0.0.1", PORT), Gestionnaire).serve_forever()

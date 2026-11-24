#!/usr/bin/env python3
"""Sert build/web en local, comme GitHub Pages : avec les requêtes « Range ».

    python3 tool/serveur_web_local.py [port] [dossier]

Sans « Range » (le `python3 -m http.server` de base), le navigateur ne peut
pas reprendre un son au milieu : après une pause, la musique repartait du
début. GitHub Pages, lui, sait servir un morceau de fichier (206).
"""

import os
import re
import sys
from http import HTTPStatus
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else int(os.environ.get("PORT", "3000"))
DOSSIER = sys.argv[2] if len(sys.argv) > 2 else os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "build", "web")


class Gestionnaire(SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=DOSSIER, **kwargs)

    def end_headers(self):
        self.send_header("Accept-Ranges", "bytes")
        super().end_headers()

    def log_message(self, *args):
        pass

    def send_head(self):
        plage = self.headers.get("Range")
        chemin = self.translate_path(self.path)
        if not plage or not os.path.isfile(chemin):
            return super().send_head()
        m = re.match(r"bytes=(\d*)-(\d*)$", plage.strip())
        taille = os.path.getsize(chemin)
        if not m or (m.group(1) == "" and m.group(2) == ""):
            return super().send_head()
        if m.group(1) == "":
            debut = max(0, taille - int(m.group(2)))
            fin = taille - 1
        else:
            debut = int(m.group(1))
            fin = int(m.group(2)) if m.group(2) else taille - 1
        fin = min(fin, taille - 1)
        if debut > fin:
            self.send_response(HTTPStatus.REQUESTED_RANGE_NOT_SATISFIABLE)
            self.send_header("Content-Range", f"bytes */{taille}")
            self.end_headers()
            return None
        f = open(chemin, "rb")
        f.seek(debut)
        self.send_response(HTTPStatus.PARTIAL_CONTENT)
        self.send_header("Content-Type", self.guess_type(chemin))
        self.send_header("Content-Range", f"bytes {debut}-{fin}/{taille}")
        self.send_header("Content-Length", str(fin - debut + 1))
        self.end_headers()
        self._reste = fin - debut + 1
        return f

    def copyfile(self, source, sortie):
        reste = getattr(self, "_reste", None)
        if reste is None:
            return super().copyfile(source, sortie)
        while reste > 0:
            bloc = source.read(min(64 * 1024, reste))
            if not bloc:
                break
            sortie.write(bloc)
            reste -= len(bloc)
        self._reste = None


if __name__ == "__main__":
    ThreadingHTTPServer(("127.0.0.1", PORT), Gestionnaire).serve_forever()

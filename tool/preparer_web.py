#!/usr/bin/env python3
"""Prépare build/web pour GitHub Pages (docs/app).

    python3 tool/preparer_web.py [build/web]

- `<base href="./">` : l'appli est servie sous /Destiny/app/.
- La version dans l'adresse de `flutter_bootstrap.js`, de `main.dart.js` et
  des données de l'appli (`assets/…?v=2.3.3+29`) : sans ça, le navigateur
  garde les anciens fichiers en cache après une mise à jour (l'ancien code,
  ou les anciens textes).
"""

import json
import os
import re
import sys

WEB = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "..", "build", "web")


def main():
    with open(os.path.join(WEB, "version.json"), encoding="utf-8") as f:
        v = json.load(f)
    version = f"{v['version']}+{v['build_number']}"

    chemin = os.path.join(WEB, "index.html")
    with open(chemin, encoding="utf-8") as f:
        html = f.read()
    html = re.sub(r'<base href="[^"]*">', '<base href="./">', html)
    html = re.sub(r'src="flutter_bootstrap\.js(\?v=[^"]*)?"', f'src="flutter_bootstrap.js?v={version}"', html)
    # Les données (textes, catalogue, pack…) que l'appli lit avec fetch.
    html = re.sub(r'\s*<script id="cache-version">.*?</script>', '', html, flags=re.S)
    script = (
        '<script id="cache-version">(function(){var v=' + json.dumps(version) + ';var f=window.fetch;'
        'window.fetch=function(i,o){if(typeof i==="string"&&i.indexOf("assets/")!==-1&&i.indexOf("?")===-1)'
        '{i=i+"?v="+encodeURIComponent(v);}return f.call(this,i,o);};})();</script>\n  '
    )
    html = html.replace('<script src="flutter_bootstrap.js', script + '<script src="flutter_bootstrap.js', 1)
    with open(chemin, "w", encoding="utf-8") as f:
        f.write(html)

    chemin = os.path.join(WEB, "flutter_bootstrap.js")
    with open(chemin, encoding="utf-8") as f:
        js = f.read()
    js, n = re.subn(r'"mainJsPath":"main\.dart\.js(\?v=[^"]*)?"', f'"mainJsPath":"main.dart.js?v={version}"', js)
    if n != 1:
        sys.exit("flutter_bootstrap.js : mainJsPath introuvable")
    with open(chemin, "w", encoding="utf-8") as f:
        f.write(js)
    print(f"build/web prêt pour Pages (version {version})")


if __name__ == "__main__":
    main()

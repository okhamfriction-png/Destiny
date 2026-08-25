#!/usr/bin/env python3
"""Upload direct d'une .aab sur Google Play via l'API Developer.

Authentification par **clé JSON de compte de service** (jamais le mot de passe
Google). La clé se crée une fois dans Play Console → Accès aux API (voir
docs/cicd_setup.md, Étape A) ; ne la committe pas.

Prérequis :
    pip3 install google-api-python-client google-auth

Usage :
    # lister les pistes existantes (pour trouver le nom exact du test fermé)
    python3 tool/play_upload.py <cle.json> --list

    # uploader la .aab et la publier sur une ou plusieurs pistes (un seul edit)
    python3 tool/play_upload.py <cle.json> <app.aab> internal alpha

Exemple :
    python3 tool/play_upload.py ~/destinystory-play-key.json \\
        build/app/outputs/bundle/release/app-release.aab internal alpha

Pistes Play : internal · alpha (test fermé par défaut) · beta · production,
ou le nom d'une piste de test fermé personnalisée (voir --list).
"""
import sys

PACKAGE = "com.okhamfriction.destinystory"
SCOPES = ["https://www.googleapis.com/auth/androidpublisher"]


def _service(key_path):
    try:
        from google.oauth2 import service_account
        from googleapiclient.discovery import build
    except ImportError:
        sys.exit("Manque les libs : pip3 install google-api-python-client google-auth")
    creds = service_account.Credentials.from_service_account_file(
        key_path, scopes=SCOPES)
    return build("androidpublisher", "v3", credentials=creds, cache_discovery=False)


def _list_tracks(svc):
    edit = svc.edits().insert(packageName=PACKAGE, body={}).execute()
    try:
        res = svc.edits().tracks().list(
            packageName=PACKAGE, editId=edit["id"]).execute()
        tracks = res.get("tracks", [])
        if not tracks:
            print("(aucune piste configurée)")
        for t in tracks:
            rels = t.get("releases", [])
            codes = ", ".join(
                str(c) for r in rels for c in r.get("versionCodes", []))
            print(f"- {t['track']}"
                  + (f"  (versionCodes: {codes})" if codes else ""))
    finally:
        svc.edits().delete(packageName=PACKAGE, editId=edit["id"]).execute()


def _upload(svc, aab, tracks):
    from googleapiclient.http import MediaFileUpload
    edit = svc.edits().insert(packageName=PACKAGE, body={}).execute()
    eid = edit["id"]
    print(f"Edit {eid} — upload de {aab} …")
    media = MediaFileUpload(
        aab, mimetype="application/octet-stream", resumable=True)
    bundle = svc.edits().bundles().upload(
        packageName=PACKAGE, editId=eid, media_body=media).execute()
    vc = bundle["versionCode"]
    print(f"Bundle uploadé — versionCode {vc}")
    for track in tracks:
        svc.edits().tracks().update(
            packageName=PACKAGE, editId=eid, track=track,
            body={"track": track,
                  "releases": [{"versionCodes": [str(vc)],
                                "status": "completed"}]},
        ).execute()
        print(f"  → assigné à la piste « {track} »")
    svc.edits().commit(packageName=PACKAGE, editId=eid).execute()
    print(f"✓ Publié (versionCode {vc}) sur : {', '.join(tracks)}")


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)
    key = sys.argv[1]
    svc = _service(key)
    if sys.argv[2] == "--list":
        _list_tracks(svc)
        return
    aab = sys.argv[2]
    tracks = sys.argv[3:] or ["internal"]
    _upload(svc, aab, tracks)


if __name__ == "__main__":
    main()

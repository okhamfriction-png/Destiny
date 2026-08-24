# CI/CD — Publier DestinyStory sur Google Play automatiquement

Pipeline : tu pousses un **tag** (ex. `v1.3.5`) → GitHub Actions build le `.aab` signé
et l'**uploade sur Google Play** (piste `internal` par défaut).

Le workflow : [`.github/workflows/release-play.yml`](../.github/workflows/release-play.yml)

> Comme ton Flutter est un **fork interne** (indisponible sur les runners GitHub),
> le pipeline tourne sur un **runner auto-hébergé sur ton Mac** : il utilise ton
> Flutter exact et ton keystore local. Ton Mac doit être allumé au moment du déploiement.

---

## Étape A — Accès API Google Play (une fois)

1. **Play Console** → **Paramètres** → **Accès aux API** → **Associer un projet Google Cloud**
   (crée-en un si besoin).
2. Dans **Google Cloud Console** → **IAM & Admin → Comptes de service** → **Créer un compte
   de service** (ex. `github-play-publisher`). Crée une **clé JSON** et télécharge-la.
3. De retour dans **Play Console → Accès aux API**, trouve ce compte de service →
   **Accorder l'accès** → autorise au minimum :
   - *Versions* : gérer les versions de test et de production,
   - restreint à l'app **DestinyStory** suffit.
4. Garde le fichier **JSON** de côté (c'est un secret).

⚠️ L'upload par API ne marche qu'**après** une première release manuelle de l'app —
c'est déjà fait (ta v1.3.4 en test interne). ✅

---

## Étape B — Installer le runner auto-hébergé sur le Mac (une fois)

1. **GitHub** → dépôt **Destiny** → **Settings → Actions → Runners → New self-hosted runner**
   → choisis **macOS / ARM64**.
2. GitHub affiche 4-5 commandes (`mkdir actions-runner`, `curl …`, `./config.sh --url … --token …`).
   Lance-les dans le Terminal. **Dis-le moi** : je peux exécuter la config avec toi.
3. Démarre le runner : `./run.sh` (ou installe-le en service : `./svc.sh install && ./svc.sh start`
   pour qu'il tourne en tâche de fond).

---

## Étape C — Ajouter les secrets GitHub (une fois)

Dépôt **Destiny** → **Settings → Secrets and variables → Actions → New repository secret** :

| Nom du secret | Valeur |
|---|---|
| `PLAY_SERVICE_ACCOUNT_JSON` | Colle **tout le contenu** du fichier JSON de l'étape A |
| `STORE_PASSWORD` | Le mot de passe de ton keystore |
| `KEY_PASSWORD` | Idem (même mot de passe si tu avais appuyé sur Entrée à la création) |

> Le keystore lui-même (`~/destinystory-upload.jks`) **reste sur ton Mac** et n'est jamais
> envoyé à GitHub — seul le runner local y accède.

---

## Utilisation — publier une nouvelle version

1. Bumpe la version dans `pubspec.yaml` si tu veux (le `versionCode` est de toute façon
   auto-incrémenté par le workflow).
2. Crée et pousse un tag :
   ```bash
   git tag v1.3.5 && git push origin v1.3.5
   ```
3. Le workflow build et pousse sur la piste **internal**. Suis-le dans l'onglet **Actions**.

Pour viser une autre piste (ex. `production`), lance-le manuellement :
**Actions → Publier sur Google Play → Run workflow → track = production**.

---

## Notes importantes

- **Production** : le verrou des **12 testeurs / 14 jours** (test fermé) s'applique toujours
  avant de pouvoir publier en production, CI/CD ou pas. Le pipeline sert surtout à automatiser
  **internal / closed** pour l'instant.
- **versionCode** : Google refuse deux uploads avec le même `versionCode`. Le workflow le calcule
  en `1000 + numéro de run`, donc toujours croissant et supérieur à l'actuel (9).
- **Mac éteint = pas de déploiement** : le runner auto-hébergé nécessite que le Mac soit allumé
  et le runner lancé. Pour un déploiement 100 % cloud indépendant du Mac, il faudrait d'abord
  publier ton SDK Flutter forké quelque part — on verra ça si le besoin se présente.

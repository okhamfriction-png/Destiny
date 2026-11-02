# Fiche Play Store — DestinyStory

Textes prêts à copier-coller dans la Google Play Console (onglet **Fiche du store principale**).
Chaque champ respecte les limites de caractères imposées par Google.

---

## 1. Nom de l'application  *(max 30 caractères)*

```
DestinyStory
```
> 12 caractères. Nom retenu — plus distinctif que « Destiny » seul (moindre risque de confusion
> avec des marques existantes). Variante possible si tu veux préciser : « DestinyStory — Impro ».

---

## 2. Description courte  *(max 80 caractères)*

```
Impro dramatique : un lieu, un danger en 4 paliers, Destiny. Rien n'est écrit.
```
> 78 caractères.

---

## 3. Description complète  *(max 4000 caractères)*

```
RIEN N'EST ÉCRIT.

DestinyStory accompagne l'improvisation dramatique avec la grammaire de Destiny. Un lieu, un groupe qui se connaît, un danger qui monte en quatre paliers. Entre les actes, Destiny : le tonnerre, la lumière bleue, les comédiens se figent… et l'histoire repart, pire qu'avant.

Pour les troupes, les ateliers, les profs de théâtre, et les familles qui aiment raconter des histoires.

━━━━━━━━━━━━━━━━━━
JOUER UN SPECTACLE
━━━━━━━━━━━━━━━━━━

• UNE DISTRIBUTION ÉQUILIBRÉE — 4, 5 ou 6 joueurs. Chacun reçoit un archétype (sa conviction face au danger) et choisit son animal (son corps). L'appli veille à ce que chaque famille soit là.

• L'ÉCHAUFFEMENT — La carte de chaque joueur, trois questions, un minuteur.

• LA MISE EN PLACE — Le lieu et le danger à voter, le groupe, les liens, trois objets et un mystère.

• LA RÉGIE — Un grand chrono, et le bouton Destiny. À chaque acte, l'appli rappelle le geste à jouer et ce que fait chaque archétype.

• LE DÉBRIEF — « Il veut… mais il a besoin de… », le choix final, le prix payé. Tout se garde, et s'exporte en PDF.

━━━━━━━━━━━━━━━━━━
JOUER EN SÉRIE, EN FAMILLE
━━━━━━━━━━━━━━━━━━

• L'ÉPISODE, LA SAISON, LA SÉRIE — Un méchant agit dans l'ombre pendant quatre épisodes. On voit d'abord ses sbires ; on le vainc par sa faille.

• 21 UNIVERS — Fantasy, policier, science-fiction, pirates, contes de fées… avec leurs lieux, leurs figurants et leurs méchants.

• LE MODE KIDS — Seulement ce qui se joue avec des enfants. Chaque enfant a un pouvoir. Personne ne meurt.

━━━━━━━━━━━━━━━━━━
S'ENTRAÎNER ET APPRENDRE
━━━━━━━━━━━━━━━━━━

• DES EXERCICES — Échauffements, statut, écoute, dialogue, et vingt exercices de la grammaire (CROW, Lieu, Destiny), avec un chrono et des cartes à tirer.

• LA BIBLIOTHÈQUE — Le livret de règles, les 12 archétypes et leurs 24 animaux, les dangers, les lieux, des œuvres lues avec la grammaire. Le livret et les cartes s'impriment en PDF.

• AVEC L'IA (facultatif, avec votre propre clé) — Jouez votre personnage dans une histoire, ou un spectacle complet ; demandez des idées pendant le jeu.

━━━━━━━━━━━━━━━━━━

Tout fonctionne hors ligne. Pas de compte, pas de publicité.

Rien n'est écrit. Tout reste à jouer.
```
> Environ 2 200 caractères (sous la limite de 4000).

---

## 4. Coordonnées & conformité

| Champ | Valeur / à préparer |
|---|---|
| **Catégorie** | Divertissement (ou Art & Design) |
| **E-mail développeur** | okhamfriction@gmail.com |
| **Politique de confidentialité** | ✅ EN LIGNE : https://okhamfriction-png.github.io/Destiny/privacy.html |
| **Classification du contenu** | À remplir via le questionnaire Google (l'app n'a pas de contenu sensible → visera « Tout public / PEGI 3 ») |
| **Section Data safety** | Tout reste sur l'appareil, **sauf** les modes « avec l'IA » : le texte de jeu part chez le fournisseur choisi (Anthropic ou OpenAI), avec la clé de l'utilisateur, sans les prénoms des comédiens. La transcription passe par la reconnaissance vocale du système (Google ou Apple) ; l'appli ne garde aucun son. À déclarer en conséquence (voir § 6). |
| **Public cible** | 13 ans et + (ou « tout public » selon ton choix) |

---

## 5. Assets graphiques à fournir

| Asset | Format requis | Statut |
|---|---|---|
| **Icône** | PNG 512 × 512 (32 bits, avec alpha) | ✅ tu as déjà `assets/icon/app_icon_full.png` (à exporter en 512²) |
| **Bannière (Feature graphic)** | JPG/PNG **1024 × 500** | ⬜ à créer |
| **Captures téléphone** | 2 à 8, min 320 px, ratio 16:9 ou 9:16 | ✅ 8 captures 1080 × 1920 (9:16) de la 2.0 dans `docs/store_assets/play_store_2_0/` : Découvrir Destiny (3), Troupe, Archétypes, Livret, Exercices, fiche d'exercice. Faites depuis la version web : à vérifier sur un téléphone |
| Captures tablette (optionnel) | 7" et 10" | ⬜ facultatif |

> Astuce captures : Découvrir Destiny, l'accueil de Troupe, la régie avec le bouton Destiny, le
> rituel (lumière bleue), une carte d'archétype, le livret, une fiche d'exercice.

---

## 6. Modèle de politique de confidentialité (à héberger)

> Google exige une URL publique. Le plus simple : coller ce texte dans une page (GitHub Pages,
> un Google Sites gratuit, ou un Gist rendu en HTML) et donner l'URL à la Console.

```
Politique de confidentialité — DestinyStory

DestinyStory ne collecte aucune donnée personnelle et n'a pas de serveur.
Les spectacles, les séries, les réglages et l'historique restent enregistrés
sur votre appareil.

Les modes « avec l'IA » sont facultatifs. Si vous les utilisez avec votre
propre clé d'API, le texte de la partie est envoyé au fournisseur que vous
avez choisi (Anthropic ou OpenAI), selon ses propres conditions. Les prénoms
des comédiens ne sont jamais envoyés.

La transcription de la voix, si vous l'activez, utilise la reconnaissance
vocale du système (Google ou Apple) ; l'application ne conserve aucun son.

L'application ne contient pas de publicité et n'utilise aucun outil de suivi.

Contact : okhamfriction@gmail.com
Dernière mise à jour : novembre 2026
```
> ✅ La page `docs/privacy.html` est à jour pour la 2.0 (IA, transcription, mode kids). Elle sera
> en ligne dès que la branche sera fusionnée dans `main`.

---

## 7. Rappel — étapes restantes côté publication

1. Créer le compte Google Play Console (25 $, une fois).
2. Générer le keystore + `android/key.properties` (voir instructions données dans le chat).
3. `flutter build appbundle --release` → `.aab` signé pour le Store.
4. Créer l'app dans la Console, remplir cette fiche, uploader les assets.
5. Uploader le `.aab` sur une piste de **test interne** d'abord, puis promouvoir en **Production**.
6. Soumettre pour examen (souvent quelques heures à quelques jours).

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
Générateur de scènes d'impro : un lieu, un danger, des héros. Rien n'est écrit.
```
> 79 caractères.

---

## 3. Description complète  *(max 4000 caractères)*

```
RIEN N'EST ÉCRIT.

DestinyStory est un générateur de situations pour l'improvisation théâtrale dramatique. En un geste, l'app tire une scène complète et prête à jouer : un LIEU, un DANGER qui menace, et des HÉROS avec leur archétype, leur tempérament, leur façon d'être et leur moteur intérieur. À vous d'écrire la suite, sur scène, en direct.

Conçu pour les comédien·nes, les troupes, les ateliers et les professeurs de théâtre, DestinyStory relance l'inspiration quand la page est blanche et pousse les joueur·ses hors de leurs automatismes.

━━━━━━━━━━━━━━━━━━
CE QUE FAIT L'APP
━━━━━━━━━━━━━━━━━━

• GÉNÉRATION INSTANTANÉE — Un lieu, un danger, des héros tirés au sort. Chaque combinaison est une scène à jouer.

• 40 LIEUX DÉTAILLÉS — Chaque lieu vient avec ses sous-espaces, ses 6 fonctions (les rôles qu'on y trouve) et un vocabulaire vraiment spécifique. De quoi ancrer la scène dans le concret et nourrir le jeu.

• DES HÉROS INCARNÉS — Archétype, tempérament, façon d'être et moteur profond : chaque personnage arrive avec de la matière à jouer, pas juste un nom.

• DES DANGERS QUI LANCENT L'ACTION — Une menace claire, avec ses étapes, pour donner une tension et une direction à la scène.

• LE CHRONO — Lancez la scène avec un compte à rebours et trois moments « DESTINY » qui rythment l'histoire et forcent les rebondissements.

• LIEU CLIQUABLE — Pendant la scène, ouvrez la fiche complète du lieu (fonctions, vocabulaire, sous-espaces) en un tap.

• ÉCRAN TOUJOURS ALLUMÉ — Pas de mise en veille pendant une répétition ou un spectacle.

• UN GUIDE — Des repères de dramaturgie pour construire une scène qui tient debout.

━━━━━━━━━━━━━━━━━━
POUR QUI ?
━━━━━━━━━━━━━━━━━━

• Comédien·nes et improvisateur·rices qui veulent s'entraîner
• Troupes et compagnies en répétition
• Profs et animateur·rices d'ateliers théâtre
• Toute personne curieuse de raconter des histoires

Pas de compte, pas de publicité intrusive : on ouvre, on tire une scène, on joue.

Rien n'est écrit. Tout reste à jouer.
```
> ~1 750 caractères (sous la limite de 4000). Adapte librement le ton.

---

## 4. Coordonnées & conformité

| Champ | Valeur / à préparer |
|---|---|
| **Catégorie** | Divertissement (ou Art & Design) |
| **E-mail développeur** | okhamfriction@gmail.com |
| **Politique de confidentialité** | URL **obligatoire** — voir modèle ci-dessous |
| **Classification du contenu** | À remplir via le questionnaire Google (l'app n'a pas de contenu sensible → visera « Tout public / PEGI 3 ») |
| **Section Data safety** | Déclarer : aucune donnée collectée/partagée (tout est local sur l'appareil) — à confirmer |
| **Public cible** | 13 ans et + (ou « tout public » selon ton choix) |

---

## 5. Assets graphiques à fournir

| Asset | Format requis | Statut |
|---|---|---|
| **Icône** | PNG 512 × 512 (32 bits, avec alpha) | ✅ tu as déjà `assets/icon/app_icon_full.png` (à exporter en 512²) |
| **Bannière (Feature graphic)** | JPG/PNG **1024 × 500** | ⬜ à créer |
| **Captures téléphone** | 2 à 8, min 320 px, ratio 16:9 ou 9:16 | ⬜ à faire (écran de génération, chrono, fiche lieu…) |
| Captures tablette (optionnel) | 7" et 10" | ⬜ facultatif |

> Astuce captures : lance l'app, génère une belle scène, capture l'écran de résultat, le chrono
> avec les héros sur une ligne, et une fiche de lieu ouverte. Le thème sombre/or rend très bien.

---

## 6. Modèle de politique de confidentialité (à héberger)

> Google exige une URL publique. Le plus simple : coller ce texte dans une page (GitHub Pages,
> un Google Sites gratuit, ou un Gist rendu en HTML) et donner l'URL à la Console.

```
Politique de confidentialité — DestinyStory

DestinyStory ne collecte, ne stocke et ne transmet aucune donnée personnelle.
Toutes les informations (scènes générées, réglages, historique) restent
enregistrées localement sur votre appareil et ne sont jamais envoyées à un serveur.

L'application ne contient pas de publicité et n'utilise aucun outil de suivi.

Contact : okhamfriction@gmail.com
Dernière mise à jour : août 2026
```

---

## 7. Rappel — étapes restantes côté publication

1. Créer le compte Google Play Console (25 $, une fois).
2. Générer le keystore + `android/key.properties` (voir instructions données dans le chat).
3. `flutter build appbundle --release` → `.aab` signé pour le Store.
4. Créer l'app dans la Console, remplir cette fiche, uploader les assets.
5. Uploader le `.aab` sur une piste de **test interne** d'abord, puis promouvoir en **Production**.
6. Soumettre pour examen (souvent quelques heures à quelques jours).

# DestinyStory — Documentation des fonctionnalités

> Application Flutter (Android / iOS) pour l'**improvisation théâtrale**.
> Tout fonctionne **hors‑ligne** à partir de fichiers JSON et d'une base SQLite locale ;
> seuls les modes « IA » nécessitent une clé d'API.
>
> Version documentée : **1.5.0** — voir [CHANGELOG / Releases](https://github.com/okhamfriction-png/Destiny/releases).
>
> ℹ️ *Captures d'écran : les images de `docs/store_assets/screens/` datent d'une version antérieure
> (barre de navigation différente) et ne sont pas intégrées ici pour ne pas induire en erreur.
> Elles seront régénérées lors d'une prochaine passe « visuels ».*

---

## 1. Vue d'ensemble

DestinyStory est une **boîte à outils de meneur de jeu / d'atelier d'impro**. Elle se compose de
quatre univers accessibles depuis la barre de navigation du bas :

| Onglet | Rôle |
|--------|------|
| **Générateur** | Tirer une situation (lieu + danger + héros) et la jouer au chrono. |
| **Musique** | Lancer des ambiances et musiques pendant le jeu. |
| **Histoire** | Raconter une histoire suivie : mode **IA** (interactif) ou **Campagne** (sans IA). |
| **Scène** | Jouer une scène : **Spectacle (IA)** solo ou **Exercices** de théâtre. |

Un bouton **Réglages** (roue crantée) et un **Guide Destiny** (livre) sont accessibles depuis l'en‑tête.

**Principes de design transverses :**
- Thème sombre unifié, **couleur porteuse de sens** (or = méchant/accent, teal = lieu/peuple,
  corail = escalade, violet = figurants/IA, bleu = rôles).
- **Statuts de jeu** colorés partout (haut = ambre, bas = bleu, neutre = blanc).
- Animations signature : **cube DESTINY** (lancer du dé) et **pièce du destin** (Brave/Smart).
- Retour **haptique** sur les actions clés.

---

## 2. Générateur

### 2.1 Réglage du tirage
- **Modes** : `Histoire` (Théâtre — tout est permis), `Rue` (uniquement les dangers « fun »),
  `Spin-off` (variations).
- **Nombre de joueurs** : réglable (−/+).
- Bouton **« Générer une histoire »**.
- Icône **historique** : revoir les derniers tirages.

### 2.2 Écran de résultat
Chaque tirage produit une fiche :
- **Danger** (avec son style) et **Lieu**, chacun illustré par une vignette
  (image réaliste, vectorielle ou minimale selon les réglages).
- **Fonctions du lieu** : rôles suggérés (puces) ; toucher pour voir les sous‑espaces et le vocabulaire.
- **Héros** : un archétype par joueur, avec tempérament · port · moteur, coloré par statut de jeu.
- **Étapes du danger** : les 4 marches de montée en tension.
- Boutons **Rejouer / Relancer / Effacer** et **TOP — chrono**.

### 2.3 Mémoire anti‑répétition (SQLite)
Les combinaisons **lieu × danger** déjà tirées ne reviennent pas tant que toutes les autres
n'ont pas été vues. Un **compteur de cycle** s'incrémente à chaque épuisement du catalogue.

### 2.4 Chrono « TOP »
- Durée réglable (30 / 40 / 45 / 50 min ; 30 par défaut).
- **3 DESTINY** minutés (curseurs de placement, par défaut 10 / 18 / 27 min sur 30 min).
- Écran de jeu **sans défilement** (mise à l'échelle automatique) : lieu, danger, héros, étapes,
  gros compte à rebours, rappel « DESTINY à … ».
- Boutons **Pause · Régler/relancer · Régie son** (sur une seule ligne).
- **Écran maintenu allumé** pendant le chrono.

### 2.5 Le dé DESTINY
À chaque DESTINY, le dé tire un **type** (Archétype / Danger / Destin) selon des **poids réglables**
(mettre 0 pour désactiver un type). L'**animation du cube doré** joue au lancement et à chaque DESTINY
(activée par défaut).

### 2.6 Musique scénarisée automatique
Pendant le chrono d'histoire :
- **Commencement** au démarrage,
- **ambiance du lieu** peu après,
- **Conclusion** après le 3ᵉ DESTINY.

### 2.7 Transcription (optionnelle)
Interrupteur « Transcrire la scène » (si un moteur de reconnaissance vocale est disponible) :
le téléphone écrit le texte **localement**, aucun son n'est conservé.

---

## 3. Musique
Menu dédié, indépendant des effets sonores : pistes classées par catégorie, lecture simple.
Voir aussi la **Régie son** (§7) accessible pendant le jeu.

---

## 4. Histoire

Le hub « Raconter une histoire » propose deux modes.

### 4.1 Mode IA
Histoire interactive menée par l'IA : elle propose, le joueur décide (une partie par choix).
**Nécessite une clé d'API** (voir Réglages → Configurer l'IA).

### 4.2 Mode Campagne (sans IA)
Des **épisodes qui se suivent** dans un même monde, avec un méchant qui revient.
**21 univers** (12 adultes + 9 enfants), alignés sur ceux du mode IA.

#### Création d'une campagne
- **Public** : Adulte (par défaut) ou Enfant — bascule l'ensemble des univers proposés.
- **Univers** (21), **Ton** (10 : drôle, aventureux, enquête, épique, tendre, tranquille,
  sombre, dramatique, burlesque, mystérieux).
- **Lore** : une couche de personnages/ambiance (10 références connues par univers).
- **Contexte** (facultatif) : détail à garder d'un épisode à l'autre — *utilisé uniquement par l'IA
  au moment du résumé* (badge « IA seulement »).

#### Préparation d'un épisode
- **Qui joue** : 2 à 5 joueurs. Pour chacun :
  - **Prénom** (vide par défaut),
  - **Peuple** — cohérent avec l'**univers ET le lore**, valeur la plus évidente par défaut, éditable,
  - **Archétype** (animal) attribué selon la **parité des statuts** (au moins un haut, un bas, un neutre),
    éditable,
  - **Fonction** dans le lieu — pré‑renseignée depuis le lieu, éditable (ou saisie libre).
  Un détail d'archétype (tempérament · port · moteur) est affiché sous chaque joueur.
- **Le temps** : durée d'épisode (30 min par défaut). Le **danger 1 démarre l'épisode** ;
  les dangers 2/3/4 tombent aux moments réglés (≈ 30 / 60 / 90 %) ; le chrono **vire au rouge**
  après le dernier.
- **Le micro** : transcription optionnelle de l'épisode.

#### Écran de jeu (épisode)
- **Lieu** + **Figurants** (chacun a sa propre affaire en cours), **Méchant** (son but, ses manœuvres,
  ses **4 présages**, ses **sbires**), **Escalade** (les 4 dangers, révélés au fil du temps avec
  **animation du cube**), **Rôles** (les joueurs, leur fonction, peuple et archétype).
- **Gestion de combat par le meneur**, directement à côté de chaque personnage :
  - **Cœur à 3 états** (distincts par la forme) : plein rouge = *en forme* → brisé = *blessé* →
    contour = *mort*.
  - **Malus / Bonus** (−/+) pour ajuster la force.
  - Le **nom est barré** quand le personnage meurt.
  - Aide contextuelle (bouton ⓘ) + retour haptique ; cibles tactiles confortables.
- **Pièce du destin** (bouton **Destin**) : le meneur la lance à volonté — tirage aléatoire
  **BRAVE / SMART** avec animation de flip 3D et son.
- **Régie son** (bouton **Régie**) : ambiances en direct.
- Indicateur de **transcription** si activée.

#### Bilan & continuité
En fin d'épisode, un **bilan** permet de demander à l'IA (si configurée) un **résumé** et une
**accroche** pour l'épisode suivant. La campagne est **persistée** ; l'écran « Ce qui s'est passé »
liste les épisodes joués. Suppression protégée par confirmation.

#### Composition déterministe & confidentialité
- Le **méchant** est stable sur toute la campagne ; les **figurants** sont stables ; le **lieu** et
  les **joueurs** varient par épisode (tirage graine).
- L'assistant de campagne est **isolé** : il ne connaît que l'univers, le ton, le contexte et la
  transcription, et **retire les prénoms** avant tout envoi.

---

## 5. Scène

Le hub « Jouer une scène » propose deux modes.

### 5.1 Spectacle (IA)
Une partie **solo** menée par une IA qui joue les partenaires, le régisseur et le coach.
**Nécessite une clé d'API.**

### 5.2 Exercices
Échauffements et jeux de théâtre courts, chronométrés, pour lancer une séance.
Classés **par thème** en onglets : **Échauffement** (par défaut), **Statut**, **Spontanéité**,
**Écoute**, **Imagination**. Un bandeau « principe d'impro » accompagne chaque thème.

---

## 6. Régie son (mixeur du régisseur)
Panneau accessible pendant le chrono d'histoire et l'épisode de campagne :
- Toutes les pistes classées par **catégorie colorée** (Émotions, Lieux, Ambiances, Thèmes, Univers),
  avec des **icônes adaptées**.
- Catégories **repliables** (par défaut seules Émotions et Lieux sont dépliées).
- Contrôles simplifiés du régisseur : **lecture en boucle** (par défaut) et **volume**.

---

## 7. Réglages
- **Tutoriel** — comment fonctionne l'application.
- **Gérer lieux & dangers** — ajouter, renommer, supprimer ; activer Rue / Théâtre.
- **Détails des lieux** — sous‑espaces et vocabulaire par lieu.
- **Antisèche de relations** — liens génériques (points de départ), éditables.
- **Dilemmes par danger** — ajouter / modifier / supprimer des dilemmes.
- **Catalogue de données** — parcourir lieux, dangers et archétypes (lecture seule).
- **Apparence** — taille et écriture du Chat, **visuels des cartes** (Réaliste / Vectoriel / Minimal),
  **affichage du résultat** (Côté / Grand / Full), durée du TOP, **poids du dé DESTINY**.
- **Mode admin** — autorise l'édition du Guide et de la configuration (désactivé = lecture seule).
- **Configurer l'IA** — fournisseur, modèle, jeton d'API (pour les modes IA).
- **Base de données** — compteur d'histoires et réinitialisation.
- **Me contacter · Crédits · À propos.**

---

## 8. Autres outils

- **Guide Destiny** — guide d'impro intégré (dont la section « Quand tu ne sais plus quoi faire »).
- **Tableaux de suivi** — suivi de partie.
- **Détails du lieu** — accès direct depuis le chrono.

---

## 9. Confidentialité & données
- Fonctionnement **hors‑ligne** par défaut ; catalogues en JSON, données de jeu en **SQLite local**.
- La **transcription** reste sur l'appareil ; aucun audio conservé ; l'utilisateur voit exactement
  ce qui part avant tout résumé IA.
- Les modes IA n'échangent que le strict nécessaire, **sans prénoms** côté campagne.
- Politique de confidentialité : [`docs/privacy.html`](privacy.html).

---

## 10. Build & publication
- **Android** : `flutter build appbundle --release` (.aab pour Google Play) /
  `flutter build apk --release` (installation directe).
- **CI/CD** : voir [`docs/cicd_setup.md`](cicd_setup.md).
- **Fiche Play Store** : [`docs/play_store_listing.md`](play_store_listing.md).

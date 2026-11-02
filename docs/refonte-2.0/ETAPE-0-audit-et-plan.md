# DestinyStory 2.0 — Étape 0 : audit et plan

> **Statut : en attente de ton feu vert.** Aucune ligne de code n'a été modifiée. Seuls ont été ajoutés au dépôt : le fichier de grammaire (`assets/data/destiny_grammaire.json`, pas encore branché) et ce dossier `docs/refonte-2.0/`.
>
> Annexes : [A — dangers et lieux, grammaire contre catalogue](annexe-A-dangers-lieux.md).

## Sommaire

0. En bref
1. Le fichier de grammaire, et l'état de départ
2. Où vit l'ancienne grammaire (réponses de l'étape 0)
3. Ancienne notion → nouvelle notion → fichiers touchés
4. Inventaire exhaustif (la liste de contrôle de la refonte)
5. Les réglages, un par un
6. Le dé
7. Navigation cible
8. Modèle de données
9. Plan de migration
10. Ce que je propose de supprimer pour de bon
11. Mes propositions (à valider)
12. Phases et prérequis
13. Les décisions qu'il me faut

---

## 0. En bref

**Ce que j'ai trouvé**

- L'ancienne grammaire est partout, mais concentrée à cinq endroits. Le **chrono TOP** porte le dé et les 3 DESTINY minutés. Le **Guide** porte le dé, les 3 actes et le moteur × danger. Le **prompt du Spectacle IA** est long d'environ 200 lignes et contient les 24 animaux en dur, avec leur moteur, ainsi que 3 actes. Le **mode Histoire IA** utilise des « dés » et fait monter le danger tous les 4 tours. Enfin, la **Campagne** gère la parité des statuts, le moteur, et un lieu qui change à chaque épisode.
- **Il n'y a ni traître ni sidéré** dans le code, donc aucune sauvegarde ne peut en contenir (l'appli ne les a jamais écrits). On trouve seulement deux phrases à réécrire : « traîtres de cour » dans le Guide, et un présage de méchant de campagne. Rien à convertir de ce côté.
- **Le dé** ne sert qu'au spectacle (chrono TOP). La seule mécanique de jeu proche est la pièce du destin de la Campagne (BRAVE / SMART), et elle reste. Il y a aussi un widget de dé 3D qui n'est utilisé nulle part.
- **Les 4 niveaux des animaux sont déjà calés sur les 4 paliers** (Masqué, Affleure, Domine, Extrême). Ils deviennent directement « le corps à chaque palier ».
- **Dangers et lieux** : la grammaire et le catalogue ont les mêmes 38 dangers et les mêmes 40 lieux. En revanche, les identifiants diffèrent, 58 textes de paliers ont été raccourcis côté grammaire, et les espaces ne correspondent pas (4 dans la grammaire, 8 sous-espaces dans l'appli). Le détail est dans l'annexe A. Je n'ai rien tranché.
- **Trois risques pour tes données**, que je corrige avant toute migration :
  1. Une erreur de lecture des campagnes peut toutes les effacer à la sauvegarde suivante.
  2. Le catalogue SQLite ne sait pas ce que tu as modifié.
  3. Une partie de Spectacle IA en cours stocke l'ancien prompt complet et le réutiliserait après la mise à jour.
- **Les personnages de campagne ne sont pas sauvegardés aujourd'hui** : ils sont recomposés à chaque épisode. La v2 les sauvegarde, avec leurs six couches.

**Ce qu'il me faut de toi** : tes réponses aux décisions de la section 13. Les plus urgentes sont D1 à D5 (données), D10 (animaux de campagne) et D16 (suppressions).

**Blocage technique** : je ne peux pas pousser sur GitHub. L'application Claude a un accès en lecture seule au dépôt `okhamfriction-png/Destiny` (erreur 403 en écriture, par `git push` comme par l'API). Mes commits sont faits localement sur `claude/destiny-story-2-refonte-cyw02u`. Pour réparer, reconnecte GitHub sur https://claude.ai/connect-github, et installe l'application Claude sur le dépôt si besoin.

---

## 1. Le fichier de grammaire, et l'état de départ

### 1.1 Contrôle du fichier (`destiny_grammaire.json`, version 2.0)

| Contenu | Attendu | Trouvé |
|---|---|---|
| Familles | 3 | 3 ✓ |
| Archétypes | 12, deux animaux chacun | 12 ✓ |
| Animaux | 24, chacun à un seul archétype | 24 uniques ✓ |
| Montées | 4 par archétype | 12 × 4 ✓ |
| Paliers et actes | 4 + 4 | ✓ |
| Règles d'or | 8 | 8 ✓ |
| Rituel, distribution (4 exemples), personnage (6 directions), échauffement | — | ✓ |
| Dangers | 38, 4 paliers chacun | 38 ✓ (voir annexe A) |
| Lieux | 40, espaces et rôles | 40 ✓ (voir annexe A) |
| Œuvres | 21 (8 séries et romans, 7 pièces, 6 films) | 8 + 7 + 6 ✓ |
| Scènes de Tarantino | 3 | 3 ✓ |
| Exercices | 20 en 3 thèmes | CROW 6, Lieu 6, Destiny 8 ✓ ; 10 cartes à tirer ✓ |
| Cohérence animal ↔ archétype dans les 21 œuvres | — | 0 erreur ✓ |

### 1.2 Petits écarts entre le fichier et ton prompt (à trancher, D5)

1. **Opportuniste** : le fichier dit « Monnaie ses services, prend les ressources ou le pouvoir. » ; ton prompt ajoute « et peut aller jusqu'à pactiser avec la menace ». La montée du palier 4 (« Pactise, ou vend sa place ») le dit déjà.
2. **Règle d'or 5** : le fichier dit « …décide du moment, pas l'alarmiste » ; ton prompt dit « jamais un comédien ».
3. **Règle d'or 3** : « 4 ou 5 joueurs », alors que la distribution prévoit aussi 6 joueurs.
4. **Port du chat** : « feutré » dans le fichier, « feutré, glissant » dans l'appli. C'est le seul écart sur les ports et les statuts des 24 animaux.
5. **Palier 4** : l'identifiant technique est `supprime` et le nom « Il bloque les sorties ». Je garde l'identifiant, qui ne s'affiche jamais, et j'affiche le nom.
6. **Couleurs** : le bleu Destiny du rituel et le bleu de la famille Interprète sont le même `#3F74B5`. Je suppose que c'est voulu (l'alarmiste porte le danger). Voir 11.3.

### 1.3 Ce qui manque au fichier pour qu'il soit vraiment la source unique (D4)

Ton prompt demande des textes qui ne sont pas encore dans le fichier. Si je les écris dans le code, je viole la règle 2. Je propose donc d'**ajouter ces clés au fichier**. J'en rédige le contenu à partir de ton prompt, sans rien inventer, et tu valides :

- `outils_de_jeu` : les mains occupées, le sous-texte, les silences, la règle des 20 %, et « ça se pratique jusqu'à devenir un instinct » (ton § 2.7) ;
- `lexique` : utiliser, ne plus utiliser (§ 1.15) ;
- `livret` : but, matériel, rôles, mise en place, déroulé, fin, variantes (§ 2.13) ;
- `campagne` : les trois règles, le grand danger, l'évolution du personnage (§ 2.5) ;
- `mode_enfant` : le vocabulaire adouci (« un gros souci »…) (§ 2.5) ;
- `module_traitre` : sa description (§ 2.5) ;
- `onboarding` : les 3 ou 4 écrans (§ 2.2) ;
- `rituel_destiny.texte_ellipse` : « Quelques heures plus tard… » (§ 2.1) ;
- `rebondissements` : les 6 cartes « Destin », si tu acceptes le module (11.2) ;
- `avant_scene` : l'écran de rappels positifs (§ 2.4).

### 1.4 État de départ des tests

Avec **Flutter 3.41.9** (la version compatible avec le `pubspec.lock` du dépôt, qui ne bouge pas), **les 28 tests passent** (5 fichiers).

Avec Flutter 3.44 ou 3.47, le test de démarrage ne compile plus : le paquet d'icônes `font_awesome_flutter` 10.12.0 étend une classe devenue fermée. Ce n'est pas un défaut de ton code, mais la prochaine mise à jour de Flutter le cassera. Je propose de monter ce paquet en version pendant la phase 1 (D13).

Je travaille donc avec Flutter 3.41.9 pour toute la refonte, sauf si ta CI en utilise une autre (D26).

---

## 2. Où vit l'ancienne grammaire (réponses de l'étape 0)

| Question | Où | Ce qu'on y trouve |
|---|---|---|
| **Archétypes et animaux** (moteurs, niveaux, statuts, ports) | `assets/data/archetypes.json` (24) ; `domain/entities/archetype.dart` ; `assets/data/campagne_archetypes.json` (16, dont tortue, dauphin, éléphant, pie) ; en dur dans `spectacle_prompt.dart:47-71`, `guide_content.dart:271-325` et `top_countdown_screen.dart:39-44` | Un « archétype » est aujourd'hui un animal : tempérament, port, **moteur**, statut, intention, 4 niveaux |
| **Le dé du destin et ses effets** | `top_countdown_screen.dart:46-227` (dé à poids, cartes Destin) ; `visual_settings.dart:175-209` et `appearance_screen.dart:259-305` (poids) ; `guide_content.dart:230-244` (section « Le dé du destin ») ; `destiny_cube_animation.dart` ; `dice_3d.dart` (inutilisé) ; `chat_controller.dart` et `chat_screen.dart` (« Résultat des dés », qui est en fait un pile ou face) | Voir section 6 |
| **La structure en actes** | **3 actes** dans `guide_content.dart:174-186`, `tracking_screen.dart` / `tracking_store.dart` et `spectacle_prompt.dart:102-116` ; **aucun acte** dans le chat ni la Campagne (dangers à 30/60/90 %) ; le chrono a 3 DESTINY et pas d'actes nommés | Partout, on passera à 4 actes alignés sur les 4 paliers |
| **Les paliers du danger** | `dangers.json` (4 paliers par danger) ; `danger.dart:11-16` (`kStadesEscalade` en dur : Signale, Enferme, Envahit, **Supprime**) ; `catalog_editor_screen.dart:225-228` (autres libellés) ; `spectacle_prompt.dart:99` (« il pointe, il s'installe, critique, irréversible ») ; `gm_prompt.dart:19` | Trois vocabulaires différents pour la même chose. Un seul après la refonte : celui du fichier |
| **Les lieux** | `locations.json`, `location_details.json` (sous-espaces, fonctions, vocabulaire), SQLite ; `campagne_lieux.json` (42 lieux de campagne) | Le lieu est déjà fixe dans le spectacle (le Guide le dit), mais il **change à chaque épisode** de campagne, et le Spectacle IA permet d'en sortir à l'acte 3 |
| **Les prompts IA** | 9 prompts dans 5 fichiers : `spectacle_prompt.dart`, `gm_prompt.dart`, `chat_controller.dart`, `spectacle_controller.dart`, `campagne_assistant.dart` (+ l'appel de `generator_screen.dart:179`) | Voir 4.4 |
| **Les exercices** | `assets/data/exercices.json` (6 thèmes, 32 exercices, 8 principes, 50 virelangues) ; `exercices_screen.dart` | Ton prompt cite 5 thèmes, il y en a 6 (Dialogue en plus) et un onglet Solo |
| **Les 21 univers** | Listes en dur dupliquées dans `campagne_store.dart:116-149`, `chat_screen.dart:18-45` et `spectacle_screen.dart:11-38` ; données dans `campagne_lieux.json` (2 lieux par univers) et `campagne_mechants.json` (2 méchants par univers) ; musiques dans `audio/universes/` | 12 univers adultes et 10 enfants, dont **Super-héros dans les deux** : cela fait bien 21 identifiants, mais `docs/FEATURES.md` dit « 12 + 9 » |
| **Navigation, thème, textes** | `root_screen.dart` (4 onglets et en-tête) ; `app_theme.dart` (fond violet nuit, or `#E8B86D`) ; or `#FFC24B` et dégradé de fond en dur dans plus de 20 fichiers ; textes en dur dans chaque écran | Voir 4.5 à 4.10 |

---

## 3. Ancienne notion → nouvelle notion → fichiers touchés

| Ancienne notion | Nouvelle notion | Fichiers touchés |
|---|---|---|
| « Archétype » = un animal (24) | **Archétype** (12, en 3 familles) + **animal** (24, deux par archétype) | `archetypes.json`, `archetype.dart`, `generate_story_usecase.dart`, `story_result_card.dart`, `top_countdown_screen.dart`, `catalog_view_screen.dart`, `chat_screen.dart`, `spectacle_*`, `campagne_*`, `entity_visuals.dart`, `guide_content.dart` |
| Moteur, intention | **Vouloir** (concret, ici, ce soir) ; l'archétype dit la conviction | les mêmes, plus `moteur_info.dart`, `dilemma*` (faux ami : « genre ») |
| 4 niveaux (Masqué → Extrême) | **Le corps à chaque palier** (déclenché par le palier, jamais tiré) | `archetypes.json`, `moteur_info.dart`, `catalog_view_screen.dart` |
| Statut haut / bas / neutre, « parité » | **Statut de départ** (pastille), **distribution par familles** | `generate_story_usecase.dart`, `constructeur_episode.dart`, `entity_visuals.dart`, `campagne_preparation_screen.dart` |
| Étapes du danger ; Signale / Enferme / Envahit / Supprime | **Paliers** : il se signale, il enferme, il envahit, il bloque les sorties | `danger.dart`, `story_result_card.dart`, `catalog_editor_screen.dart`, `rue_result_card.dart`, prompts |
| 3 actes (Poser, Réagir, Converger) | **4 actes** (un par palier) ; gestes Dire, Fixer, Bloquer, Nommer, Choisir | `guide_content.dart`, `tracking_*`, `spectacle_prompt.dart`, chrono, Campagne, chat |
| 3 DESTINY minutés + **dé** (Archétype / Danger / Destin) | **Destiny, le rituel** (tonnerre, rire, lumière bleue, figé, ellipse) : palier + 1, nouvelle de l'alarmiste ; lancé de l'extérieur | `top_countdown_screen.dart`, `visual_settings.dart`, `appearance_screen.dart`, `guide_content.dart`, `spectacle_*`, `campagne_jeu_screen.dart` |
| Dangers de campagne à 30 / 60 / 90 % | **Les 3 Destiny** de l'épisode | `campagne_preparation_screen.dart`, `campagne_jeu_screen.dart`, `constructeur_episode.dart` |
| Présages du méchant (4) | **Grand danger** de la campagne | `campagne_mechants.json`, `constructeur_episode.dart`, `campagne_jeu_screen.dart` |
| « Résultat des dés » (chat) | Réussite ou échec du destin (mécanique de jeu gardée, sans le mot « dé ») | `chat_controller.dart`, `chat_screen.dart`, `gm_prompt.dart`, `tutorial_screen.dart` |
| Danger qui monte « tous les 4 tours » (chat) | **Un palier par chapitre** | `chat_controller.dart` |
| Lieu qui change à chaque épisode ; sortie du lieu à l'acte 3 (Spectacle IA) | **Un seul lieu** ; un second seulement pour un secret, un complot, une trahison, une balance | `constructeur_episode.dart`, `spectacle_prompt.dart`, `guide_content.dart` |
| Objectif / motivation (CROW « O ») | **Vouloir**, et sous lui le **besoin** | `tracking_*`, `spectacle_*`, `guide_content.dart` |
| Antagoniste (spin-off), « traîtres de cour » | **Opportuniste** ; « pas besoin de coupable » ; traître seulement en module de jeu | `spectacle_prompt.dart`, `spinoff_history_screen.dart`, `guide_content.dart:319`, `campagne_mechants.json:538` |
| Animaux annoncés (« Héros : Renard ») | Archétype et animal = **outils de jeu**, jamais nommés au public ni dans la narration IA | prompts, écran de régie (vue « public ») |
| Guide Destiny + Catalogue | **Bibliothèque** + livret de règles | `guide_*`, `catalog_view_screen.dart`, `root_screen.dart` |
| Tutoriel | **Découvrir Destiny** (onboarding) | `tutorial_screen.dart` |
| « RIEN EST ÉCRIT » | **« Rien n'est écrit »** | `top_countdown_screen.dart` |
| (n'existait pas) | Blessure, besoin, prix à payer, phrase fixée au premier figé, groupe, 3 objets, mystère, distribution, échauffement, débrief | à créer |

---

## 4. Inventaire exhaustif (liste de contrôle)

Chaque ligne sera cochée par la phase qui la traite. Légende de la colonne « Devient » : **À refondre**, **Gardé**, **Obsolète** (gardé, caché), **À créer**, **Remplacé**. La colonne § renvoie à ton prompt.

### 4.1 Données (`assets/data/`)

| ☐ | Fichier | Aujourd'hui | Devient | § |
|---|---|---|---|---|
| ☐ | `destiny_grammaire.json` | Absent de l'appli (ajouté au dépôt, non branché) | **À créer** comme asset, lu par le `GrammaireRepository`, validé au démarrage | 0.2, 3 |
| ☐ | `archetypes.json` | 24 animaux : tempérament, port, **moteur**, statut, intention, 4 niveaux (Masqué, Affleure, Domine, Extrême) | **À refondre** : fusion par id avec la grammaire (archétype, famille, réplique, posture). `moteur` et `intention` **obsolètes** (gardés, cachés). `niveaux` → « le corps à chaque palier » | 1.7, 1.8, 2.0 |
| ☐ | `dangers.json` | 38 dangers, style, Rue/Théâtre, 4 paliers (textes longs) | **Gardé comme référence**. Les noms de paliers viennent de la grammaire. Textes : à décider (annexe A) | 1.3, 0.2 |
| ☐ | `locations.json` | 40 lieux, 6 rôles, Rue | **Gardé**, + champ `espaces` (4 de la grammaire) | 1.2, 0.2 |
| ☐ | `location_details.json` | 40 lieux : 8 sous-espaces, fonctions, vocabulaire | **Gardé** (réserve d'idées) ; les 4 espaces passent devant | 1.2, 2.0 |
| ☐ | `dilemmas.json` | Dilemmes A/B par danger, champ `moteur` (= genre : Sacrifice, Confiance/Trahison…) | **À refondre** : servent le prix à payer de l'acte 4 ; `moteur` renommé « genre » à l'écran | 2.0, 2.4 |
| ☐ | `exercices.json` | 6 thèmes (Échauffement, Statut, Spontanéité, Écoute, Dialogue, Imagination), 32 exercices, 8 principes, 50 virelangues (onglet Solo) | **Gardé tel quel** ; les 3 nouveaux thèmes et leurs 20 exercices sont lus dans la grammaire (voir 9.5) | 2.7 |
| ☐ | `campagne_archetypes.json` | 16 animaux (dont tortue, dauphin, éléphant, pie) avec **moteur** et statut ; 18 objectifs | **À refondre** : correspondance animal → archétype (11.4) ; objectifs → propositions de vouloir ; moteur **obsolète** | 2.5 |
| ☐ | `campagne_lieux.json` | 42 lieux (2 par univers), 5 espaces, rôles en texte | **À refondre** : lieux uniques par univers, avec groupes et dangers à 4 paliers (phase 5) | 2.5 |
| ☐ | `campagne_mechants.json` | 42 méchants : but, 3 manœuvres, 4 présages, sbires. Présage 4 de `post_apo_chef` : « un traître se cache parmi eux » | **À refondre** : les 4 présages deviennent le **grand danger** de la campagne. La phrase du traître est à réécrire (« le soupçon ») | 2.5, 1.14 |
| ☐ | Cartes « Destin » (en dur dans `top_countdown_screen.dart:46-54`) | 6 cartes de Johnstone | **À déplacer** dans un fichier de données, module facultatif « Rebondissement de régie » | 2.0, 6 |

### 4.2 Domaine et logique

| ☐ | Fichier | Aujourd'hui | Devient | § |
|---|---|---|---|---|
| ☐ | `domain/entities/archetype.dart` | Un « archétype » = un animal (moteur, statut, niveaux) | **À refondre** : devient `Animal` ; nouvelle entité `Archetype` (12) et `Famille` (3) | 3.1 |
| ☐ | `domain/entities/danger.dart` | `Danger` + `kStadesEscalade` **en dur** (Signale, Enferme, Envahit, **Supprime**) | **À refondre** : paliers nommés depuis la grammaire (« Il bloque les sorties ») ; `kStadesEscalade` supprimé | 1.3, 0.2 |
| ☐ | `domain/entities/location.dart` | Lieu, rôles, Rue, actif | **À refondre** : + espaces | 1.2 |
| ☐ | `domain/entities/story.dart`, `player_assignment.dart` | Tirage : lieu, danger, joueurs (animal + rôle), dilemme | **À refondre** : `Histoire` avec groupe, objets, mystère, distribution, personnages à six couches | 2.8, 3.1 |
| ☐ | `domain/entities/dilemma.dart` | Dilemme (champ `moteur` = genre) | **Gardé**, champ renommé à l'affichage | 2.0 |
| ☐ | `domain/entities/exercice.dart` | Exercice simple | **À refondre** : source, badge, notion, exemples, débrief, variante, cartes à tirer | 2.7 |
| ☐ | `domain/entities/campagne.dart` | Lieu, méchant, sbires, `ArchetypeHistoire` (moteur, statut), figurant, rôle joueur, escalade, épisode, campagne | **À refondre** : personnages à six couches persistés, grand danger, objets, mystère, sortie du palier 4 | 2.5 |
| ☐ | `domain/entities/chat_story.dart`, `chat_message.dart` | Histoire IA : joueurs `{name, archetype, traits}`, messages avec `kind` brave/smart et résultat | **À refondre** : personnage à six couches, univers explicite, version de grammaire | 2.6 |
| ☐ | `domain/entities/spectacle_turn.dart` | Lecture du JSON de tour (phase, acte, palier, CROW, score) | **À refondre** (nouveau schéma, 4 actes, rituel) | 2.6 |
| ☐ | `domain/usecases/generate_story_usecase.dart` | Tirage lieu × danger (anti-répétition), animaux avec variété de statuts, rôles. Effet de bord : le chat consomme le cycle de dangers du Générateur | **À refondre** : distribution par familles (alarmiste toujours là), groupe, objets, mystère, fixation possible de n'importe quel élément. Découplé du chat | 1.9, 2.8 |
| ☐ | `domain/usecases/constructeur_episode.dart` | Épisode de campagne : méchant stable, **lieu qui alterne** à chaque épisode, 2 figurants, parité des statuts, 4 marches (présages des sbires puis du méchant). `horairesDesPresages` et `borner` servent seulement aux tests | **À refondre** : un lieu et un danger par épisode, 4 actes, sortie du palier 4 → lieu suivant, PNJ avec archétype. Le défaut d'appariement lieu/méchant est corrigé | 2.5 |
| ☐ | `domain/repositories/*` | Contrats catalogue, histoire, mémoire, chat | **Gardés** + `GrammaireRepository`, `SessionRepository` | 3.2 |
| ☐ | `application/services/random_picker_service.dart` | Tirages | **Gardé** | — |
| ☐ | **À créer** : `domain/grammaire/` (entités typées), `domain/usecases/distribution.dart`, `progression_paliers.dart`, `controle_besoin.dart`, `migration/` | — | **À créer** | 3, 1.9, 1.12 |

### 4.3 Infrastructure et persistance

| ☐ | Élément | Aujourd'hui | Devient | § |
|---|---|---|---|---|
| ☐ | `sqlite_catalog_store.dart` (`destiny_catalog.db` v4) | Lieux, dangers, dilemmes ; seed unique au premier lancement ; ne sait pas ce que tu as modifié | **Migration v5** (9.1) : empreinte de l'origine, ajout des espaces, respect de tes modifications | 3.4 |
| ☐ | `sqlite_chat_store.dart` (`destiny_chat.db` v5) | Histoires IA (messages, joueurs, ton, archives) | **Migration v6** : version de grammaire, univers ; les anciennes restent lisibles en archives marquées | 3.3 |
| ☐ | `sqlite_combination_memory.dart` | Mémoire anti-répétition des dangers (ids) | **Gardé tel quel** (les ids de dangers ne changent pas) | 3.5 |
| ☐ | `in_memory_*` (web) | Équivalents en mémoire pour la version web | **Gardés**, + équivalents des nouveaux stockages | 2.0 |
| ☐ | `local_json_datasource.dart` | Lecture des JSON embarqués | **À refondre** : + grammaire | 3.2 |
| ☐ | `story_repository_impl.dart` | Lieux et dangers du catalogue, animaux du JSON | **À refondre** : branché sur la grammaire | 3.2 |
| ☐ | SharedPreferences `campagnes_v1`, `campagne_seances_v1`, `campagne_prochain_id_v1` | Campagnes et séances. **Une erreur de lecture peut tout effacer** à la sauvegarde suivante | **Migration v2** (9.2) + correctif de sécurité | 3.3 |
| ☐ | SharedPreferences `spectacle_session`, `spectacle_history` | Partie en cours (**avec l'ancien prompt système complet**) et 40 parties archivées | **À refondre** : une partie en cours de l'ancienne grammaire est proposée en archive, pas reprise ; le prompt n'est plus stocké | 3.3 |
| ☐ | **À créer** : base `destiny_sessions.db` | — | Spectacles, répétitions et parties : distribution, objets, mystère, Destiny, notes de régie, débrief | 2.4 |

### 4.4 Prompts IA (tous à centraliser dans `lib/application/prompts/`)

| ☐ | Prompt | Aujourd'hui | Devient | § |
|---|---|---|---|---|
| ☐ | P1 Spectacle, `spectacle_prompt.dart:3-202` | ~200 lignes. 24 archétypes **en dur** avec « tempérament · port · **moteur** », statuts de Johnstone, **3 actes** pour 4 paliers, paliers nommés autrement (« il pointe, il s'installe, critique, irréversible »), **DESTINY lancé par l'IA**, sortie du lieu permise à l'acte 3, CROW et score sur 100 | **À refondre** : Maître du destin (rôle 1), 4 actes, rituel déclenché par le joueur (bouton), alarmiste, six couches. CROW gardé comme outil de coach | 2.6 |
| ☐ | P2 Spin-off du Spectacle, `spectacle_prompt.dart:309-359` | Film réel, archétype « parmi les 24 », paliers inventés à la volée, démarre sur le danger, protagoniste `antagoniste` | **À refondre** selon la décision sur le Spin-off (11.1) | 2.6 |
| ☐ | P3 Carte spin-off, `spectacle_prompt.dart:206-245` (appel `generator_screen.dart:179`) | Film, année, lieu, danger | **Gardé** (pas de grammaire), centralisé | 2.6 |
| ☐ | P4 Messages de tour du Spectacle, `spectacle_controller.dart:385-467` | « Lève le rideau : Acte 1, scène 1… » | **À refondre** | 2.6 |
| ☐ | P5 Maître du jeu du chat, `gm_prompt.dart` (+ duo, percutant, enfant, petit) | BRAVE/SMART, DONC/MAIS, « l'archétype est une personnalité, pas l'animal », danger monté sur demande, sans actes | **À refondre** : Maître du destin, 4 chapitres = 4 paliers, Destiny entre les chapitres, alarmiste, six couches, choix final vouloir/besoin. BRAVE/SMART gardés comme choix d'action | 2.6, 2.5 |
| ☐ | P6 Amorce du chat, `chat_controller.dart:425-495` | Injecte « tempérament · port · **moteur** » de chaque héros, lieu « à réinterpréter dans l'univers » | **À refondre** (générateur de mise en place, rôle 2) | 2.6 |
| ☐ | P7 Messages de tour du chat, `chat_controller.dart:79-366` | « **Résultat des dés** », malus « 2 réussites », « MONTE LE DANGER » **tous les 4 tours** (7 montées pour 4 paliers en 30 réponses) | **À refondre** : montée alignée sur les 4 chapitres ; plus de « dés » dans les textes | 2.6 |
| ☐ | P8 Résumé du chat, `chat_controller.dart:177-192` | Résumé en 3-4 phrases ou conte | **À refondre** : résumé + « il veut… mais il a besoin de… » (coach de débrief, rôle 5) | 2.6 |
| ☐ | P9 Résumé de campagne, `campagne_assistant.dart:56-105` | JSON `{resume, suite}` ; « ce que le méchant a fait depuis » ; sans prénoms | **À refondre** : + palier du grand danger, prix payé, sortie vers le lieu suivant. Contrainte gardée : l'assistant n'importe pas l'entité Campagne (test « vie privée ») | 2.5, 2.6 |
| ☐ | **À créer** : générateur de personnage (rôle 3), voix de l'alarmiste (rôle 4), coach de débrief (rôle 5), coach d'échauffement (rôle 6) | — | **À créer**, variantes adulte et enfant | 2.6 |
| ☐ | `llm_service.dart` | Transport OpenAI / Anthropic / Google. Anthropic limité à 1024 jetons (le score du Spectacle peut être tronqué) ; température 0,9 imposée (refusée par certains modèles de raisonnement) | **Gardé**, réglages techniques corrigés | 2.6 |

### 4.5 Écrans (`lib/presentation/screens/`, 32 fichiers)

| ☐ | Écran | Aujourd'hui | Devient | § |
|---|---|---|---|---|
| ☐ | `root_screen.dart` | 4 onglets ; en-tête : Instagram, TikTok, Guide, Suivi, Catalogue dangers, Catalogue archétypes, Paramètres, son | **À refondre** : en-tête Bibliothèque + Réglages + son ; onglet 1 « Troupe » ; DA | 2, 7 |
| ☐ | `generator_screen.dart` | Modes Histoire / Rue / Spin-off (Dilemme caché), joueurs (−/+), tirage, Rejouer / Relancer / Effacer, TOP. Construit les « héros » avec moteur | **À refondre** : devient l'accueil + le mode Troupe + « Tirage rapide » (2.8) + formats courts | 2.4, 2.8 |
| ☐ | `top_countdown_screen.dart` | Chrono plein écran : durée 30-50 min, **3 DESTINY minutés**, **dé** à poids, cartes Destin, héros avec moteur, étapes du danger, musique scénarisée, transcription, « RIEN EST ÉCRIT » | **À refondre** : tableau de bord de régie (4 actes, minuteur par acte, bouton Destiny manuel + automatique, nouvelle de l'alarmiste, rappels Dire/Fixer/Bloquer/Nommer/Choisir, montée par archétype, notes horodatées). « Rien n'est écrit » | 2.4 |
| ☐ | `generation_history_screen.dart` | Derniers tirages (« Héros : archétype (rôle) », paliers) | **Gardé**, adapté ; les tirages 1.x restent lisibles, marqués « ancienne grammaire » | 3.5 |
| ☐ | `spinoff_history_screen.dart` | Historique des spin-off (antagoniste en rouge) | **Selon décision Spin-off** (11.1) | 2.0 |
| ☐ | `music_screen.dart` | Onglet Musique (catégories, tri, lecture) | **Gardé** (DA) | 2.0 |
| ☐ | `histoire_hub_screen.dart` | Cartes IA et Campagne (« Sans IA » inexact) | **Gardé**, textes refaits | 2.9 |
| ☐ | `chat_screen.dart` | Création (univers, ton, solo/duo, longueur, héros = un des 24 animaux avec **moteur**), bulles, **« dés »** (pile ou face), malus « 2 réussites », orage tous les 4 tours, BRAVE / SMART | **À refondre** : personnage à six couches (choix d'archétype puis d'animal), 4 chapitres = 4 paliers, rituel Destiny entre chapitres, choix final vouloir/besoin. La résolution réussite/échec est **gardée** (c'est du jeu), sans le mot « dé » | 2.5, 2.6 |
| ☐ | `chat_archives_screen.dart` | Archives du chat | **Gardé** ; histoires 1.x marquées « ancienne grammaire » | 3.3 |
| ☐ | `campagne_liste_screen.dart` | Liste, création (public, univers, ton, lore, contexte), fiche (résumé, épisodes) | **À refondre** : + groupe, grand danger, réglages de campagne, module traître | 2.5 |
| ☐ | `campagne_preparation_screen.dart` | 2 à 5 joueurs ; prénom, peuple, animal (**parité des statuts**), fonction ; détail « tempérament · port · **moteur** » ; dangers 2/3/4 à **30/60/90 %** | **À refondre** : fiche personnage six couches, distribution équilibrée (alarmiste PNJ si moins de 4), 4 actes | 2.5 |
| ☐ | `campagne_jeu_screen.dart` | Chrono, lieu, figurants, méchant, escalade (cube « DANGER N »), rôles (**moteur** en doré), combat (cœurs, malus/bonus), pièce du destin, régie. Micro coupé à 12 min | **À refondre** : 4 actes et rituel Destiny, PNJ avec archétype et montée, grand danger ; combat, malus/bonus, pièce **gardés** (activables). Micro aligné sur la durée | 2.5 |
| ☐ | `campagne_bilan_screen.dart` | Ce qui a marché, phrase gardée, résumé IA sans prénoms | **À refondre** : prix payé, choix vouloir/besoin, sortie du palier 4 (lieu suivant), palier du grand danger | 2.5 |
| ☐ | `scene_hub_screen.dart` | Cartes Spectacle (IA) et Exercices | **Gardé**, textes | 2.9 |
| ☐ | `spectacle_screen.dart` | Réglages, tirage (icône **dé**), 4 animaux « · **moteur** », Acte / Scène / Palier, propositions, CROW, bandeau « DESTINY » posé par l'IA, score | **À refondre** : décor = lieu + espaces + groupe + objets + mystère, archétype puis animal, bouton Destiny côté joueur, 4 actes | 2.6 |
| ☐ | `spectacle_archives_screen.dart` | Parties archivées, score brut | **Gardé**, rendu du score corrigé, parties 1.x marquées | 3.3 |
| ☐ | `exercices_screen.dart` | 6 thèmes + Solo (virelangues), principe du jour, chrono, confettis | **Gardé** + onglets CROW, Lieu, Destiny ; fiche enrichie (source, badge Mark Jane, exemples, débrief, variante, lien Bibliothèque, tirage des 10 cartes) | 2.7 |
| ☐ | `guide_screen.dart` | 16 sections dépliables, édition en mode admin | **Remplacé** par la Bibliothèque ; le moteur de rendu (puces, encadrés) est réutilisé pour le livret | 2.3, 2.13 |
| ☐ | `tutorial_screen.dart` | 9 cartes (« 5 onglets », « l'app lance les dés », BRAVE/SMART) | **Remplacé** par l'onboarding « Découvrir Destiny » | 2.2 |
| ☐ | `tracking_screen.dart` | Suivi de répétition en **3 actes** : C·O·W·A par joueur, relations, antisèche | **À refondre** : 4 actes, colonnes Dire / Fixer / Bloquer / Nommer / Choisir, relations ; intégré au débrief de la Troupe | 2.4 |
| ☐ | `relation_cheatsheet_screen.dart` | Antisèche : 12 liens, 6 registres (dont « Trahison », un type de lien) | **Gardé** : sert « tout le monde se connaît » (liens proposés au tirage) | 2.0 |
| ☐ | `location_details_screen.dart` | Liste, édition, popup : sous-espaces, fonctions, vocabulaire | **Gardé** : + les 4 espaces en tête | 2.0 |
| ☐ | `catalog_editor_screen.dart` | CRUD lieux et dangers, paliers libellés « Palier 1 — un signe… Palier 4 — climax, survie » | **À refondre** : paliers nommés (grammaire), espaces | 2.12 |
| ☐ | `catalog_view_screen.dart` | Catalogue lecture seule (lieux, dangers, archétypes avec **moteur** et niveaux Masqué… Extrême), export JSON | **Remplacé** par la Bibliothèque ; l'export JSON passe en admin | 2.3 |
| ☐ | `dilemma_editor_screen.dart` | CRUD dilemmes par danger, « Genre (moteur) » | **Gardé** : « Genre » ; présenté comme « dilemme de l'acte 4 » | 2.0, 2.12 |
| ☐ | `settings_screen.dart` | 13 entrées, mode admin, « v1.4.0 » | **À refondre** : section Destiny en tête, regroupements, version unique | 2.12 |
| ☐ | `appearance_screen.dart` | Texte du Chat, visuels, affichage du résultat, durée du TOP court, **poids du dé**, sons du chrono, musique à chaque DESTINY | **À refondre** : Apparence (texte, visuels, affichage, thème clair/sombre, réduire les animations) ; le dé sort ; sons → « Rituel Destiny » | 2.12 |
| ☐ | `ai_config_screen.dart` | Fournisseur, modèle, jeton, « Style du Maître du jeu » ; texte CORS contradictoire | **Gardé**, textes corrigés (« Maître du destin »), liste de modèles à jour | 2.12 |
| ☐ | `database_screen.dart` | Cycle et combinaisons tirées, remise à zéro | **Gardé**, renommé « Mémoire des tirages » + rapport de migration (admin) | 3 |
| ☐ | `about_screen.dart` | « Version 1.0.0 », icône dé, textes 1.x | **À refondre** | 2.9 |
| ☐ | `credits_screen.dart` | Crédits des sons | **Gardé** + polices (OFL), Mark Jane, sources des répliques | 2.9 |
| ☐ | `contact_screen.dart` | Instagram / TikTok | **Gardé** (DA) | 2.9 |
| ☐ | **À créer** | Onboarding ; Accueil ; Bibliothèque (hub, archétypes, fiche archétype, animaux, dangers, lieux, œuvres, fiche œuvre, vouloir et besoin, outils de jeu, livret, lexique) ; Troupe (joueurs, distribution, animaux, échauffement, avant d'entrer, régie, débrief, historique) ; rituel Destiny (plein écran) ; réglages Destiny ; rapport de migration ; éditeur d'archétypes en lecture seule (admin) | **À créer** | 2.2-2.4, 2.12, 2.13 |

### 4.6 Widgets et visuels

| ☐ | Élément | Aujourd'hui | Devient | § |
|---|---|---|---|---|
| ☐ | `story_result_card.dart` | Fiche du tirage : danger, lieu, fonctions, « Héros » (tempérament · port · **moteur**), « Étapes du danger » | **À refondre** : carte d'archétype (famille en couleur, animal, réplique, montée du palier), frise des paliers, groupe, objets, mystère | 2.1, 2.8 |
| ☐ | `moteur_info.dart` | Bulle « moteur » : intention + niveaux Masqué / Affleure / Domine / Extrême | **Obsolète** → remplacé par la fiche archétype / animal (« le corps à ce palier ») | 2.0 |
| ☐ | `rue_result_card.dart` | Carte Rue (paliers 3-4 seulement) | **Selon décision Rue** (11.1) | 2.0 |
| ☐ | `dilemma_result_card.dart` | Carte du mode Dilemme (« Genre : » + moteur) | **Réutilisée** pour proposer le dilemme à l'acte 4 | 2.0 |
| ☐ | `destiny_cube_animation.dart` | Cube doré « lancement du dé » | **Gardé**, intégré à l'animation du rituel (sans tirage) | 2.1 |
| ☐ | `dice_3d.dart` | Dé 3D **inutilisé** ; couleurs `DestinyOmen` de la pièce | **Classe à supprimer** (couleurs gardées) | 10 |
| ☐ | `piece_destin_flip.dart` | Pièce BRAVE / SMART | **Gardée** | 2.5 |
| ☐ | `sound_mixer_sheet.dart` | Régie son | **Gardée** (DA) | 2.0 |
| ☐ | `entity_image.dart` | Vignette réaliste / vectorielle / minimale | **Gardée**, sert aux médaillons | 2.0 |
| ☐ | `film_poster.dart`, `spinoff_lottery.dart` | Affiche et loterie du spin-off | **Selon décision Spin-off** | 11.1 |
| ☐ | `story_controls_card.dart` | Réglage du nombre de joueurs | **À refondre** (4, 5 ou 6) | 2.4 |
| ☐ | `mode_card.dart`, `ecran_sombre.dart`, `location_detail_section.dart` | Cartes de hub, habillage sombre, sections de lieu | **Gardés** (DA ; « Sous-espaces » → « Espaces ») | 2.1 |
| ☐ | `theme/app_theme.dart` | Thème sombre violet et or, Roboto | **À refondre** : `ThemeData` clair et sombre + `ThemeExtension` Destiny, Cinzel et Montserrat | 2.1 |
| ☐ | `visuals/entity_visuals.dart` | Statuts (ambre / bleu / blanc), dégradés, icônes, emojis (**Hyène = léopard, Vautour = aigle**), champs `query` morts | **À refondre** : couleurs de famille, pastilles de statut DA, emojis corrigés | 2.1 |
| ☐ | `visuals/campagne_visuals.dart` | Emojis des 16 animaux de campagne | **À refondre** (24 + animaux enfant) | 2.5 |
| ☐ | Couleurs en dur hors thème | Dégradé de fond dans 21 fichiers, or `#FFC24B` dans 24 fichiers (≠ or du thème) | **Centralisées** dans le thème | 2.1 |
| ☐ | **À créer** : carte d'archétype (recto archétype, recto animal, verso « Rien n'est écrit »), puce de famille, pastille de statut, médaillon d'animal, frise des paliers, bandeau « affiche », encart de réplique, fiche personnage six couches, animation Destiny | — | **À créer** + tests golden | 2.1 |

### 4.7 État applicatif (`lib/application/state/`)

| ☐ | Fichier | Aujourd'hui | Devient | § |
|---|---|---|---|---|
| ☐ | `visual_settings.dart` | Apparence, durée du TOP court, **poids du dé**, sons du chrono, musique DESTINY, mode admin, cube (toujours vrai) | **À refondre** (voir 5) | 2.12 |
| ☐ | `guide_content.dart` | 16 sections : 3 actes, statuts, CROW, « 3 Destinys », **le dé du destin** (s10), **moteur × danger** (s12), « 24 archétypes incarnés » avec moteurs (s13), « traîtres de cour » (l.319) | **Remplacé** par les contenus de la grammaire dans la Bibliothèque. Les surcharges admin (`guide_overrides_v1`) sont gardées en base mais ne s'appliquent pas au nouveau contenu | 2.3 |
| ☐ | `tracking_store.dart` | Suivi en 3 actes | **À refondre** (4 actes) | 2.4 |
| ☐ | `story_controller.dart`, `story_state.dart` | État du Générateur (modes, dont `dilemme` caché) | **À refondre** | 2.8 |
| ☐ | `last_generation_store.dart`, `generation_history.dart`, `spinoff_history.dart` | Dernier tirage et historiques (le JSON embarque moteur et niveaux) | **Gardés**, schéma versionné, lecture des anciens tirages | 3.5 |
| ☐ | `music_controller.dart` | Commencement au départ, ambiance du lieu 15 s après DESTINY 2, Conclusion 15 s après DESTINY 3 ; musiques importées à chaque DESTINY | **Gardé**, aligné sur les actes : Commencement (acte 1), ambiance du lieu (acte 2), Conclusion (acte 4) ; ambiance par palier possible avec les pistes existantes (voir 4.8) | 2.0 |
| ☐ | `relation_cheatsheet.dart`, `location_details.dart` | Antisèche, détails des lieux | **Gardés** (+ espaces) | 2.0 |
| ☐ | `campagne_store.dart`, `chat_controller.dart`, `spectacle_controller.dart`, `spectacle_store.dart`, `ai_settings.dart` | Voir 4.3 et 4.4 | Voir 4.3 et 4.4 | 2.5, 2.6 |
| ☐ | `main.dart` | Démarrage : catalogue, use case, contrôleurs, campagnes, thème | **À refondre** : chargement et validation de la grammaire, migrations, nouveaux stores | 3 |

### 4.8 Sons et musiques

| ☐ | Fichier | Aujourd'hui | Devient | § |
|---|---|---|---|---|
| ☐ | `audio/DestinyStorm.wav` (« Tonnerre Destiny ») | Son par défaut à chaque DESTINY | **Le tonnerre du rituel** | 1.4 |
| ☐ | `audio/dice.wav` (« Dé ») | Son par défaut **au début du chrono** | **Gardé** comme son au choix ; n'est plus le défaut | 1.14 |
| ☐ | `audio/thunder.wav` | Alerte 10 s avant la fin ; montée du danger dans le chat | **Gardé** | — |
| ☐ | `audio/coin.wav` | Pièce du destin | **Gardé** | 2.5 |
| ☐ | `audio/crack.wav`, `shine.wav`, `reveal.wav`, `story_epic.wav` | Fin du chrono, bilan / exercice, révélation, épique | **Gardés** | — |
| ☐ | **Rire du destin** | **N'existe pas** | **À créer** : il me faut un fichier (voir décisions) | 1.4 |
| ☐ | `music/01_commencement.m4a`, `02_conclusionainsique.m4a`, `destinystorm.m4a` | Thèmes du spectacle | **Gardés** : Commencement → acte 1, Conclusion → acte 4 | 2.0 |
| ☐ | `music/emo_*` (13 émotions × 2, dont « Trahison ») | Régie son | **Gardés**. Proposition d'ambiance par palier avec les pistes existantes : Mystère (1), Tension (2), Traque ou Peur (3), Climax (4). Le titre « Trahison » est une émotion musicale, pas le rôle : je le garde | 2.0 |
| ☐ | `music/atm_*` (11), `audio/ambiences/*` (40 lieux), `audio/universes/*` (21 univers) | Ambiances | **Gardés** (les ambiances des lieux sont rangées par id de lieu, d'où l'importance de garder les ids) | 0.2 |

### 4.9 Images, polices, icône, stores

| ☐ | Élément | Aujourd'hui | Devient | § |
|---|---|---|---|---|
| ☐ | `images/archetypes/*.jpg` (24) | Vignettes des animaux | **Gardées** → médaillons cerclés d'or | 2.1 |
| ☐ | `images/locations` (40), `images/dangers` (38) | Vignettes | **Gardées** | — |
| ☐ | `images/destiny_cube.png` | Cube doré | **Gardé** : dos des cartes et rituel | 2.1 |
| ☐ | `fonts/PatrickHand-Regular.ttf` | « RIEN EST ÉCRIT » et écriture manuscrite du Chat | **Gardée** pour l'option manuscrite ; la signature passe en Cinzel | 2.1 |
| ☐ | Cinzel, Montserrat | Absentes | **À embarquer** (licence libre OFL) | 2.1 |
| ☐ | `icon/app_icon*.png` | Icône actuelle | **À décider** (garder ou refaire en noir et or) | 0 bis |
| ☐ | `docs/store_assets/` (icône, bannière 1024×500, 4 captures 1.5.0) | Fiche Play Store | **À refaire** (captures automatiques via la version web) | 2.9 |

### 4.10 Documentation, web, version

| ☐ | Fichier | Aujourd'hui | Devient | § |
|---|---|---|---|---|
| ☐ | `README.md` | Survol 1.x (« dé animé », « archétypes ») | **À refondre** | 8 |
| ☐ | `docs/FEATURES.md` | Documenté en 1.5.0 ; dé, moteur, statuts, « 12 + 9 univers » | **À refondre** | 8 |
| ☐ | `docs/play_store_listing.md` | « héros… leur moteur intérieur », « trois moments DESTINY qui forcent les rebondissements » | **À refondre** (description courte et longue) | 2.9 |
| ☐ | `docs/play_console_answers.md`, `privacy.html`, `cicd_setup.md` | Formulaires Play, confidentialité, CI | **Relus** (rien de grammatical ; la confidentialité reste vraie hors IA) | 8 |
| ☐ | `docs/app/` | Version web compilée (1.5.7) | **Reconstruite** à la fin | 8 |
| ☐ | Version affichée | « v1.4.0 » (Réglages), « 1.0.0 » (À propos), 1.5.7+19 (pubspec) | **Une seule source**, 2.0.0+20 | 0.7 |
| ☐ | **À créer** : `CHANGELOG.md` en français pour les comédiens | — | **À créer** | 0.7 |

### 4.11 Tests (`test/`)

État au départ : voir 1.4.

| ☐ | Fichier | Ce qu'il teste | Devient | § |
|---|---|---|---|---|
| ☐ | `catalog_paliers_test.dart` | Recomplétion des paliers ; 38 dangers à 4 paliers | **Mis à jour** : paliers nommés, migration v5 (tes modifications respectées) | 0.7 |
| ☐ | `constructeur_episode_test.dart` | Méchant stable, **le lieu change d'un épisode à l'autre**, figurants, continuité des morts | **Mis à jour** : un lieu par épisode, sortie du palier 4 → lieu suivant, 4 actes, PNJ avec archétype | 0.7 |
| ☐ | `generate_story_usecase_test.dart` | Entrées actives, cycle anti-répétition | **Mis à jour** + distribution équilibrée | 1.9 |
| ☐ | `campagne_assistant_test.dart` | Sans prénoms, lecture du résumé, test « vie privée » | **Gardé** (+ nouveaux champs) | 2.5 |
| ☐ | `widget_test.dart` | Démarrage de l'appli | **Mis à jour** | — |
| ☐ | **À créer** | Grammaire (schéma), distribution (4/5/6, refus et explication), paliers, montées, besoin-objet, migrations, prompts (cas types), golden des cartes | **À créer** | 3, 4 |

---

## 5. Les réglages, un par un (§ 2.12)

### 5.1 Réglages existants

| ☐ | Réglage (écran › libellé) | Clé | Aujourd'hui | Décision proposée |
|---|---|---|---|---|
| ☐ | Apparence › Taille du texte du Chat | `text_scale` | 0,8 à 1,6 | **Gardé**, renommé « Taille du texte » et appliqué aussi à la Bibliothèque et aux fiches |
| ☐ | Apparence › Écriture du Chat (standard / manuscrite) | `chat_handwritten` | police PatrickHand | **Gardé** |
| ☐ | Apparence › Visuels des cartes (réaliste / vectoriel / minimal) | `visual_source` | `ai` par défaut | **Gardé**, appliqué aux médaillons et aux cartes d'archétype |
| ☐ | Apparence › Affichage du résultat (côté / grand / plein écran) | `result_layout` | `cote` par défaut | **Gardé**, appliqué à la carte du tirage |
| ☐ | Apparence › Durée du TOP (30 / 45 / 60 / 90 **secondes**), pour Rue et Spin-off | `top_seconds` | 30 s | **Gardé** pour les formats courts, renommé « Durée des formats courts » |
| ☐ | Chrono › Durée du chrono (30 / 40 / 45 / 50 **minutes**), non sauvegardé | — | 30 min | **Remplacé** par « Durée totale du spectacle » et « Durée de chaque acte », sauvegardés (section Destiny) |
| ☐ | Chrono › Moments des 3 DESTINY (10 / 18 / 27 min), non sauvegardé | — | 25 / 50 / 75 % | **Remplacé** par « Déclenchement du rituel » : automatique (fin de chaque acte), manuel par la régie, ou les deux (défaut : les deux) |
| ☐ | Apparence › DESTINY — le dé (poids Archétype / Danger / Destin) | `destiny_w_arch`, `destiny_w_dang`, `destiny_w_dest` | 3 / 2 / 7 | **Retiré** de l'interface ; clés gardées, ignorées. Remplacé par les réglages du rituel et le module « Rebondissement de régie » |
| ☐ | Apparence › Sons du chrono › Au début du chrono | `son_debut` | `dice` (Dé) | **Renommé** « Son du lever de rideau » ; nouveau défaut proposé : Révélation |
| ☐ | Apparence › Sons du chrono › À chaque DESTINY | `son_destiny` | `storm` | **Renommé** « Tonnerre du rituel » (section Destiny) |
| ☐ | Apparence › Musique à chaque DESTINY (importée) | `son_destiny_musique` | aucune | **Gardé**, rangé dans le rituel |
| ☐ | Animation du cube (sans interface, toujours activée) | — | vrai | **Remplacé** par « Réduire les animations » (accessibilité) |
| ☐ | Paramètres › Mode admin | `admin_mode` | ne protège que l'édition du Guide | **Gardé** ; il protège l'édition du livret et donne accès à l'éditeur d'archétypes (lecture seule), à l'export JSON et au rapport de migration. Faut-il qu'il protège aussi les éditeurs du catalogue ? (D20) |
| ☐ | Configurer l'IA › fournisseur, modèle, jeton | `ai_provider`, `ai_model`, `ai_token` | OpenAI, gpt-4o | **Gardé**, liste des modèles mise à jour |
| ☐ | Configurer l'IA › Style du Maître du jeu (normal / percutant / enfant / petit) | `ai_narration` | percutant | **Renommé** « Style du Maître du destin » (longueur des réponses ; le mode enfant devient un réglage à part) |
| ☐ | Régie son › boucle, volume | — | boucle, 0,8 | **Gardés** |
| ☐ | Son coupé (en-tête) | — | non sauvegardé | **Gardé** |
| ☐ | Tutoriel | — | 9 cartes | **Remplacé** par « Découvrir Destiny » |
| ☐ | Gérer lieux et dangers | SQLite | lieux, dangers, 4 paliers | **Gardé** + espaces + paliers nommés |
| ☐ | Détails des lieux | `location_details_overrides_v1` | sous-espaces, fonctions, vocabulaire | **Gardé** + les 4 espaces en tête |
| ☐ | Antisèche de relations | `relation_cheatsheet_v1` | 12 liens | **Gardé** (« tout le monde se connaît ») |
| ☐ | Dilemmes par danger | SQLite | « Genre (moteur) » | **Gardé** : « Genre », dilemme de l'acte 4 |
| ☐ | Catalogue de données | — | lecture seule | **Déplacé** dans la Bibliothèque ; l'export JSON passe en admin |
| ☐ | Base de données | SQLite | cycle, remise à zéro | **Gardé**, renommé « Mémoire des tirages » |
| ☐ | Me contacter, Crédits, À propos | — | — | **Gardés**, textes refaits, version unique |

### 5.2 Nouvelle section « Destiny »

| Réglage | Valeurs | Défaut proposé |
|---|---|---|
| Nombre de joueurs par défaut | 4, 5, 6 | 4 |
| Mode de distribution | choix concerté, tirage équilibré, exemple tout prêt | tirage équilibré |
| Leader | facultatif, obligatoire | facultatif (comme le dit le fichier) |
| Durée totale du spectacle | libre (de 20 à 60 min) | 30 min (voir D25) |
| Durée de chaque acte | 4 curseurs, recalculés avec la durée totale | 10 / 8 / 8 / 4 min |
| Déclenchement du rituel | automatique, manuel, les deux | les deux |
| Rituel : tonnerre, rire, lumière bleue | 3 interrupteurs + choix du son | tous activés |
| Rituel : durée du figé | 2 à 10 s | 4 s |
| Rituel : texte d'ellipse | texte libre | « Quelques heures plus tard… » |
| Musique du rituel | aucune, au hasard, importée | aucune |
| Rappel du premier figé (fixer le besoin) | oui, non | oui |
| Rappels de régie acte par acte | oui, non | oui |
| Répliques des animaux | afficher, masquer | afficher |
| Sources des répliques | fiche détaillée seulement (non modifiable : c'est ta règle) | — |
| Mode enfant | oui, non | non |
| Minuteur d'échauffement | 10 à 60 min | 30 min |
| Rebondissement de régie (cartes « Destin ») | oui, non | non |
| Module traître (jeu seulement) | oui, non | non |

**Campagne** : épisodes par palier du grand danger (1 à 3, défaut 1) ; évolution de l'archétype entre deux épisodes (permise ou non, défaut permise) ; combat (oui/non) ; pièce du destin (oui/non).

**Apparence** (nouveaux réglages) : thème clair, sombre ou automatique ; réduire les animations.

---

## 6. Le dé : où il sert aujourd'hui, et ce que je propose

| Où | Ce qu'il fait | Mécanique de spectacle ou de jeu ? | Proposition |
|---|---|---|---|
| Chrono TOP (`top_countdown_screen.dart:189-227`, `_rollDestiny`) | À chaque DESTINY, tire un **type** (Archétype / Danger / Destin) selon des poids réglables (3 / 2 / 7 par défaut), puis une valeur : un animal au hasard, un danger au hasard, ou une carte « Destin » de Johnstone. Affiché sous le chrono (« DESTINY 2 — Archétype : Renard »). | Spectacle. C'est exactement ce que la nouvelle grammaire retire : le changement d'animal et de danger au lancer. | **Retiré.** Un Destiny fait toujours monter le palier. Les poids deviennent des réglages obsolètes (clés gardées, ignorées). |
| Cartes « Destin » (`top_countdown_screen.dart:46-54`, 6 cartes en dur) | Une des trois faces du dé. | Spectacle. | **Gardées, en module facultatif « Rebondissement de régie »**, désactivé par défaut : un bouton de la régie tire une carte quand la régie le décide, jamais à la place du palier. Les cartes passent dans un fichier de données (elles sont aujourd'hui en dur, ce qui contredit la règle 2), chacune avec l'acte où elle tombe le mieux (exemple : « L'un de vous a menti… » pour l'acte 3, « Il n'y a plus qu'une issue pour un seul d'entre vous » pour l'acte 4). |
| Cube doré (`destiny_cube_animation.dart`, `assets/images/destiny_cube.png`) | Animation « lancement du dé » au départ du chrono et à chaque DESTINY ; aussi à chaque danger de la Campagne (« DANGER N »). | Visuel. | **Gardé comme élément du rituel** (le dé Destiny reste l'emblème, au dos des cartes), mais il ne « tire » plus rien : il apparaît dans l'animation Destiny (tonnerre → rire → voile bleu → figé). |
| `Dice3D` (`dice_3d.dart`) | Dé 3D générique. **Utilisé nulle part** (seules ses couleurs `DestinyOmen` servent à la pièce du destin). | Code mort. | À supprimer (liste section 10), en gardant les couleurs. |
| Pièce du destin BRAVE / SMART (Campagne, `piece_destin_flip.dart`) | Pile ou face lancé par le meneur, à volonté. | **Jeu** (résolution d'une action par le meneur). Ce n'est pas un dé de spectacle. | **Gardée telle quelle**, activable dans les réglages Campagne (2.12). |
| Mode Histoire IA (`gm_prompt.dart`) | Le MJ IA propose deux actions [BRAVE] / [SMART] ; aucun dé. | Jeu. | Gardé comme mécanique de choix ; le prompt est réécrit (phase 6). |

Le dé n'a donc **aucune autre utilisation de jeu** que la pièce du destin. Rien à arbitrer de plus de ce côté.

## 7. Navigation cible

Je garde les quatre onglets, avec leur nouveau sens, et je remplace le Guide par la Bibliothèque dans l'en-tête.

```
En-tête : [Bibliothèque]  DestinyStory  [Réglages]
┌──────────────┬──────────┬──────────────┬──────────┐
│ Troupe       │ Musique  │ Histoire     │ Scène    │
│ (ex-Générat.)│          │              │          │
└──────────────┴──────────┴──────────────┴──────────┘
```

1. **Troupe** (ex-Générateur, « Préparer et jouer un spectacle »)
   - En haut, l'**accueil** : la règle d'or ou la réplique du jour, et quatre entrées (Jouer une histoire → onglet Histoire ; Préparer un spectacle ; Explorer la bibliothèque ; Faire un exercice → onglet Scène).
   - **Préparer un spectacle** : joueurs → distribution → animaux → échauffement (30 min) → avant d'entrer en scène.
   - **Régie** : le tableau de bord (ex-chrono TOP) avec le bouton Destiny, les rappels acte par acte, les notes.
   - **Débrief**, puis **historique** des spectacles et répétitions (export PDF).
   - **Tirage rapide** : le générateur d'histoire complet (2.8), où l'on peut fixer lieu, danger ou distribution.
   - **Formats courts** : Rue et Spin-off (voir 11.1).
2. **Musique** : inchangé dans son principe ; la musique suit les actes.
3. **Histoire** : mode IA et Campagne, refondus.
4. **Scène** : Spectacle IA (solo) et Exercices (trois nouveaux onglets CROW, Lieu, Destiny à côté des cinq existants).

**Bibliothèque** (icône livre de l'en-tête, et entrée de l'accueil) : Découvrir Destiny (l'onboarding, à revoir à tout moment), Livret de règles, Archétypes, Animaux, Dangers, Lieux, Œuvres, Vouloir et besoin, Outils de jeu, Lexique. Elle absorbe le Guide Destiny et le Catalogue (lecture).

**Première ouverture** : trois à quatre écrans (promesse ; lieu et groupe ; danger en quatre paliers et rituel ; personnages), puis l'accueil.

**Réglages** : nouvelle section « Destiny » en tête (2.12), puis Apparence, Catalogue (éditeurs), IA, Données, À propos.

## 8. Modèle de données proposé

Nouveau dossier `lib/domain/grammaire/` pour les objets typés de la grammaire, chargés une seule fois par un `GrammaireRepository` qui lit `assets/data/destiny_grammaire.json` et le valide au démarrage (12 archétypes, 24 animaux uniques, montées complètes, 4 paliers par danger, références croisées valides). En cas d'échec de validation, l'appli démarre quand même, avec un message clair en mode admin.

| Entité | Champs | Source |
|---|---|---|
| `Famille` | id (`tient`, `interprete`, `fissure`), nom, couleur, couleurClaire, idee, pourquoi | grammaire |
| `Archetype` | id (`leader`…), nom, familleId, ceQuIlFait, montee (palierId → texte), animalIds (2) | grammaire |
| `Animal` | id (`lion`…), nom, archetypeId, statutDepart, port, posture, replique, sourceReplique, image ; **temperament** et **niveauxCorps** (palierId → texte, ex-`niveaux`) ; `moteur` et `intention` gardés en `@Deprecated` | grammaire + `archetypes.json` (fusion par id) |
| `Palier` | n, id (`signale`, `enferme`, `envahit`, `supprime`), nom, acte, ambiance, etatArchetype | grammaire |
| `Acte` | numero, palierId, ambiance, consignes, geste (Dire, Bloquer, Nommer, Choisir) | grammaire |
| `RegleDOr`, `RituelDestiny`, `RegleDistribution`, `ExempleDistribution` | tels que dans le fichier | grammaire |
| `Danger` | id (appli), nom, style, rue, theatre, actif, paliers (palierId → texte) | catalogue SQLite (référence) |
| `Lieu` | id (appli), nom, roles, rue, actif, **espaces** (4, nouveau), sousEspaces, fonctions, vocabulaire | catalogue SQLite + détails des lieux |
| `Groupe` | description (« une famille », « des associés »…), liens entre personnages | tirage + antisèche de relations |
| `Objet` | nom, touche (acte 1), seRetourne (palier), sertALaFin | saisie ou génération |
| `Mystere` | question, endroitOuObjet, elementsPoses, reponse | saisie ou génération |
| `Personnage` | id, joueur (prénom), fonction dans le lieu, archetypeId, animalId, blessure, vouloir, besoin, prixAPayer, phraseFixee (premier figé), choixFinal (`vouloir` / `besoin`), estPnj | tous les modes |
| `Distribution` | nbJoueurs, personnages, mode (concerté / tirage / exemple) + `validerDistribution()` qui rend « valide » ou une raison en une phrase et une correction proposée | règles de la grammaire |
| `Session` (spectacle, répétition, partie) | id, date, type, lieu, groupe, danger, objets, mystère, distribution, palierCourant, durées des actes, événements Destiny (n, heure, automatique ou régie), notes de régie (heure, texte), débrief (par personnage : phrase du groupe, phrase fixée, choix, prix ; ce qui a marché) | nouvelle base SQLite locale |
| `Oeuvre`, `PersonnageOeuvre`, `SceneReference` | tels que dans le fichier | grammaire |
| `Exercice` | existant + source, badgeMarkJane, notion, but, exemples, debrief, variante, cartesATirer | `exercices.json` + grammaire (les 20 nouveaux sont lus dans la grammaire, voir 9.5) |

**Logique pure et testable** (dans `lib/domain/usecases/`) : distribution (validation, tirage équilibré, exemples), progression des paliers (Destiny → palier + 1, jamais au-delà de 4, jamais en arrière), montée attendue par archétype et par palier, détection d'un besoin qui est un objet (liste de motifs simple côté appli, contrôle complet côté IA), migration.

## 9. Plan de migration

Principe : **on ne réécrit jamais une ancienne sauvegarde en place.** On lit l'ancienne, on écrit la nouvelle à côté, on garde l'ancienne. Revenir en arrière, c'est effacer la nouvelle. Un **rapport de migration** (mode admin) est calculé à blanc avant toute écriture, et je te le montre avant d'activer quoi que ce soit.

### 9.1 Catalogue modifiable (SQLite `destiny_catalog.db`, version 4 → 5)

Aujourd'hui, la base ne sait pas ce que tu as modifié : elle est remplie une fois depuis les JSON, puis éditée. Pour respecter tes modifications :

1. J'embarque une **empreinte des données d'origine de la 1.5.7** (dangers, lieux, dilemmes).
2. Pour chaque ligne de ta base :
   - identique à l'origine → « non modifiée » : elle peut recevoir les nouveaux champs **et**, si tu le décides (annexe A), les nouveaux textes ;
   - différente de l'origine → « modifiée par toi » : on ajoute seulement les nouveaux champs, sans toucher à tes textes ;
   - absente de l'origine → « ajoutée par toi » : intouchée ;
   - présente à l'origine mais absente de ta base → « supprimée par toi » : elle **ne revient pas**.
3. Nouveaux champs : `espaces` pour les lieux. Les noms de paliers ne sont pas stockés par danger : ils viennent de la grammaire (les 4 paliers sont communs à tous les dangers).
4. Table `meta` : version des données de référence, date de migration.

### 9.2 Campagnes (SharedPreferences `campagnes_v1`, `campagne_seances_v1`)

- Nouvelles clés `campagnes_v2` et `campagne_seances_v2` avec un champ `version`. Les clés v1 restent intactes.
- **Constat important** : les personnages joueurs ne sont pas sauvegardés aujourd'hui (prénom, animal, fonction sont recomposés à chaque épisode). Il n'y a donc **aucun personnage à convertir**. Ce qui est sauvegardé et migre : les figurants morts (identifiants d'animal, toujours valides), les sbires et méchants morts, le résumé, l'accroche, les séances.
- La v2 ajoute : personnages persistés (six couches), grand danger de la campagne (palier atteint), lieu de l'épisode suivant (la sortie du palier 4), réglages de campagne.
- Les règles « traître → opportuniste » et « sidéré → archétype de son animal » n'ont rien à convertir : aucune sauvegarde ne peut contenir de traître ni de sidéré, puisque le code ne les a jamais connus (vérifié dans tout le code et les données).
- **Correctif de sécurité** (phase 1, avant toute migration) : aujourd'hui, une erreur de lecture vide la liste et la sauvegarde suivante **efface toutes les campagnes**. Je bloque l'écriture tant que la lecture n'a pas réussi.

### 9.3 Mode Histoire IA, Spectacle IA, historiques, mémoire

| Stockage | Migration |
|---|---|
| Histoires IA (`destiny_chat.db`, table `stories`, v5) | Passage en v6 : ajout de colonnes `grammaire` (1 ou 2) et `univers`. Les histoires existantes restent lisibles et reprennent leur cours en ancienne grammaire, avec un badge « ancienne grammaire ». Aucune n'est réécrite |
| Partie de Spectacle IA en cours (`spectacle_session`) | Elle contient l'ancien prompt complet. À la mise à jour, elle **n'est pas reprise** : elle est rangée dans les archives, avec un message clair. Le nouveau format ne stocke plus le prompt |
| Parties de Spectacle archivées (`spectacle_history`) | Gardées telles quelles, badge « ancienne grammaire » |
| Historique des tirages, dernier tirage, spin-off | Gardés ; les anciens tirages (avec moteur) s'affichent en lecture, badge « ancienne grammaire » |
| Mémoire anti-répétition (`destiny_memory.db`) | **Inchangée** : les identifiants des dangers ne bougent pas |
| Guide modifié en admin (`guide_overrides_v1`) | Gardé en base, non appliqué au nouveau contenu (D19) |
| Antisèche, détails des lieux, suivi (`*_v1`) | Gardés ; les détails des lieux reçoivent les espaces ; le suivi passe en 4 actes (nouvelle clé, l'ancienne gardée) |
| Réglages (`visual_settings`) | Les poids du dé sont ignorés ; les sons sont repris dans le rituel ; les nouvelles clés prennent leurs valeurs par défaut |

### 9.4 Archives clairement marquées

Ton critère d'acceptation tolère les anciens mots dans les écrans d'archives clairement marqués. Toutes les données 1.x affichées (histoires IA, parties de Spectacle, tirages) portent donc le badge « ancienne grammaire ». Nulle part ailleurs l'interface ne montrera « moteur », « dé », « traître » ou « sidéré ».

### 9.5 Exercices

Pour respecter la source unique, les 20 nouveaux exercices **ne sont pas recopiés** dans `exercices.json`. L'écran Exercices lit les trois nouveaux thèmes directement dans le fichier de grammaire, et les thèmes existants dans `exercices.json`, qui ne change pas. Pour toi, le résultat est le même : trois onglets de plus.

### 9.6 Tests de migration

- Jeux de données construits sur le format exact des sauvegardes 1.5.7 (catalogue modifié, ajouté, supprimé ; campagnes à plusieurs épisodes ; histoires IA archivées).
- **J'aimerais une vraie sauvegarde** de ton téléphone pour la tester : il n'y a pas de fonction d'export aujourd'hui. Je peux en ajouter une (Réglages → Données → Exporter mes données, un fichier JSON) dans une petite version 1.5.8 avant la refonte, ou tu peux me décrire tes modifications. À toi de choisir.

---

## 10. Ce que je propose de supprimer pour de bon (D16)

Rien ne sera supprimé sans ton feu vert. **Aucune donnée n'est dans cette liste** : les anciens champs (moteur, intention, poids du dé, anciennes clés) sont gardés, marqués obsolètes et cachés. Cette liste ne contient que du **code**, qui devient inutile une fois remplacé.

| # | Quoi | Pourquoi | Quand |
|---|---|---|---|
| 1 | Classe `Dice3D` (`dice_3d.dart`), en gardant ses couleurs | Utilisée nulle part | Phase 2 |
| 2 | `moteur_info.dart` (bulle « moteur ») | Remplacée par la fiche archétype / animal | Phase 3 |
| 3 | `kStadesEscalade` (`danger.dart`) et `kNiveauxMoteur` (`moteur_info.dart`) | Textes de grammaire en dur, remplacés par le fichier | Phase 1 |
| 4 | Liste `_kArchetypes` et code du dé (`_rollDestiny`, `_rolls`, `_archetypeRoll`, `_destinRoll`) dans `top_countdown_screen.dart` | Remplacés par le rituel ; les cartes passent dans un fichier de données | Phase 4 |
| 5 | Le mode caché `GeneratorMode.dilemme` | Son onglet est déjà retiré ; les dilemmes servent désormais l'acte 4 | Phase 4 |
| 6 | Les champs `query` de `entity_visuals.dart` | Plus lus nulle part | Phase 2 |
| 7 | `horairesDesPresages()` et `borner()` (`constructeur_episode.dart`) | Servent seulement aux tests ; remplacés par le minutage des actes | Phase 5 |
| 8 | Getter `cubeAnimation` (toujours vrai) | Remplacé par « réduire les animations » | Phase 2 |
| 9 | Les 24 animaux en dur dans `spectacle_prompt.dart` et les sections 10, 12 et 13 du Guide | Remplacés par la grammaire (les textes restent dans l'historique git) | Phases 3 et 6 |
| 10 | `tutorial_screen.dart` | Remplacé par l'onboarding | Phase 7 |

---

## 11. Mes propositions (à valider)

### 11.1 Rue et Spin-off (D7)

Ce sont des formats courts. Aujourd'hui, Rue ne montre que les paliers 3 et 4, et Spin-off part d'un film réel.

- **Rue → « Destiny express »** (ma recommandation) : un lieu, un danger, l'alarmiste et 2 ou 3 autres, sans contrainte de familles. Les 4 paliers défilent sur un chrono court (par exemple 2 minutes par palier), avec un rituel allégé (tonnerre et figé). On ne demande que le vouloir, pas de besoin.
  Variante : Rue reste un format libre (lieu, danger, archétypes), sans actes.
- **Spin-off → « D'après un film »** : on garde le tirage d'un film réel (lieu, danger), mais on joue en grammaire Destiny (groupe qui se connaît, alarmiste, archétypes en familles). Le protagoniste « antagoniste » devient l'opportuniste.
  Variante : Spin-off reste un échauffement sans actes.

### 11.2 Les cartes « Destin » (D8)

Elles deviennent un module facultatif, **« Rebondissement de régie »**, désactivé par défaut. La régie peut tirer une carte quand elle le veut, mais jamais à la place du palier. Les 6 cartes passent dans le fichier de grammaire. Chacune porte l'acte où elle fonctionne le mieux :

| Carte | Acte |
|---|---|
| Quelqu'un que l'un de vous aime apparaît, et il est en danger | 2 |
| Quelqu'un que l'un de vous croyait mort est là, vivant | 2 |
| L'un de vous a menti sur quelque chose d'essentiel | 3, Nommer |
| L'un de vous détient, sans le savoir, ce qui peut tous vous sauver | 3, peut toucher un des 3 objets |
| Le plus faible d'entre vous prend le pouvoir de décider pour tous | 3 |
| Il n'y a plus qu'une issue pour un seul d'entre vous | 4 |

### 11.3 Palette unique (D9)

Elle garde le sens des couleurs actuelles sans entrer en conflit avec les familles.

| Usage | Avant | Après |
|---|---|---|
| Fond sombre | violet nuit `#0E0B1F`, dégradé dans 21 fichiers | **nuit** `#100d08` |
| Accent, titres | or `#E8B86D` et or `#FFC24B` (deux ors) | **or** `#c9a35a`, or clair `#e8b86d`, or foncé `#8a5f14` (un seul or) |
| Cartes (mode clair) | — | **crème** `#fbf7ee`, filets **trait** `#e6d8b8`, texte **encre** `#221e16` / **texte doux** `#5b5244` |
| Familles | — | **réservées** : vert `#4E9F7A`, bleu `#3F74B5`, rouge `#B5473A` (et teintes claires) |
| Rituel Destiny | — | bleu Destiny `#3F74B5`, en voile plein écran (jamais en puce, pour ne pas le confondre avec la famille) |
| Méchant (Campagne) | or | **or foncé** `#8a5f14` |
| Lieu | teal `#5EE0C4` | **or clair** (le décor), sans couleur de famille |
| Escalade, danger | corail | **frise des paliers** : de l'or vers la braise (`#8a5f14` → `#5a2a12`). C'est un dégradé d'intensité, distinct du rouge Fissure |
| Rôles, fonctions | bleu `#64B5F6` (conflit avec Interprète) | **crème / trait** (neutre) |
| Figurants, IA | violet `#8A6FE8` | violet gardé **pour l'IA seulement** (les PNJ prennent la couleur de leur famille) |
| Statuts | haut ambre, bas bleu, neutre blanc | **pastilles** de la DA : haut `#d6ecd9`, neutre `#faedc4`, bas `#e5dcf5`, avec le mot écrit (haut / neutre / bas), parce que la pastille « haut » est proche du vert Tient |
| Succès / échec (chat, exercices) | vert `#3FE08A` / rouge `#FF7A6B` | gardés, plus doux, et jamais sur une carte d'archétype |

### 11.4 Les animaux de campagne (D10)

La Campagne a 16 animaux : 12 sont aussi dans le spectacle, 4 lui sont propres (tortue, dauphin, éléphant, pie). Je propose cette correspondance :

| Animal | Archétype proposé | Pourquoi |
|---|---|---|
| Aigle, Lion | Leader | comme au spectacle |
| Ours, Loup | Protecteur | comme au spectacle |
| Chien | Aidant | comme au spectacle |
| Souris, Hibou | Débrouillard | comme au spectacle |
| Singe, Renard | Cynique | comme au spectacle |
| Paon | Prophète | comme au spectacle |
| Chat | Solitaire | comme au spectacle |
| Lapin | Paranoïaque | comme au spectacle (en mots d'enfant : « l'inquiet qui remarque tout ») |
| **Tortue** (calme, avance à son rythme) | **Dénégateur** | « Ça va se régler », refuse de se presser |
| **Dauphin** (joueur, que tout le monde s'amuse) | **Aidant** | rassure, réconcilie |
| **Éléphant** (doux, costaud, se souvient de tout) | **Gardien de l'ordre** | connaît les règles, « on a toujours fait comme ça » |
| **Pie** (bavarde, curieuse) | **Alarmiste** | elle apporte les nouvelles. Variante : opportuniste (« collectionne les jolies choses ») |

**Fusion proposée** : la Campagne utilise les 24 animaux du spectacle, et les 4 animaux propres restent comme **animaux du mode enfant** (un troisième animal possible pour leur archétype, en mode enfant seulement). Le mode enfant y gagne un alarmiste doux (la pie), qui manque aujourd'hui. Je n'applique rien sans ton accord.

### 11.5 Les 21 univers (phase 5)

Aujourd'hui, chaque univers a 2 lieux et 2 méchants. Les méchants sont écrits pour un lieu précis, mais le constructeur les mélange (un épisode sur deux, le méchant joue hors de son lieu). Je propose, pour chaque univers, en adulte et en enfant :
- 4 lieux uniques, dont les 2 existants, avec leurs espaces ;
- 4 groupes qui se connaissent ;
- 6 dangers à 4 paliers, propres à l'univers ;
- le méchant comme grand danger, avec ses 4 présages en paliers.

Je livre ces données sous forme de fichier, univers par univers, pour que tu les relises avant de les brancher.

### 11.6 Le mode Histoire IA (D18)

C'est du jeu de rôle. Je garde donc la résolution réussite / échec et les deux actions BRAVE / SMART, mais :
- le mot « dés » disparaît (« le destin tranche ») ;
- l'histoire suit 4 chapitres, un par palier, avec un rituel Destiny entre chaque chapitre (au lieu d'une montée tous les 4 tours, qui donne aujourd'hui 7 montées pour 4 paliers) ;
- chaque héros a ses six couches ; le besoin est fixé à la fin du chapitre 1 et le dernier chapitre force le choix ;
- le malus « 2 réussites » devient une option.

### 11.7 Le Spectacle IA (D17)

Aujourd'hui, il note le joueur sur 100 et utilise une grille CROW sur 16. Je propose :
- de garder CROW comme **outil de coach** (c'est un thème d'exercices désormais) ;
- de remplacer la note par un **débrief positif** : « il veut… mais il a besoin de… », ce qui a marché, le choix de l'acte 4 ;
- de garder éventuellement une note facultative pour ceux qui aiment.

### 11.8 Mode public, et hors ligne (§ 2.11)

- **Hors ligne** : le mode Troupe et la régie ne dépendront d'aucun réseau (polices et sons embarqués). L'IA y reste facultative ; sans elle, le mystère et les objets se tirent dans des listes locales.
- **Écran pour la salle** : faisable sans réseau, avec une vue « public » plein écran à projeter (lieu, choix du danger, rituel Destiny, jamais les archétypes ni les animaux). Je propose de l'inclure dans la phase 4.
- **Vote par QR code ou par lien** : cela demande un petit serveur en ligne, ce qui contredit le hors ligne. Je propose de le **reporter après la 2.0**, et de faire en attendant un compteur de vote à main levée dans l'appli.

### 11.9 Nouvelles dépendances (D13)

- `pdf` et `printing` : exports PDF (cartes, fiche de spectacle, livret, historique). Ils fonctionnent aussi sur le web.
- `share_plus` : partager une histoire.
- Polices Cinzel et Montserrat, embarquées (licence libre OFL).
- `font_awesome_flutter` : à monter en version, sinon l'appli ne compilera plus avec les prochaines versions de Flutter (voir 1.4).

---

## 12. Phases et prérequis

| Phase | Contenu | Ce qu'elle coche |
|---|---|---|
| **1. Données et domaine** | Asset de grammaire et validation ; entités ; `GrammaireRepository` ; distribution ; paliers ; montées ; contrôle du besoin ; correctifs de sécurité (campagnes, Spectacle en cours) ; migrations à blanc et rapport ; tests | 4.1, 4.2, 4.3 |
| **2. Design system** | Thème clair et sombre, polices, couleurs de famille, composants, animation Destiny, tests golden | 4.6, 4.9 |
| **3. Bibliothèque** | Archétypes, animaux, dangers, lieux, œuvres, vouloir et besoin, outils de jeu, lexique | 4.5 (Guide, Catalogue) |
| **4. Mode Troupe** | Préparer, échauffement, avant d'entrer, régie et bouton Destiny, vue salle, débrief, historique, exports PDF | 4.5 (Générateur, chrono, suivi) |
| **5. Campagnes et 21 univers** | Personnages persistés, 4 actes, grand danger, sortie du palier 4, PNJ, mode enfant, module traître, données des univers | 4.1, 4.5 (Campagne) |
| **6. IA** | Dossier de prompts centralisé et versionné, 6 rôles, variantes adulte et enfant, tests de cas types ; chat et Spectacle IA refondus | 4.4 |
| **7. Règles, réglages, exercices, accueil, textes** | Livret, réglages, 20 exercices, onboarding, accueil, relecture de tous les textes, fiche des stores | 4.5, 5 |
| **8. Finitions** | Accessibilité, hors ligne, performances, documentation, version web, 2.0.0+20, changelog | 4.10 |

**Prérequis** :
1. **Accès en écriture à GitHub** (voir section 0).
2. Flutter 3.41.9, avec lequel les 28 tests actuels passent (D26).
3. Pour les captures des stores : je peux les produire automatiquement depuis la version web.

---

## 13. Les décisions qu'il me faut

| # | Sujet | Ma recommandation |
|---|---|---|
| **D1** | Identifiants des dangers et des lieux (annexe A) | Garder ceux de l'appli et les recopier dans le fichier de grammaire |
| **D2** | Textes des paliers : longs (appli) ou courts (grammaire) | Les courts, si ce sont ta dernière version, et seulement pour les dangers que tu n'as pas modifiés |
| **D3** | Espaces des lieux | Ajouter les 4 espaces de la grammaire et garder les 8 sous-espaces en réserve |
| **D4** | Clés à ajouter au fichier de grammaire (1.3) | Oui : je rédige, tu valides |
| **D5** | Petits écarts du fichier (1.2) | Tu me dis quelle version fait foi |
| **D6** | Nom du premier onglet | « Troupe » (sous-titre « Préparer et jouer ») |
| **D7** | Rue et Spin-off (11.1) | Rue → Destiny express ; Spin-off → « D'après un film » |
| **D8** | Cartes « Destin » (11.2) | Module « Rebondissement de régie », désactivé par défaut |
| **D9** | Palette (11.3) | Celle proposée |
| **D10** | Animaux de campagne et fusion (11.4) | La correspondance proposée ; la pie devient l'alarmiste enfant |
| **D11** | Contenu des 21 univers (11.5) | 4 lieux, 4 groupes, 6 dangers par univers, relus par toi |
| **D12** | Vote par QR code (11.8) | Après la 2.0 ; vue salle et vote à main levée dans la 2.0 |
| **D13** | Nouvelles dépendances (11.9) | Oui |
| **D14** | Son du « rire du destin » | Il me faut un fichier (le tien, ou un son libre de droits que je te propose) |
| **D15** | Vraie sauvegarde pour tester la migration (9.6) | Une petite 1.5.8 avec « Exporter mes données », ou ta description |
| **D16** | Suppressions de code (section 10) | Feu vert sur la liste |
| **D17** | Note du Spectacle IA (11.7) | Débrief positif à la place de la note |
| **D18** | Mode Histoire IA (11.6) | Garder réussite / échec, sans « dés », avec 4 chapitres |
| **D19** | Ancien Guide | Ne plus l'afficher ; tes modifications d'admin restent en base |
| **D20** | Portée du mode admin (5.1) | Protéger aussi les éditeurs du catalogue |
| **D21** | Groupes et liens au tirage | Tirer le groupe (famille, équipe, associés) et 1 lien par duo depuis l'antisèche |
| **D22** | Icône de l'appli | La garder (elle est déjà noire et or) ; à revoir si tu veux |
| **D23** | Accès GitHub | À réparer de ton côté |
| **D24** | Exercices : ton prompt cite 5 thèmes, il en existe 6 (Dialogue) + Solo | Les garder tous, ajouter les 3 nouveaux |
| **D25** | Durée par défaut du spectacle | 30 min (actes 10 / 8 / 8 / 4). Le Guide parle de 45 min (Destiny à 10, 22, 35) : lequel est juste ? |
| **D26** | Version de Flutter | 3.41.9 (tous les tests passent) ; dis-moi si ta CI en utilise une autre |

# DestinyStory — consignes pour Claude Code

## Destiny Note : routine de mise à jour

Destiny Note, ce sont les notes privées de Marouene sur le spectacle Destiny (séances, comptes rendus,
décisions, règles). Elles sont chiffrées sur la branche orpheline `destiny-story-data` (dossier `notes/`),
jamais fusionnée ailleurs. Le dépôt est **public** : rien ne s'écrit en clair sur GitHub.

**Mot de passe** : seulement dans la variable `DESTINY_NOTES_PASSWORD`. Ne jamais le demander dans le chat,
ne jamais l'écrire dans un fichier, ne jamais l'afficher. Marouene l'a rangé dans le trousseau macOS :

```bash
export DESTINY_NOTES_PASSWORD="$(security find-generic-password -s destiny-notes -w)"
```

**À chaque session**, dès que Marouene donne un compte rendu (répète, spectacle, séance avec Mark Jane), une
décision, un changement de règle, une distribution, un plan de séance ou une idée, mettre les notes à jour
dans la même session :

1. `dart run tool/destiny_notes.dart pull` (déchiffre dans `.destiny_notes/notes/`, ignoré par git) ;
2. créer ou compléter l'entrée datée `entries/AAAA-MM-JJ_type_slug.json` (champs : `id`, `date`, `type`,
   `titre`, `resume`, `contenu_md`, `whatsapp`, `tags`, `personnes`, `cree_le`, `mis_a_jour_le`), avec son
   texte WhatsApp tiré du modèle (`modeles.json`) ;
3. mettre à jour `prochaine_seance.json`, `regles_en_vigueur.json` et `journal_decisions.json` si c'est
   concerné (l'index se reconstruit tout seul au push) ;
4. `dart run tool/destiny_notes.dart push -m "notes: CR répète du 22/11"` ;
5. dire à Marouene, en une phrase, ce qui a changé.

Règles :

- **Ne jamais supprimer l'historique.** Une règle remplacée reste dans le journal, avec `remplacee_le` et
  `remplacee_par`. Une entrée corrigée garde `cree_le` et prend un nouveau `mis_a_jour_le`.
- Tout est daté `AAAA-MM-JJ`. Les minutages sont repris quand ils existent.
- Séparer ce que Marouene a dit ou décidé de ce qui est une analyse : toute analyse commence par « Analyse : ».
- Les notes parlent du jeu et des scènes, avec des faits. Pas de jugement sur la personne, pas de détail de
  vie privée des comédiens.
- Le texte WhatsApp est positif et collectif : il ne vise ni ne critique jamais un comédien nommé (les
  critiques restent dans les notes). Syntaxe WhatsApp seulement : `*gras*`, `_italique_`, puces `•`, emojis.
- Quand la prochaine séance est passée, elle devient une entrée (avec ce qui s'y est passé, si Marouene l'a
  raconté), et la carte passe à la suivante (`suivantes` garde le calendrier des salles).

Types d'entrée : `repetition`, `spectacle`, `seance_mark_jane`, `decision`, `regie`, `troupe`, `promo`, `idee`.

# DestinyStory — Réponses exactes pour la Play Console

Pour chaque tâche de « Terminer la configuration de votre appli », voici quoi saisir.
Ce sont des déclarations que **tu** valides (ton compte, tes attestations) — je te donne
les réponses justes pour DestinyStory, à recopier/cocher.

---

## DÉCRIRE LE CONTENU DE VOTRE APPLICATION

### 1. Définir les règles de confidentialité
Colle cette URL :
```
https://okhamfriction-png.github.io/Destiny/privacy.html
```

### 2. Informations de connexion (App access / Accès à l'application)
- Coche : **« Toutes les fonctionnalités sont disponibles sans restriction d'accès particulière »**
  (l'app ne demande aucun identifiant / compte).

### 3. Annonces (Ads)
- **« Non »**, mon application **ne contient pas** d'annonces.

### 4. Classification du contenu (questionnaire IARC)
- E-mail : `okhamfriction@gmail.com`
- Catégorie : **Divertissement** (ou « Toutes les autres apps »).
- Réponds **NON** à toutes les questions sur : violence, contenu sexuel, langage grossier,
  drogues, jeux d'argent, contenu généré par les utilisateurs partagé, achats, localisation.
  → Résultat attendu : **PEGI 3 / Tous publics**.
- ⚠️ Une seule nuance possible : l'app génère des situations « dramatiques » (danger, tension),
  mais **il n'y a aucune image ni description violente** — c'est du texte d'ambiance théâtrale.
  Donc « Non » à la violence est correct.

### 5. Cible (Public cible et contenu)
- Tranches d'âge : coche **13-15, 16-17, et 18 et plus** (pas les tranches enfants).
- « Votre appli attire-t-elle les enfants ? » → **Non**.
  (Évite de cibler les moins de 13 ans : ça éviterait des obligations « Familles » supplémentaires.)

### 6. Sécurité des données (Data safety)
- « Votre appli collecte-t-elle ou partage-t-elle des données utilisateur ? » → **Non**.
- « Toutes les données sont-elles chiffrées en transit ? » → sans objet (aucune donnée envoyée).
- « Proposez-vous un moyen de demander la suppression des données ? » → sans objet.
- Résumé à cocher : **aucune donnée collectée, aucune donnée partagée**.
  (Tout est stocké localement sur l'appareil — ce n'est pas de la « collecte » au sens Google.)

### 7. Applis gouvernementales
- **« Non »**, ce n'est pas une application gouvernementale.

### 8. Fonctionnalités financières
- **« Non »**, mon appli ne propose aucune fonctionnalité financière.

### 9. Santé
- **« Non »**, mon appli n'est pas liée à la santé.

---

## GÉRER L'ORGANISATION ET LA PRÉSENTATION

### 10. Catégorie + coordonnées
- **Type d'application** : Application.
- **Catégorie** : **Divertissement** (alternative : Art et Design).
- **Tags** : théâtre, improvisation, création (facultatif).
- **Coordonnées** : e-mail `okhamfriction@gmail.com` (téléphone / site web facultatifs).

### 11. Configurer une fiche Play Store
Reprends le fichier `docs/play_store_listing.md` :
- **Nom** : `DestinyStory`
- **Description courte** (80 car.) : `Générateur de scènes d'impro : un lieu, un danger, des héros. Rien n'est écrit.`
- **Description complète** : (voir le doc — bloc « RIEN N'EST ÉCRIT… »)
- **Icône** : PNG 512×512
- **Bannière (Feature graphic)** : 1024×500
- **Captures téléphone** : 2 à 8

---

## Après cette configuration
Le bouton **Test fermé** se débloque. Il faudra :
1. Lancer un **test fermé** avec **12 testeurs minimum** pendant **14 jours**.
2. Puis **Demander l'accès à la production**.
3. Créer la release de Production (même `.aab`) → **Envoyer pour examen**.

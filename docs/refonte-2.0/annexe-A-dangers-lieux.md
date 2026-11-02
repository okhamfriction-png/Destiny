# Annexe A — Dangers et lieux : grammaire contre catalogue de l'appli

Comparaison automatique entre `destiny_grammaire.json` (v2.0) et le catalogue embarqué de l'appli (`dangers.json`, `locations.json`, `location_details.json`, v1.5.7). Le catalogue reste la référence (règle 2 du prompt) : **rien n'est choisi ici**, chaque écart attend ta décision.

## Synthèse

| | Grammaire | Appli | Écart |
|---|---|---|---|
| Dangers | 38 | 38 | mêmes 38 noms ; **38 identifiants différents** ; **58 textes de paliers différents** (sur 152), dans 33 dangers |
| Lieux | 40 | 40 | mêmes 40 noms ; **8 identifiants différents** ; rôles identiques (40/40) ; **4 espaces** côté grammaire contre **8 sous-espaces** côté appli, différents pour 40 lieux |
| Style, Rue/Théâtre, actif | absents | présents | la grammaire ne les porte pas |
| Vocabulaire, fonctions détaillées | absents | présents (`location_details.json`) | la grammaire ne les porte pas |

### Ce que je recommande (à valider)

1. **Garder les identifiants de l'appli.** Ils servent de clé partout : base SQLite du catalogue, mémoire anti-répétition (`used_combos`), images (`assets/images/dangers|locations/<id>.jpg`), ambiances sonores (`assets/audio/ambiences/<id>.m4a`), dilemmes (`danger_lie`), historique des tirages. Changer d'identifiant casserait tout cela. Je propose d'aligner les identifiants **dans le fichier de grammaire** sur ceux de l'appli (correspondance ci-dessous), ou, si tu préfères ne pas toucher ton fichier, de faire la correspondance par le nom au chargement.
2. **Paliers des dangers** : la grammaire contient des versions raccourcies (la fin de phrase est coupée, par exemple « …on est dedans » disparaît). Deux options : (a) garder les textes de l'appli, plus longs ; (b) adopter les textes courts de la grammaire, en ne remplaçant que les dangers que tu n'as pas modifiés dans l'appli. Je penche pour (b) si ces textes courts sont ta dernière version, sinon (a).
3. **Espaces des lieux** : la grammaire donne 4 « espaces » de jeu par lieu, l'appli 8 « sous-espaces » plus riches. Je propose d'**ajouter** un champ `espaces` (les 4 de la grammaire, les coins où jouer sans sortir du lieu) à côté des 8 sous-espaces existants, qui restent comme réserve d'idées. Les 4 espaces s'affichent en premier.

## Correspondance des identifiants — dangers

| Nom | Id appli (gardé) | Id grammaire |
|---|---|---|
| Des robots se rebellent | `robots_rebelle` | `des_robots_se_rebellent` |
| L'air devient irrespirable | `air_irrespirable` | `l_air_devient_irrespirable` |
| La guerre éclate | `siege_arme` | `la_guerre_eclate` |
| Le lieu va s'autodétruire | `bombe_retardement` | `le_lieu_va_s_autodetruire` |
| Le noir total | `noir_total` | `le_noir_total` |
| Le soleil grossit, tout brûle | `soleil_grossit` | `le_soleil_grossit_tout_brule` |
| Le soleil s'éteint, le froid gagne | `soleil_eteint` | `le_soleil_s_eteint_le_froid_gagne` |
| Les murs se referment | `murs_referment` | `les_murs_se_referment` |
| On est perdus | `perdus_nature` | `on_est_perdus` |
| On est traqués | `traques` | `on_est_traques` |
| Tout se verrouille, on est piégés | `verrouillage` | `tout_se_verrouille_on_est_pieges` |
| Un braquage | `braquage` | `un_braquage` |
| Un brouillard qui rend fou | `brume_etrange` | `un_brouillard_qui_rend_fou` |
| Un crash | `crash_exterieur` | `un_crash` |
| Un essaim | `essaim` | `un_essaim` |
| Un gaz toxique se répand | `nuage_toxique` | `un_gaz_toxique_se_repand` |
| Un gouffre s'ouvre sous nos pieds | `gouffre` | `un_gouffre_s_ouvre_sous_nos_pieds` |
| Un incendie | `incendie` | `un_incendie` |
| Un jeu mortel | `jeu_mortel` | `un_jeu_mortel` |
| Un monstre géant | `monstre_geant` | `un_monstre_geant` |
| Un naufrage | `naufrage` | `un_naufrage` |
| Un pacte ancien réactivé | `pacte_ancien` | `un_pacte_ancien_reactive` |
| Un raz-de-marée | `raz_de_maree` | `un_raz_de_maree` |
| Un tremblement de terre | `tremblement_terre` | `un_tremblement_de_terre` |
| Un tueur en série | `tueur_en_serie` | `un_tueur_en_serie` |
| Un volcan en éruption | `volcan` | `un_volcan_en_eruption` |
| Une IA prend le contrôle | `ia_controle` | `une_ia_prend_le_controle` |
| Une créature nous traque | `invasion_creature` | `une_creature_nous_traque` |
| Une fuite de gaz, ça va exploser | `reaction_chimique` | `une_fuite_de_gaz_ca_va_exploser` |
| Une inondation | `inondation` | `une_inondation` |
| Une invasion de zombies | `zombies` | `une_invasion_de_zombies` |
| Une invasion extraterrestre | `invasion_alien` | `une_invasion_extraterrestre` |
| Une meute lâchée | `meute` | `une_meute_lachee` |
| Une prise d'otage | `prise_otage` | `une_prise_d_otage` |
| Une tempête | `tempete` | `une_tempete` |
| Une tornade | `tornade` | `une_tornade` |
| Une émeute | `emeute_hostile` | `une_emeute` |
| Une épidémie se propage | `maladie_contagieuse` | `une_epidemie_se_propage` |

## Correspondance des identifiants — lieux (8 différents)

| Nom | Id appli (gardé) | Id grammaire |
|---|---|---|
| Laboratoire de recherche | `laboratoire` | `laboratoire_de_recherche` |
| Hôtel de luxe | `hotel_luxe` | `hotel_de_luxe` |
| Boîte de nuit | `boite_nuit` | `boite_de_nuit` |
| Station spatiale | `base_spatiale` | `station_spatiale` |
| Refuge de montagne | `refuge_montagne` | `refuge_de_montagne` |
| Avion en vol | `avion` | `avion_en_vol` |
| Salle de sport | `salle_sport` | `salle_de_sport` |
| Navire de croisière | `navire_croisiere` | `navire_de_croisiere` |

## Les 58 textes de paliers différents

| Danger | Palier | Appli (actuel) | Grammaire |
|---|---|---|---|
| Des robots se rebellent | 3 | Elles nous traquent une par une, l'étau se resserre sur nous. | Elles nous traquent une par une, l'étau se resserre. |
| Des robots se rebellent | 4 | La rébellion est totale : les arrêter maintenant ou finir avec elles. | Rébellion totale : les arrêter maintenant ou finir avec elles. |
| L'air devient irrespirable | 2 | Chaque souffle coûte, et rien ne s'ouvre pour renouveler l'air. | Chaque souffle coûte, rien ne s'ouvre pour renouveler l'air. |
| L'air devient irrespirable | 3 | La tête tourne, la vue se trouble, il faut décider avec le peu qui reste. | La tête tourne, la vue se trouble, décider avec le peu qui reste. |
| La guerre éclate | 2 | Les explosions coupent les rues autour, impossible de partir. | Les explosions coupent les rues, impossible de partir. |
| Le lieu va s'autodétruire | 2 | Le verrouillage s'enclenche, les sorties se scellent, on est dedans. | Le verrouillage s'enclenche, les sorties se scellent. |
| Le noir total | 1 | Les lumières faiblissent, des ombres s'étirent, on se rassure mal. | Les lumières faiblissent, des ombres s'étirent. |
| Le noir total | 2 | Le noir tombe d'un coup, on ne retrouve plus la sortie, on tâtonne. | Le noir tombe d'un coup, on ne retrouve plus la sortie. |
| Le noir total | 3 | On ne voit plus rien, chaque bruit tout près devient une menace. | On ne voit plus rien, chaque bruit tout près devient menace. |
| Le noir total | 4 | Dans le noir absolu quelque chose bouge, il faut agir à l'aveugle. | Dans le noir absolu quelque chose bouge, agir à l'aveugle. |
| Le soleil grossit, tout brûle | 2 | La chaleur scelle le lieu, dehors est mortel, on reste enfermés. | La chaleur scelle le lieu, dehors est mortel. |
| Le soleil grossit, tout brûle | 3 | Les vitres se fissurent, le sol brûle, l'ombre se réduit à rien. | Les vitres se fissurent, le sol brûle, l'ombre se réduit. |
| Le soleil grossit, tout brûle | 4 | Tout s'embrase, le dernier coin vivable disparaît, il faut choisir. | Tout s'embrase, le dernier coin vivable disparaît. |
| Le soleil s'éteint, le froid gagne | 4 | Le noir glacé avale tout, rester immobile c'est mourir, il faut trancher. | Le noir glacé avale tout, rester immobile c'est mourir. |
| Les murs se referment | 1 | Un grincement, une paroi semble un peu plus proche qu'avant. | Un grincement, une paroi semble un peu plus proche. |
| Les murs se referment | 3 | Le plafond descend, on doit se baisser, se serrer les uns contre les autres. | Le plafond descend, on doit se baisser, se serrer. |
| On est perdus | 2 | Chaque direction ramène au même point, on tourne en rond, pris au piège. | Chaque direction ramène au même point, on tourne en rond. |
| Un braquage | 1 | Une tension, des regards, quelque chose cloche dans le lieu. | Une tension, des regards, quelque chose cloche. |
| Un brouillard qui rend fou | 2 | Le brouillard scelle le lieu, on ne trouve plus l'issue, on doute des autres. | Le brouillard scelle le lieu, on doute des autres. |
| Un brouillard qui rend fou | 4 | Chacun voit un ennemi dans l'autre, il faut se ressaisir ou s'entretuer. | Chacun voit un ennemi dans l'autre, se ressaisir ou s'entretuer. |
| Un crash | 2 | L'impact tord la structure, les issues sont coincées, on est dedans. | L'impact tord la structure, les issues sont coincées. |
| Un essaim | 4 | Le nuage vivant nous dévore, il faut un sacrifice pour passer. | Le nuage vivant nous dévore, un sacrifice pour passer. |
| Un gaz toxique se répand | 2 | Le gaz sature le lieu, les sorties sont dans le nuage, on reste bloqués. | Le gaz sature le lieu, les sorties sont dans le nuage. |
| Un gaz toxique se répand | 3 | La tête tourne, on tousse, il faut décider vite et à plusieurs. | La tête tourne, on tousse, décider vite et à plusieurs. |
| Un gouffre s'ouvre sous nos pieds | 2 | Le gouffre coupe le lieu en deux, plus de passage vers la sortie. | Le gouffre coupe le lieu en deux, plus de passage. |
| Un incendie | 1 | Une odeur de fumée, une lueur, on n'est pas sûr encore. | Une odeur de fumée, une lueur, on n'est pas sûr. |
| Un incendie | 2 | Le feu coupe une première sortie, on ne part plus librement. | Le feu coupe une première sortie, on ne part plus. |
| Un incendie | 3 | La chaleur est sur nous, les issues tombent une à une, on est piégés. | La chaleur est sur nous, les issues tombent une à une. |
| Un jeu mortel | 2 | Les portes se verrouillent, le jeu commence, impossible de refuser. | Les portes se verrouillent, impossible de refuser. |
| Un monstre géant | 2 | La créature bloque l'issue, on est acculés dans le lieu. | La créature bloque l'issue, on est acculés. |
| Un naufrage | 2 | L'eau bloque les coursives, on ne remonte plus librement. | L'eau bloque les coursives, on ne remonte plus. |
| Un pacte ancien réactivé | 2 | Le lieu se scelle, on comprend qu'on est liés au pacte, on ne part pas. | Le lieu se scelle, on est liés au pacte, on ne part pas. |
| Un raz-de-marée | 1 | La mer se retire trop loin, un grondement monte, on s'inquiète. | La mer se retire trop loin, un grondement monte. |
| Un raz-de-marée | 3 | L'eau envahit le lieu, on grimpe, on se hisse les uns les autres. | L'eau envahit le lieu, on grimpe, on se hisse. |
| Un tremblement de terre | 1 | Une vibration, un objet tombe, on se fige une seconde. | Une vibration, un objet tombe, on se fige. |
| Un tremblement de terre | 4 | Le bâtiment cède : dégager quelqu'un ou se sauver, il faut choisir. | Le bâtiment cède : dégager quelqu'un ou se sauver. |
| Un tueur en série | 1 | Un détail dérange, un malaise, on se rassure entre nous. | Un détail dérange, un malaise, on se rassure. |
| Un tueur en série | 2 | Une porte verrouillée, un absent, on comprend qu'on est enfermés avec lui. | Une porte verrouillée, un absent, on est enfermés avec lui. |
| Un volcan en éruption | 1 | La terre gronde, une odeur de soufre, on hésite à partir. | La terre gronde, une odeur de soufre, on hésite. |
| Un volcan en éruption | 2 | La coulée coupe les routes, on est cernés, on reste sur place. | La coulée coupe les routes, on est cernés. |
| Une créature nous traque | 1 | Un bruit, une trace, on n'est pas sûrs d'avoir bien vu. | Un bruit, une trace, on n'est pas sûrs d'avoir vu. |
| Une créature nous traque | 2 | Elle coupe la sortie, on est acculés dans le lieu. | Elle coupe la sortie, on est acculés. |
| Une fuite de gaz, ça va exploser | 2 | La moindre étincelle est fatale, on ne peut plus sortir sans risque. | La moindre étincelle est fatale, on ne peut plus sortir. |
| Une fuite de gaz, ça va exploser | 3 | La concentration monte, chaque geste compte, on retient tout. | La concentration monte, chaque geste compte. |
| Une inondation | 1 | L'eau s'infiltre, on lève les pieds sans trop s'alarmer. | L'eau s'infiltre, on lève les pieds sans s'alarmer. |
| Une inondation | 2 | Le niveau bloque les portes, on ne sort plus, on est pris. | Le niveau bloque les portes, on ne sort plus. |
| Une invasion de zombies | 1 | Des cris dehors, on barricade sans vraiment y croire. | Des cris dehors, on barricade sans y croire. |
| Une invasion de zombies | 2 | Ils encerclent le lieu, les issues sont prises, on est enfermés. | Ils encerclent le lieu, les issues sont prises. |
| Une meute lâchée | 1 | Des grognements, une présence, on se rapproche instinctivement. | Des grognements, une présence, on se rapproche. |
| Une meute lâchée | 2 | La meute garde les sorties, on est bloqués à l'intérieur. | La meute garde les sorties, on est bloqués. |
| Une tempête | 1 | Le vent forcit, le ciel noircit, on rentre se mettre à l'abri. | Le vent forcit, le ciel noircit, on se met à l'abri. |
| Une tempête | 2 | La tempête scelle les issues, dehors est mortel, on reste enfermés. | La tempête scelle les issues, dehors est mortel. |
| Une tornade | 1 | Le ciel vire, une colonne se forme au loin, on hésite. | Le ciel vire, une colonne se forme au loin. |
| Une tornade | 2 | Elle coupe la route, on doit rester terrés sur place. | Elle coupe la route, on doit rester terrés. |
| Une émeute | 2 | La foule encercle le lieu, les issues sont prises, on est bloqués. | La foule encercle le lieu, les issues sont prises. |
| Une émeute | 3 | Ça force les portes, la violence entre, on se barricade serrés. | Ça force les portes, la violence entre, on se barricade. |
| Une épidémie se propage | 2 | Le lieu est mis en quarantaine, les portes se scellent, on reste dedans. | Le lieu est mis en quarantaine, les portes se scellent. |
| Une épidémie se propage | 3 | Les symptômes frappent vite, la peur du contact monte, on se soupçonne. | Les symptômes frappent vite, la peur du contact monte. |

## Espaces : les 4 de la grammaire contre les 8 sous-espaces de l'appli

| Lieu | Espaces (grammaire) | Sous-espaces (appli) |
|---|---|---|
| Aéroport ⚠️ | hall d'embarquement, contrôle de sûreté, salon VIP, piste / tarmac | hall des départs, porte d'embarquement, salon VIP, contrôle des passeports, tapis à bagages, tour de contrôle, piste de nuit, zone de transit |
| Laboratoire de recherche ⚠️ | salle blanche, bureau, réserve de produits, salle serveurs | salle blanche, animalerie, chambre froide, paillasse d'analyses, bureau du directeur, sas de décontamination, salle des serveurs, stock de réactifs |
| Hôtel de luxe ⚠️ | hall / réception, suite, restaurant, cuisines / sous-sol | suite présidentielle, réception, bar du dernier étage, spa, cuisine de banquet, loge du concierge, ascenseur privé, cave à vin |
| Ferme ⚠️ | cour, étable, grange, maison d'habitation | étable, grange à foin, poulailler, champ de blé, cuisine paysanne, puits, hangar à tracteur, verger |
| Bunker militaire ⚠️ | salle de commandement, dortoir, salle radio, réserve de vivres | salle de commandement, dortoir souterrain, armurerie, sas blindé, réserve de vivres, cellule d'isolement, salle radio, galerie d'évacuation |
| Bibliothèque ⚠️ | salle de lecture, rayonnages, réserve / archives, accueil | salle de lecture, réserve des manuscrits, archives au sous-sol, banque de prêt, coin des enfants, cabine de silence, atelier de reliure, rayon interdit |
| Usine ⚠️ | atelier / chaîne, entrepôt, salle de contrôle, vestiaire | chaîne de montage, atelier de soudure, salle des machines, vestiaire ouvrier, bureau du contremaître, entrepôt, quai de chargement, chaufferie |
| Restaurant gastronomique ⚠️ | salle, cuisine, cave à vin, bureau du chef | salle à manger, cuisine ouverte, plonge, cave à vin, table du chef, réserve sèche, terrasse, bureau de réservation |
| Commissariat ⚠️ | accueil, salle d'interrogatoire, cellules, bureau du commissaire | accueil, salle d'interrogatoire, garde à vue, salle de repos, bureau du chef, vestiaire, sous-sol des scellés, salle d'archives |
| Centre commercial ⚠️ | galerie marchande, boutique, parking, poste de sécurité | galerie marchande, aire de restauration, parking souterrain, cabine d'essayage, arrière-boutique, poste de sécurité, escalator central, toilettes publiques |
| Zoo ⚠️ | allées / enclos, infirmerie animale, réserve, bureau du directeur | fosse aux fauves, vivarium, enclos des primates, infirmerie animale, billetterie, coulisses des soigneurs, bassin des phoques, réserve de nourriture |
| Musée ⚠️ | hall d'accueil, salle d'exposition, réserve, salle de surveillance | galerie des maîtres, salle des antiquités, réserve des œuvres, atelier de restauration, hall d'entrée, poste de surveillance, salle des coffres, auditorium |
| Camping ⚠️ | accueil, emplacements, sanitaires, piscine | emplacement de tente, sanitaires collectifs, feu de camp, accueil du gérant, bord du lac, aire de jeux, épicerie du camping, sentier boisé |
| Plateau télé ⚠️ | plateau, régie, loges, coulisses | studio d'enregistrement, régie, loges des invités, coulisses, maquillage, salle de rédaction, gradins du public, bureau du producteur |
| Boîte de nuit ⚠️ | piste de danse, bar, carré VIP, loge / arrière-salle | entrée sous cordon, piste de danse, carré VIP, bar central, coin fumeurs, loge du DJ, toilettes bondées, arrière-salle |
| Station spatiale ⚠️ | poste de pilotage, module de vie, sas, salle des machines | sas d'accostage, poste de commandement, module d'habitation, salle des machines, serre hydroponique, coupole d'observation, baie médicale, réserve d'oxygène |
| Bureau ⚠️ | open space, salle de réunion, bureau du directeur, accueil | open space, salle de réunion, bureau du directeur, machine à café, photocopieuse, archives, ascenseur, parking souterrain |
| Palais présidentiel ⚠️ | bureau présidentiel, salle du conseil, salon de réception, poste de garde | salle du conseil, bureau ovale, antichambre, salle de bal, jardins d'honneur, bunker de commandement, appartements privés, salle de presse |
| Manoir abandonné ⚠️ | grand hall, bibliothèque, chambre à l'étage, cave | grand hall, escalier grinçant, chambre condamnée, bibliothèque poussiéreuse, cave voûtée, grenier, jardin envahi, passage dérobé |
| Prison ⚠️ | cour de promenade, cellule, parloir, poste de garde | cellule, cour de promenade, parloir, quartier d'isolement, réfectoire, mirador, atelier, bureau du directeur |
| Stade ⚠️ | terrain, vestiaire, tribunes, salle de presse | pelouse, vestiaires, tribune d'honneur, virage des ultras, tunnel des joueurs, salle de presse, buvette, parking des bus |
| Refuge de montagne ⚠️ | salle commune, dortoir, cuisine, terrasse | salle commune, dortoir, cheminée, cuisine du gardien, terrasse enneigée, réserve de bois, cave à vivres, porche gelé |
| Banque ⚠️ | hall clientèle, bureau conseiller, salle des coffres, salle de sécurité | guichet, salle des coffres, bureau du conseiller, salle d'attente, hall marbré, sas de sécurité, salle de comptage, bureau du directeur |
| Aquarium ⚠️ | hall d'accueil, grand bassin, salle des machines, bureau du directeur | tunnel vitré, grand bassin, bassin tactile, salle des méduses, coulisses techniques, quarantaine, billetterie, passerelle des soigneurs |
| Avion en vol ⚠️ | cockpit, cabine passagers, galley, soute | cockpit, cabine première classe, classe économique, galley, toilettes exiguës, soute, issue de secours, coin des hôtesses |
| Port maritime ⚠️ | quai, entrepôt, capitainerie, pont d'un navire | quai de chargement, entrepôt, bureau des douanes, cale du cargo, phare, bar des marins, grue portuaire, poste d'amarrage |
| Église ⚠️ | nef, chœur / autel, sacristie, clocher | nef, confessionnal, autel, sacristie, crypte, clocher, chapelle latérale, parvis |
| Salle de sport ⚠️ | plateau de musculation, vestiaire, salle de cours, accueil | Zone de musculation, Vestiaires, Salle de spinning, Sauna, Comptoir d'accueil, Ring de boxe, Douches collectives, Local à serviettes |
| Forêt ⚠️ | clairière, sentier, cabane, ruisseau | Clairière, Sentier envahi, Cabane du garde, Berge du ruisseau, Fourré épais, Vieux chêne creux, Poste de chasse, Ravin |
| Sous-marin ⚠️ | passerelle / commandement, salle des torpilles, salle des machines, poste équipage | Salle des machines, Poste de commandement, Coursive étroite, Cabine du capitaine, Torpilleur, Sas d'évacuation, Sonar, Couchettes |
| Métro ⚠️ | quai, rame, couloir / correspondance, poste de commande | Quai bondé, Rame, Couloir de correspondance, Guichet abandonné, Escalator en panne, Tourniquets, Bout de tunnel, Cabine du conducteur |
| Navire de croisière ⚠️ | pont supérieur, cabine, salle de bal, salle des machines | Pont supérieur, Cabine avec balcon, Salle de bal, Cuisine du bord, Piscine, Passerelle de commandement, Canots de sauvetage, Cale |
| Université ⚠️ | amphithéâtre, salle de TD, labo de recherche, bureau administratif | Amphithéâtre, Bibliothèque, Laboratoire, Bureau du doyen, Cafétéria, Résidence étudiante, Couloir des casiers, Salle de partiels |
| Hôpital ⚠️ | accueil / urgences, chambre, bloc opératoire, couloir | Salle d'attente, Bloc opératoire, Chambre du patient, Réanimation, Morgue, Poste des infirmières, Couloir des urgences, Salle de garde |
| École ⚠️ | salle de classe, cour de récréation, bureau du principal, préau | Salle de classe, Cour de récréation, Bureau du directeur, Cantine, Préau, Couloir des porte-manteaux, Salle des maîtres, Toilettes |
| Supermarché ⚠️ | rayons, caisses, réserve, bureau du manager | Caisses, Rayon frais, Réserve, Parking souterrain, Poste de sécurité, Étalage des fruits, Chambre froide, Bureau du gérant |
| Casino ⚠️ | salle de jeux, bar, salle des coffres, bureau de sécurité | Table de blackjack, Salle des machines à sous, Roulette, Bar feutré, Salle VIP, Caisse des jetons, Poste de vidéosurveillance, Salon des grosses mises |
| Théâtre ⚠️ | scène, coulisses, loges, salle / gradins | Scène, Coulisses, Loge d'artiste, Fosse d'orchestre, Balcon, Régie, Foyer, Dessous de scène |
| Tribunal ⚠️ | salle d'audience, bureau du juge, salle des témoins, cellule de garde à vue | Salle d'audience, Box des accusés, Bureau du juge, Salle des délibérations, Couloir des pas perdus, Cellule de garde, Greffe, Banc de la défense |
| Station-service ⚠️ | boutique, pistes / pompes, atelier, réserve | Piste de ravitaillement, Boutique, Caisse, Station de lavage, Réserve à carburant, Toilettes extérieures, Aire de repos, Atelier |

⚠️ = au moins un espace de la grammaire n'existe pas tel quel dans les sous-espaces de l'appli.

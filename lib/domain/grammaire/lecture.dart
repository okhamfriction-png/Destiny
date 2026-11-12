import 'modeles.dart';

/// Les données propres à l'appli pour un animal (`assets/data/archetypes.json`) :
/// tempérament, niveaux de corps, et les anciens champs conservés.
class DonneesAnimalAppli {
  const DonneesAnimalAppli({
    this.temperament = '',
    this.niveaux = const [],
    this.moteur = '',
    this.intention = '',
  });

  final String temperament;
  final List<String> niveaux;
  final String moteur;
  final String intention;

  /// Lit une entrée de `archetypes.json` (marqueurs markdown retirés).
  factory DonneesAnimalAppli.depuisJson(Map<String, dynamic> j) =>
      DonneesAnimalAppli(
        temperament: _nettoyer(j['temperament']),
        niveaux: [for (final n in (j['niveaux'] as List? ?? const [])) '$n'.trim()],
        moteur: _nettoyer(j['moteur']),
        intention: _nettoyer(j['intention']),
      );

  static String _nettoyer(Object? v) {
    var s = (v as String? ?? '').trim();
    if (s.startsWith('**') && s.endsWith('**') && s.length >= 4) {
      s = s.substring(2, s.length - 2);
    }
    if (s.startsWith('_') && s.endsWith('_') && s.length >= 2) {
      s = s.substring(1, s.length - 1);
    }
    return s.trim();
  }
}

/// Vérifie le fichier de grammaire avant de le lire. Rend la liste des
/// problèmes trouvés (vide si tout va bien).
List<String> validerGrammaire(Map<String, dynamic> j) {
  final erreurs = <String>[];
  List<dynamic> liste(String cle) {
    final v = j[cle];
    if (v is List) return v;
    erreurs.add('La clé « $cle » manque ou n\'est pas une liste.');
    return const [];
  }

  final familles = liste('familles');
  final idsFamilles = {for (final f in familles) (f as Map)['id']};
  for (final f in FamilleId.values) {
    if (!idsFamilles.contains(f.name)) {
      erreurs.add('La famille « ${f.name} » manque.');
    }
  }

  final archetypes = liste('archetypes');
  if (archetypes.length != 12) {
    erreurs.add('Il faut 12 archétypes, il y en a ${archetypes.length}.');
  }
  final idsArchetypes = <String>{};
  final idsAnimaux = <String>{};
  for (final a in archetypes) {
    final m = a as Map;
    final id = '${m['id']}';
    if (!idsArchetypes.add(id)) erreurs.add('Archétype en double : $id.');
    if (FamilleId.depuisTexte(m['famille'] as String?) == null) {
      erreurs.add('L\'archétype $id a une famille inconnue.');
    }
    final montee = m['montee'];
    for (final p in PalierId.values) {
      final t = montee is Map ? montee[p.name] : null;
      if (t is! String || t.trim().isEmpty) {
        erreurs.add('L\'archétype $id n\'a pas de montée au palier ${p.name}.');
      }
    }
    final animaux = m['animaux'];
    if (animaux is! List || animaux.length != 2) {
      erreurs.add('L\'archétype $id doit avoir 2 animaux.');
    } else {
      for (final an in animaux) {
        final aid = '${(an as Map)['id']}';
        if (!idsAnimaux.add(aid)) {
          erreurs.add('L\'animal $aid sert à plusieurs archétypes.');
        }
        if ((an['replique'] as String? ?? '').trim().isEmpty) {
          erreurs.add('L\'animal $aid n\'a pas de réplique.');
        }
      }
    }
  }
  if (idsAnimaux.length != 24) {
    erreurs.add('Il faut 24 animaux uniques, il y en a ${idsAnimaux.length}.');
  }
  if (!idsArchetypes.contains(Grammaire.alarmisteId)) {
    erreurs.add('L\'alarmiste manque.');
  }

  final paliers = liste('paliers');
  if (paliers.length != 4) erreurs.add('Il faut 4 paliers.');
  for (final p in PalierId.values) {
    if (!paliers.any((x) => (x as Map)['id'] == p.name)) {
      erreurs.add('Le palier « ${p.name} » manque.');
    }
  }
  if (liste('actes').length != 4) erreurs.add('Il faut 4 actes.');

  for (final d in liste('dangers')) {
    final m = d as Map;
    final pal = m['paliers'];
    for (final p in PalierId.values) {
      final t = pal is Map ? pal[p.name] : null;
      if (t is! String || t.trim().isEmpty) {
        erreurs.add('Le danger « ${m['nom']} » n\'a pas son palier ${p.name}.');
      }
    }
  }
  for (final l in liste('lieux')) {
    final m = l as Map;
    if ((m['espaces'] as List? ?? const []).isEmpty) {
      erreurs.add('Le lieu « ${m['nom']} » n\'a pas d\'espaces.');
    }
  }

  final distribution = j['distribution'];
  if (distribution is! Map) {
    erreurs.add('La distribution manque.');
  } else {
    for (final e in (distribution['exemples'] as List? ?? const [])) {
      final m = e as Map;
      for (final id in [...(m['a_4'] as List? ?? const []), m['plus_a_5'], m['plus_a_6']]) {
        if (!idsArchetypes.contains(id)) {
          erreurs.add('Un exemple de distribution cite un archétype inconnu : $id.');
        }
      }
    }
  }

  final perso = j['personnage'];
  if (perso is Map) {
    for (final d in (perso['six_directions'] as List? ?? const [])) {
      final id = (d as Map)['archetype'];
      if (!idsArchetypes.contains(id)) {
        erreurs.add('Une des six directions cite un archétype inconnu : $id.');
      }
    }
  } else {
    erreurs.add('La partie « personnage » manque.');
  }

  final nomsAnimaux = <String, String>{};
  for (final a in archetypes) {
    for (final an in ((a as Map)['animaux'] as List? ?? const [])) {
      nomsAnimaux['${(an as Map)['nom']}'] = '${a['id']}';
    }
  }
  for (final o in (j['oeuvres'] as List? ?? const [])) {
    final om = o as Map;
    for (final p in (om['personnages'] as List? ?? const [])) {
      final pm = p as Map;
      if (!idsArchetypes.contains(pm['archetype'])) {
        erreurs.add('« ${om['titre']} » : ${pm['nom']} a un archétype inconnu.');
      } else if (nomsAnimaux[pm['animal']] != pm['archetype']) {
        erreurs.add('« ${om['titre']} » : l\'animal de ${pm['nom']} '
            'n\'appartient pas à son archétype.');
      }
    }
  }
  // Méchants et sbires.
  final mechants = j['mechants'];
  if (mechants is List) {
    final parArchetype = <String, int>{};
    final idsSbires = <String>{};
    for (final m in mechants) {
      final mm = m as Map;
      final arch = '${mm['archetype']}';
      parArchetype[arch] = (parArchetype[arch] ?? 0) + 1;
      if (!idsArchetypes.contains(arch)) {
        erreurs.add('Le méchant ${mm['id']} a un archétype inconnu.');
      }
      if (nomsAnimaux.containsKey(mm['animal'])) {
        erreurs.add('Le méchant ${mm['id']} prend un animal des comédiens.');
      }
      if (mm['kids'] == true &&
          ('${mm['version_kids'] ?? ''}'.isEmpty || '${mm['faille_kids'] ?? ''}'.isEmpty)) {
        erreurs.add('Le méchant kids ${mm['id']} n\'a pas sa version kids.');
      }
      final sbires = mm['sbires'];
      if (sbires is! List || sbires.length != 2) {
        erreurs.add('Le méchant ${mm['id']} doit avoir 2 sbires.');
        continue;
      }
      for (final sb in sbires) {
        final sm = sb as Map;
        if (!idsSbires.add('${sm['id']}')) erreurs.add('Sbire en double : ${sm['id']}.');
        if (nomsAnimaux[sm['animal']] != sm['archetype']) {
          erreurs.add('Le sbire ${sm['id']} : son animal n\'appartient pas à son archétype.');
        }
      }
    }
    for (final id in idsArchetypes) {
      if ((parArchetype[id] ?? 0) == 0) erreurs.add('Aucun méchant pour l\'archétype $id.');
    }
  }

  // Figurants des lieux.
  final types = {
    for (final t in ((j['figurants'] as Map?)?['types'] as List? ?? const []))
      (t as Map)['id'],
  };
  for (final l in (j['lieux'] as List? ?? const [])) {
    final lm = l as Map;
    for (final f in (lm['figurants'] as List? ?? const [])) {
      final fm = f as Map;
      if (nomsAnimaux[fm['animal']] != fm['archetype']) {
        erreurs.add('« ${lm['nom']} » : l\'animal de ${fm['nom']} '
            'n\'appartient pas à son archétype.');
      }
      if (types.isNotEmpty && !types.contains(fm['type'])) {
        erreurs.add('« ${lm['nom']} » : ${fm['nom']} a un type inconnu.');
      }
    }
  }

  // Dangers kids : un palier 4 sans mort.
  for (final d in (j['dangers'] as List? ?? const [])) {
    final dm = d as Map;
    if (dm['kids'] == true && '${dm['supprime_kids'] ?? ''}'.trim().isEmpty) {
      erreurs.add('Le danger kids « ${dm['nom']} » n\'a pas son palier 4 kids.');
    }
  }
  return erreurs;
}

/// Lit le fichier de grammaire. [animauxAppli] apporte, par identifiant
/// d'animal, le tempérament et les niveaux de corps de l'appli.
Grammaire lireGrammaire(
  Map<String, dynamic> j, {
  Map<String, DonneesAnimalAppli> animauxAppli = const {},
}) {
  String s(Object? v) => (v as String? ?? '').trim();
  List<String> ls(Object? v) => [for (final x in (v as List? ?? const [])) s(x)];
  Map<PalierId, String> parPalier(Object? v) => {
        for (final p in PalierId.values)
          p: v is Map ? s(v[p.name]) : '',
      };
  List<Map<String, dynamic>> maps(Object? v) =>
      [for (final x in (v as List? ?? const [])) Map<String, dynamic>.from(x as Map)];

  final familles = [
    for (final f in maps(j['familles']))
      Famille(
        id: FamilleId.depuisTexte(s(f['id'])) ?? FamilleId.tient,
        nom: s(f['nom']),
        couleur: s(f['couleur']),
        couleurClaire: s(f['couleur_claire']),
        idee: s(f['idee']),
        pourquoi: s(f['pourquoi']),
      ),
  ];

  final archetypes = <Archetype>[];
  final animaux = <Animal>[];
  for (final a in maps(j['archetypes'])) {
    final id = s(a['id']);
    final ans = maps(a['animaux']);
    archetypes.add(Archetype(
      id: id,
      nom: s(a['nom']),
      famille: FamilleId.depuisTexte(s(a['famille'])) ?? FamilleId.tient,
      ceQuIlFait: s(a['ce_qu_il_fait']),
      montee: parPalier(a['montee']),
      animalIds: [for (final an in ans) s(an['id'])],
    ));
    for (final an in ans) {
      final aid = s(an['id']);
      final appli = animauxAppli[aid] ?? const DonneesAnimalAppli();
      animaux.add(Animal(
        id: aid,
        nom: s(an['nom']),
        archetypeId: id,
        statutDepart: Statut.depuisTexte(s(an['statut_depart'])),
        port: s(an['port']),
        posture: s(an['posture']),
        replique: s(an['replique']),
        sourceReplique: s(an['source_replique']),
        repliqueKids: s(an['replique_kids']),
        sourceRepliqueKids: s(an['source_replique_kids']),
        repliqueAdulteSeulement: an['replique_adulte_seulement'] == true,
        temperament: appli.temperament,
        niveauxCorps: {
          for (var i = 0; i < PalierId.values.length && i < appli.niveaux.length; i++)
            PalierId.values[i]: appli.niveaux[i],
        },
        // ignore: deprecated_member_use_from_same_package
        ancienMoteur: appli.moteur,
        // ignore: deprecated_member_use_from_same_package
        ancienneIntention: appli.intention,
      ));
    }
  }

  final paliers = [
    for (final p in maps(j['paliers']))
      Palier(
        id: PalierId.depuisTexte(s(p['id'])) ?? PalierId.signale,
        nom: s(p['nom']),
        acte: (p['acte'] as num?)?.toInt() ?? 1,
        ambiance: s(p['ambiance']),
        etatArchetype: s(p['archetype']),
      ),
  ];

  final actes = [
    for (final a in maps(j['actes']))
      Acte(
        numero: (a['acte'] as num?)?.toInt() ?? 1,
        palier: PalierId.deNumero((a['acte'] as num?)?.toInt() ?? 1),
        ambiance: s(a['ambiance']),
        consignes: ls(a['consignes']),
      ),
  ];

  String idAnimal(Object? nom) {
    final cle = Grammaire.normaliser(s(nom));
    for (final a in animaux) {
      if (Grammaire.normaliser(a.nom) == cle || a.id == s(nom)) return a.id;
    }
    return s(nom);
  }

  List<RegleDOr> regles(Object? v) => [
        for (final r in maps(v)) RegleDOr(titre: s(r['titre']), texte: s(r['texte'])),
      ];

  final se = Map<String, dynamic>.from(j['serie'] as Map? ?? const {});
  final reg = Map<String, dynamic>.from(se['registre'] as Map? ?? const {});
  final fi = Map<String, dynamic>.from(j['figurants'] as Map? ?? const {});
  final fiModes = Map<String, dynamic>.from(fi['modes'] as Map? ?? const {});
  final mk = Map<String, dynamic>.from(j['mode_kids'] as Map? ?? const {});
  final sigle = Map<String, dynamic>.from(mk['sigle'] as Map? ?? const {});

  final rd = Map<String, dynamic>.from(j['rituel_destiny'] as Map? ?? const {});
  final di = Map<String, dynamic>.from(j['distribution'] as Map? ?? const {});
  final pe = Map<String, dynamic>.from(j['personnage'] as Map? ?? const {});
  final ech = Map<String, dynamic>.from(pe['echauffement'] as Map? ?? const {});
  final da = Map<String, dynamic>.from(j['direction_artistique'] as Map? ?? const {});
  final polices = Map<String, dynamic>.from(da['polices'] as Map? ?? const {});
  final statuts = Map<String, dynamic>.from(da['statuts'] as Map? ?? const {});

  return Grammaire(
    version: s(j['version']),
    nom: s(j['nom']),
    promesse: s(j['promesse']),
    familles: familles,
    archetypes: archetypes,
    animaux: animaux,
    paliers: paliers,
    actes: actes,
    reglesDOr: [
      for (final r in maps(j['regles_d_or']))
        RegleDOr(id: s(r['id']), titre: s(r['titre']), texte: s(r['texte'])),
    ],
    rituel: RituelDestiny(
      quand: s(rd['quand']),
      quiDeclenche: s(rd['qui_declenche']),
      sequence: ls(rd['sequence']),
      reprise: s(rd['reprise']),
      premierFige: s(rd['premier_fige']),
      suite: ls(rd['suite']),
    ),
    distribution: RegleDistribution(
      regle: s(di['regle']),
      compositions: [
        for (final c in maps(di['par_nombre']))
          CompositionDistribution(
            joueurs: (c['joueurs'] as num?)?.toInt() ?? 0,
            alarmiste: (c['alarmiste'] as num?)?.toInt() ?? 1,
            tient: (c['tient'] as num?)?.toInt() ?? 0,
            interprete: (c['interprete'] as num?)?.toInt() ?? 0,
            fissure: (c['fissure'] as num?)?.toInt() ?? 0,
            auChoix: (c['au_choix'] as num?)?.toInt() ?? 0,
          ),
      ],
      exemples: [
        for (final e in maps(di['exemples']))
          ExempleDistribution(
            aQuatre: ls(e['a_4']),
            plusACinq: s(e['plus_a_5']),
            plusASix: s(e['plus_a_6']),
          ),
      ],
      aSix: s(di['a_6']),
    ),
    personnage: PedagogiePersonnage(
      couches: ls(pe['couches']),
      phraseCle: s(pe['phrase_cle']),
      piege: s(pe['piege']),
      chaine: ls(pe['chaine']),
      detecterPasJouer: s(pe['detecter_pas_jouer']),
      vouloirTests: ls(pe['vouloir_tests']),
      vouloirMethode: s(pe['vouloir_methode']),
      planterPourPayer: s(pe['planter_pour_payer']),
      vouloirAvoue: s(pe['vouloir_avoue']),
      troisCartes: [
        for (final c in maps(pe['trois_cartes']))
          CartePersonnage(
            titre: s(c['titre']),
            sousTitre: s(c['sous_titre']),
            texte: s(c['texte']),
            exemple: s(c['exemple']),
          ),
      ],
      acteParActe: [
        for (final g in maps(pe['acte_par_acte']))
          GesteActe(
            moment: s(g['moment']),
            verbe: s(g['verbe']),
            consigne: s(g['consigne']),
          ),
      ],
      sixDirections: [
        for (final d in maps(pe['six_directions']))
          Direction(
            archetypeId: s(d['archetype']),
            personnage: s(d['personnage']),
            besoin: s(d['besoin']),
            acte1Veut: s(d['acte1_veut']),
            acte1Blessure: s(d['acte1_blessure']),
            acte2: s(d['acte2']),
            acte3: s(d['acte3']),
            acte4: s(d['acte4']),
          ),
      ],
      echauffement: Echauffement(
        quand: s(ech['quand']),
        questions: ls(ech['questions']),
        limite: s(ech['limite']),
      ),
    ),
    dangers: [
      for (final d in maps(j['dangers']))
        DangerGrammaire(
          id: s(d['id']),
          nom: s(d['nom']),
          paliers: parPalier(d['paliers']),
          kids: d['kids'] == true,
          supprimeKids: s(d['supprime_kids']),
        ),
    ],
    lieux: [
      for (final l in maps(j['lieux']))
        LieuGrammaire(
          id: s(l['id']),
          nom: s(l['nom']),
          espaces: ls(l['espaces']),
          roles: ls(l['roles']),
          kids: l['kids'] == true,
          figurants: [
            for (final (i, f) in maps(l['figurants']).indexed)
              FigurantPret(
                id: '${s(l['id'])}.$i',
                nom: s(f['nom']),
                type: s(f['type']),
                archetypeId: s(f['archetype']),
                animalId: idAnimal(f['animal']),
                veut: s(f['veut']),
                vientDe: s(f['vient_de']),
                sait: s(f['sait']),
                mode: ModePnj.depuisTexte(s(f['mode'])),
              ),
          ],
        ),
    ],
    oeuvres: [
      for (final o in maps(j['oeuvres']))
        Oeuvre(
          categorie: CategorieOeuvre.depuisTexte(s(o['categorie'])),
          titre: s(o['titre']),
          fiche: s(o['fiche']),
          pitch: s(o['pitch']),
          lieu: s(o['lieu']),
          groupe: s(o['groupe']),
          danger: s(o['danger']),
          paliers: ls(o['paliers']),
          personnages: [
            for (final p in maps(o['personnages']))
              PersonnageOeuvre(
                archetypeId: s(p['archetype']),
                animalNom: s(p['animal']),
                nom: s(p['nom']),
                veut: s(p['veut']),
                besoin: s(p['besoin']),
                faceAuDanger: s(p['face_au_danger']),
                choix: s(p['choix']),
              ),
          ],
          lecon: s(o['lecon']),
        ),
    ],
    scenes: [
      for (final sc in maps(j['scenes_tarantino']))
        SceneReference(
          titre: s(sc['titre']),
          film: s(sc['film']),
          lieu: s(sc['lieu']),
          danger: s(sc['danger']),
          paliers: ls(sc['paliers']),
          lecon: s(sc['lecon']),
        ),
    ],
    exercices: [
      for (final e in maps(j['exercices']))
        ExerciceGrammaire(
          id: s(e['id']),
          titre: s(e['titre']),
          source: s(e['source']),
          duree: s(e['duree']),
          joueurs: s(e['joueurs']),
          notion: s(e['notion']),
          but: s(e['but']),
          consignes: ls(e['consignes']),
          exemples: ls(e['exemples']),
          debrief: s(e['debrief']),
          variante: s(e['variante']),
          themeId: s(e['theme']),
          cartesATirer: ls(e['cartes_a_tirer']),
        ),
    ],
    themesExercices: [
      for (final t in maps(j['themes_exercices']))
        ThemeExercice(
          id: s(t['id']),
          nom: s(t['nom']),
          sousTitre: s(t['sous_titre']),
          principe: s(t['principe']),
          explication: s(t['explication']),
        ),
    ],
    obsolete: ls(j['obsolete']),
    directionArtistique: DirectionArtistique(
      couleurs: {
        for (final e in da.entries)
          if (e.value is String) e.key: (e.value as String).trim(),
      },
      policeTitres: s(polices['titres']),
      policeTexte: s(polices['texte']),
      statuts: {
        for (final st in Statut.values)
          if (statuts[st.name] is String) st: s(statuts[st.name]),
      },
    ),
    serie: ReglesSerie(
      episode: s(se['episode']),
      saison: s(se['saison']),
      serie: s(se['serie']),
      reglesDuMechant: ls(se['regles_du_mechant']),
      registre: RegistreSerie(
        principe: s(reg['principe']),
        categories: ls(reg['categories']),
        suggestion: s(reg['suggestion']),
      ),
    ),
    mechants: [
      for (final m in maps(j['mechants']))
        Mechant(
          id: s(m['id']),
          nom: s(m['nom']),
          archetypeId: s(m['archetype']),
          animal: s(m['animal']),
          inspiration: s(m['inspiration']),
          posture: s(m['posture']),
          histoire: s(m['histoire']),
          veut: s(m['veut']),
          besoin: s(m['besoin']),
          faille: s(m['faille']),
          cible: s(m['cible']),
          offreAuTraitre: s(m['offre_au_traitre']),
          kids: m['kids'] == true,
          versionKids: s(m['version_kids']),
          failleKids: s(m['faille_kids']),
          sbires: [
            for (final sb in maps(m['sbires']))
              Sbire(
                id: s(sb['id']),
                nom: s(sb['nom']),
                archetypeId: s(sb['archetype']),
                animalId: idAnimal(sb['animal']),
                veut: s(sb['veut']),
                vientDe: s(sb['vient_de']),
                fait: s(sb['fait']),
                kids: sb['kids'] == true,
              ),
          ],
        ),
    ],
    figurants: ReglesFigurants(
      modes: {
        ModePnj.figurant: s(fiModes['figurant']),
        ModePnj.sbire: s(fiModes['sbire']),
      },
      spectacle: s(fiModes['spectacle']),
      types: [
        for (final t in maps(fi['types']))
          TypeFigurant(
            id: s(t['id']),
            nom: s(t['nom']),
            ceQuIlEst: s(t['ce_qu_il_est']),
            veut: s(t['veut']),
            commentLeJouer: s(t['comment_le_jouer']),
            sertA: s(t['sert_a']),
          ),
      ],
      regles: regles(fi['regles']),
      parLieu: s(fi['par_lieu']),
      inspiration: s(fi['inspiration']),
    ),
    modeKids: ModeKids(
      sigleTexte: s(sigle['texte']),
      sigleFond: s(sigle['fond']),
      sigleTexteCouleur: s(sigle['texte_couleur']),
      principe: s(mk['principe']),
      regles: regles(mk['regles']),
      pouvoirsExemples: ls(mk['pouvoirs_exemples']),
      pouvoirRegle: s(mk['pouvoir_regle']),
      palier4: s(mk['palier_4']),
      dureeEpisodeMinutes: [
        for (final x in (mk['duree_episode_minutes'] as List? ?? const [])) (x as num).toInt(),
      ],
      mechantIds: ls(mk['mechants']),
      dangerIds: ls(mk['dangers']),
      lieuxAdultesSeulement: ls(mk['lieux_adultes_seulement']),
    ),
  );
}

import 'package:flutter/material.dart';

import '../../application/state/visual_settings.dart';
import '../../domain/entities/danger.dart';
import '../../domain/entities/location.dart';
import '../../domain/grammaire/modeles.dart';
import '../../domain/grammaire/progression.dart';
import '../../domain/troupe/session.dart';
import '../bibliotheque/archetypes_screen.dart';
import '../bibliotheque/bibliotheque_screen.dart';
import '../bibliotheque/dangers_lieux_screen.dart';
import '../destiny/composants.dart';
import '../destiny/donnees.dart';
import '../destiny/page.dart';
import '../theme/destiny_theme.dart';
import 'troupe_screen.dart';

/// Les composants partagés des écrans Troupe, une fois la distribution
/// choisie : on ne montre plus que l'archétype (et son animal s'il a été
/// choisi), en petit rectangle, avec une bulle d'info pour en savoir plus.

/// La Bibliothèque vue depuis la Troupe (pour ouvrir les fiches).
ContexteBibliotheque bibliothequeDe(ContexteTroupe c) => ContexteBibliotheque(
      catalogue: c.catalogue,
      visuels: c.visuels,
      detailsLieux: c.detailsLieux,
    );

void _ouvrir(BuildContext context, Widget page) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

/// La petite bulle d'info : un « i » qui ouvre une fiche de la Bibliothèque.
class BulleInfo extends StatelessWidget {
  const BulleInfo({super.key, required this.nom, required this.onPressed});

  /// Ce dont on veut en savoir plus (pour le libellé).
  final String nom;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.destiny;
    return IconButton(
      tooltip: context.textes.t('troupe.info_de', {'nom': nom}),
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
      padding: EdgeInsets.zero,
      iconSize: 22,
      icon: Icon(Icons.info_outline_rounded, color: c.titre),
      onPressed: onPressed,
    );
  }
}

/// Le haut d'un rectangle d'archétype, sans sa carte : le médaillon de
/// l'animal s'il a été choisi, le nom de l'archétype, une ligne courte, et la
/// bulle d'info. Sert aussi d'en-tête aux cartes du débrief.
class EnteteArchetype extends StatelessWidget {
  const EnteteArchetype({super.key, required this.personnage, required this.contexte, this.palier});

  final PersonnageTroupe personnage;
  final ContexteTroupe contexte;

  /// À la régie : la ligne montre la montée à ce palier, et le corps de
  /// l'animal. Sinon : ce que fait l'archétype.
  final PalierId? palier;

  @override
  Widget build(BuildContext context) {
    final g = context.grammaire;
    final c = context.destiny;
    final a = g.archetype(personnage.archetypeId);
    if (a == null) return const SizedBox.shrink();
    final animal = personnage.animalId.isEmpty ? null : g.animal(personnage.animalId);
    final couleur = c.famille(a.famille);
    final montee = palier == null ? null : monteeAttendue(g, archetypeId: a.id, animalId: animal?.id, palier: palier!);
    final ligne = montee?.ceQuIlFait ?? a.ceQuIlFait;
    final corps = montee?.corps ?? '';
    final bibliotheque = bibliothequeDe(contexte);

    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (animal != null) ...[
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: _MedaillonInfo(
            animal: animal,
            source: contexte.visuels.source,
            onTap: () => _ouvrir(context, FicheAnimal(animalId: animal.id, contexte: bibliotheque)),
          ),
        ),
        const SizedBox(width: 12),
      ],
      Expanded(
        child: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text.rich(
              TextSpan(children: [
                if (personnage.joueur.isNotEmpty) TextSpan(text: '${personnage.joueur} · '),
                TextSpan(text: a.nom),
                if (animal != null)
                  TextSpan(
                    text: '  ·  ${animal.nom}',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5, color: c.accent(couleur)),
                  ),
              ]),
              style: TextStyle(
                fontFamily: kPoliceTexte,
                fontWeight: FontWeight.w800,
                fontSize: 16.5,
                height: 1.25,
                color: c.texte,
              ),
            ),
            if (ligne.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                ligne,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: kPoliceTexte,
                  fontSize: 14,
                  height: 1.35,
                  fontWeight: montee == null ? FontWeight.w400 : FontWeight.w600,
                  color: montee == null ? c.texteSecondaire : c.accent(couleur),
                ),
              ),
            ],
            if (corps.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                corps,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: kPoliceTexte, fontSize: 13.5, height: 1.35, color: c.texteSecondaire),
              ),
            ],
          ]),
        ),
      ),
      const SizedBox(width: 4),
      BulleInfo(
        nom: a.nom,
        onPressed: () => _ouvrir(context, FicheArchetype(archetypeId: a.id, contexte: bibliotheque)),
      ),
    ]);
  }
}

/// Le médaillon de l'animal choisi : on le touche pour ouvrir sa fiche.
class _MedaillonInfo extends StatelessWidget {
  const _MedaillonInfo({required this.animal, required this.source, required this.onTap});

  final Animal animal;
  final VisualSource source;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final libelle = context.textes.t('troupe.info_de', {'nom': animal.nom});
    return Tooltip(
      message: libelle,
      child: Semantics(
        button: true,
        label: libelle,
        excludeSemantics: true,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: MedaillonAnimal(animal, taille: 44, source: source),
        ),
      ),
    );
  }
}

/// Un archétype en petit rectangle : la barre de couleur de sa famille, son
/// nom, une ligne courte, l'animal choisi s'il y en a un, et la bulle d'info.
class RectangleArchetype extends StatelessWidget {
  const RectangleArchetype({
    super.key,
    required this.personnage,
    required this.contexte,
    this.palier,
    this.pied,
  });

  final PersonnageTroupe personnage;
  final ContexteTroupe contexte;

  /// À la régie : la montée à ce palier (voir [EnteteArchetype]).
  final PalierId? palier;

  /// Sous le rectangle (un bouton d'idées de l'IA, par exemple).
  final Widget? pied;

  @override
  Widget build(BuildContext context) {
    final a = context.grammaire.archetype(personnage.archetypeId);
    if (a == null) return const SizedBox.shrink();
    final c = context.destiny;
    return CadreLisere(
      couleur: c.famille(a.famille),
      marge: 10,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        EnteteArchetype(personnage: personnage, contexte: contexte, palier: palier),
        if (pied != null) Padding(padding: const EdgeInsets.only(top: 8), child: pied),
      ]),
    );
  }
}

/// Une ligne du lieu ou du danger : sa vignette, son nom, et la bulle d'info.
class LigneDecor extends StatelessWidget {
  const LigneDecor({
    super.key,
    required this.dossier,
    required this.id,
    this.surtitre,
    required this.nom,
    required this.icone,
    required this.source,
    this.detail,
    this.onInfo,
  });

  /// `locations` ou `dangers` (le dossier des images).
  final String dossier;
  final String id;
  final String? surtitre;
  final String nom;
  final IconData icone;
  final VisualSource source;
  final String? detail;
  final VoidCallback? onInfo;

  @override
  Widget build(BuildContext context) {
    final c = context.destiny;
    Widget repli() => DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [c.orFonce, c.nuit],
            ),
          ),
          child: Center(child: Icon(icone, size: 26, color: c.orClair)),
        );
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(10, 10, 4, 10),
      decoration: decorCarte(c),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 56,
            height: 56,
            child: id.isNotEmpty && source == VisualSource.ai
                ? Image.asset('assets/images/$dossier/$id.jpg',
                    fit: BoxFit.cover, errorBuilder: (_, __, ___) => repli())
                : repli(),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (surtitre != null) ...[
              Text(
                surtitre!.toUpperCase(),
                style: TextStyle(
                  fontFamily: kPoliceTexte,
                  fontSize: 11.5,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w700,
                  color: c.texteSecondaire,
                ),
              ),
              const SizedBox(height: 2),
            ],
            Text(
              nom.isEmpty ? '—' : nom,
              style: TextStyle(
                fontFamily: kPoliceTexte,
                fontWeight: FontWeight.w700,
                fontSize: 16,
                height: 1.25,
                color: c.texte,
              ),
            ),
            if (detail != null && detail!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                detail!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: kPoliceTexte, fontSize: 13, height: 1.3, color: c.texteSecondaire),
              ),
            ],
          ]),
        ),
        if (onInfo != null) BulleInfo(nom: nom, onPressed: onInfo),
      ]),
    );
  }
}

/// Le lieu et le danger d'une session, chacun avec sa bulle d'info. Le
/// catalogue se charge à l'ouverture (pour les fiches).
class LieuEtDanger extends StatefulWidget {
  const LieuEtDanger({super.key, required this.contexte, required this.session});

  final ContexteTroupe contexte;
  final SessionTroupe session;

  @override
  State<LieuEtDanger> createState() => _LieuEtDangerState();
}

class _LieuEtDangerState extends State<LieuEtDanger> {
  List<Location> _lieux = const [];
  List<Danger> _dangers = const [];

  SessionTroupe get s => widget.session;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final lieux = await widget.contexte.catalogue.getLocations();
    final dangers = await widget.contexte.catalogue.getDangers();
    if (!mounted) return;
    setState(() {
      _lieux = lieux;
      _dangers = dangers;
    });
  }

  T? _trouver<T>(List<T> liste, String id, String nom, String Function(T) idDe, String Function(T) nomDe) {
    for (final e in liste) {
      if (id.isNotEmpty && idDe(e) == id) return e;
    }
    for (final e in liste) {
      if (nom.isNotEmpty && nomDe(e) == nom) return e;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.textes;
    final lieu = _trouver<Location>(_lieux, s.lieuId, s.lieuNom, (l) => l.id, (l) => l.name);
    final danger = _trouver<Danger>(_dangers, s.dangerId, s.dangerNom, (d) => d.id, (d) => d.name);
    final source = widget.contexte.visuels.source;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      LigneDecor(
        dossier: 'locations',
        id: lieu?.id ?? s.lieuId,
        surtitre: t.t('mise_en_place.lieu'),
        nom: s.lieuNom,
        icone: Icons.place_rounded,
        source: source,
        onInfo: lieu == null
            ? null
            : () => _ouvrir(context, FicheLieu(lieu: lieu, contexte: bibliothequeDe(widget.contexte))),
      ),
      LigneDecor(
        dossier: 'dangers',
        id: danger?.id ?? s.dangerId,
        surtitre: t.t('mise_en_place.danger'),
        nom: s.dangerNom,
        icone: Icons.bolt_rounded,
        source: source,
        onInfo: danger == null ? null : () => _ouvrir(context, FicheDanger(danger: danger)),
      ),
    ]);
  }
}

/// Un repère de la frise des Destiny.
enum EtatDestiny { passe, prochain, avenir }

class RepereDestiny {
  const RepereDestiny({required this.numero, required this.secondes, required this.etat});

  final int numero;
  final int secondes;
  final EtatDestiny etat;
}

/// Les repères des trois Destiny d'une session : ceux déjà lancés à l'heure
/// où ils l'ont été, les autres à l'heure prévue.
List<RepereDestiny> reperesDestiny(SessionTroupe s) => [
      for (var i = 0; i < s.destinyMinutes.length; i++)
        RepereDestiny(
          numero: i + 1,
          secondes: i < s.destinys.length ? s.destinys[i].secondes : s.destinyMinutes[i] * 60,
          etat: i < s.destinys.length
              ? EtatDestiny.passe
              : (i == s.destinys.length ? EtatDestiny.prochain : EtatDestiny.avenir),
        ),
    ];

/// Une durée en « mm:ss ».
String horloge(int secondes) {
  final v = secondes.abs();
  return '${secondes < 0 ? '-' : ''}${(v ~/ 60).toString().padLeft(2, '0')}:${(v % 60).toString().padLeft(2, '0')}';
}

/// La frise du chrono : toute la durée, la position actuelle, et les trois
/// Destiny numérotés (ceux passés cochés, le prochain mis en avant).
class FriseDestiny extends StatelessWidget {
  const FriseDestiny({
    super.key,
    required this.totalSecondes,
    required this.ecouleSecondes,
    required this.reperes,
    this.curseur = true,
  });

  final int totalSecondes;
  final int ecouleSecondes;
  final List<RepereDestiny> reperes;

  /// Montrer où en est le chrono (pas pour un simple aperçu).
  final bool curseur;

  static const double _hauteur = 36;
  static const double _rayon = 16;

  @override
  Widget build(BuildContext context) {
    final c = context.destiny;
    final t = context.textes;
    final total = totalSecondes <= 0 ? 1 : totalSecondes;
    final avance = (ecouleSecondes / total).clamp(0.0, 1.0);
    return MediaQuery.withNoTextScaling(
      child: SizedBox(
        height: _hauteur,
        child: LayoutBuilder(builder: (context, contraintes) {
          final largeur = contraintes.maxWidth;
          double x(int secondes) => _rayon + (largeur - 2 * _rayon) * (secondes / total).clamp(0.0, 1.0);
          return Stack(clipBehavior: Clip.none, children: [
            // La barre, et ce qui est déjà joué.
            Positioned(
              left: _rayon,
              right: _rayon,
              top: _hauteur / 2 - 3,
              height: 6,
              child: DecoratedBox(
                decoration: BoxDecoration(color: c.filet, borderRadius: BorderRadius.circular(3)),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: avance,
                    heightFactor: 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(color: c.or, borderRadius: BorderRadius.circular(3)),
                    ),
                  ),
                ),
              ),
            ),
            for (final r in reperes)
              Positioned(
                left: x(r.secondes) - _rayon,
                top: _hauteur / 2 - _rayon,
                width: _rayon * 2,
                height: _rayon * 2,
                child: Semantics(
                  excludeSemantics: true,
                  label: t.t(
                    switch (r.etat) {
                      EtatDestiny.passe => 'regie.marque_passe',
                      EtatDestiny.prochain => 'regie.marque_prochain',
                      EtatDestiny.avenir => 'regie.marque_avenir',
                    },
                    {'n': '${r.numero}', 't': horloge(r.secondes)},
                  ),
                  child: _Repere(key: ValueKey('repere_destiny_${r.numero}'), repere: r),
                ),
              ),
            // Le curseur : où en est le chrono.
            if (curseur)
              Positioned(
                left: x(ecouleSecondes) - 2,
                top: 2,
                width: 4,
                height: _hauteur - 4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: c.titre,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [BoxShadow(color: c.carte, blurRadius: 0, spreadRadius: 1.2)],
                  ),
                ),
              ),
          ]);
        }),
      ),
    );
  }
}

class _Repere extends StatelessWidget {
  const _Repere({super.key, required this.repere});

  final RepereDestiny repere;

  @override
  Widget build(BuildContext context) {
    final c = context.destiny;
    final bleu = c.bleuDestiny;
    final passe = repere.etat == EtatDestiny.passe;
    final prochain = repere.etat == EtatDestiny.prochain;
    final taille = prochain ? 32.0 : 26.0;
    return Center(
      child: Stack(clipBehavior: Clip.none, children: [
        Container(
          width: taille,
          height: taille,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: passe ? bleu : c.carte,
            border: Border.all(color: passe || prochain ? bleu : c.ligne, width: prochain ? 3 : 2),
            boxShadow: prochain ? [BoxShadow(color: bleu.withValues(alpha: 0.55), blurRadius: 10)] : null,
          ),
          child: Text(
            '${repere.numero}',
            style: TextStyle(
              fontFamily: kPoliceTexte,
              fontWeight: FontWeight.w800,
              fontSize: prochain ? 15 : 13,
              color: passe ? Colors.white : (prochain ? c.bleuTexte : c.texteSecondaire),
            ),
          ),
        ),
        if (passe)
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.carte,
                border: Border.all(color: bleu, width: 1.5),
              ),
              child: Icon(Icons.check_rounded, size: 10, color: c.bleuTexte),
            ),
          ),
      ]),
    );
  }
}

/// Le fil des étapes du spectacle : où on en est, et chaque étape à un appui,
/// la régie comprise, sans passer par les autres.
class FilEtapes extends StatelessWidget {
  const FilEtapes({
    super.key,
    required this.contexte,
    required this.session,
    required this.courante,
    this.peutAvancer = true,
  });

  final ContexteTroupe contexte;
  final SessionTroupe session;
  final EtapeSession courante;

  /// Faux tant que la distribution n'est pas jouable : les étapes suivantes
  /// attendent.
  final bool peutAvancer;

  static const List<(EtapeSession, IconData)> etapes = [
    (EtapeSession.preparation, Icons.style_rounded),
    (EtapeSession.echauffement, Icons.self_improvement_rounded),
    (EtapeSession.miseEnPlace, Icons.theater_comedy_rounded),
    (EtapeSession.regie, Icons.play_circle_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final t = context.textes;
    return Semantics(
      container: true,
      label: t.t('troupe.fil.titre'),
      child: Wrap(spacing: 6, runSpacing: 6, children: [
        for (final (etape, icone) in etapes)
          _EtapeFil(
            libelle: t.t('troupe.fil.${etape.name}'),
            icone: icone,
            courante: etape == courante,
            regie: etape == EtapeSession.regie,
            onTap: etape == courante || (!peutAvancer && etape.index > courante.index)
                ? null
                : () => allerAEtape(context, contexte, session, etape),
          ),
      ]),
    );
  }
}

class _EtapeFil extends StatelessWidget {
  const _EtapeFil({
    required this.libelle,
    required this.icone,
    required this.courante,
    required this.regie,
    required this.onTap,
  });

  final String libelle;
  final IconData icone;
  final bool courante;

  /// La régie se détache : c'est là que se joue le spectacle.
  final bool regie;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.destiny;
    final fond = courante ? c.or : (regie ? c.teinte(c.bleuDestiny) : c.carte);
    final bord = courante ? c.or : (regie ? c.bleuDestiny : c.ligne);
    final encre = courante ? c.surOr : (regie ? c.bleuTexte : c.texte);
    final forme = StadiumBorder(side: BorderSide(color: bord, width: regie && !courante ? 1.5 : 1));
    return Semantics(
      button: true,
      selected: courante,
      enabled: onTap != null || courante,
      child: Opacity(
        opacity: onTap == null && !courante ? 0.5 : 1,
        child: Material(
          color: fond,
          shape: forme,
          child: InkWell(
            customBorder: forme,
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(icone, size: 18, color: encre),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      libelle,
                      style: TextStyle(
                        fontFamily: kPoliceTexte,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        height: 1.2,
                        color: encre,
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

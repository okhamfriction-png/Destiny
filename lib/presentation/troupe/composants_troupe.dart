import 'package:flutter/gestures.dart';
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
    this.reactions = false,
    this.pied,
  });

  final PersonnageTroupe personnage;
  final ContexteTroupe contexte;

  /// À la régie : la montée à ce palier (voir [EnteteArchetype]).
  final PalierId? palier;

  /// À l'échauffement : ses quatre réactions au danger, une par palier.
  final bool reactions;

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
        if (reactions) Padding(padding: const EdgeInsets.only(top: 8), child: ReactionsArchetype(archetype: a)),
        if (pied != null) Padding(padding: const EdgeInsets.only(top: 8), child: pied),
      ]),
    );
  }
}

/// Les quatre réactions d'un archétype au danger, une par palier, numérotées
/// dans la couleur du palier.
class ReactionsArchetype extends StatelessWidget {
  const ReactionsArchetype({super.key, required this.archetype});

  final Archetype archetype;

  @override
  Widget build(BuildContext context) {
    final g = context.grammaire;
    final c = context.destiny;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final p in g.paliers)
        if (archetype.monteeA(p.id).isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Semantics(
              label: '${p.numero}. ${p.nom} : ${archetype.monteeA(p.id)}',
              excludeSemantics: true,
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SizedBox.square(
                  dimension: 22,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: c.teinte(c.palier(p.id)),
                      border: Border.all(color: c.palier(p.id), width: 1.5),
                    ),
                    child: Center(
                      child: MediaQuery.withNoTextScaling(
                        child: Text(
                          '${p.numero}',
                          style: TextStyle(
                            fontFamily: kPoliceTexte,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                            color: c.accent(c.palier(p.id)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      archetype.monteeA(p.id),
                      style: TextStyle(fontFamily: kPoliceTexte, fontSize: 14, height: 1.3, color: c.texte),
                    ),
                  ),
                ),
              ]),
            ),
          ),
    ]);
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
/// Destiny numérotés (ceux passés cochés, le prochain mis en avant), avec
/// leur heure en dessous : prévue, ou celle où ils ont été lancés. Avec
/// [deplacer], on fait glisser un Destiny pas encore lancé, à la minute près.
class FriseDestiny extends StatefulWidget {
  const FriseDestiny({
    super.key,
    required this.totalSecondes,
    required this.ecouleSecondes,
    required this.reperes,
    this.curseur = true,
    this.deplacer,
  });

  final int totalSecondes;
  final int ecouleSecondes;
  final List<RepereDestiny> reperes;

  /// Montrer où en est le chrono (pas pour un simple aperçu).
  final bool curseur;

  /// Place le Destiny d'index (0 à 2) à une minute ; rend faux si les règles
  /// le refusent (le repère s'arrête alors à la dernière place permise).
  final bool Function(int index, int minute)? deplacer;

  static const double _hauteur = 36;
  static const double _rayon = 16;

  /// La zone qu'on attrape autour d'un repère.
  static const double _prise = 44;

  /// La ligne des heures, sous les repères.
  static const double _hauteurHeures = 20;
  static const double _largeurHeure = 46;

  /// Où poser l'heure de chaque repère : centrée dessous, sans que deux
  /// heures se chevauchent ni sortent de la frise.
  static List<double> placerHeures(List<double> centres, double largeur) {
    const l = _largeurHeure;
    const ecart = 2.0;
    final gauches = [for (final cx in centres) (cx - l / 2).clamp(0.0, (largeur - l).clamp(0.0, double.infinity))];
    for (var i = 1; i < gauches.length; i++) {
      if (gauches[i] < gauches[i - 1] + l + ecart) gauches[i] = gauches[i - 1] + l + ecart;
    }
    final max = (largeur - l).clamp(0.0, double.infinity);
    if (gauches.isNotEmpty && gauches.last > max) {
      gauches[gauches.length - 1] = max;
      for (var i = gauches.length - 2; i >= 0; i--) {
        if (gauches[i] > gauches[i + 1] - l - ecart) gauches[i] = gauches[i + 1] - l - ecart;
      }
    }
    return [for (final g in gauches) g < 0 ? 0.0 : g];
  }

  @override
  State<FriseDestiny> createState() => _FriseDestinyState();
}

class _FriseDestinyState extends State<FriseDestiny> {
  /// Les repères sous le doigt quand le geste commence (deux s'ils sont
  /// collés), puis celui qu'on fait glisser.
  List<int> _candidats = const [];
  int? _saisi;

  int get _total => widget.totalSecondes <= 0 ? 1 : widget.totalSecondes;

  bool _mobile(RepereDestiny r) => widget.deplacer != null && r.etat != EtatDestiny.passe;

  double _x(int secondes, double largeur) =>
      FriseDestiny._rayon + (largeur - 2 * FriseDestiny._rayon) * (secondes / _total).clamp(0.0, 1.0);

  void _debut(Offset local, double largeur) {
    _candidats = [
      for (final (i, r) in widget.reperes.indexed)
        if (_mobile(r) && (_x(r.secondes, largeur) - local.dx).abs() <= FriseDestiny._prise / 2) i,
    ];
    _saisi = _candidats.length == 1 ? _candidats.single : null;
  }

  void _glisser(DragUpdateDetails d, double largeur) {
    if (_candidats.isEmpty) return;
    // Deux repères collés : vers la gauche, on prend celui de gauche ; vers
    // la droite, celui de droite (l'autre ne pourrait pas passer).
    _saisi ??= d.delta.dx < 0 ? _candidats.first : _candidats.last;
    final r = widget.reperes[_saisi!];
    final index = r.numero - 1;
    final minute = (r.secondes / 60).round();
    final part = ((d.localPosition.dx - FriseDestiny._rayon) / (largeur - 2 * FriseDestiny._rayon)).clamp(0.0, 1.0);
    final nouvelle = (part * _total / 60).round();
    // Refusé (trop près d'un autre Destiny, du chrono ou de la fin) : on
    // s'arrête à la minute permise la plus proche du doigt.
    final pas = nouvelle > minute ? -1 : 1;
    for (var m = nouvelle; m != minute; m += pas) {
      if (widget.deplacer!(index, m)) break;
    }
  }

  void _fin() {
    _candidats = const [];
    _saisi = null;
  }

  /// Un repère : son nom pour les lecteurs d'écran et, s'il peut bouger,
  /// « plus tard / plus tôt » au clavier ou au lecteur d'écran, et la main
  /// qui glisse à la souris.
  Widget _repere(RepereDestiny r) {
    final t = context.textes;
    final mobile = _mobile(r);
    final index = r.numero - 1;
    final minute = (r.secondes / 60).round();
    final repere = Semantics(
      excludeSemantics: true,
      label: t.t(
        switch (r.etat) {
          EtatDestiny.passe => 'regie.marque_passe',
          EtatDestiny.prochain => 'regie.marque_prochain',
          EtatDestiny.avenir => 'regie.marque_avenir',
        },
        {'n': '${r.numero}', 't': horloge(r.secondes)},
      ),
      hint: mobile ? t.t('regie.glisser') : null,
      onIncrease: mobile ? () => widget.deplacer!(index, minute + 1) : null,
      onDecrease: mobile ? () => widget.deplacer!(index, minute - 1) : null,
      child: _Repere(key: ValueKey('repere_destiny_${r.numero}'), repere: r),
    );
    return mobile ? MouseRegion(cursor: SystemMouseCursors.resizeLeftRight, child: repere) : repere;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.destiny;
    final reperes = widget.reperes;
    final avance = (widget.ecouleSecondes / _total).clamp(0.0, 1.0);
    const hauteur = FriseDestiny._hauteur;
    const rayon = FriseDestiny._rayon;
    const prise = FriseDestiny._prise;
    return MediaQuery.withNoTextScaling(
      child: SizedBox(
        height: hauteur + FriseDestiny._hauteurHeures,
        child: LayoutBuilder(builder: (context, contraintes) {
          final largeur = contraintes.maxWidth;
          double x(int secondes) => _x(secondes, largeur);
          final heures = FriseDestiny.placerHeures([for (final r in reperes) x(r.secondes)], largeur);
          final frise = Stack(clipBehavior: Clip.none, children: [
            // La barre, et ce qui est déjà joué.
            Positioned(
              left: rayon,
              right: rayon,
              top: hauteur / 2 - 3,
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
                left: x(r.secondes) - prise / 2,
                top: 0,
                width: prise,
                height: hauteur,
                child: _repere(r),
              ),
            // L'heure de chaque Destiny, sous son repère.
            for (final (i, r) in reperes.indexed)
              Positioned(
                left: heures[i],
                top: hauteur + 2,
                width: FriseDestiny._largeurHeure,
                child: ExcludeSemantics(
                  child: Text(
                    horloge(r.secondes),
                    key: ValueKey('heure_destiny_${r.numero}'),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    style: TextStyle(
                      fontFamily: kPoliceTexte,
                      fontWeight: r.etat == EtatDestiny.avenir ? FontWeight.w600 : FontWeight.w800,
                      fontSize: 12.5,
                      height: 1.2,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: r.etat == EtatDestiny.avenir ? c.texteSecondaire : c.bleuTexte,
                    ),
                  ),
                ),
              ),
            // Le curseur : où en est le chrono.
            if (widget.curseur)
              Positioned(
                left: x(widget.ecouleSecondes) - 2,
                top: 2,
                width: 4,
                height: hauteur - 4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: c.titre,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [BoxShadow(color: c.carte, blurRadius: 0, spreadRadius: 1.2)],
                  ),
                ),
              ),
          ]);
          if (widget.deplacer == null) return frise;
          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            dragStartBehavior: DragStartBehavior.down,
            onHorizontalDragStart: (d) => _debut(d.localPosition, largeur),
            onHorizontalDragUpdate: (d) => _glisser(d, largeur),
            onHorizontalDragEnd: (_) => _fin(),
            onHorizontalDragCancel: _fin,
            child: frise,
          );
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

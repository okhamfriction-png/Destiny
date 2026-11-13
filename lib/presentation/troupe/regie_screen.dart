import 'dart:async';

import 'package:flutter/material.dart';

import '../../application/son/conduite_son.dart';
import '../../application/son/regie_son.dart';
import '../../application/state/reglages_destiny.dart';
import '../../domain/entities/dilemma.dart';
import '../../domain/grammaire/modeles.dart';
import '../../domain/troupe/session.dart';
import '../destiny/composants.dart';
import '../destiny/donnees.dart';
import '../destiny/page.dart';
import '../regie_son/apparence_sons.dart';
import '../regie_son/table_regie.dart';
import '../theme/destiny_theme.dart';
import 'composants_troupe.dart';
import 'spectacle_en_cours.dart';
import 'troupe_screen.dart';

/// Pourquoi un Destiny ne peut pas aller à la minute demandée.
enum RefusDestiny { dejaLance, avantChrono, avantPrecedent, apresSuivant, apresFin }

/// Peut-on placer le Destiny [index] (0 à 2) à [minute] ? Il doit tomber
/// strictement après le chrono, après le Destiny précédent (s'il n'est pas
/// encore lancé), avant le suivant et avant la fin. Rend null si c'est bon.
RefusDestiny? refusDestiny(SceneJouee s, {required int index, required int minute, required int ecouleSecondes}) {
  if (index < s.destinys.length) return RefusDestiny.dejaLance;
  if (minute < 1 || minute * 60 <= ecouleSecondes) return RefusDestiny.avantChrono;
  if (index > s.destinys.length && minute <= s.destinyMinutes[index - 1]) return RefusDestiny.avantPrecedent;
  if (index + 1 < s.destinyMinutes.length && minute >= s.destinyMinutes[index + 1]) return RefusDestiny.apresSuivant;
  if (minute >= s.dureeMinutes) return RefusDestiny.apresFin;
  return null;
}

/// Le tableau de bord de la régie : le chrono toujours visible avec la frise
/// des trois Destiny, le bouton DESTINY (réservé à la régie), la régie son,
/// le lieu et le danger, les rappels, la montée de chacun et les notes. Rien
/// ne dépend du réseau.
class RegieScreen extends StatefulWidget {
  const RegieScreen({super.key, required this.contexte, required this.session, this.spectacle, this.enPopup = false});

  final ContexteTroupe contexte;
  final SessionTroupe session;

  /// Le spectacle en cours (le chrono), tenu par l'écran du jeu. Sans lui, la
  /// régie tient le sien.
  final SpectacleEnCours? spectacle;

  /// Ouverte en pop-up par-dessus le jeu : une grande croix la ferme.
  final bool enPopup;

  @override
  State<RegieScreen> createState() => _RegieScreenState();
}

class _RegieScreenState extends State<RegieScreen> {
  late final SpectacleEnCours _sp = widget.spectacle ??
      SpectacleEnCours.troupe(
        widget.contexte,
        widget.session,
        contexteRituel: () => mounted ? context : null,
      );
  List<Dilemma> _dilemmes = const [];

  SessionTroupe get s => widget.session;
  ReglagesDestiny get r => widget.contexte.reglages;
  PalierId get _palier => _sp.palier;
  ConduiteSon? get _conduite => _sp.conduite;
  bool get _conduiteActive => _sp.conduite?.active ?? false;

  @override
  void initState() {
    super.initState();
    _sp.addListener(_maj);
    widget.contexte.catalogue.getDilemmas().then((d) {
      if (!mounted) return;
      setState(() => _dilemmes = [
            for (final x in d)
              if (x.dangerLie == s.dangerId) x,
          ]);
    });
  }

  void _maj() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _sp.removeListener(_maj);
    // La régie ne tient le spectacle que si personne ne le lui a donné.
    if (widget.spectacle == null) _sp.dispose();
    super.dispose();
  }

  /// « Terminer » : plus de débrief. Le spectacle s'arrête, il est rangé dans
  /// l'historique, et on revient à l'accueil.
  Future<void> _terminer() async {
    final t = context.textes;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(t.t('regie.terminer_confirmer')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t.t('troupe.non'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(t.t('troupe.oui'))),
        ],
      ),
    );
    if (ok != true) return;
    await _sp.terminer();
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }

  /// Le panneau du chrono, toujours visible en haut : le temps qui reste, le
  /// temps écoulé, la frise des trois Destiny, le prochain, et DESTINY.
  Widget _panneauChrono(BuildContext context) {
    final g = context.grammaire;
    final t = context.textes;
    final c = context.destiny;
    String rg(String k, [Map<String, String> v = const {}]) => t.t('regie.$k', v);
    final palier = g.palier(_palier);
    final reste = _sp.total - _sp.ecoule;
    final prochain = _sp.prochain;
    final couleurReste = reste <= 0 ? Theme.of(context).colorScheme.error : c.titre;

    // Le panneau reste compact même avec un texte très agrandi : ses chiffres
    // et ses boutons sont déjà grands.
    final panneau = Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 14),
      decoration: decorCarte(c, rayon: 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(
                height: 62,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    horloge(reste),
                    key: const ValueKey('chrono_reste'),
                    style: TextStyle(
                      fontFamily: kPoliceTitres,
                      fontWeight: FontWeight.w900,
                      fontSize: 56,
                      height: 1.05,
                      color: couleurReste,
                    ),
                  ),
                ),
              ),
              // Le temps écoulé, puis l'acte : chacun d'un bloc s'il faut
              // passer à la ligne.
              Wrap(spacing: 10, children: [
                Text(
                  rg('ecoule', {'t': horloge(_sp.ecoule)}),
                  key: const ValueKey('chrono_ecoule'),
                  style: TextStyle(fontFamily: kPoliceTexte, fontSize: 13.5, height: 1.3, color: c.texteSecondaire),
                ),
                Text(
                  '${rg('acte', {'n': '${palier.acte}'})} — ${palier.nom}',
                  style: TextStyle(
                    fontFamily: kPoliceTexte,
                    fontSize: 13.5,
                    height: 1.3,
                    fontWeight: FontWeight.w700,
                    color: c.accent(c.palier(_palier)),
                  ),
                ),
              ]),
            ]),
          ),
          const SizedBox(width: 10),
          IconButton.filled(
            tooltip: _sp.enMarche ? rg('pause') : (_sp.demarre ? rg('reprendre') : rg('demarrer')),
            iconSize: 34,
            style: ButtonStyle(
              backgroundColor: WidgetStatePropertyAll(c.or),
              foregroundColor: WidgetStatePropertyAll(c.surOr),
              minimumSize: const WidgetStatePropertyAll(Size(60, 60)),
            ),
            icon: Icon(_sp.enMarche ? Icons.pause_rounded : Icons.play_arrow_rounded),
            onPressed: _sp.basculer,
          ),
        ]),
        const SizedBox(height: 12),
        FriseDestiny(
          totalSecondes: _sp.total,
          ecouleSecondes: _sp.ecoule,
          reperes: reperesDestiny(s),
          deplacer: _sp.placer,
        ),
        if (reste <= 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(rg('temps_ecoule'),
                style: TextStyle(fontFamily: kPoliceTexte, fontWeight: FontWeight.w700, color: couleurReste)),
          ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: Semantics(
              hint: prochain == null ? null : rg('destiny_aide'),
              child: FilledButton.icon(
                key: const ValueKey('bouton_destiny'),
                style: FilledButton.styleFrom(
                  backgroundColor: c.bleuDestiny,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(48, 58),
                  textStyle: const TextStyle(fontFamily: kPoliceTitres, fontWeight: FontWeight.w900, fontSize: 21),
                ),
                onPressed: prochain == null || _sp.rituelEnCours ? null : () => _sp.destiny(manuel: true),
                icon: const Icon(Icons.flash_on_rounded),
                label: Text(
                  prochain == null
                      ? rg('destiny').toUpperCase()
                      : rg('destiny_n', {'n': '${prochain + 1}'}).toUpperCase(),
                ),
              ),
            ),
          ),
          // Le bruitage du palier, à la main (conduite du spectacle).
          if (_conduiteActive) ...[
            const SizedBox(width: 10),
            _BoutonDanger(conduite: _conduite!, libelle: t.t('regie_son.danger')),
          ],
          // La régie son, sauf si on l'a retirée dans les réglages.
          if (r.regieSon) ...[
            const SizedBox(width: 10),
            BoutonRegieSon(contexte: widget.contexte, session: s, compact: true, pilote: piloteDe(context, _sp)),
          ],
        ]),
        if (_conduiteActive) _EtatConduite(conduite: _conduite!),
      ]),
    );
    return MediaQuery.withClampedTextScaling(maxScaleFactor: 1.3, child: panneau);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.textes;
    final c = context.destiny;
    String rg(String k, [Map<String, String> v = const {}]) => t.t('regie.$k', v);
    // Assez de hauteur : le chrono reste fixé en haut. Sinon (téléphone à
    // l'horizontale), il défile avec le reste.
    final collant = MediaQuery.sizeOf(context).height >= 600;
    final panneau = _panneauChrono(context);

    return PageDestiny(
      titre: rg('titre'),
      fermer: widget.enPopup ? () => Navigator.of(context).pop() : null,
      libelleFermer: rg('fermer'),
      entete: collant ? panneau : null,
      enfants: [
        if (!collant) panneau,
        // Trois cadres, pour lire d'un coup d'œil : le lieu et le danger, les
        // paliers du danger, puis les archétypes.
        _Cadre(titre: rg('scene'), enfants: [LieuEtDanger.troupe(contexte: widget.contexte, session: s)]),
        _Cadre(titre: rg('paliers'), enfants: [FrisePaliers(textes: s.paliers, courant: _palier)]),
        _Cadre(titre: rg('archetypes'), enfants: [
          for (final p in s.personnages) RectangleArchetype(personnage: p, contexte: widget.contexte, palier: _palier, kids: s.kids),
        ]),
        if (_palier == PalierId.supprime && _dilemmes.isNotEmpty)
          SectionDestiny(titre: rg('dilemme'), enfants: [
            Paragraphe(rg('dilemme_aide'), italique: true),
            for (final d in _dilemmes.take(2))
              CadreLisere(
                couleur: c.or,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(d.nom, style: Theme.of(context).textTheme.titleMedium),
                  Paragraphe(d.situation),
                  Puce(d.choixA),
                  Puce(d.choixB),
                ]),
              ),
          ]),
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: _terminer,
          icon: const Icon(Icons.flag_rounded),
          label: Text(rg('terminer')),
        ),
      ],
    );
  }
}

/// La régie son : la table de régie (conduite du spectacle, tranches,
/// banques de sons par catégorie). Elle respecte le son coupé. Elle s'ouvre
/// en plein écran ([ouvrirRegieSon]).
class TabletteSon extends StatelessWidget {
  const TabletteSon({super.key, required this.contexte, required this.session});

  final SourcesSon contexte;
  final SceneJouee session;

  @override
  Widget build(BuildContext context) => TableRegie(contexte: contexte, session: session);
}

/// Ouvre la table de régie en plein écran, par-dessus la régie : on la ferme
/// avec la croix. Le chrono continue pendant ce temps.
Future<void> ouvrirRegieSon(BuildContext context, SourcesSon contexte, SceneJouee session,
        {PiloteSpectacle? pilote}) =>
    ouvrirTableRegie(context, contexte, session,
        contenu: TabletteSon(contexte: contexte, session: session), pilote: pilote);

/// Le bouton « Danger » du panneau du chrono : rejoue le bruitage du palier
/// en cours, musique atténuée.
class _BoutonDanger extends StatelessWidget {
  const _BoutonDanger({required this.conduite, required this.libelle});

  final ConduiteSon conduite;
  final String libelle;

  @override
  Widget build(BuildContext context) {
    final c = context.destiny;
    const couleur = Color(0xFFFF7043);
    return Tooltip(
      message: libelle,
      child: SizedBox(
        width: 64,
        height: 58,
        child: OutlinedButton(
          key: const ValueKey('bouton_danger'),
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            side: const BorderSide(color: couleur, width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onPressed: conduite.danger,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.warning_rounded, size: 24, color: c.accent(couleur)),
            Text(
              libelle,
              style: TextStyle(fontFamily: kPoliceTexte, fontWeight: FontWeight.w700, fontSize: 12, color: c.accent(couleur)),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Une ligne sous DESTINY : ce que fait la conduite son en ce moment.
class _EtatConduite extends StatelessWidget {
  const _EtatConduite({required this.conduite});

  final ConduiteSon conduite;

  @override
  Widget build(BuildContext context) {
    final c = context.destiny;
    final t = context.textes;
    return ListenableBuilder(
      listenable: conduite,
      builder: (context, _) {
        final musique = conduite.lecteurs[BusSon.musique]!.enCours;
        final etape = conduite.etape;
        final texte = etape != EtapeConduite.repos
            ? t.t('regie_son.etapes.${etape.name}')
            : (musique?.titre ?? t.t('regie_son.au_repos'));
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(children: [
            Icon(etape != EtapeConduite.repos ? Icons.auto_mode_rounded : Icons.graphic_eq_rounded,
                size: 16, color: etape != EtapeConduite.repos ? Console.or : c.texteSecondaire),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                texte,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: kPoliceTexte, fontSize: 13, color: c.texteSecondaire),
              ),
            ),
            if (conduite.attenue)
              Text(t.t('regie_son.attenuee'),
                  style: TextStyle(fontFamily: kPoliceTexte, fontSize: 12, fontWeight: FontWeight.w700, color: c.titre)),
          ]),
        );
      },
    );
  }
}

/// Le bouton de la régie son : il ouvre toute la tablette son dans une
/// fenêtre ([ouvrirRegieSon]), et dit ce qui joue.
class BoutonRegieSon extends StatelessWidget {
  const BoutonRegieSon({super.key, required this.contexte, required this.session, this.compact = false, this.pilote});

  final ContexteTroupe contexte;
  final SessionTroupe session;

  /// Le chrono et DESTINY, repris en haut de la table de régie.
  final PiloteSpectacle? pilote;

  /// Un bouton carré, à côté de DESTINY dans le panneau du chrono.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = context.textes;
    final c = context.destiny;
    String rg(String k, [Map<String, String> v = const {}]) => t.t('regie.$k', v);
    void ouvrir() => ouvrirRegieSon(context, contexte, session, pilote: pilote);
    final bord = BorderSide(color: c.or, width: 1.5);
    if (compact) {
      return Tooltip(
        message: rg('son_ouvrir'),
        child: SizedBox(
          width: 64,
          height: 58,
          child: OutlinedButton(
            key: const ValueKey('bouton_regie_son'),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              side: bord,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: ouvrir,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.graphic_eq_rounded, size: 24, color: c.titre),
              Text(
                rg('son_court'),
                style: TextStyle(fontFamily: kPoliceTexte, fontWeight: FontWeight.w700, fontSize: 12, color: c.titre),
              ),
            ]),
          ),
        ),
      );
    }
    return ListenableBuilder(
      listenable: contexte.musique,
      builder: (context, _) {
        final musique = contexte.musique;
        final enCours = musique.playing ? musique.current : null;
        return OutlinedButton.icon(
          key: const ValueKey('bouton_regie_son'),
          style: OutlinedButton.styleFrom(
            side: bord,
            minimumSize: const Size(48, 56),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          onPressed: ouvrir,
          icon: Icon(Icons.graphic_eq_rounded, color: c.titre),
          label: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(rg('son_ouvrir')),
            if (enCours != null)
              Text(
                rg('son_en_cours', {'titre': enCours.title}),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontFamily: kPoliceTexte, fontWeight: FontWeight.w500, fontSize: 13, color: c.texteSecondaire),
              ),
          ]),
        );
      },
    );
  }
}

/// Un cadre de la régie : un titre de section et son contenu, dans une
/// carte, pour regrouper ce qui va ensemble.
class _Cadre extends StatelessWidget {
  const _Cadre({required this.titre, required this.enfants});

  final String titre;
  final List<Widget> enfants;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 18),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        decoration: decorCarte(context.destiny, rayon: 18),
        child: SectionDestiny(titre: titre, espace: 0, enfants: enfants),
      );
}

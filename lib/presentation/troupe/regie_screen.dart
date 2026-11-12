import 'dart:async';

import 'package:flutter/material.dart';

import '../../application/son/conduite_son.dart';
import '../../application/state/reglages_destiny.dart';
import '../../domain/entities/dilemma.dart';
import '../../domain/grammaire/modeles.dart';
import '../../domain/grammaire/progression.dart';
import '../../domain/troupe/session.dart';
import '../destiny/composants.dart';
import '../destiny/donnees.dart';
import '../destiny/page.dart';
import '../destiny/rituel_destiny.dart';
import '../regie_son/apparence_sons.dart';
import '../regie_son/table_regie.dart';
import '../theme/destiny_theme.dart';
import 'composants_troupe.dart';
import 'troupe_screen.dart';

/// Pourquoi un Destiny ne peut pas aller à la minute demandée.
enum RefusDestiny { dejaLance, avantChrono, avantPrecedent, apresSuivant, apresFin }

/// Peut-on placer le Destiny [index] (0 à 2) à [minute] ? Il doit tomber
/// strictement après le chrono, après le Destiny précédent (s'il n'est pas
/// encore lancé), avant le suivant et avant la fin. Rend null si c'est bon.
RefusDestiny? refusDestiny(SessionTroupe s, {required int index, required int minute, required int ecouleSecondes}) {
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
  const RegieScreen({super.key, required this.contexte, required this.session});

  final ContexteTroupe contexte;
  final SessionTroupe session;

  @override
  State<RegieScreen> createState() => _RegieScreenState();
}

class _RegieScreenState extends State<RegieScreen> {
  Timer? _minuteur;
  int _ecoule = 0;
  bool _demarre = false;
  bool _rituelEnCours = false;
  final List<Timer> _musiques = [];
  final TextEditingController _note = TextEditingController();
  List<Dilemma> _dilemmes = const [];

  SessionTroupe get s => widget.session;
  ReglagesDestiny get r => widget.contexte.reglages;
  PalierId get _palier => PalierId.deNumero(s.palierAtteint);
  bool get _enMarche => _minuteur?.isActive ?? false;
  int get _total => s.dureeMinutes * 60;

  /// La conduite son automatique du spectacle (pack audio importé et actif).
  ConduiteSon? get _conduite => widget.contexte.regieSon?.conduite;
  bool get _conduiteActive => _conduite?.active ?? false;

  /// L'index (0 à 2) du prochain Destiny, ou null s'ils sont tous passés.
  int? get _prochain =>
      s.destinys.length < s.destinyMinutes.length && _palier != PalierId.supprime ? s.destinys.length : null;

  @override
  void initState() {
    super.initState();
    if (s.destinys.isNotEmpty) _ecoule = s.destinys.last.secondes;
    _conduite?.preparer(lieuId: s.lieuId, dangerId: s.dangerId, acte: s.palierAtteint);
    widget.contexte.catalogue.getDilemmas().then((d) {
      if (!mounted) return;
      setState(() => _dilemmes = [
            for (final x in d)
              if (x.dangerLie == s.dangerId) x,
          ]);
    });
  }

  @override
  void dispose() {
    _minuteur?.cancel();
    for (final t in _musiques) {
      t.cancel();
    }
    // En quittant la régie, plus rien ne joue : ni séquence, ni son orphelin.
    final conduite = _conduite;
    if (conduite != null) unawaited(conduite.stopTout());
    _note.dispose();
    super.dispose();
  }

  void _basculer() {
    if (_enMarche) {
      _minuteur?.cancel();
      // Une séquence Destiny en cours s'arrête net avec le chrono.
      if (_conduiteActive) unawaited(_conduite!.annulerSequence());
      setState(() {});
      return;
    }
    if (!_demarre) {
      _demarre = true;
      if (_conduiteActive) {
        // Conduite du spectacle : le son Destiny puis la musique de l'acte 1 ;
        // une régie reprise en cours de spectacle repart sur son acte.
        if (s.destinys.isEmpty) {
          unawaited(_conduite!.ouverture());
        } else {
          unawaited(_conduite!.musiqueActe(s.palierAtteint));
        }
      } else if (!widget.contexte.audio.muted && r.musiqueActe(1) != ChoixMusique.aucune) {
        _conduite?.arreterBus(BusSon.musique);
        widget.contexte.musique.jouerChoix(r.musiqueActe(1), lieu: s.lieuNom);
      }
    }
    _minuteur = Timer.periodic(const Duration(seconds: 1), (_) => _seconde());
    setState(() {});
  }

  void _seconde() {
    if (!mounted) return;
    setState(() => _ecoule++);
    if (_ecoule == _total) {
      widget.contexte.audio.playCrack();
      // Pas de coupure automatique (l'impro peut déborder), sauf si on la veut.
      final regie = widget.contexte.regieSon;
      if (_conduiteActive && regie != null) {
        if (regie.reglages.v.conclusionFinChrono) {
          unawaited(_conduite!.conclusion());
        } else if (regie.reglages.v.coupureFinChrono) {
          unawaited(_conduite!.fonduFin());
        }
      }
    }
    if (_ecoule == _total - 10) widget.contexte.audio.playThunder();
    final auto = r.declenchement != Declenchement.manuel;
    final prochain = _prochain;
    if (auto && !_rituelEnCours && prochain != null && _ecoule >= s.destinyMinutes[prochain] * 60) {
      _destiny(manuel: false);
    }
  }

  /// Lance le prochain Destiny : à la main (le bouton, quel que soit le
  /// réglage du déclenchement) ou par le chrono.
  Future<void> _destiny({required bool manuel}) async {
    if (_rituelEnCours || _prochain == null) return;
    _rituelEnCours = true;
    final premier = s.destinys.isEmpty;
    final nouveau = PalierId.values[_palier.index + 1];
    s.destinys.add(EvenementDestiny(numero: s.destinys.length + 1, secondes: _ecoule, manuel: manuel));
    s.palierAtteint = nouveau.numero;
    await widget.contexte.store.enregistrer(s);
    _programmerMusiques(s.destinys.length);
    if (!mounted) return;
    setState(() {});
    final nouvelle = s.paliers.length > nouveau.index ? s.paliers[nouveau.index] : null;
    await lancerRituelDestiny(
      context,
      nouveauPalier: nouveau,
      nouvelle: nouvelle,
      premierFige: premier,
      reglages: ReglagesRituel(
        lumiereBleue: r.lumiereBleue,
        dureeFige: Duration(seconds: r.dureeFigeSecondes),
        texteEllipse: r.texteEllipse.isEmpty ? null : r.texteEllipse,
        reduireAnimations: r.reduireAnimations,
        rappelPremierFige: r.rappelPremierFige,
      ),
      auTonnerre: () {
        if (widget.contexte.audio.muted) return;
        if (_conduiteActive) {
          // La conduite enchaîne tout : sortie de la musique, son Destiny,
          // REVEAL, bruitage du nouveau palier, musique de l'acte.
          unawaited(_conduite!.destiny(s.destinys.length));
          return;
        }
        widget.contexte.audio.playEffet(r.sonDestiny);
        widget.contexte.musique.jouerDestiny(r.musiqueDestiny);
      },
    );
    _rituelEnCours = false;
    if (mounted) setState(() {});
  }

  /// La musique de l'acte qui commence, 15 s après le Destiny [numero] (celle
  /// des réglages : l'acte 2 après le 1er Destiny, et ainsi de suite).
  void _programmerMusiques(int numero) {
    if (widget.contexte.audio.muted || _conduiteActive) return;
    final choix = r.musiqueActe(numero + 1);
    if (choix == ChoixMusique.aucune) return;
    _musiques.add(Timer(const Duration(seconds: 15), () {
      if (!mounted) return;
      _conduite?.arreterBus(BusSon.musique);
      widget.contexte.musique.jouerChoix(choix, lieu: s.lieuNom);
    }));
  }

  /// Place le Destiny [index] à [minute], au doigt sur la frise. Rend faux
  /// si les règles le refusent.
  bool _placer(int index, int minute) {
    if (refusDestiny(s, index: index, minute: minute, ecouleSecondes: _ecoule) != null) return false;
    setState(() => s.destinyMinutes = [...s.destinyMinutes]..[index] = minute);
    widget.contexte.store.enregistrer(s);
    return true;
  }

  Future<void> _noter() async {
    final texte = _note.text.trim();
    if (texte.isEmpty) return;
    setState(() {
      s.notes.add(NoteRegie(secondes: _ecoule, texte: texte));
      _note.clear();
    });
    await widget.contexte.store.enregistrer(s);
  }

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
    _minuteur?.cancel();
    s.etape = EtapeSession.debrief;
    await widget.contexte.store.enregistrer(s);
    if (mounted) ouvrirEtape(context, widget.contexte, s, remplacer: true);
  }

  /// Le panneau du chrono, toujours visible en haut : le temps qui reste, le
  /// temps écoulé, la frise des trois Destiny, le prochain, et DESTINY.
  Widget _panneauChrono(BuildContext context) {
    final g = context.grammaire;
    final t = context.textes;
    final c = context.destiny;
    String rg(String k, [Map<String, String> v = const {}]) => t.t('regie.$k', v);
    final palier = g.palier(_palier);
    final reste = _total - _ecoule;
    final prochain = _prochain;
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
                  rg('ecoule', {'t': horloge(_ecoule)}),
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
            tooltip: _enMarche ? rg('pause') : (_demarre ? rg('reprendre') : rg('demarrer')),
            iconSize: 34,
            style: ButtonStyle(
              backgroundColor: WidgetStatePropertyAll(c.or),
              foregroundColor: WidgetStatePropertyAll(c.surOr),
              minimumSize: const WidgetStatePropertyAll(Size(60, 60)),
            ),
            icon: Icon(_enMarche ? Icons.pause_rounded : Icons.play_arrow_rounded),
            onPressed: _basculer,
          ),
        ]),
        const SizedBox(height: 12),
        FriseDestiny(
          totalSecondes: _total,
          ecouleSecondes: _ecoule,
          reperes: reperesDestiny(s),
          deplacer: _placer,
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
                onPressed: prochain == null || _rituelEnCours ? null : () => _destiny(manuel: true),
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
            BoutonRegieSon(contexte: widget.contexte, session: s, compact: true),
          ],
        ]),
        if (_conduiteActive) _EtatConduite(conduite: _conduite!),
      ]),
    );
    return MediaQuery.withClampedTextScaling(maxScaleFactor: 1.3, child: panneau);
  }

  @override
  Widget build(BuildContext context) {
    final g = context.grammaire;
    final t = context.textes;
    final c = context.destiny;
    String rg(String k, [Map<String, String> v = const {}]) => t.t('regie.$k', v);
    final palier = g.palier(_palier);
    final acte = g.actes.firstWhere((a) => a.palier == _palier);
    final geste = gestePourActe(g, palier.acte);
    // Assez de hauteur : le chrono reste fixé en haut. Sinon (téléphone à
    // l'horizontale), il défile avec le reste.
    final collant = MediaQuery.sizeOf(context).height >= 600;
    final panneau = _panneauChrono(context);

    return PageDestiny(
      titre: rg('titre'),
      entete: collant ? panneau : null,
      enfants: [
        if (!collant) panneau,
        SectionDestiny(titre: rg('scene'), enfants: [
          LieuEtDanger(contexte: widget.contexte, session: s),
          LigneInfo(t.t('mise_en_place.groupe'), s.groupe),
          FrisePaliers(textes: s.paliers, courant: _palier),
        ]),
        if (r.rappelsRegie)
          SectionDestiny(titre: rg('rappel'), enfants: [
            if (geste != null) LigneInfo(geste.verbe, geste.consigne),
            for (final consigne in acte.consignes) Puce(consigne),
          ]),
        SectionDestiny(titre: rg('montee'), enfants: [
          for (final p in s.personnages) RectangleArchetype(personnage: p, contexte: widget.contexte, palier: _palier),
        ]),
        SectionDestiny(titre: rg('mystere'), enfants: [
          LigneInfo(t.t('mise_en_place.mystere'), s.mystere),
          LigneInfo(t.t('mise_en_place.reponse'), s.reponseMystere, italique: true),
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
        SectionDestiny(titre: rg('notes'), enfants: [
          Row(children: [
            Expanded(
              child: TextField(
                controller: _note,
                decoration: InputDecoration(hintText: rg('note_aide'), isDense: true),
                onSubmitted: (_) => _noter(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(onPressed: _noter, child: Text(rg('noter'))),
          ]),
          const SizedBox(height: 8),
          for (final n in s.notes.reversed) LigneInfo(n.horodatage, n.texte),
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

  final ContexteTroupe contexte;
  final SessionTroupe session;

  @override
  Widget build(BuildContext context) => TableRegie(contexte: contexte, session: session);
}

/// Ouvre la table de régie en plein écran, par-dessus la régie : on la ferme
/// avec la croix. Le chrono continue pendant ce temps.
Future<void> ouvrirRegieSon(BuildContext context, ContexteTroupe contexte, SessionTroupe session) =>
    ouvrirTableRegie(context, contexte, session, contenu: TabletteSon(contexte: contexte, session: session));

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
  const BoutonRegieSon({super.key, required this.contexte, required this.session, this.compact = false});

  final ContexteTroupe contexte;
  final SessionTroupe session;

  /// Un bouton carré, à côté de DESTINY dans le panneau du chrono.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final t = context.textes;
    final c = context.destiny;
    String rg(String k, [Map<String, String> v = const {}]) => t.t('regie.$k', v);
    void ouvrir() => ouvrirRegieSon(context, contexte, session);
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

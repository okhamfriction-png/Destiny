import 'dart:async';

import 'package:flutter/material.dart';

import '../../application/services/audio_service.dart';
import '../../application/state/music_controller.dart';
import '../../application/state/reglages_destiny.dart';
import '../../domain/entities/dilemma.dart';
import '../../domain/grammaire/modeles.dart';
import '../../domain/grammaire/progression.dart';
import '../../domain/troupe/session.dart';
import '../destiny/composants.dart';
import '../destiny/donnees.dart';
import '../destiny/page.dart';
import '../destiny/rituel_destiny.dart';
import '../theme/destiny_theme.dart';
import '../widgets/sound_mixer_sheet.dart';
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

  /// L'index (0 à 2) du prochain Destiny, ou null s'ils sont tous passés.
  int? get _prochain =>
      s.destinys.length < s.destinyMinutes.length && _palier != PalierId.supprime ? s.destinys.length : null;

  @override
  void initState() {
    super.initState();
    if (s.destinys.isNotEmpty) _ecoule = s.destinys.last.secondes;
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
    _note.dispose();
    super.dispose();
  }

  void _basculer() {
    if (_enMarche) {
      _minuteur?.cancel();
      setState(() {});
      return;
    }
    if (!_demarre) {
      _demarre = true;
      if (!widget.contexte.audio.muted && r.musiqueActe(1) != ChoixMusique.aucune) {
        widget.contexte.musique.jouerChoix(r.musiqueActe(1), lieu: s.lieuNom);
      }
    }
    _minuteur = Timer.periodic(const Duration(seconds: 1), (_) => _seconde());
    setState(() {});
  }

  void _seconde() {
    if (!mounted) return;
    setState(() => _ecoule++);
    if (_ecoule == _total) widget.contexte.audio.playCrack();
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
    if (widget.contexte.audio.muted) return;
    final choix = r.musiqueActe(numero + 1);
    if (choix == ChoixMusique.aucune) return;
    _musiques.add(Timer(const Duration(seconds: 15), () {
      if (mounted) widget.contexte.musique.jouerChoix(choix, lieu: s.lieuNom);
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
          // La régie son, sauf si on l'a retirée dans les réglages.
          if (r.regieSon) ...[
            const SizedBox(width: 10),
            BoutonRegieSon(contexte: widget.contexte, session: s, compact: true),
          ],
        ]),
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

/// La régie son, en tablette : de grandes tuiles pour les musiques du
/// spectacle, le son de Destiny et Stop, plus tout le mixeur. Elle respecte
/// le son coupé. Elle s'ouvre dans une fenêtre ([ouvrirRegieSon]).
class TabletteSon extends StatefulWidget {
  const TabletteSon({super.key, required this.contexte, required this.session});

  final ContexteTroupe contexte;
  final SessionTroupe session;

  @override
  State<TabletteSon> createState() => _TabletteSonState();
}

class _TabletteSonState extends State<TabletteSon> {
  MusicController get _musique => widget.contexte.musique;
  AudioService get _audio => widget.contexte.audio;
  ReglagesDestiny get _r => widget.contexte.reglages;
  String get _lieu => widget.session.lieuNom;

  /// Un choix « aucune » devient la musique par défaut : si on appuie,
  /// c'est qu'on veut l'entendre.
  String _ou(String choix, String defaut) => choix.isEmpty || choix == ChoixMusique.aucune ? defaut : choix;

  /// Le fichier que ferait jouer ce choix (pour allumer la tuile qui joue).
  String? _fichier(String choix) {
    if (choix != ChoixMusique.lieu) return choix;
    final nom = _lieu.trim().toLowerCase();
    for (final piste in _musique.tracks) {
      if (piste.category == 'Lieux' && piste.title.trim().toLowerCase() == nom) return piste.file;
    }
    return null;
  }

  void _jouer(String choix) {
    if (_audio.muted) return;
    _musique.jouerChoix(choix, lieu: _lieu);
  }

  void _sonDestiny() {
    if (_audio.muted) return;
    _audio.playEffet(_r.sonDestiny == 'aucun' ? 'storm' : _r.sonDestiny);
  }

  void _stop() {
    _musique.stop();
    _audio.stopStorm();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.textes;
    final c = context.destiny;
    String rg(String k, [Map<String, String> v = const {}]) => t.t('regie.$k', v);
    final muet = _audio.muted;
    // La musique de chaque acte (celle des réglages, ou à défaut le début,
    // l'ambiance du lieu, puis la fin), et l'ambiance du lieu.
    const icones = [Icons.looks_one_rounded, Icons.looks_two_rounded, Icons.looks_3_rounded, Icons.looks_4_rounded];
    const defauts = [ChoixMusique.commencement, ChoixMusique.lieu, ChoixMusique.lieu, ChoixMusique.conclusion];
    final musiques = [
      for (var acte = 1; acte <= 4; acte++)
        (icones[acte - 1], rg('son_acte', {'n': '$acte'}), _ou(_r.musiqueActe(acte), defauts[acte - 1])),
      (Icons.place_rounded, rg('son_lieu'), ChoixMusique.lieu),
    ];

    return ListenableBuilder(
      listenable: _musique,
      builder: (context, _) {
        final enCours = _musique.playing ? _musique.current : null;
        final enfants = <Widget>[
          if (muet)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, children: [
                Icon(Icons.volume_off_rounded, color: c.texteSecondaire),
                Text(rg('son_coupe'), style: TextStyle(fontFamily: kPoliceTexte, color: c.texteSecondaire)),
                TextButton(
                  onPressed: () => setState(() => _audio.setMuted(false)),
                  child: Text(rg('son_remettre')),
                ),
              ]),
            ),
          LayoutBuilder(builder: (context, contraintes) {
            final colonnes = contraintes.maxWidth >= 560 ? 3 : 2;
            // Texte très agrandi : l'icône passe au-dessus du libellé, pour
            // ne pas couper les mots.
            final empilee = MediaQuery.textScalerOf(context).scale(10) > 12.5;
            final tuiles = [
              for (final (icone, libelle, choix) in musiques)
                _TuileSon(
                  icone: icone,
                  libelle: libelle,
                  couleur: c.or,
                  empilee: empilee,
                  actif: enCours != null && enCours.file == _fichier(choix),
                  onTap: muet ? null : () => _jouer(choix),
                ),
              _TuileSon(
                icone: Icons.flash_on_rounded,
                libelle: rg('son_destiny'),
                couleur: c.bleuDestiny,
                empilee: empilee,
                onTap: muet ? null : _sonDestiny,
              ),
              _TuileSon(
                icone: Icons.stop_rounded,
                libelle: rg('son_stop'),
                couleur: Theme.of(context).colorScheme.error,
                empilee: empilee,
                onTap: _stop,
              ),
            ];
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              // Des rangées de tuiles de même hauteur.
              for (var i = 0; i < tuiles.length; i += colonnes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: IntrinsicHeight(
                    child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      for (var j = i; j < i + colonnes; j++) ...[
                        if (j > i) const SizedBox(width: 10),
                        Expanded(child: j < tuiles.length ? tuiles[j] : const SizedBox.shrink()),
                      ],
                    ]),
                  ),
                ),
              _TuileSon(
                icone: Icons.graphic_eq_rounded,
                libelle: rg('son_mixeur'),
                couleur: c.titre,
                compacte: true,
                onTap: () => showSoundMixer(context, _musique),
              ),
            ]);
          }),
          if (enCours != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(children: [
                Icon(Icons.graphic_eq_rounded, size: 18, color: c.titre),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    rg('son_en_cours', {'titre': enCours.title}),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: kPoliceTexte, fontSize: 14, color: c.texteSecondaire),
                  ),
                ),
              ]),
            ),
        ];
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: enfants);
      },
    );
  }
}

/// Ouvre la régie son dans une fenêtre, par-dessus l'écran : on la ferme
/// avec la croix, en la glissant vers le bas ou en touchant à côté. Le chrono
/// continue pendant ce temps.
Future<void> ouvrirRegieSon(BuildContext context, ContexteTroupe contexte, SessionTroupe session) {
  final t = context.textes;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (ctx) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text(t.t('regie.son'), style: Theme.of(ctx).textTheme.titleLarge)),
          IconButton(
            key: const ValueKey('fermer_regie_son'),
            tooltip: t.t('regie.son_fermer'),
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.pop(ctx),
          ),
        ]),
        const SizedBox(height: 8),
        TabletteSon(contexte: contexte, session: session),
      ]),
    ),
  );
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

/// Une grande tuile de la régie son.
class _TuileSon extends StatelessWidget {
  const _TuileSon({
    required this.icone,
    required this.libelle,
    required this.couleur,
    required this.onTap,
    this.actif = false,
    this.compacte = false,
    this.empilee = false,
  });

  final IconData icone;
  final String libelle;
  final Color couleur;
  final VoidCallback? onTap;
  final bool actif;

  /// Une tuile basse, centrée (« Tout le mixeur »).
  final bool compacte;

  /// L'icône au-dessus du libellé (texte très agrandi).
  final bool empilee;

  @override
  Widget build(BuildContext context) {
    final c = context.destiny;
    final pastille = PastilleIcone(icone, couleur: couleur, taille: compacte ? 32 : 38);
    final temoin = Icon(Icons.volume_up_rounded, size: 18, color: c.accent(couleur));
    final texte = Text(
      libelle,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: kPoliceTexte,
        fontWeight: FontWeight.w700,
        fontSize: 14.5,
        height: 1.2,
        color: c.texte,
      ),
    );
    return Semantics(
      button: true,
      selected: actif,
      enabled: onTap != null,
      child: Opacity(
        opacity: onTap == null ? 0.5 : 1,
        child: Material(
          color: actif ? c.teinte(couleur) : c.carte,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: actif ? couleur : c.ligne, width: actif ? 2 : 1),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: compacte ? 52 : 68),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: empilee
                    ? Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        Row(children: [
                          pastille,
                          const Spacer(),
                          if (actif) temoin,
                        ]),
                        const SizedBox(height: 6),
                        texte,
                      ])
                    : Row(
                        mainAxisAlignment: compacte ? MainAxisAlignment.center : MainAxisAlignment.start,
                        children: [
                          pastille,
                          const SizedBox(width: 10),
                          Flexible(fit: compacte ? FlexFit.loose : FlexFit.tight, child: texte),
                          if (actif) ...[const SizedBox(width: 6), temoin],
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

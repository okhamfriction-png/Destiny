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
      if (!widget.contexte.audio.muted) {
        widget.contexte.musique.jouerChoix(r.musiqueDebut, lieu: s.lieuNom);
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

  /// L'ambiance du 2ᵉ Destiny et la musique de fin du 3ᵉ, 15 s après.
  void _programmerMusiques(int numero) {
    if (widget.contexte.audio.muted) return;
    final choix = switch (numero) {
      2 => r.ambianceActe2,
      3 => r.musiqueFin,
      _ => null,
    };
    if (choix == null) return;
    _musiques.add(Timer(const Duration(seconds: 15), () {
      if (mounted) widget.contexte.musique.jouerChoix(choix, lieu: s.lieuNom);
    }));
  }

  /// Avance ou recule le Destiny [index] de [delta] minutes. Rend le message
  /// du refus si c'est impossible.
  String? _deplacer(int index, int delta) {
    final minute = s.destinyMinutes[index] + delta;
    final refus = refusDestiny(s, index: index, minute: minute, ecouleSecondes: _ecoule);
    if (refus != null) return _messageRefus(refus, index);
    setState(() => s.destinyMinutes = [...s.destinyMinutes]..[index] = minute);
    widget.contexte.store.enregistrer(s);
    return null;
  }

  String _messageRefus(RefusDestiny refus, int index) {
    final t = context.textes;
    final n = '${index + 1}';
    return switch (refus) {
      RefusDestiny.dejaLance => t.t('regie.lance_a', {'t': horloge(s.destinys[index].secondes)}),
      RefusDestiny.avantChrono => t.t('regie.refus_chrono', {'t': horloge(_ecoule)}),
      RefusDestiny.avantPrecedent => t.t('regie.refus_precedent', {'n': n, 'm': '$index'}),
      RefusDestiny.apresSuivant => t.t('regie.refus_suivant', {'n': n, 'm': '${index + 2}'}),
      RefusDestiny.apresFin => t.t('regie.refus_fin', {'n': n}),
    };
  }

  /// « −1 min » / « +1 min » sur le prochain Destiny.
  void _decalerProchain(int delta) {
    final i = _prochain;
    if (i == null) return;
    final refus = _deplacer(i, delta);
    final messager = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    if (refus != null) {
      messager.showSnackBar(SnackBar(content: Text(refus), duration: const Duration(seconds: 3)));
    }
  }

  /// La feuille « Régler les Destiny » : un réglage pour chaque Destiny qui
  /// reste, avec les mêmes règles.
  Future<void> _regler() async {
    String? refus;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, majFeuille) {
        final t = ctx.textes;
        final c = ctx.destiny;
        String rg(String k, [Map<String, String> v = const {}]) => t.t('regie.$k', v);
        void decaler(int i, int delta) => majFeuille(() => refus = _deplacer(i, delta));
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            children: [
              Text(rg('regler'), style: Theme.of(ctx).textTheme.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: 10),
              Paragraphe(rg('regler_aide')),
              Paragraphe(r.declenchement == Declenchement.manuel ? rg('manuel') : rg('auto'), italique: true),
              const SizedBox(height: 4),
              for (var i = 0; i < s.destinyMinutes.length; i++)
                _LigneReglage(
                  numero: i + 1,
                  minute: s.destinyMinutes[i],
                  lanceA: i < s.destinys.length ? s.destinys[i].secondes : null,
                  prochain: i == s.destinys.length,
                  onMoins: () => decaler(i, -1),
                  onPlus: () => decaler(i, 1),
                ),
              if (refus != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    refus!,
                    key: const ValueKey('refus_reglage'),
                    style: TextStyle(
                      fontFamily: kPoliceTexte,
                      fontWeight: FontWeight.w600,
                      fontSize: 14.5,
                      color: Theme.of(ctx).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                style: FilledButton.styleFrom(backgroundColor: c.or, foregroundColor: c.surOr),
                child: Text(t.t('troupe.retour')),
              ),
            ],
          ),
        );
      }),
    );
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
    final enRetard = prochain != null && s.destinyMinutes[prochain] * 60 <= _ecoule;
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
        FriseDestiny(totalSecondes: _total, ecouleSecondes: _ecoule, reperes: reperesDestiny(s)),
        const SizedBox(height: 8),
        if (prochain != null) ...[
          Text(
            enRetard
                ? rg('en_retard', {'n': '${prochain + 1}'})
                : rg('dans', {'n': '${prochain + 1}', 't': horloge(s.destinyMinutes[prochain] * 60 - _ecoule)}),
            key: const ValueKey('compte_a_rebours'),
            style: TextStyle(
              fontFamily: kPoliceTexte,
              fontWeight: FontWeight.w700,
              fontSize: 15.5,
              height: 1.3,
              color: c.bleuTexte,
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: _BoutonDecalage(
                libelle: rg('moins_une'),
                aide: rg('plus_tot', {'n': '${prochain + 1}'}),
                onPressed: () => _decalerProchain(-1),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _BoutonDecalage(
                libelle: rg('plus_une'),
                aide: rg('plus_tard', {'n': '${prochain + 1}'}),
                onPressed: () => _decalerProchain(1),
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: rg('regler'),
              icon: Icon(Icons.tune_rounded, color: c.titre),
              onPressed: _regler,
            ),
          ]),
        ] else
          Text(rg('dernier_acte'),
              style: TextStyle(fontFamily: kPoliceTexte, fontWeight: FontWeight.w600, color: c.texteSecondaire)),
        if (reste <= 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(rg('temps_ecoule'),
                style: TextStyle(fontFamily: kPoliceTexte, fontWeight: FontWeight.w700, color: couleurReste)),
          ),
        const SizedBox(height: 12),
        Semantics(
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
              prochain == null ? rg('destiny').toUpperCase() : rg('destiny_n', {'n': '${prochain + 1}'}).toUpperCase(),
            ),
          ),
        ),
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
      actions: [
        IconButton(
          tooltip: t.t('navigation.regie_son'),
          icon: const Icon(Icons.graphic_eq_rounded),
          onPressed: () => showSoundMixer(context, widget.contexte.musique),
        ),
      ],
      entete: collant ? panneau : null,
      enfants: [
        if (!collant) panneau,
        TabletteSon(contexte: widget.contexte, session: s),
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
        SectionDestiny(titre: rg('objets_mystere'), enfants: [
          for (final (i, o) in s.objets.indexed)
            if (o.isNotEmpty) Puce(o, numero: i + 1),
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

/// « −1 min » ou « +1 min » : déplace le prochain Destiny.
class _BoutonDecalage extends StatelessWidget {
  const _BoutonDecalage({required this.libelle, required this.aide, required this.onPressed});

  final String libelle;
  final String aide;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.destiny;
    return Tooltip(
      message: aide,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 42),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          side: BorderSide(color: c.bleuDestiny.withValues(alpha: 0.7), width: 1.4),
          foregroundColor: c.bleuTexte,
          textStyle: const TextStyle(fontFamily: kPoliceTexte, fontWeight: FontWeight.w700, fontSize: 15),
        ),
        child: Text(libelle, semanticsLabel: aide),
      ),
    );
  }
}

/// Une ligne de la feuille « Régler les Destiny ».
class _LigneReglage extends StatelessWidget {
  const _LigneReglage({
    required this.numero,
    required this.minute,
    required this.lanceA,
    required this.prochain,
    required this.onMoins,
    required this.onPlus,
  });

  final int numero;
  final int minute;

  /// Déjà lancé, à cette seconde (sinon null).
  final int? lanceA;
  final bool prochain;
  final VoidCallback onMoins;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    final t = context.textes;
    final c = context.destiny;
    String rg(String k, [Map<String, String> v = const {}]) => t.t('regie.$k', v);
    final lance = lanceA != null;
    return Container(
      key: ValueKey('reglage_destiny_$numero'),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
      decoration: decorCarte(c, bordure: prochain ? c.bleuDestiny : null),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(rg('destiny_n', {'n': '$numero'}),
                style: TextStyle(fontFamily: kPoliceTexte, fontWeight: FontWeight.w800, fontSize: 16, color: c.texte)),
            Text(
              lance ? rg('lance_a', {'t': horloge(lanceA!)}) : rg('prevu_a', {'t': horloge(minute * 60)}),
              style: TextStyle(
                fontFamily: kPoliceTexte,
                fontSize: 14,
                fontWeight: prochain ? FontWeight.w700 : FontWeight.w400,
                color: prochain ? c.bleuTexte : c.texteSecondaire,
              ),
            ),
          ]),
        ),
        if (lance)
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Icon(Icons.check_circle_rounded, color: c.bleuTexte),
          )
        else ...[
          IconButton(
            tooltip: rg('plus_tot', {'n': '$numero'}),
            icon: const Icon(Icons.remove_circle_outline_rounded),
            color: c.titre,
            onPressed: onMoins,
          ),
          IconButton(
            tooltip: rg('plus_tard', {'n': '$numero'}),
            icon: const Icon(Icons.add_circle_outline_rounded),
            color: c.titre,
            onPressed: onPlus,
          ),
        ],
      ]),
    );
  }
}

/// La régie son, en tablette : de grandes tuiles pour les musiques du
/// spectacle, le son de Destiny et Stop, plus tout le mixeur. Elle respecte
/// le son coupé.
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
    final musiques = [
      (Icons.music_note_rounded, rg('son_debut'), _ou(_r.musiqueDebut, ChoixMusique.commencement)),
      (Icons.place_rounded, rg('son_lieu'), ChoixMusique.lieu),
      (Icons.waves_rounded, rg('son_acte2'), _ou(_r.ambianceActe2, ChoixMusique.lieu)),
      (Icons.nightlight_round, rg('son_fin'), _ou(_r.musiqueFin, ChoixMusique.conclusion)),
    ];

    return ListenableBuilder(
      listenable: _musique,
      builder: (context, _) {
        final enCours = _musique.playing ? _musique.current : null;
        return SectionDestiny(titre: rg('son'), espace: 18, enfants: [
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
        ]);
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

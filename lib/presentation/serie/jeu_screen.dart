import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../../application/prompts/prompts.dart';
import '../../application/services/transcription_service.dart';
import '../../application/state/reglages_destiny.dart';
import '../../domain/grammaire/modeles.dart';
import '../../domain/grammaire/progression.dart';
import '../../domain/serie/regles_serie.dart';
import '../../domain/serie/serie.dart';
import '../destiny/bouton_ia.dart';
import '../destiny/composants.dart';
import '../destiny/donnees.dart';
import '../destiny/page.dart';
import '../destiny/rituel_destiny.dart';
import '../theme/destiny_theme.dart';
import '../widgets/piece_destin_flip.dart';
import '../widgets/sound_mixer_sheet.dart';
import 'composants_serie.dart';
import 'contexte_serie.dart';

/// L'écran du maître du jeu pendant un épisode : le chrono (ou pas), Destiny
/// et son rituel, les paliers, le présage et le méchant (dans l'ombre avant
/// l'épisode 4), l'escalade, les personnages et leur montée, les figurants et
/// les sbires, le combat, la pièce du destin, la régie son et les notes.
class JeuEpisodeScreen extends StatefulWidget {
  const JeuEpisodeScreen({super.key, required this.contexte, required this.serie, required this.episode});

  final ContexteSerie contexte;
  final Serie serie;
  final EpisodeSerie episode;

  @override
  State<JeuEpisodeScreen> createState() => _JeuEpisodeScreenState();
}

class _JeuEpisodeScreenState extends State<JeuEpisodeScreen> {
  Timer? _minuteur;
  int _ecoule = 0;
  bool _demarre = false;
  bool _rituelEnCours = false;
  final List<Timer> _musiques = [];
  final TextEditingController _note = TextEditingController();
  final Map<String, TextEditingController> _besoins = {};
  TranscriptionService? _micro;
  String _microRaison = '';

  bool _piece = false;
  bool _pieceBrave = true;
  int _pieceNo = 0;
  final Random _hasard = Random();

  Serie get s => widget.serie;
  EpisodeSerie get e => widget.episode;
  ReglagesDestiny get r => widget.contexte.reglages;
  PalierId get _palier => PalierId.deNumero(e.palierAtteint);
  bool get _enMarche => _minuteur?.isActive ?? false;
  int get _total => e.dureeMinutes * 60;

  @override
  void initState() {
    super.initState();
    if (e.destinys.isNotEmpty) _ecoule = e.destinys.last.secondes;
    if (!e.avecChrono && e.destinys.isEmpty) _lancerMusique();
    if (e.transcrire) _demarrerMicro();
  }

  @override
  void dispose() {
    _minuteur?.cancel();
    for (final t in _musiques) {
      t.cancel();
    }
    _micro?.arreter();
    _note.dispose();
    for (final c in _besoins.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _demarrerMicro() async {
    final m = TranscriptionService();
    _micro = m;
    final echec = await m.demarrer(
      onPhrase: (_) {},
      onChangement: () {
        if (mounted) setState(() {});
      },
      dureeMax: Duration(minutes: e.avecChrono ? e.dureeMinutes + 5 : 90),
    );
    if (!echec.ok && mounted) setState(() => _microRaison = echec.message);
  }

  void _lancerMusique() {
    _demarre = true;
    if (!widget.contexte.audio.muted) widget.contexte.musique.jouerChoix(r.musiqueDebut, lieu: e.lieuNom);
  }

  Future<void> _sauver() => widget.contexte.store.enregistrer(s);

  void _basculer() {
    if (_enMarche) {
      _minuteur?.cancel();
      setState(() {});
      return;
    }
    if (!_demarre) _lancerMusique();
    _minuteur = Timer.periodic(const Duration(seconds: 1), (_) => _seconde());
    setState(() {});
  }

  void _seconde() {
    if (!mounted) return;
    setState(() => _ecoule++);
    if (_ecoule == _total) widget.contexte.audio.playCrack();
    if (_ecoule == _total - 10) widget.contexte.audio.playThunder();
    final auto = r.declenchement != Declenchement.manuel;
    final prochain = e.destinys.length;
    if (auto && !_rituelEnCours && prochain < e.destinyMinutes.length && _ecoule >= e.destinyMinutes[prochain] * 60) {
      _destiny(manuel: false);
    }
  }

  Future<void> _destiny({required bool manuel}) async {
    if (_rituelEnCours || _palier == PalierId.supprime) return;
    _rituelEnCours = true;
    final premier = e.destinys.isEmpty;
    final nouveau = PalierId.values[_palier.index + 1];
    e.destinys.add(EvenementDestiny(numero: e.destinys.length + 1, secondes: _ecoule, manuel: manuel));
    e.palierAtteint = nouveau.numero;
    await _sauver();
    _programmerMusiques(e.destinys.length);
    if (!mounted) return;
    setState(() {});
    final nouvelle = e.paliers.length > nouveau.index ? e.paliers[nouveau.index] : null;
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
      if (mounted) widget.contexte.musique.jouerChoix(choix, lieu: e.lieuNom);
    }));
  }

  void _lancerPiece() {
    if (_piece) return;
    HapticFeedback.mediumImpact();
    widget.contexte.audio.playCoin();
    setState(() {
      _pieceBrave = _hasard.nextBool();
      _pieceNo++;
      _piece = true;
    });
  }

  Future<void> _noter() async {
    final texte = _note.text.trim();
    if (texte.isEmpty) return;
    setState(() {
      e.notes.add(NoteRegie(secondes: _ecoule, texte: texte));
      _note.clear();
    });
    await _sauver();
  }

  void _bascule(PnjEpisode p) {
    final t = context.textes;
    setState(() {
      p
        ..aBascule = true
        ..mode = ModePnj.sbire;
    });
    _sauver();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.t('serie.jeu.bascule', {'nom': p.nom}))));
  }

  Future<void> _terminer() async {
    final t = context.textes;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(t.t('serie.jeu.terminer_confirmer')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t.t('serie.non'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(t.t('serie.oui'))),
        ],
      ),
    );
    if (ok != true) return;
    _minuteur?.cancel();
    final m = _micro;
    if (m != null) {
      await m.arreter();
      e.transcription = [e.transcription, m.texte].where((x) => x.trim().isNotEmpty).join('\n').trim();
    }
    e.etape = EtapeEpisode.bilan;
    await _sauver();
    if (mounted) await ouvrirEpisode(context, widget.contexte, s, e, remplacer: true);
  }

  /// La voix de l'alarmiste : une ou deux répliques pour la nouvelle du
  /// palier, quand c'est le maître du jeu qui joue l'alarmiste.
  Future<void> _soufflerAlarmiste() async {
    final alarmiste = s.personnagesActifs.firstWhere((p) => p.pnj && p.archetypeId == Grammaire.alarmisteId);
    final texte = await widget.contexte.ia!.voixAlarmiste(
      scene: ScenePrompt(lieu: e.lieuNom, espaces: e.espaces, groupe: e.groupe, danger: e.dangerNom, paliers: e.paliers),
      palier: _palier,
      animalId: alarmiste.animalId,
      kids: s.kids,
    );
    if (!mounted) return;
    final t = context.textes;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.t('ia_jeu.alarmiste_titre')),
        content: Text(texte),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t.t('ia_jeu.fermer')))],
      ),
    );
  }

  String _horloge(int secondes) {
    final v = secondes.abs();
    return '${secondes < 0 ? '-' : ''}${(v ~/ 60).toString().padLeft(2, '0')}:${(v % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final g = context.grammaire;
    final t = context.textes;
    final c = context.destiny;
    String rg(String x, [Map<String, String> v = const {}]) => t.t('regie.$x', v);
    String k(String x, [Map<String, String> v = const {}]) => t.t('serie.jeu.$x', v);
    final palier = g.palier(_palier);
    final acte = g.actes.firstWhere((a) => a.palier == _palier);
    final geste = gestePourActe(g, palier.acte);
    final mechant = widget.contexte.mechant(g, e.mechantId);
    final enPersonne = mechantEnPersonne(saison: e.saison, numero: e.numero, aUnMechant: mechant != null);
    final marches = escaladeEpisode(
        paliersDanger: e.paliers, mechant: mechant, saison: e.saison, numero: e.numero, sortis: s.pnjSortis);
    final saison = s.saison(e.saison);
    final traitre = saison?.traitre;
    final finale = e.saison == 0 || e.numero >= 4;
    final prochain = e.avecChrono && e.destinys.length < e.destinyMinutes.length ? e.destinyMinutes[e.destinys.length] * 60 : null;
    final reste = _total - _ecoule;
    final figurants = [for (final p in e.pnjs) if (p.mode == ModePnj.figurant) p];
    final sbires = [for (final p in e.pnjs) if (p.mode == ModePnj.sbire) p];

    Widget? combatPnj(PnjEpisode p) => s.reglages.combat
        ? CombatEnLigne(
            sante: p.sante,
            mod: p.mod,
            onSante: (v) {
              setState(() => p.sante = v);
              _sauver();
            },
            onMod: (v) {
              setState(() => p.mod = v);
              _sauver();
            },
          )
        : null;

    final page = PageDestiny(
      titre: e.saison > 0 ? '${t.t('serie.saison_n', {'n': '${e.saison}'})} · ${k('titre', {'n': '${e.numero}'})}' : k('titre', {'n': '${e.numero}'}),
      actions: [
        if (_micro?.ecoute ?? false)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Row(children: [
              Icon(Icons.mic, size: 18, color: c.famille(FamilleId.fissure)),
              const SizedBox(width: 4),
              Text(k('micro_on'), style: TextStyle(fontSize: 12, color: c.famille(FamilleId.fissure))),
            ]),
          ),
        if (s.reglages.combat)
          IconButton(
            tooltip: k('combat_aide'),
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () => expliquerCombat(context, kids: s.kids),
          ),
        IconButton(
          tooltip: t.t('navigation.regie_son'),
          icon: const Icon(Icons.graphic_eq_rounded),
          onPressed: () => showSoundMixer(context, widget.contexte.musique),
        ),
      ],
      enfants: [
        if (_microRaison.isNotEmpty) Paragraphe(k('micro_echec', {'raison': _microRaison}), italique: true),
        Text('${e.lieuNom} · ${e.dangerNom}', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
        if (e.groupe.isNotEmpty)
          Text(e.groupe, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
        if (s.kids) const Center(child: SigleKids(petit: true)),
        const SizedBox(height: 8),
        if (e.avecChrono)
          Center(
            child: Text(
              _horloge(reste),
              style: TextStyle(
                fontFamily: kPoliceTitres,
                fontWeight: FontWeight.w900,
                fontSize: 60,
                color: reste <= 0 ? c.famille(FamilleId.fissure) : c.titre,
              ),
            ),
          ),
        Center(
          child: Text(
            '${rg('acte', {'n': '${palier.acte}'})} · ${palier.nom} · ${palier.ambiance}',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: kPoliceTexte, fontWeight: FontWeight.w600, color: c.palier(_palier)),
          ),
        ),
        if (prochain != null)
          Center(child: Text(rg('prochain', {'t': _horloge(prochain)}), style: TextStyle(color: c.texteSecondaire)))
        else if (_palier == PalierId.supprime)
          Center(child: Text(rg('dernier_acte'), style: TextStyle(color: c.texteSecondaire))),
        const SizedBox(height: 12),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: c.bleuDestiny,
            foregroundColor: Colors.white,
            minimumSize: const Size(48, 60),
            textStyle: const TextStyle(fontFamily: kPoliceTitres, fontWeight: FontWeight.w900, fontSize: 22),
          ),
          onPressed: _palier == PalierId.supprime ||
                  _rituelEnCours ||
                  (e.avecChrono && r.declenchement == Declenchement.automatique)
              ? null
              : () => _destiny(manuel: true),
          icon: const Icon(Icons.flash_on_rounded),
          label: Text(rg('destiny').toUpperCase()),
        ),
        if (e.avecChrono) ...[
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _basculer,
            icon: Icon(_enMarche ? Icons.pause_rounded : Icons.play_arrow_rounded),
            label: Text(_enMarche ? rg('pause') : (_demarre ? rg('reprendre') : rg('demarrer'))),
          ),
        ],
        const SizedBox(height: 12),
        FrisePaliers(textes: e.paliers, courant: _palier),
        if (r.rappelsRegie)
          SectionDestiny(titre: rg('rappel'), enfants: [
            if (geste != null) LigneInfo(geste.verbe, geste.consigne),
            for (final consigne in acte.consignes) Puce(consigne),
            if (e.destinys.length == 1) Puce(k('rappel_fixer')),
            if (_palier == PalierId.envahit) Puce(k('rappel_nommer')),
            if (_palier == PalierId.supprime) Puce(k('rappel_choisir')),
            if (_palier == PalierId.supprime && finale) Puce(k('rappel_forcer')),
            if (s.kids && _palier.index >= PalierId.envahit.index) Puce(k('rappel_kids')),
          ]),
        if (widget.contexte.ia != null && s.personnagesActifs.any((p) => p.pnj && p.archetypeId == Grammaire.alarmisteId))
          BoutonIA(
            libelle: t.t('ia_jeu.alarmiste'),
            disponible: widget.contexte.ia!.disponible,
            action: _soufflerAlarmiste,
          ),
        if (traitre != null && traitre.accepte != null && e.numero == 3 && !traitre.revele)
          _revelationTraitre(traitre),
        if (e.saison > 0 && e.presage.isNotEmpty)
          SectionDestiny(titre: k('presage'), enfants: [
            EncartReplique(e.presage, couleur: c.palier(PalierId.deNumero(e.numero.clamp(1, 4)))),
          ]),
        if (mechant != null)
          SectionDestiny(titre: k('mechant'), enfants: [
            CadreLisere(
              couleur: enPersonne ? c.famille(FamilleId.fissure) : c.texteSecondaire,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Icon(enPersonne ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                      color: enPersonne ? c.famille(FamilleId.fissure) : c.texteSecondaire),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(mechant.nom,
                        style: TextStyle(
                            fontFamily: kPoliceTitres,
                            fontWeight: FontWeight.w900,
                            color: c.texte,
                            decoration: e.mechantSante == Sante.sorti ? TextDecoration.lineThrough : null)),
                  ),
                  Chip(label: Text(enPersonne ? k('en_personne') : k('dans_l_ombre'))),
                ]),
                LigneInfo(t.t('bibliotheque.fiche.il_veut'), mechant.veut),
                if (enPersonne) LigneInfo(k('sa_faille'), mechant.faillePour(kids: s.kids)),
                Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  ActionChip(
                    avatar: const Icon(Icons.open_in_full_rounded, size: 16),
                    label: Text(k('voir_carte')),
                    onPressed: () => ouvrirCarteMechant(context, mechant, kids: s.kids),
                  ),
                  if (enPersonne && s.reglages.combat)
                    CombatEnLigne(
                      sante: e.mechantSante,
                      mod: e.mechantMod,
                      onSante: (v) {
                        setState(() => e.mechantSante = v);
                        _sauver();
                      },
                      onMod: (v) {
                        setState(() => e.mechantMod = v);
                        _sauver();
                      },
                    ),
                ]),
              ]),
            ),
          ]),
        SectionDestiny(titre: k('escalade'), enfants: [
          for (final m in marches)
            Opacity(
              opacity: m.palier.index <= _palier.index ? 1 : 0.45,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(m.palier == _palier ? Icons.bolt_rounded : Icons.circle_outlined, size: 18, color: c.palier(m.palier)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text.rich(TextSpan(children: [
                      TextSpan(
                        text: '${m.nom.isEmpty ? k('le_danger') : m.nom} : ',
                        style: TextStyle(fontWeight: FontWeight.w700, color: c.palier(m.palier)),
                      ),
                      if (m.ceQuIlFait.isNotEmpty) TextSpan(text: '${m.ceQuIlFait} → '),
                      TextSpan(text: m.ceQueCaProduit),
                    ])),
                  ),
                ]),
              ),
            ),
        ]),
        SectionDestiny(titre: k('personnages'), enfants: [
          for (final p in s.personnagesActifs) _personnage(p),
        ]),
        if (figurants.isNotEmpty)
          SectionDestiny(titre: k('figurants'), enfants: [
            for (final p in figurants)
              LignePnj(
                pnj: p,
                kids: s.kids,
                source: widget.contexte.visuels.source,
                onMode: (m) {
                  setState(() => p.mode = m);
                  _sauver();
                },
                onBascule: mechant == null ? null : () => _bascule(p),
                combat: combatPnj(p),
              ),
          ]),
        if (sbires.isNotEmpty)
          SectionDestiny(titre: k('sbires'), enfants: [
            for (final p in sbires)
              LignePnj(
                pnj: p,
                kids: s.kids,
                source: widget.contexte.visuels.source,
                onMode: (m) {
                  setState(() => p.mode = m);
                  _sauver();
                },
                combat: combatPnj(p),
              ),
          ]),
        TextButton.icon(
          onPressed: () => ouvrirTypesFigurants(context),
          icon: const Icon(Icons.help_outline_rounded),
          label: Text(k('types')),
        ),
        const SizedBox(height: 8),
        if (s.reglages.piece)
          FilledButton.icon(
            onPressed: _lancerPiece,
            icon: const Icon(Icons.toll_rounded),
            label: Text(k('piece')),
          ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => showSoundMixer(context, widget.contexte.musique),
          icon: const Icon(Icons.tune_rounded),
          label: Text(k('regie')),
        ),
        SectionDestiny(titre: rg('objets_mystere'), enfants: [
          for (final (i, o) in e.objets.indexed)
            if (o.isNotEmpty) Puce(o, numero: i + 1),
          LigneInfo(t.t('mise_en_place.mystere'), e.mystere),
          LigneInfo(t.t('mise_en_place.reponse'), e.reponseMystere, italique: true),
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
          for (final n in e.notes.reversed) LigneInfo(n.horodatage, n.texte),
        ]),
        const SizedBox(height: 18),
        OutlinedButton.icon(onPressed: _terminer, icon: const Icon(Icons.flag_rounded), label: Text(k('terminer'))),
      ],
    );

    return Stack(children: [
      page,
      if (_piece)
        Positioned.fill(
          child: LayoutBuilder(builder: (context, cs) {
            final taille = (cs.biggest.shortestSide * 0.6).clamp(180.0, 320.0).toDouble();
            return PieceDestinFlip(
              key: ValueKey(_pieceNo),
              brave: _pieceBrave,
              size: taille,
              onFini: () {
                if (mounted) setState(() => _piece = false);
              },
            );
          }),
        ),
    ]);
  }

  Widget _revelationTraitre(TraitreSaison traitre) {
    final t = context.textes;
    final c = context.destiny;
    final p = s.personnage(traitre.personnageId);
    final nom = p == null ? '' : (p.joueur.isNotEmpty ? p.joueur : p.appel);
    return SectionDestiny(titre: t.t('serie.traitre.revele'), enfants: [
      CadreLisere(
        couleur: c.famille(FamilleId.fissure),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Paragraphe(t.t(traitre.accepte == true ? 'serie.traitre.revele_oui' : 'serie.traitre.revele_non', {'nom': nom})),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () {
                setState(() => traitre.revele = true);
                _sauver();
              },
              child: Text(t.t('serie.traitre.marquer_revele')),
            ),
          ),
        ]),
      ),
    ]);
  }

  Widget _personnage(PersonnageSerie p) {
    final g = context.grammaire;
    final t = context.textes;
    final c = context.destiny;
    String k(String x) => t.t('serie.jeu.$x');
    final role = e.role(p.id);
    final m = monteeAttendue(g, archetypeId: p.archetypeId, animalId: p.animalId, palier: _palier);
    final arch = g.archetype(p.archetypeId);
    final couleur = arch == null ? c.or : c.famille(arch.famille);
    final sorti = role?.sante == Sante.sorti;
    final besoin = _besoins[p.id] ??= TextEditingController(text: p.besoin);
    return CadreLisere(
      couleur: couleur,
      marge: 8,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (m?.animal != null) MedaillonAnimal(m!.animal!, taille: 40, source: widget.contexte.visuels.source),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                [p.appel, if (p.joueur.isNotEmpty && p.joueur != p.appel) '(${p.joueur})', arch?.nom ?? ''].join(' · '),
                style: TextStyle(
                    fontFamily: kPoliceTitres,
                    fontWeight: FontWeight.w700,
                    color: c.texte,
                    decoration: sorti ? TextDecoration.lineThrough : null),
              ),
              if (m != null)
                Text(m.ceQuIlFait, style: TextStyle(fontFamily: kPoliceTexte, fontWeight: FontWeight.w600, color: couleur)),
              if (m != null && m.corps.isNotEmpty)
                Text(m.corps, style: TextStyle(fontFamily: kPoliceTexte, fontSize: 12.5, color: c.texteSecondaire)),
            ]),
          ),
        ]),
        LigneInfo(k('veut'), role?.vouloir ?? ''),
        if (p.besoin.isNotEmpty || e.destinys.isEmpty)
          LigneInfo(k('besoin'), p.besoin)
        else
          TextField(
            controller: besoin,
            decoration: InputDecoration(labelText: k('besoin'), isDense: true),
            onChanged: (v) {
              p.besoin = v.trim();
              _sauver();
            },
          ),
        if (s.kids) LigneInfo(k('pouvoir'), p.pouvoir),
        if (s.reglages.combat && role != null)
          Align(
            alignment: Alignment.centerRight,
            child: CombatEnLigne(
              sante: role.sante,
              mod: role.mod,
              onSante: (v) {
                setState(() => role.sante = v);
                _sauver();
              },
              onMod: (v) {
                setState(() => role.mod = v);
                _sauver();
              },
            ),
          ),
      ]),
    );
  }
}

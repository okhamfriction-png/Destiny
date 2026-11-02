import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../../application/prompts/prompts.dart';
import '../../application/services/transcription_service.dart';
import '../../application/state/reglages_destiny.dart';
import '../../domain/grammaire/modeles.dart';
import '../../domain/grammaire/progression.dart';
import '../../domain/serie/pbta.dart';
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
import 'aide_mj_screen.dart';
import 'composants_serie.dart';
import 'contexte_serie.dart';
import 'pbta_composants.dart';
import 'piece_serie.dart';

/// Le poste du Maître du destin pendant un épisode : le chrono (ou pas),
/// Destiny et son rituel, « Tirer la pièce » (BRAVE ou SMART), les deux
/// horloges (les paliers du danger, les présages du méchant), l'aide du MJ,
/// le méchant (dans l'ombre avant l'épisode 4), l'escalade, la fiche de
/// chaque personnage avec ses blessures, les figurants et les sbires, la
/// régie son et les notes.
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

  /// La pièce en l'air (null : aucune).
  FacePiece? _faceAnimee;
  int _pieceNo = 0;
  String _titrePiece = '';
  Completer<void>? _finPiece;
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
    for (final p in s.personnagesActifs) {
      if (e.role(p.id) == null) e.roles.add(RoleEpisode(personnageId: p.id));
    }
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

  /// L'aide du MJ ; après un échec, elle s'ouvre sur ses mouvements.
  void _aideMj([OngletAideMj onglet = OngletAideMj.piece]) => Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => AideMjScreen(kids: s.kids, palier: e.palierAtteint, onglet: onglet),
      ));

  /// « Tirer la pièce » : on choisit qui agit, sa ligne du destin et ce qui
  /// donne le second lancer, la pièce tourne (une ou deux fois), puis le
  /// résultat s'affiche avec, après un échec, les mouvements du MJ.
  Future<void> _tirerPiece([String? personnageId]) async {
    if (_faceAnimee != null) return;
    final regles = ReglesPbta.depuis(context.textes);
    final choix = await ouvrirChoixPiece(context, serie: s, episode: e, regles: regles, personnageId: personnageId);
    if (choix == null || !mounted) return;
    final resultat = choix.lancers == null
        ? lancerPiece(approche: choix.approche, mode: choix.mode, palier: e.palierAtteint, hasard: _hasard)
        : ResultatPiece(approche: choix.approche, mode: choix.mode, lancers: choix.lancers!, palier: e.palierAtteint);
    final role = e.role(choix.personnageId);
    // Le second lancer du vouloir dit ne sert qu'une fois.
    if (role != null && role.elan) role.elan = false;
    _sauver();
    if (choix.lancers == null) await _animer(resultat);
    if (!mounted) return;
    setState(() {});
    final p = s.personnage(choix.personnageId);
    await ouvrirResultatPiece(
      context,
      resultat: resultat,
      regles: regles,
      kids: s.kids,
      nom: p?.appel ?? '',
      mouvement: regles.mouvement(choix.mouvementId),
      hasard: _hasard,
      onBlessure: role == null
          ? null
          : () {
              setState(role.marquerBlessure);
              _sauver();
            },
      onAideMj: () => _aideMj(OngletAideMj.maitre),
    );
  }

  /// La pièce tourne, une fois par lancer.
  Future<void> _animer(ResultatPiece resultat) async {
    final t = context.textes;
    for (final (i, f) in resultat.lancers.indexed) {
      HapticFeedback.mediumImpact();
      widget.contexte.audio.playCoin();
      final fin = Completer<void>();
      setState(() {
        _faceAnimee = f;
        _pieceNo++;
        _titrePiece = (resultat.mode == ModeLancer.simple
                ? t.t('pbta.piece.titre')
                : t.t('serie.piece.lancer_n', {'n': '${i + 1}'}))
            .toUpperCase();
        _finPiece = fin;
      });
      await fin.future;
      if (!mounted) return;
    }
    setState(() => _faceAnimee = null);
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
    final regles = ReglesPbta.depuis(t);
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
    final texteDuPalier = e.paliers.length > _palier.index ? e.paliers[_palier.index] : '';

    Widget horsJeu(PnjEpisode p) => InterrupteurHorsJeu(
          horsJeu: p.sante == Sante.sorti,
          libelle: k('hors_jeu'),
          onChange: (v) {
            setState(() => p.sante = v ? Sante.sorti : Sante.enForme);
            _sauver();
          },
        );

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
        IconButton(
          tooltip: t.t('serie.aide_mj.titre'),
          icon: const Icon(Icons.menu_book_outlined),
          onPressed: _aideMj,
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
        FilledButton.icon(
          style: FilledButton.styleFrom(
            minimumSize: const Size(48, 56),
            textStyle: const TextStyle(fontFamily: kPoliceTitres, fontWeight: FontWeight.w900, fontSize: 18),
          ),
          onPressed: _faceAnimee == null ? () => _tirerPiece() : null,
          icon: const Icon(Icons.toll_rounded),
          label: Text(k('tirer_piece')),
        ),
        const SizedBox(height: 8),
        Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 6, children: [
          OutlinedButton.icon(
            onPressed: _aideMj,
            icon: const Icon(Icons.menu_book_outlined),
            label: Text(t.t('serie.aide_mj.titre')),
          ),
          OutlinedButton.icon(
            onPressed: () => showSoundMixer(context, widget.contexte.musique),
            icon: const Icon(Icons.tune_rounded),
            label: Text(k('regie')),
          ),
        ]),
        SectionDestiny(titre: t.t('pbta.horloges.titre'), enfants: [
          HorlogeQuatre(
            titre: k('horloge_episode'),
            rempli: e.palierAtteint,
            icone: Icons.bolt_rounded,
            legende: [palier.nom, texteDuPalier].where((x) => x.isNotEmpty).join(' · '),
          ),
          if (e.saison > 0)
            HorlogeQuatre(
              titre: k('horloge_saison'),
              rempli: e.numero,
              icone: Icons.local_fire_department_outlined,
              legende: e.presage,
            ),
          Text(
            k('gravite', {
              'gravite': graviteAuPalier(e.palierAtteint) == GraviteMouvement.doux ? t.t('serie.piece.doux') : t.t('serie.piece.dur'),
            }),
            style: TextStyle(fontFamily: kPoliceTexte, fontSize: 12.5, fontWeight: FontWeight.w700, color: c.texteSecondaire),
          ),
          const SizedBox(height: 10),
          FrisePaliers(textes: e.paliers, courant: _palier, compacte: true),
        ]),
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
                ]),
                Text(enPersonne ? k('en_personne') : k('dans_l_ombre'),
                    style: TextStyle(fontFamily: kPoliceTexte, fontWeight: FontWeight.w700, color: c.texteSecondaire)),
                LigneInfo(t.t('bibliotheque.fiche.il_veut'), mechant.veut),
                if (enPersonne) LigneInfo(k('sa_faille'), mechant.faillePour(kids: s.kids)),
                Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  ActionChip(
                    avatar: const Icon(Icons.open_in_full_rounded, size: 16),
                    label: Text(k('voir_carte')),
                    onPressed: () => ouvrirCarteMechant(context, mechant, kids: s.kids),
                  ),
                  if (enPersonne)
                    InterrupteurHorsJeu(
                      horsJeu: e.mechantSante == Sante.sorti,
                      libelle: k('hors_jeu'),
                      onChange: (v) {
                        setState(() => e.mechantSante = v ? Sante.sorti : Sante.enForme);
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
          for (final p in s.personnagesActifs) _personnage(p, regles),
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
                etat: horsJeu(p),
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
                etat: horsJeu(p),
              ),
          ]),
        TextButton.icon(
          onPressed: () => ouvrirTypesFigurants(context),
          icon: const Icon(Icons.help_outline_rounded),
          label: Text(k('types')),
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

    final face = _faceAnimee;
    return Stack(children: [
      page,
      if (face != null)
        Positioned.fill(
          child: LayoutBuilder(builder: (context, cs) {
            final taille = (cs.biggest.shortestSide * 0.6).clamp(180.0, 320.0).toDouble();
            return PieceDestinFlip(
              key: ValueKey(_pieceNo),
              brave: face == FacePiece.brave,
              size: taille,
              titre: _titrePiece,
              legende: t.t('pbta.piece.faces.${face.name}.legende'),
              onFini: () {
                final fin = _finPiece;
                if (fin != null && !fin.isCompleted) fin.complete();
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

  /// La fiche compacte d'un personnage : son animal, son archétype et son
  /// bonus, ce qu'il fait à ce palier, son vouloir et son besoin, son pouvoir
  /// (kids), ses blessures, et quand il lance deux fois.
  Widget _personnage(PersonnageSerie p, ReglesPbta regles) {
    final g = context.grammaire;
    final t = context.textes;
    final c = context.destiny;
    String k(String x, [Map<String, String> v = const {}]) => t.t('serie.jeu.$x', v);
    final role = e.role(p.id);
    final m = monteeAttendue(g, archetypeId: p.archetypeId, animalId: p.animalId, palier: _palier);
    final arch = g.archetype(p.archetypeId);
    final animal = g.animal(p.animalId);
    final couleur = arch == null ? c.or : c.famille(arch.famille);
    final horsJeu = role?.horsJeu ?? false;
    final besoin = _besoins[p.id] ??= TextEditingController(text: p.besoin);
    final bonus = p.bonus;
    final deuxLancers = [
      if (bonus != null) k('rappel_bonus', {'face': nomFace(context, bonus)}),
      k('rappel_aide'),
      if (role != null && !role.vouloirDit) k('rappel_vouloir'),
      if (s.kids && p.pouvoir.isNotEmpty) k('rappel_pouvoir'),
    ];
    return CadreLisere(
      couleur: couleur,
      marge: 8,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (animal != null) MedaillonAnimal(animal, taille: 40, source: widget.contexte.visuels.source),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                [p.appel, if (p.joueur.isNotEmpty && p.joueur != p.appel) '(${p.joueur})'].where((x) => x.isNotEmpty).join(' '),
                style: TextStyle(
                  fontFamily: kPoliceTitres,
                  fontWeight: FontWeight.w700,
                  color: c.texte,
                  decoration: horsJeu ? TextDecoration.lineThrough : null,
                ),
              ),
              Text(
                [arch?.nom ?? '', animal?.nom ?? '', if (p.pnj) t.t('serie.personnages.pnj')].where((x) => x.isNotEmpty).join(' · '),
                style: TextStyle(fontFamily: kPoliceTexte, fontWeight: FontWeight.w600, fontSize: 12.5, color: c.texteSecondaire),
              ),
            ]),
          ),
          if (!p.pnj && !horsJeu)
            IconButton(
              tooltip: k('tirer_pour', {'nom': p.appel.isEmpty ? (arch?.nom ?? '') : p.appel}),
              icon: Icon(Icons.toll_rounded, color: c.titre),
              onPressed: _faceAnimee == null ? () => _tirerPiece(p.id) : null,
            ),
        ]),
        if (bonus != null || (s.kids && p.pouvoir.isNotEmpty)) ...[
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 4, children: [
            if (bonus != null) PuceFace(bonus, suffixe: t.t('serie.piece.bonus')),
            if (s.kids && p.pouvoir.isNotEmpty) Chip(visualDensity: VisualDensity.compact, label: Text(p.pouvoir)),
          ]),
        ],
        if (m != null) ...[
          const SizedBox(height: 4),
          Text(m.ceQuIlFait, style: TextStyle(fontFamily: kPoliceTexte, fontWeight: FontWeight.w600, color: couleur)),
          if (m.corps.isNotEmpty)
            Text(m.corps, style: TextStyle(fontFamily: kPoliceTexte, fontSize: 12.5, color: c.texteSecondaire)),
        ],
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
        if (role != null) ...[
          const SizedBox(height: 4),
          Text(t.t('pbta.blessures.titre'), style: TextStyle(fontFamily: kPoliceTexte, fontSize: 12.5, color: c.texteSecondaire)),
          PisteBlessures(
            cases: role.blessures,
            libelles: regles.blessures(kids: s.kids),
            soigner: k('soigner'),
            onChange: (v) {
              setState(() => role.blessures = v);
              _sauver();
            },
          ),
          if (horsJeu)
            Paragraphe(s.kids ? t.t('pbta.blessures.hors_jeu_kids') : t.t('pbta.blessures.hors_jeu'), italique: true),
          if (!p.pnj) ...[
            Text(k('deux_lancers', {'liste': deuxLancers.join(' · ')}),
                style: TextStyle(fontFamily: kPoliceTexte, fontSize: 12.5, color: c.texteSecondaire)),
            const SizedBox(height: 4),
            Wrap(spacing: 6, runSpacing: 4, children: [
              if (!role.vouloirDit)
                ActionChip(
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(Icons.record_voice_over_outlined, size: 16),
                  label: Text(k('dit_vouloir')),
                  onPressed: () {
                    setState(() {
                      role
                        ..vouloirDit = true
                        ..elan = true;
                    });
                    _sauver();
                  },
                ),
              if (role.elan)
                Chip(
                  visualDensity: VisualDensity.compact,
                  avatar: Icon(Icons.auto_awesome_rounded, size: 16, color: c.titre),
                  label: Text(k('elan')),
                ),
            ]),
          ],
        ],
      ]),
    );
  }
}

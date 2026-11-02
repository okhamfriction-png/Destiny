import 'dart:async';

import 'package:flutter/material.dart';

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
import 'troupe_screen.dart';

/// Le tableau de bord de la régie : le chrono, les quatre actes, le bouton
/// Destiny (réservé à la régie), les rappels et les notes. Rien ne dépend du
/// réseau.
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

  @override
  void initState() {
    super.initState();
    if (s.destinys.isNotEmpty) _ecoule = s.destinys.last.secondes;
    widget.contexte.catalogue.getDilemmas().then((d) {
      if (mounted) setState(() => _dilemmes = [for (final x in d) if (x.dangerLie == s.dangerId) x]);
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
    final prochain = s.destinys.length;
    if (auto &&
        !_rituelEnCours &&
        prochain < s.destinyMinutes.length &&
        _ecoule >= s.destinyMinutes[prochain] * 60) {
      _destiny(manuel: false);
    }
  }

  Future<void> _destiny({required bool manuel}) async {
    if (_rituelEnCours || _palier == PalierId.supprime) return;
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

  String _horloge(int secondes) {
    final v = secondes.abs();
    return '${secondes < 0 ? '-' : ''}${(v ~/ 60).toString().padLeft(2, '0')}:${(v % 60).toString().padLeft(2, '0')}';
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
    final prochain = s.destinys.length < s.destinyMinutes.length ? s.destinyMinutes[s.destinys.length] * 60 : null;
    final reste = _total - _ecoule;

    return PageDestiny(
      titre: rg('titre'),
      actions: [
        IconButton(
          tooltip: t.t('navigation.regie_son'),
          icon: const Icon(Icons.graphic_eq_rounded),
          onPressed: () => showSoundMixer(context, widget.contexte.musique),
        ),
      ],
      enfants: [
        Text('${s.lieuNom} · ${s.dangerNom}',
            textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
        if (s.groupe.isNotEmpty)
          Text(s.groupe, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        // Le chrono.
        Center(
          child: Text(
            _horloge(reste),
            style: TextStyle(
              fontFamily: kPoliceTitres,
              fontWeight: FontWeight.w900,
              fontSize: 64,
              color: reste <= 0 ? c.famille(FamilleId.fissure) : c.titre,
            ),
          ),
        ),
        Center(
          child: Text(
            '${rg('acte', {'n': '${palier.acte}'})} · ${palier.nom} · ${palier.ambiance}',
            style: TextStyle(fontFamily: kPoliceTexte, fontWeight: FontWeight.w600, color: c.palier(_palier)),
          ),
        ),
        if (prochain != null)
          Center(
            child: Text(rg('prochain', {'t': _horloge(prochain)}),
                style: TextStyle(fontFamily: kPoliceTexte, color: c.texteSecondaire)),
          )
        else
          Center(child: Text(rg('dernier_acte'), style: TextStyle(color: c.texteSecondaire))),
        if (reste <= 0) Center(child: Paragraphe(rg('temps_ecoule'), gras: true)),
        const SizedBox(height: 12),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: c.bleuDestiny,
            foregroundColor: Colors.white,
            minimumSize: const Size(48, 64),
            textStyle: const TextStyle(fontFamily: kPoliceTitres, fontWeight: FontWeight.w900, fontSize: 22),
          ),
          onPressed: _palier == PalierId.supprime || _rituelEnCours || r.declenchement == Declenchement.automatique
              ? null
              : () => _destiny(manuel: true),
          icon: const Icon(Icons.flash_on_rounded),
          label: Text(rg('destiny').toUpperCase()),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _basculer,
          icon: Icon(_enMarche ? Icons.pause_rounded : Icons.play_arrow_rounded),
          label: Text(_enMarche ? rg('pause') : (_demarre ? rg('reprendre') : rg('demarrer'))),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(rg('destiny_aide'), textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
        ),
        const SizedBox(height: 12),
        FrisePaliers(textes: s.paliers, courant: _palier),
        if (r.rappelsRegie)
          SectionDestiny(titre: rg('rappel'), enfants: [
            if (geste != null) LigneInfo(geste.verbe, geste.consigne),
            for (final consigne in acte.consignes) Puce(consigne),
          ]),
        SectionDestiny(titre: rg('montee'), enfants: [
          for (final p in s.personnages) _monteePersonnage(context, p),
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

  Widget _monteePersonnage(BuildContext context, PersonnageTroupe p) {
    final g = context.grammaire;
    final c = context.destiny;
    final m = monteeAttendue(g, archetypeId: p.archetypeId, animalId: p.animalId, palier: _palier);
    if (m == null) return const SizedBox.shrink();
    final couleur = c.famille(m.archetype.famille);
    return CadreLisere(
      couleur: couleur,
      marge: 8,
      child: Row(children: [
        if (m.animal != null) MedaillonAnimal(m.animal!, taille: 38, source: widget.contexte.visuels.source),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              [if (p.joueur.isNotEmpty) p.joueur, m.archetype.nom].join(' · '),
              style: TextStyle(fontSize: 16, fontFamily: kPoliceTexte, fontWeight: FontWeight.w700, color: c.texte),
            ),
            Text(m.ceQuIlFait, style: TextStyle(fontFamily: kPoliceTexte, fontWeight: FontWeight.w600, color: couleur)),
            if (m.corps.isNotEmpty)
              Text(m.corps, style: TextStyle(fontFamily: kPoliceTexte, fontSize: 13.5, color: c.texteSecondaire)),
          ]),
        ),
      ]),
    );
  }
}

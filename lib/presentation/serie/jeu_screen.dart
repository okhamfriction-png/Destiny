import 'dart:async';

import 'package:flutter/material.dart';

import '../../application/services/transcription_service.dart';
import '../../domain/entities/dilemma.dart';
import '../../domain/grammaire/modeles.dart';
import '../../domain/serie/regles_serie.dart';
import '../../domain/serie/serie.dart';
import '../destiny/composants.dart';
import '../destiny/donnees.dart';
import '../destiny/page.dart';
import '../regie_son/table_regie.dart';
import '../theme/destiny_theme.dart';
import '../troupe/composants_troupe.dart';
import '../troupe/regie_screen.dart' show ouvrirRegieSon;
import '../troupe/spectacle_en_cours.dart';
import 'composants_serie.dart';
import 'contexte_serie.dart';
import 'pbta_composants.dart' show InterrupteurHorsJeu;
import 'sante_serie.dart';

/// Le jeu d'un épisode, aussi simple qu'au théâtre : le fil des étapes,
/// l'épisode (le chrono, DESTINY, et la table de régie qui s'ouvre en pop-up
/// par-dessus), le lieu et le danger, les paliers du danger, le méchant,
/// chaque personnage avec son cœur et son cerveau, les figurants et les
/// sbires, et les Destiny prévus. Pas de flèche de retour : on ne quitte pas
/// l'épisode par erreur. « Fin de l'épisode » mène au bilan, où l'IA écrit
/// le compte rendu.
class JeuEpisodeScreen extends StatefulWidget {
  const JeuEpisodeScreen({
    super.key,
    required this.contexte,
    required this.serie,
    required this.episode,
    this.ouvrirRegie = false,
  });

  final ContexteSerie contexte;
  final Serie serie;
  final EpisodeSerie episode;

  /// Arrivé par « Régie » : la table s'ouvre d'office.
  final bool ouvrirRegie;

  @override
  State<JeuEpisodeScreen> createState() => _JeuEpisodeScreenState();
}

class _JeuEpisodeScreenState extends State<JeuEpisodeScreen> {
  /// L'épisode qui se joue (le chrono, les Destiny, la conduite son) : il vit
  /// ici, la régie en pop-up ne fait que le montrer.
  late final SpectacleEnCours _sp = SpectacleEnCours(
    contexte: widget.contexte,
    session: widget.episode,
    contexteRituel: () => mounted ? context : null,
    enregistrer: _sauver,
    aLaFin: () => widget.episode.etape = EtapeEpisode.bilan,
  );
  bool _regieOuverte = false;
  List<Dilemma> _dilemmes = const [];
  TranscriptionService? _micro;
  String _microRaison = '';

  Serie get s => widget.serie;
  EpisodeSerie get e => widget.episode;

  @override
  void initState() {
    super.initState();
    for (final p in s.personnagesActifs) {
      if (e.role(p.id) == null) e.roles.add(s.nouveauRole(p.id, sauf: e));
    }
    _sp.addListener(_maj);
    widget.contexte.catalogue.getDilemmas().then((d) {
      if (!mounted) return;
      setState(() => _dilemmes = [for (final x in d) if (x.dangerLie == e.dangerId) x]);
    });
    if (e.transcrire) _demarrerMicro();
    if (widget.ouvrirRegie) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _ouvrirRegie();
      });
    }
  }

  void _maj() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _sp.removeListener(_maj);
    _sp.dispose();
    _micro?.arreter();
    super.dispose();
  }

  Future<void> _sauver() => widget.contexte.store.enregistrer(s);

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

  /// La régie : la table de régie, directement, en pop-up par-dessus le jeu
  /// (le chrono et DESTINY en haut) ; sa croix ramène ici.
  Future<void> _ouvrirRegie() async {
    if (_regieOuverte) return;
    _regieOuverte = true;
    await ouvrirRegieSon(context, widget.contexte, e, pilote: piloteDe(context, _sp));
    _regieOuverte = false;
    if (mounted) setState(() {});
  }

  Future<bool> _confirmer(String texte) async {
    final t = context.textes;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(texte),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t.t('serie.non'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(t.t('serie.oui'))),
        ],
      ),
    );
    return ok == true;
  }

  /// « Fin de l'épisode » : plus de chrono ni de son, la transcription est
  /// gardée, et l'on passe au bilan (le compte rendu de l'IA).
  Future<void> _terminer() async {
    if (!await _confirmer(context.textes.t('serie.jeu.terminer_confirmer'))) return;
    final m = _micro;
    if (m != null) {
      await m.arreter();
      e.transcription = [e.transcription, m.texte].where((x) => x.trim().isNotEmpty).join('\n').trim();
      _micro = null;
    }
    await _sp.terminer();
    if (mounted) await ouvrirEpisode(context, widget.contexte, s, e, remplacer: true);
  }

  /// Le bouton retour du téléphone : on demande avant de quitter l'épisode
  /// (il reste en cours, on le reprend depuis la fiche de la série).
  Future<void> _quitter() async {
    if (!await _confirmer(context.textes.t('serie.jeu.quitter_confirmer'))) return;
    if (mounted) Navigator.of(context).pop();
  }

  /// Revenir à la préparation (avant le premier Destiny seulement).
  Future<void> _preparer() async {
    e.etape = EtapeEpisode.preparation;
    await _sauver();
    if (mounted) await ouvrirEpisode(context, widget.contexte, s, e, remplacer: true);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.textes;
    final c = context.destiny;
    String k(String x, [Map<String, String> v = const {}]) => t.t('serie.jeu.$x', v);
    final mechant = widget.contexte.mechant(context.grammaire, e.mechantId);
    final enPersonne = mechantEnPersonne(saison: e.saison, numero: e.numero, aUnMechant: mechant != null);
    final figurants = [for (final p in e.pnjs) if (p.mode == ModePnj.figurant) p];
    final sbires = [for (final p in e.pnjs) if (p.mode == ModePnj.sbire) p];

    Widget horsJeu(PnjEpisode p) => InterrupteurHorsJeu(
          horsJeu: p.sante == Sante.sorti,
          libelle: k('hors_jeu'),
          onChange: (v) {
            setState(() => p.sante = v ? Sante.sorti : Sante.enForme);
            _sauver();
          },
        );

    void changerMode(PnjEpisode p, ModePnj m) {
      setState(() => p.mode = m);
      _sauver();
    }

    final page = PageDestiny(
      titre: e.saison > 0
          ? '${t.t('serie.saison_n', {'n': '${e.saison}'})} · ${k('titre', {'n': '${e.numero}'})}'
          : k('titre', {'n': '${e.numero}'}),
      retour: false,
      actions: [
        if (_micro?.ecoute ?? false)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Row(children: [
              Icon(Icons.mic, size: 18, color: c.famille(FamilleId.fissure)),
              const SizedBox(width: 4),
              Text(k('micro_on'), style: TextStyle(fontSize: 12, color: c.famille(FamilleId.fissure))),
            ]),
          ),
      ],
      enfants: [
        FilEpisode(
          courante: EtapeFil.jeu,
          onPreparer: e.destinys.isEmpty && !_sp.demarre ? _preparer : null,
          onRegie: _ouvrirRegie,
        ),
        const SizedBox(height: 14),
        if (_microRaison.isNotEmpty) Paragraphe(k('micro_echec', {'raison': _microRaison}), italique: true),
        if (s.kids) const Center(child: SigleKids(petit: true)),
        // L'épisode, toujours sous la main : le chrono, DESTINY, et la régie.
        SectionDestiny(titre: k('episode'), espace: 0, enfants: [
          BarrePilote(pilote: piloteDe(context, _sp)),
          const SizedBox(height: 8),
          FilledButton.icon(
            key: const ValueKey('ouvrir_regie'),
            style: FilledButton.styleFrom(
              backgroundColor: c.or,
              foregroundColor: c.surOr,
              minimumSize: const Size(48, 54),
              textStyle: const TextStyle(fontFamily: kPoliceTexte, fontWeight: FontWeight.w800, fontSize: 16),
            ),
            onPressed: _ouvrirRegie,
            icon: const Icon(Icons.play_circle_rounded),
            label: Text(t.t('echauffement.ouvrir_regie')),
          ),
        ]),
        SectionDestiny(titre: t.t('regie.scene'), enfants: [
          LieuEtDanger(catalogue: widget.contexte.catalogue, visuels: widget.contexte.visuels, session: e),
        ]),
        SectionDestiny(titre: t.t('regie.paliers'), enfants: [
          if (e.presage.isNotEmpty) ...[
            EncartReplique(e.presage, couleur: c.palier(PalierId.deNumero(e.numero.clamp(1, 4)))),
            const SizedBox(height: 8),
          ],
          FrisePaliers(textes: e.paliers, courant: _sp.palier),
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
        SectionDestiny(titre: k('personnages'), enfants: [
          for (final p in s.personnagesActifs) _personnage(p),
        ]),
        if (sbires.isNotEmpty)
          SectionDestiny(titre: k('sbires'), enfants: [
            for (final p in sbires)
              LignePnj(
                pnj: p,
                kids: s.kids,
                source: widget.contexte.visuels.source,
                onMode: (m) => changerMode(p, m),
                etat: horsJeu(p),
              ),
          ]),
        if (figurants.isNotEmpty)
          SectionDestiny(titre: k('figurants'), enfants: [
            for (final p in figurants)
              LignePnj(
                pnj: p,
                kids: s.kids,
                source: widget.contexte.visuels.source,
                onMode: (m) => changerMode(p, m),
                etat: horsJeu(p),
              ),
          ]),
        if (_sp.avecChrono)
          SectionDestiny(titre: k('destinys'), enfants: [
            FriseDestiny(
              totalSecondes: e.dureeMinutes * 60,
              ecouleSecondes: _sp.ecoule,
              curseur: _sp.demarre,
              reperes: reperesDestiny(e),
              deplacer: _sp.placer,
            ),
            const SizedBox(height: 6),
            Text(
              k('plan', {'duree': '${e.dureeMinutes}', 'liste': e.destinyMinutes.map((x) => '$x').join(' · ')}),
              style: TextStyle(fontFamily: kPoliceTexte, fontWeight: FontWeight.w600, color: c.texte),
            ),
          ]),
        // À l'acte 4, un dilemme du danger, si ça sert l'histoire.
        if (_sp.palier == PalierId.supprime && _dilemmes.isNotEmpty)
          SectionDestiny(titre: t.t('regie.dilemme'), enfants: [
            Paragraphe(t.t('regie.dilemme_aide'), italique: true),
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
        Center(
          child: OutlinedButton.icon(
            key: const ValueKey('terminer_episode'),
            onPressed: _terminer,
            icon: const Icon(Icons.flag_rounded),
            label: Text(k('terminer')),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (aSorti, _) {
        if (!aSorti) _quitter();
      },
      child: page,
    );
  }

  /// La fiche d'un personnage : son animal et son archétype, son cœur et son
  /// cerveau.
  Widget _personnage(PersonnageSerie p) {
    final g = context.grammaire;
    final t = context.textes;
    final c = context.destiny;
    final role = e.role(p.id);
    final arch = g.archetype(p.archetypeId);
    final animal = g.animal(p.animalId);
    final couleur = arch == null ? c.or : c.famille(arch.famille);
    final mort = role?.sante == Sante.sorti;
    // Sans nom ni prénom, l'archétype tient lieu de nom.
    final sansNom = p.appel.trim().isEmpty;
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
                sansNom
                    ? (arch?.nom ?? '')
                    : [p.appel, if (p.joueur.isNotEmpty && p.joueur != p.appel) '(${p.joueur})']
                        .where((x) => x.isNotEmpty)
                        .join(' '),
                style: TextStyle(
                  fontFamily: kPoliceTitres,
                  fontWeight: FontWeight.w700,
                  color: c.texte,
                  decoration: mort ? TextDecoration.lineThrough : null,
                ),
              ),
              Text(
                [if (!sansNom) arch?.nom ?? '', animal?.nom ?? '', if (p.pnj) t.t('serie.personnages.pnj')]
                    .where((x) => x.isNotEmpty)
                    .join(' · '),
                style: TextStyle(fontFamily: kPoliceTexte, fontWeight: FontWeight.w600, fontSize: 12.5, color: c.texteSecondaire),
              ),
              if (s.kids && p.pouvoir.isNotEmpty)
                Text('${t.t('serie.jeu.pouvoir')} : ${p.pouvoir}',
                    style: TextStyle(fontFamily: kPoliceTexte, fontSize: 12.5, color: c.texteSecondaire)),
            ]),
          ),
        ]),
        if (role != null) ...[
          const SizedBox(height: 8),
          PistesSante(
            cle: p.id,
            sante: role.sante,
            esprit: role.esprit,
            kids: s.kids,
            onSante: (v) {
              setState(() => role.sante = v);
              _sauver();
            },
            onEsprit: (v) {
              setState(() => role.esprit = v);
              _sauver();
            },
          ),
        ],
      ]),
    );
  }
}

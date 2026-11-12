import 'dart:async';

import 'package:flutter/material.dart';

import '../../application/son/conduite_son.dart';
import '../../application/son/lecteur_son.dart';
import '../../domain/entities/dilemma.dart';
import '../../domain/grammaire/distribution.dart';
import '../../domain/grammaire/modeles.dart';
import '../../domain/troupe/session.dart';
import '../destiny/bouton_ia.dart';
import '../destiny/composants.dart';
import '../destiny/donnees.dart';
import '../destiny/page.dart';
import '../theme/destiny_theme.dart';
import 'composants_troupe.dart';
import '../regie_son/table_regie.dart';
import 'regie_screen.dart';
import 'spectacle_en_cours.dart';
import 'troupe_screen.dart';

/// Le jeu (l'ancien échauffement) : l'écran qui porte le spectacle. Le fil
/// des étapes, le spectacle (chrono, DESTINY, et la régie qui s'ouvre en
/// pop-up par-dessus), le minuteur d'échauffement, le lieu et le danger, les
/// paliers du danger, chaque archétype en petit rectangle, et les Destiny
/// prévus, qu'on fait glisser sur la frise. Pas de flèche de retour : on ne
/// quitte pas le spectacle par erreur.
class EchauffementScreen extends StatefulWidget {
  const EchauffementScreen({super.key, required this.contexte, required this.session});

  final ContexteTroupe contexte;
  final SessionTroupe session;

  @override
  State<EchauffementScreen> createState() => _EchauffementScreenState();
}

class _EchauffementScreenState extends State<EchauffementScreen> {
  late int _reste = widget.contexte.reglages.minuteurEchauffement * 60;
  Timer? _minuteur;

  /// Le spectacle (le chrono, les Destiny, la conduite son) : il vit ici, la
  /// régie en pop-up ne fait que le montrer.
  late final SpectacleEnCours _sp = SpectacleEnCours(
    contexte: widget.contexte,
    session: widget.session,
    contexteRituel: () => mounted ? context : null,
  );
  bool _regieOuverte = false;
  List<Dilemma> _dilemmes = const [];

  @override
  void initState() {
    super.initState();
    _sp.addListener(_maj);
    widget.contexte.catalogue.getDilemmas().then((d) {
      if (!mounted) return;
      setState(() => _dilemmes = [
            for (final x in d)
              if (x.dangerLie == widget.session.dangerId) x,
          ]);
    });
    // Arrivé par « Régie » (ou une régie reprise) : elle s'ouvre d'office.
    if (widget.session.etape == EtapeSession.regie) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _ouvrirRegie();
      });
    }
  }

  void _maj() {
    if (mounted) setState(() {});
  }

  /// La régie : la table de régie, directement, en pop-up par-dessus le jeu
  /// (le chrono et DESTINY en haut) ; sa croix ramène ici.
  Future<void> _ouvrirRegie() async {
    if (_regieOuverte) return;
    _regieOuverte = true;
    final s = widget.session;
    if (s.etape != EtapeSession.regie) {
      s.etape = EtapeSession.regie;
      await widget.contexte.store.enregistrer(s);
    }
    if (!mounted) return;
    await ouvrirRegieSon(context, widget.contexte, s, pilote: piloteDe(context, _sp));
    _regieOuverte = false;
    if (mounted) setState(() {});
  }

  /// « Terminer » : le spectacle s'arrête, il est rangé dans l'historique, et
  /// l'on revient à l'accueil (pas de débrief).
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

  /// Le bouton retour du téléphone : on demande avant de quitter le spectacle.
  Future<void> _quitter() async {
    final t = context.textes;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(t.t('troupe.quitter_confirmer')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t.t('troupe.non'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(t.t('troupe.oui'))),
        ],
      ),
    );
    if (ok == true && mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }

  bool get _enMarche => _minuteur?.isActive ?? false;

  void _basculer() {
    if (_enMarche) {
      _minuteur?.cancel();
      // En pause, la musique de l'échauffement sort en fondu.
      unawaited(widget.contexte.regieSon?.conduite.couperMusique());
      setState(() {});
      return;
    }
    _musique();
    _minuteur = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _reste = (_reste - 1).clamp(0, 1 << 30));
      if (_reste == 0) {
        t.cancel();
        widget.contexte.audio.playShine();
        unawaited(widget.contexte.regieSon?.conduite.couperMusique(fondu: 3));
      }
    });
    setState(() {});
  }

  /// La musique de l'échauffement (réglage de la régie son), lancée avec le
  /// minuteur : l'ambiance du lieu par défaut. Elle continue jusqu'à la
  /// régie, où l'ouverture du spectacle la fait sortir en fondu.
  void _musique() {
    final regie = widget.contexte.regieSon;
    if (regie == null || widget.contexte.audio.muted) return;
    final c = regie.conduite;
    final s = widget.session;
    final v = regie.reglages.v;
    c.preparer(lieuId: s.lieuId, dangerId: s.dangerId, acte: s.palierAtteint);
    SourceSon? source;
    switch (v.musiqueEchauffement) {
      case 'aucune':
        return;
      case 'acte1':
        final chemin = c.musiqueDe(1).chemin;
        if (chemin != null) source = SourcePack(chemin, titre: c.titreMusique(1));
      case 'lieu':
        final nom = s.lieuNom.trim().toLowerCase();
        for (final p in widget.contexte.musique.tracks) {
          if (p.category == 'Lieux' && p.title.trim().toLowerCase() == nom) {
            source = SourceAsset(p.file, titre: p.title);
          }
        }
      default:
        source = SourceAsset(v.musiqueEchauffement, titre: v.musiqueEchauffement.split('/').last);
    }
    // Déjà en train de jouer (reprise après une pause) : on ne relance pas.
    final enCours = c.lecteurs[BusSon.musique]!.enCours;
    if (source == null || enCours?.cle == source.cle) return;
    c.jouerMusique(source, volume: v.volumeEchauffement, fondu: 3);
  }

  @override
  void dispose() {
    _minuteur?.cancel();
    _sp.removeListener(_maj);
    _sp.dispose();
    super.dispose();
  }

  /// Le coach d'échauffement : des idées pour les trois questions.
  Future<void> _idees(String archetypeId, String animalId) async {
    final idees = await widget.contexte.ia!
        .echauffement(archetypeId: archetypeId, animalId: animalId, kids: widget.session.kids);
    if (!mounted) return;
    final t = context.textes;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (ctx, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.all(16),
          children: [
            Text(t.t('ia_jeu.idees_titre'), style: Theme.of(ctx).textTheme.titleLarge, textAlign: TextAlign.center),
            for (final q in idees)
              SectionDestiny(titre: q.question, enfants: [for (final i in q.idees) Puce(i)]),
          ],
        ),
      ),
    );
  }

  /// Changer l'archétype d'un personnage à la main ; son animal repart à
  /// zéro. Si la distribution n'est plus équilibrée, on le dit, sans bloquer.
  Future<void> _changerArchetype(PersonnageTroupe p) async {
    final id = await choisirArchetype(context);
    if (id == null || id == p.archetypeId || !mounted) return;
    setState(() {
      p.archetypeId = id;
      p.animalId = '';
    });
    await widget.contexte.store.enregistrer(widget.session);
    if (!mounted) return;
    final g = context.grammaire;
    final t = context.textes;
    final verdict = validerDistribution(
      g,
      [for (final x in widget.session.personnages) x.archetypeId],
      leaderObligatoire: widget.contexte.reglages.leaderObligatoire,
    );
    if (verdict.valide) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(verdict.raison(g, t)), duration: const Duration(seconds: 5)));
  }

  /// Fait glisser un Destiny sur la frise : mêmes règles qu'à la régie.
  bool _placer(int index, int minute) => _sp.placer(index, minute);

  @override
  Widget build(BuildContext context) {
    final t = context.textes;
    final c = context.destiny;
    final m = _reste ~/ 60;
    final s = _reste % 60;
    final session = widget.session;
    final page = PageDestiny(
      titre: t.t('echauffement.titre'),
      retour: false,
      enfants: [
        FilEtapes(
          contexte: widget.contexte,
          session: session,
          courante: EtapeSession.echauffement,
          onRegie: _ouvrirRegie,
        ),
        const SizedBox(height: 14),
        // Le spectacle, toujours sous la main : le chrono, DESTINY, et la régie.
        SectionDestiny(titre: t.t('echauffement.spectacle'), espace: 0, enfants: [
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
        const SizedBox(height: 18),
        Paragraphe(t.t('echauffement.intro')),
        Center(
          child: Text(
            t.t('echauffement.temps').toUpperCase(),
            style: TextStyle(
              fontFamily: kPoliceTexte,
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
              letterSpacing: 1.4,
              color: c.texteSecondaire,
            ),
          ),
        ),
        Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}',
              style: TextStyle(fontFamily: kPoliceTitres, fontWeight: FontWeight.w900, fontSize: 56, color: c.titre),
            ),
          ),
        ),
        if (_reste == 0) Center(child: Paragraphe(t.t('echauffement.fini'), gras: true)),
        Center(
          child: OutlinedButton.icon(
            onPressed: _reste == 0 ? null : _basculer,
            icon: Icon(_enMarche ? Icons.pause_rounded : Icons.timer_outlined),
            label: Text(_enMarche
                ? t.t('echauffement.pause')
                : (_reste < widget.contexte.reglages.minuteurEchauffement * 60
                    ? t.t('echauffement.reprendre')
                    : t.t('echauffement.demarrer'))),
          ),
        ),
        SectionDestiny(titre: t.t('regie.scene'), enfants: [
          LieuEtDanger(contexte: widget.contexte, session: session),
        ]),
        SectionDestiny(titre: t.t('regie.paliers'), enfants: [
          FrisePaliers(textes: session.paliers, courant: _sp.palier),
        ]),
        SectionDestiny(titre: t.t('echauffement.personnages'), enfants: [
          for (final p in widget.session.personnages)
            RectangleArchetype(
              personnage: p,
              contexte: widget.contexte,
              reactions: true,
              onChanger: () => _changerArchetype(p),
              pied: widget.contexte.ia?.disponible == true && p.archetypeId.isNotEmpty
                  ? BoutonIA(
                      libelle: t.t('ia_jeu.idees_echauffement'),
                      disponible: widget.contexte.ia!.disponible,
                      action: () => _idees(p.archetypeId, p.animalId),
                    )
                  : null,
            ),
        ]),
        SectionDestiny(titre: t.t('echauffement.destinys'), enfants: [
          FriseDestiny(
            totalSecondes: session.dureeMinutes * 60,
            ecouleSecondes: _sp.ecoule,
            curseur: _sp.demarre,
            reperes: reperesDestiny(session),
            deplacer: _placer,
          ),
          const SizedBox(height: 6),
          Text(
            t.t('echauffement.plan', {
              'duree': '${session.dureeMinutes}',
              'liste': session.destinyMinutes.map((x) => '$x').join(' · '),
            }),
            key: const ValueKey('plan_destiny'),
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
            key: const ValueKey('terminer_spectacle'),
            onPressed: _terminer,
            icon: const Icon(Icons.flag_rounded),
            label: Text(t.t('regie.terminer')),
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
}

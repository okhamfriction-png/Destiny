import 'dart:async';

import 'package:flutter/material.dart';

import '../../application/son/conduite_son.dart';
import '../../application/son/lecteur_son.dart';
import '../../domain/grammaire/distribution.dart';
import '../../domain/troupe/session.dart';
import '../destiny/bouton_ia.dart';
import '../destiny/donnees.dart';
import '../destiny/page.dart';
import '../theme/destiny_theme.dart';
import 'composants_troupe.dart';
import 'regie_screen.dart';
import 'troupe_screen.dart';

/// L'échauffement : le fil des étapes (la régie à un appui), le minuteur
/// (30 minutes par défaut), le lieu et le danger, chaque archétype en petit
/// rectangle (sa fiche à portée d'une bulle d'info), et les Destiny prévus,
/// qu'on fait glisser sur la frise.
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
  bool _placer(int index, int minute) {
    final s = widget.session;
    if (refusDestiny(s, index: index, minute: minute, ecouleSecondes: 0) != null) return false;
    setState(() => s.destinyMinutes = [...s.destinyMinutes]..[index] = minute);
    widget.contexte.store.enregistrer(s);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.textes;
    final c = context.destiny;
    final m = _reste ~/ 60;
    final s = _reste % 60;
    final session = widget.session;
    return PageDestiny(
      titre: t.t('echauffement.titre'),
      enfants: [
        FilEtapes(contexte: widget.contexte, session: session, courante: EtapeSession.echauffement),
        const SizedBox(height: 14),
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
            ecouleSecondes: 0,
            curseur: false,
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
        const SizedBox(height: 12),
      ],
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/troupe/session.dart';
import '../destiny/bouton_ia.dart';
import '../destiny/composants.dart';
import '../destiny/donnees.dart';
import '../destiny/page.dart';
import '../theme/destiny_theme.dart';
import 'composants_troupe.dart';
import 'regie_screen.dart';
import 'troupe_screen.dart';

/// L'échauffement : le fil des étapes (la régie à un appui), le minuteur
/// (30 minutes par défaut), le lieu et le danger, la régie son pour
/// s'échauffer en musique, les trois questions, chaque archétype en petit
/// rectangle (sa fiche à portée d'une bulle d'info) et les Destiny prévus.
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
      setState(() {});
      return;
    }
    _minuteur = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _reste = (_reste - 1).clamp(0, 1 << 30));
      if (_reste == 0) {
        t.cancel();
        widget.contexte.audio.playShine();
      }
    });
    setState(() {});
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

  @override
  Widget build(BuildContext context) {
    final g = context.grammaire;
    final t = context.textes;
    final c = context.destiny;
    final e = g.personnage.echauffement;
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
        TabletteSon(contexte: widget.contexte, session: session),
        SectionDestiny(titre: t.t('bibliotheque.regles.questions'), enfants: [
          for (final (i, q) in e.questions.indexed) Puce(q, numero: i + 1),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.or),
            ),
            child: Paragraphe(e.limite, italique: true),
          ),
        ]),
        SectionDestiny(titre: t.t('echauffement.personnages'), enfants: [
          for (final p in widget.session.personnages)
            RectangleArchetype(
              personnage: p,
              contexte: widget.contexte,
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
          ),
          const SizedBox(height: 6),
          Text(
            t.t('echauffement.plan', {
              'duree': '${session.dureeMinutes}',
              'liste': session.destinyMinutes.map((x) => '$x').join(' · '),
            }),
            style: TextStyle(fontFamily: kPoliceTexte, fontWeight: FontWeight.w600, color: c.texte),
          ),
          Paragraphe(t.t('echauffement.destinys_aide'), italique: true),
        ]),
        const SizedBox(height: 22),
        FilledButton.icon(
          icon: const Icon(Icons.wb_sunny_outlined),
          onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(
              builder: (_) => AvantSceneScreen(contexte: widget.contexte, session: widget.session))),
          label: Text(t.t('echauffement.vers_avant_scene')),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          icon: const Icon(Icons.play_circle_rounded),
          onPressed: () => allerAEtape(context, widget.contexte, session, EtapeSession.regie),
          label: Text(t.t('echauffement.vers_regie')),
        ),
      ],
    );
  }
}

/// Avant d'entrer en scène : un écran qui donne envie de jouer. La
/// distribution, les règles d'or, les quatre paliers, la phrase des débriefs.
/// Jamais de critique.
class AvantSceneScreen extends StatelessWidget {
  const AvantSceneScreen({super.key, required this.contexte, required this.session});

  final ContexteTroupe contexte;
  final SessionTroupe session;

  @override
  Widget build(BuildContext context) {
    final g = context.grammaire;
    final t = context.textes;
    final c = context.destiny;
    return PageDestiny(
      titre: t.t('avant_scene.titre'),
      enfants: [
        FilEtapes(contexte: contexte, session: session, courante: EtapeSession.echauffement),
        const SizedBox(height: 14),
        BandeauAffiche(titre: g.promesse.toUpperCase(), sousTitre: t.t('avant_scene.message')),
        SectionDestiny(titre: t.t('avant_scene.distribution'), enfants: [
          for (final p in session.personnages) RectangleArchetype(personnage: p, contexte: contexte),
        ]),
        SectionDestiny(titre: t.t('bibliotheque.regles.regles_d_or'), enfants: [
          for (final r in g.reglesDOr) Puce(r.titre),
        ]),
        SectionDestiny(titre: t.t('bibliotheque.regles.paliers'), enfants: const [FrisePaliers()]),
        SectionDestiny(titre: t.t('bibliotheque.vouloir_besoin.phrase_cle'), enfants: [
          EncartReplique(g.personnage.phraseCle, couleur: c.bleuDestiny, taille: 15),
        ]),
        const SizedBox(height: 24),
        FilledButton.icon(
          icon: const Icon(Icons.theater_comedy_rounded),
          onPressed: () async {
            session.etape = EtapeSession.miseEnPlace;
            await contexte.store.enregistrer(session);
            if (context.mounted) ouvrirEtape(context, contexte, session, remplacer: true);
          },
          label: Text(t.t('avant_scene.entrer')),
        ),
      ],
    );
  }
}

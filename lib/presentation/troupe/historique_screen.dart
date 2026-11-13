import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../application/services/export_pdf.dart';
import '../../domain/grammaire/modeles.dart';
import '../../domain/troupe/session.dart';
import '../destiny/composants.dart';
import '../destiny/donnees.dart';
import '../destiny/page.dart';
import '../theme/destiny_theme.dart';
import 'composants_troupe.dart';
import 'troupe_screen.dart';

String _date(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

/// L'historique des spectacles et des répétitions.
class HistoriqueScreen extends StatelessWidget {
  const HistoriqueScreen({super.key, required this.contexte});

  final ContexteTroupe contexte;

  @override
  Widget build(BuildContext context) {
    final t = context.textes;
    return ListenableBuilder(
      listenable: contexte.store,
      builder: (context, _) {
        final sessions = contexte.store.sessions;
        return PageDestiny(
          titre: t.t('historique.titre'),
          enfants: [
            if (sessions.isEmpty) Paragraphe(t.t('historique.vide'), italique: true),
            for (final s in sessions)
              ElementListe(
                titre: '${t.t('troupe.types.${s.type.name}')} · ${_date(s.date)}',
                sousTitre: [
                  [s.lieuNom, s.dangerNom].where((x) => x.isNotEmpty).join(' · '),
                  if (s.etape != EtapeSession.terminee) t.t('troupe.etapes.${s.etape.name}'),
                ].where((x) => x.isNotEmpty).join('\n'),
                apres: s.kids ? const SigleKids(petit: true) : null,
                onTap: () => ouvrirEtape(context, contexte, s),
              ),
          ],
        );
      },
    );
  }
}

/// La fiche d'un spectacle terminé, avec l'export PDF.
class FicheSession extends StatelessWidget {
  const FicheSession({super.key, required this.contexte, required this.session});

  final ContexteTroupe contexte;
  final SessionTroupe session;

  Future<void> _exporter(BuildContext context) async {
    final g = context.grammaire;
    final t = context.textes;
    final polices = await PolicesPdf.chargerDepuisAssets();
    final octets = await fichePdfSession(s: session, g: g, t: t, polices: polices);
    await Printing.sharePdf(bytes: octets, filename: 'destiny-${session.date.toIso8601String().substring(0, 10)}.pdf');
  }

  Future<void> _supprimer(BuildContext context) async {
    final t = context.textes;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(t.t('historique.supprimer_confirmer')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t.t('troupe.non'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(t.t('troupe.oui'))),
        ],
      ),
    );
    if (ok == true) {
      await contexte.store.supprimer(session.id);
      if (context.mounted) Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = context.grammaire;
    final t = context.textes;
    final c = context.destiny;
    final s = session;
    return PageDestiny(
      titre: '${t.t('troupe.types.${s.type.name}')} · ${_date(s.date)}',
      actions: [
        IconButton(
          tooltip: t.t('historique.exporter'),
          icon: const Icon(Icons.picture_as_pdf_outlined),
          onPressed: () => _exporter(context),
        ),
        IconButton(
          tooltip: t.t('historique.supprimer'),
          icon: const Icon(Icons.delete_outline_rounded),
          onPressed: () => _supprimer(context),
        ),
      ],
      enfants: [
        SectionDestiny(titre: t.t('historique.mise_en_place'), espace: 0, enfants: [
          LieuEtDanger.troupe(contexte: contexte, session: s),
          LigneInfo(t.t('mise_en_place.groupe'), s.groupe),
          FrisePaliers(textes: s.paliers, courant: PalierId.deNumero(s.palierAtteint)),
          LigneInfo(t.t('mise_en_place.mystere'), s.mystere),
          LigneInfo(t.t('mise_en_place.reponse'), s.reponseMystere, italique: true),
        ]),
        SectionDestiny(titre: t.t('historique.distribution'), enfants: [
          for (final p in s.personnages)
            CadreLisere(
              couleur: g.archetype(p.archetypeId) == null ? c.or : c.famille(g.archetype(p.archetypeId)!.famille),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                EnteteArchetype(personnage: p, contexte: contexte, kids: s.kids),
                const SizedBox(height: 8),
                LigneInfo(t.t('debrief.groupe'), [p.groupeVeut, p.groupeBesoin].where((x) => x.isNotEmpty).join(' / ')),
                LigneInfo(t.t('debrief.fixe'), [p.fixeVeut, p.fixeBesoin].where((x) => x.isNotEmpty).join(' / ')),
                LigneInfo(
                  t.t('debrief.choix'),
                  switch (p.choixFinal) {
                    ChoixFinal.vouloir => t.t('debrief.choix_vouloir'),
                    ChoixFinal.besoin => t.t('debrief.choix_besoin'),
                    ChoixFinal.aucun => '',
                  },
                ),
                LigneInfo(t.t('debrief.prix'), p.prixPaye),
              ]),
            ),
        ]),
        if (s.notes.isNotEmpty)
          SectionDestiny(titre: t.t('regie.notes'), enfants: [
            for (final n in s.notes) LigneInfo(n.horodatage, n.texte),
          ]),
        if (s.ceQuiAMarche.isNotEmpty)
          SectionDestiny(titre: t.t('debrief.ce_qui_a_marche'), enfants: [
            for (final m in s.ceQuiAMarche) Puce(m),
          ]),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: () => _exporter(context),
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: Text(t.t('historique.exporter')),
        ),
      ],
    );
  }
}

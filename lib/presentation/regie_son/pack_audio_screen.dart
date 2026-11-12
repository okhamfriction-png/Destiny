import 'package:flutter/material.dart';

import '../../application/son/pack_audio.dart';
import '../../application/son/regie_son.dart';
import '../../domain/son/manifeste_audio.dart';
import '../../domain/son/resolution_son.dart';
import '../destiny/donnees.dart';
import '../destiny/page.dart';

/// « Pack audio du spectacle » : importer les musiques et les bruitages
/// (un dossier ou un .zip) dans l'appli, puis voir ce qu'ils couvrent. Au
/// spectacle, le téléphone n'a pas le NAS : tout doit être importé avant.
class PackAudioScreen extends StatelessWidget {
  const PackAudioScreen({super.key, required this.regieSon});

  final RegieSon regieSon;

  PackAudio get _pack => regieSon.pack;

  Future<void> _importer(BuildContext context, Future<ResultatImport> Function() importer) async {
    final t = context.textes;
    String k(String x, [Map<String, String> v = const {}]) => t.t('regie_son.pack.$x', v);
    final r = await importer();
    if (!context.mounted || r.erreur == 'annule') return;
    final message = switch (r.erreur) {
      null => k('importe', {'copies': '${r.copies}', 'deja': '${r.dejaLa}'}),
      'vide' => k('import_vide'),
      'web' => k('import_web'),
      _ => k('import_erreur', {'copies': '${r.copies}'}),
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 5)));
  }

  Future<void> _supprimer(BuildContext context) async {
    final t = context.textes;
    String k(String x, [Map<String, String> v = const {}]) => t.t('regie_son.pack.$x', v);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(k('supprimer_confirmer')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t.t('troupe.non'))),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(t.t('troupe.oui'))),
        ],
      ),
    );
    if (ok == true) await _pack.supprimer();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.textes;
    String k(String x, [Map<String, String> v = const {}]) => t.t('regie_son.pack.$x', v);
    return ListenableBuilder(
      listenable: Listenable.merge([_pack, regieSon.reglages]),
      builder: (context, _) {
        final m = _pack.manifeste;
        final bilan = _pack.bilan(repliFamille: regieSon.reglages.v.repliFamille);
        String noms(List<String> ids) => ids.map((id) => m?.lieux[id]?.nom ?? id).join(' · ');
        String sons(List<String> codes) => codes.map((c) => m?.sons[c]?.nom ?? c).join(' · ');
        return PageDestiny(
          titre: k('titre'),
          enfants: [
            SectionDestiny(titre: k('etat'), espace: 0, enfants: [
              Paragraphe(k('aide')),
              LigneInfo(
                k('fichiers'),
                _pack.disponible ? k('fichiers_n', {'n': '${_pack.index.chemins.length}'}) : k('aucun_fichier'),
              ),
              if (m != null)
                LigneInfo(k('manifeste'),
                    _pack.manifesteDuPack ? k('manifeste_pack', {'v': '${m.version}'}) : k('manifeste_appli', {'v': '${m.version}'})),
              if (_pack.importEnCours) ...[
                const SizedBox(height: 8),
                const LinearProgressIndicator(),
                Paragraphe(k('import_en_cours', {'n': '${_pack.importTraites}'}), italique: true),
              ],
            ]),
            SectionDestiny(titre: k('importer'), enfants: [
              if (!_pack.importPossible) Paragraphe(k('import_web'), italique: true),
              Wrap(spacing: 10, runSpacing: 8, children: [
                FilledButton.icon(
                  key: const ValueKey('importer_zip'),
                  onPressed: !_pack.importPossible || _pack.importEnCours ? null : () => _importer(context, _pack.importerZip),
                  icon: const Icon(Icons.folder_zip_rounded),
                  label: Text(k('importer_zip')),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('importer_dossier'),
                  onPressed:
                      !_pack.importPossible || _pack.importEnCours ? null : () => _importer(context, _pack.importerDossier),
                  icon: const Icon(Icons.folder_open_rounded),
                  label: Text(k('importer_dossier')),
                ),
              ]),
              const SizedBox(height: 6),
              Paragraphe(k('importer_aide'), italique: true),
            ]),
            if (bilan != null && _pack.disponible)
              SectionDestiny(titre: k('bilan'), enfants: [
                _LigneBilan(Icons.music_note_rounded, k('lieux_propres', {'n': '${bilan.lieuxPropres.length}'}),
                    noms(bilan.lieuxPropres)),
                _LigneBilan(Icons.call_split_rounded, k('lieux_famille', {'n': '${bilan.lieuxFamille.length}'}),
                    noms(bilan.lieuxFamille)),
                if (bilan.lieuxSansMusique.isNotEmpty)
                  _LigneBilan(Icons.music_off_rounded, k('lieux_muets', {'n': '${bilan.lieuxSansMusique.length}'}),
                      noms(bilan.lieuxSansMusique),
                      alerte: true),
                if (bilan.sonsRemplaces.isNotEmpty)
                  _LigneBilan(Icons.swap_horiz_rounded, k('sons_remplaces', {'n': '${bilan.sonsRemplaces.length}'}),
                      _remplacements(bilan, m!)),
                _LigneBilan(
                  Icons.graphic_eq_rounded,
                  k('sons_manquants', {'n': '${bilan.sonsManquants.length}'}),
                  bilan.sonsManquants.isEmpty ? k('rien') : sons(bilan.sonsManquants),
                  alerte: bilan.sonsManquants.isNotEmpty,
                ),
                _LigneBilan(Icons.visibility_rounded, k('stingers', {'n': '${bilan.stingers}'}), ''),
              ]),
            if (_pack.disponible && _pack.importPossible)
              SectionDestiny(titre: k('supprimer'), enfants: [
                OutlinedButton.icon(
                  onPressed: () => _supprimer(context),
                  icon: const Icon(Icons.delete_outline_rounded),
                  label: Text(k('supprimer')),
                ),
              ]),
          ],
        );
      },
    );
  }

  String _remplacements(BilanPack b, ManifesteAudio m) => [
        for (final code in b.sonsRemplaces) '${m.sons[code]?.nom ?? code} → ${m.sons[m.remplacements[code]]?.nom ?? '—'}',
      ].join(' · ');
}

class _LigneBilan extends StatelessWidget {
  const _LigneBilan(this.icone, this.titre, this.detail, {this.alerte = false});

  final IconData icone;
  final String titre;
  final String detail;
  final bool alerte;

  @override
  Widget build(BuildContext context) {
    final couleur = alerte ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icone, color: couleur, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(titre, style: Theme.of(context).textTheme.titleSmall),
            if (detail.isNotEmpty) Text(detail, style: Theme.of(context).textTheme.bodySmall),
          ]),
        ),
      ]),
    );
  }
}

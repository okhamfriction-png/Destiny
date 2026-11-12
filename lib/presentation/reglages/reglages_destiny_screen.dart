import 'package:flutter/material.dart';

import '../../application/services/audio_service.dart';
import '../../application/son/regie_son.dart';
import '../../application/state/music_controller.dart';
import '../../application/state/reglages_destiny.dart';
import '../../domain/grammaire/chronos.dart';
import '../destiny/donnees.dart';
import '../destiny/page.dart';
import '../regie_son/pack_audio_screen.dart';
import '../regie_son/regie_son_screen.dart';
import '../theme/destiny_theme.dart';

/// Les réglages de Destiny : les chronos, le déclenchement et le rituel, les
/// musiques des quatre moments, la distribution, le jeu de rôle,
/// l'échauffement et les cartes. Tout est gardé tant qu'on ne le change pas.
class ReglagesDestinyScreen extends StatelessWidget {
  const ReglagesDestinyScreen(
      {super.key, required this.reglages, required this.audio, required this.musique, this.regieSon});

  final ReglagesDestiny reglages;
  final AudioService audio;
  final MusicController musique;

  /// La régie son du spectacle (pack audio et conduite automatique).
  final RegieSon? regieSon;

  @override
  Widget build(BuildContext context) {
    final t = context.textes;
    String k(String x, [Map<String, String> v = const {}]) => t.t('reglages.$x', v);
    return ListenableBuilder(
      listenable: Listenable.merge([reglages, musique]),
      builder: (context, _) {
        final r = reglages;
        return PageDestiny(
          titre: k('destiny'),
          enfants: [
            SectionDestiny(titre: k('chronos'), espace: 0, enfants: [
              Text(k('chronos_aide'), style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              for (var i = 0; i < r.chronos.length; i++) _EditeurChrono(reglages: r, index: i),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: r.remettreChronos,
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: Text(k('remettre')),
                ),
              ),
            ]),
            SectionDestiny(titre: k('declenchement'), enfants: [
              Wrap(spacing: 8, runSpacing: 6, children: [
                for (final d in Declenchement.values)
                  ChoiceChip(
                    label: Text(k('declenchements.${d.name}')),
                    selected: r.declenchement == d,
                    onSelected: (_) => r.changer(declenchement: d),
                  ),
              ]),
              const SizedBox(height: 4),
              Text(k('declenchement_aide'), style: Theme.of(context).textTheme.bodySmall),
            ]),
            SectionDestiny(titre: k('rituel'), enfants: [
              _Bascule(k('lumiere_bleue'), r.lumiereBleue, (v) => r.changer(lumiereBleue: v)),
              Text(k('duree_fige', {'n': '${r.dureeFigeSecondes}'})),
              Slider(
                value: r.dureeFigeSecondes.toDouble(),
                min: 2,
                max: 10,
                divisions: 8,
                label: '${r.dureeFigeSecondes} s',
                onChanged: (v) => r.changer(dureeFigeSecondes: v.round()),
              ),
              _ChampTexte(
                libelle: k('texte_ellipse'),
                aide: k('texte_ellipse_aide', {'defaut': t.t('rituel.texte_ellipse')}),
                valeur: r.texteEllipse,
                onChange: (v) => r.changer(texteEllipse: v.trim()),
              ),
              _Bascule(k('rappel_premier_fige'), r.rappelPremierFige, (v) => r.changer(rappelPremierFige: v)),
              _Bascule(k('rappels_regie'), r.rappelsRegie, (v) => r.changer(rappelsRegie: v)),
              _Bascule(k('reduire_animations'), r.reduireAnimations, (v) => r.changer(reduireAnimations: v)),
            ]),
            SectionDestiny(titre: k('musiques'), enfants: [
              Text(k('musiques_aide'), style: Theme.of(context).textTheme.bodySmall),
              // La musique de chaque acte : au début, puis après chaque Destiny.
              for (final (i, libelle) in t.liste('reglages.musiques_actes').indexed)
                _ChoixMusiqueLigne(
                  key: ValueKey('musique_acte_${i + 1}'),
                  libelle: libelle,
                  valeur: r.musiqueActe(i + 1),
                  musique: musique,
                  onChoix: (v) => r.changerMusiqueActe(i + 1, v),
                ),
              _ChoixSon(libelle: k('son_destiny'), valeur: r.sonDestiny, audio: audio, onChoix: (v) => r.changer(sonDestiny: v)),
              const SizedBox(height: 8),
              Text(k('musique_destiny'), style: Theme.of(context).textTheme.titleSmall),
              Wrap(spacing: 8, runSpacing: 6, children: [
                ChoiceChip(
                  label: Text(k('aucune')),
                  selected: r.musiqueDestiny == ChoixMusique.aucune,
                  onSelected: (_) => r.changer(musiqueDestiny: ChoixMusique.aucune),
                ),
                ChoiceChip(
                  label: Text(k('au_hasard')),
                  selected: r.musiqueDestiny == ChoixMusique.aleatoire,
                  onSelected: (_) => r.changer(musiqueDestiny: ChoixMusique.aleatoire),
                ),
                for (final m in musique.importees)
                  ChoiceChip(
                    label: Text(m.nom),
                    selected: r.musiqueDestiny == m.chemin,
                    onSelected: (_) => r.changer(musiqueDestiny: m.chemin),
                  ),
              ]),
              const SizedBox(height: 8),
              _MusiquesImportees(musique: musique, reglages: r),
              _Bascule(k('regie_son'), r.regieSon, (v) => r.changer(regieSon: v), aide: k('regie_son_aide')),
              if (regieSon != null) ...[
                const SizedBox(height: 4),
                ListTile(
                  key: const ValueKey('ouvrir_regie_son_spectacle'),
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.tune_rounded),
                  title: Text(t.t('regie_son.r.titre')),
                  subtitle: Text(t.t('regie_son.r.entree_aide')),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => RegieSonScreen(regieSon: regieSon!, musique: musique))),
                ),
                ListTile(
                  key: const ValueKey('ouvrir_pack_audio'),
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.library_music_rounded),
                  title: Text(t.t('regie_son.pack.titre')),
                  subtitle: Text(t.t('regie_son.pack.entree_aide')),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context)
                      .push(MaterialPageRoute<void>(builder: (_) => PackAudioScreen(regieSon: regieSon!))),
                ),
              ],
            ]),
            SectionDestiny(titre: k('distribution'), enfants: [
              Text(k('joueurs'), style: Theme.of(context).textTheme.titleSmall),
              Wrap(spacing: 8, children: [
                for (final n in [3, 4, 5, 6])
                  ChoiceChip(
                    label: Text('$n'),
                    selected: r.joueursParDefaut == n,
                    onSelected: (_) => r.changer(joueursParDefaut: n),
                  ),
              ]),
              const SizedBox(height: 8),
              Text(k('mode_distribution'), style: Theme.of(context).textTheme.titleSmall),
              Wrap(spacing: 8, runSpacing: 6, children: [
                for (final m in ['concerte', 'tirage', 'exemple'])
                  ChoiceChip(
                    label: Text(t.t('distribution.modes.$m')),
                    selected: r.modeDistribution == m,
                    onSelected: (_) => r.changer(modeDistribution: m),
                  ),
              ]),
              _Bascule(k('leader_obligatoire'), r.leaderObligatoire, (v) => r.changer(leaderObligatoire: v)),
            ]),
            SectionDestiny(titre: k('jeu_de_role'), enfants: [
              _Bascule(k('registre_defaut'), r.registreParDefaut, (v) => r.changer(registreParDefaut: v)),
            ]),
            SectionDestiny(titre: k('echauffement'), enfants: [
              Text(k('minuteur', {'n': '${r.minuteurEchauffement}'})),
              Slider(
                value: r.minuteurEchauffement.toDouble().clamp(10, 60),
                min: 10,
                max: 60,
                divisions: 10,
                label: '${r.minuteurEchauffement} min',
                onChanged: (v) => r.changer(minuteurEchauffement: v.round()),
              ),
            ]),
            SectionDestiny(titre: k('cartes'), enfants: [
              _Bascule(k('repliques'), r.afficherRepliques, (v) => r.changer(afficherRepliques: v)),
            ]),
          ],
        );
      },
    );
  }
}

class _Bascule extends StatelessWidget {
  const _Bascule(this.libelle, this.valeur, this.onChange, {this.aide});

  final String libelle;
  final bool valeur;
  final ValueChanged<bool> onChange;
  final String? aide;

  @override
  Widget build(BuildContext context) => SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(libelle),
        subtitle: aide == null ? null : Text(aide!),
        value: valeur,
        onChanged: onChange,
      );
}

/// Un champ texte qui garde sa valeur pendant qu'on tape.
class _ChampTexte extends StatefulWidget {
  const _ChampTexte({required this.libelle, required this.valeur, required this.onChange, this.aide});

  final String libelle;
  final String valeur;
  final String? aide;
  final ValueChanged<String> onChange;

  @override
  State<_ChampTexte> createState() => _ChampTexteState();
}

class _ChampTexteState extends State<_ChampTexte> {
  late final TextEditingController _c = TextEditingController(text: widget.valeur);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
        controller: _c,
        decoration: InputDecoration(labelText: widget.libelle, helperText: widget.aide, isDense: true),
        onChanged: widget.onChange,
      );
}

/// Un chrono de base : sa durée et ses trois Destiny, modifiables.
class _EditeurChrono extends StatelessWidget {
  const _EditeurChrono({required this.reglages, required this.index});

  final ReglagesDestiny reglages;
  final int index;

  Future<void> _changer(BuildContext context, ChronoSpectacle c) async {
    final ok = await reglages.modifierChrono(index, c);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.textes.t('reglages.chrono_invalide'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.textes;
    final c = context.destiny;
    String k(String x, [Map<String, String> v = const {}]) => t.t('reglages.$x', v);
    final ch = reglages.chronos[index];
    final choisi = reglages.chronoChoisi == index;

    Widget ligne(String libelle, int valeur, ValueChanged<int> changer) => Row(children: [
          Expanded(child: Text(libelle)),
          IconButton(
            tooltip: context.textes.t('accessibilite.moins'),
            visualDensity: VisualDensity.compact,
            onPressed: valeur > 1 ? () => changer(valeur - 1) : null,
            icon: const Icon(Icons.remove_circle_outline),
          ),
          SizedBox(
            width: 64,
            child: Text(k('minutes', {'n': '$valeur'}),
                textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          IconButton(
            tooltip: context.textes.t('accessibilite.plus'),
            visualDensity: VisualDensity.compact,
            onPressed: () => changer(valeur + 1),
            icon: const Icon(Icons.add_circle_outline),
          ),
        ]);

    return CadreLisere(
      couleur: choisi ? c.or : c.filet,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Text(k('chrono_n', {'n': '${ch.dureeMinutes}'}),
                style: TextStyle(fontFamily: kPoliceTexte, fontSize: 17, fontWeight: FontWeight.w700, color: c.texte)),
          ),
          ChoiceChip(
            label: Text(k('par_defaut')),
            selected: choisi,
            onSelected: (_) => reglages.choisirChrono(index),
          ),
        ]),
        ligne(k('duree'), ch.dureeMinutes, (v) => _changer(context, ch.copierAvec(dureeMinutes: v))),
        for (var i = 0; i < 3; i++)
          ligne(k('destiny_n', {'n': '${i + 1}'}), ch.destinyMinutes[i], (v) {
            final d = [...ch.destinyMinutes]..[i] = v;
            _changer(context, ch.copierAvec(destinyMinutes: d));
          }),
      ]),
    );
  }
}

/// Le choix d'une musique pour un moment : aucune, l'ambiance du lieu, ou un
/// morceau de l'appli.
class _ChoixMusiqueLigne extends StatelessWidget {
  const _ChoixMusiqueLigne({super.key, required this.libelle, required this.valeur, required this.musique, required this.onChoix});

  final String libelle;
  final String valeur;
  final MusicController musique;
  final ValueChanged<String> onChoix;

  String _nom(BuildContext context) {
    final t = context.textes;
    if (valeur == ChoixMusique.aucune) return t.t('reglages.aucune');
    if (valeur == ChoixMusique.lieu) return t.t('reglages.ambiance_lieu');
    for (final m in musique.tracks) {
      if (m.file == valeur) return m.title;
    }
    return valeur.split('/').last;
  }

  Future<void> _choisir(BuildContext context) async {
    final t = context.textes;
    final categories = <String>{for (final m in musique.tracks) m.category}.toList();
    final v = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        builder: (ctx, scroll) => ListView(
          controller: scroll,
          children: [
            ListTile(title: Text(t.t('reglages.aucune')), onTap: () => Navigator.pop(ctx, ChoixMusique.aucune)),
            ListTile(title: Text(t.t('reglages.ambiance_lieu')), onTap: () => Navigator.pop(ctx, ChoixMusique.lieu)),
            for (final cat in categories) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(cat, style: Theme.of(ctx).textTheme.titleSmall),
              ),
              for (final m in musique.tracksOf(cat))
                ListTile(
                  title: Text(m.title),
                  selected: m.file == valeur,
                  onTap: () => Navigator.pop(ctx, m.file),
                ),
            ],
          ],
        ),
      ),
    );
    if (v != null) onChoix(v);
  }

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(libelle),
        subtitle: Text(_nom(context)),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => _choisir(context),
      );
}

/// Le son de chaque Destiny, avec son aperçu.
class _ChoixSon extends StatelessWidget {
  const _ChoixSon({required this.libelle, required this.valeur, required this.audio, required this.onChoix});

  final String libelle;
  final String valeur;
  final AudioService audio;
  final ValueChanged<String> onChoix;

  @override
  Widget build(BuildContext context) {
    const effets = AudioService.effets;
    final courant = effets.containsKey(valeur) ? valeur : 'storm';
    return Row(children: [
      Expanded(child: Text(libelle)),
      DropdownButton<String>(
        value: courant,
        underline: const SizedBox.shrink(),
        items: [for (final e in effets.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
        onChanged: (v) {
          if (v == null) return;
          onChoix(v);
          if (v != 'aucun') audio.playEffet(v);
        },
      ),
      IconButton(
        tooltip: context.textes.t('reglages.ecouter'),
        icon: const Icon(Icons.play_circle_outline),
        onPressed: courant == 'aucun' ? null : () => audio.playEffet(courant),
      ),
    ]);
  }
}

/// Les musiques importées : importer, écouter, retirer.
class _MusiquesImportees extends StatelessWidget {
  const _MusiquesImportees({required this.musique, required this.reglages});

  final MusicController musique;
  final ReglagesDestiny reglages;

  @override
  Widget build(BuildContext context) {
    final t = context.textes;
    String k(String x, [Map<String, String> v = const {}]) => t.t('reglages.$x', v);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(k('importees'), style: Theme.of(context).textTheme.titleSmall),
      if (musique.importees.isEmpty) Paragraphe(k('importees_vide'), italique: true),
      for (final m in musique.importees)
        Row(children: [
          Expanded(child: Text(m.nom, overflow: TextOverflow.ellipsis)),
          IconButton(
            tooltip: k('ecouter'),
            icon: const Icon(Icons.play_circle_outline),
            onPressed: () => musique.apercuImportee(m),
          ),
          IconButton(
            tooltip: k('retirer'),
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () async {
              if (reglages.musiqueDestiny == m.chemin) await reglages.changer(musiqueDestiny: ChoixMusique.aucune);
              await musique.retirerImportee(m);
            },
          ),
        ]),
      Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: () async {
            final n = await musique.importerMusiques();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(k('importees_ajout', {'n': '$n'}))));
            }
          },
          icon: const Icon(Icons.upload_file_rounded),
          label: Text(k('importer')),
        ),
      ),
    ]);
  }
}

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../application/services/audio_service.dart';
import '../../application/son/conduite_son.dart';
import '../../application/son/lecteur_son.dart';
import '../../application/son/regie_son.dart';
import '../../application/son/reglages_regie_son.dart';
import '../../application/state/music_controller.dart';
import '../../domain/son/resolution_son.dart';
import '../destiny/donnees.dart';
import '../destiny/page.dart';
import 'apparence_sons.dart';
import 'pack_audio_screen.dart';

/// « Régie son du spectacle » : la conduite automatique (musique par acte,
/// son Destiny, bruitage du danger, REVEAL), la banque de sons à trier à
/// l'oreille, et un banc d'essai pour répéter la régie sans chrono.
class RegieSonScreen extends StatelessWidget {
  const RegieSonScreen({super.key, required this.regieSon, required this.musique});

  final RegieSon regieSon;
  final MusicController musique;

  ReglagesRegieSon get _r => regieSon.reglages;

  @override
  Widget build(BuildContext context) {
    final t = context.textes;
    String k(String x, [Map<String, String> v = const {}]) => t.t('regie_son.r.$x', v);
    return ListenableBuilder(
      listenable: Listenable.merge([_r, regieSon.pack]),
      builder: (context, _) {
        final v = _r.v;
        void change(void Function(ValeursRegieSon v) f) => _r.modifier(f);
        final pack = regieSon.pack;
        return PageDestiny(
          titre: k('titre'),
          enfants: [
            SectionDestiny(titre: k('pack'), espace: 0, enfants: [
              SwitchListTile(
                key: const ValueKey('pack_actif'),
                contentPadding: EdgeInsets.zero,
                title: Text(k('pack_actif')),
                subtitle: Text(k('pack_actif_aide')),
                value: v.packActif,
                onChanged: (x) => change((v) => v.packActif = x),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(pack.disponible ? Icons.library_music_rounded : Icons.library_music_outlined),
                title: Text(t.t('regie_son.pack.titre')),
                subtitle: Text(pack.disponible
                    ? t.t(pack.integre ? 'regie_son.pack.integre_n' : 'regie_son.pack.fichiers_n',
                        {'n': '${pack.index.chemins.length}'})
                    : t.t('regie_son.pack.aucun_fichier')),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context)
                    .push(MaterialPageRoute<void>(builder: (_) => PackAudioScreen(regieSon: regieSon))),
              ),
            ]),
            SectionDestiny(titre: k('musique'), enfants: [
              Paragraphe(k('musique_aide'), italique: true),
              for (var a = 1; a <= 4; a++)
                _CarteActe(
                  acte: a,
                  titre: k('acte', {'n': '$a'}),
                  v: v,
                  k: k,
                  change: change,
                ),
              _Curseur(k('fondu_sortie'), v.fonduSortie, 0, 6, 12, (x) => change((v) => v.fonduSortie = x), suffixe: 's'),
              _Bascule(k('repli_famille'), v.repliFamille, (x) => change((v) => v.repliFamille = x),
                  aide: k('repli_famille_aide')),
              _Bascule(k('ambiance_apres'), v.ambianceApresMusique, (x) => change((v) => v.ambianceApresMusique = x),
                  aide: k('ambiance_apres_aide')),
              if (v.ambianceApresMusique)
                _Curseur(k('volume_ambiance'), v.volumeAmbiance, 0, 1, 20, (x) => change((v) => v.volumeAmbiance = x),
                    pourcent: true),
              _Bascule(k('boucle'), v.boucle, (x) => change((v) => v.boucle = x), aide: k('boucle_aide')),
            ]),
            SectionDestiny(titre: k('son_destiny'), enfants: [
              _ChoixEffet(k('son_ouverture'), v.sonOuverture, (x) => change((v) => v.sonOuverture = x)),
              _ChoixEffet(k('son_chaque_destiny'), v.sonDestiny, (x) => change((v) => v.sonDestiny = x)),
              _Curseur(
                v.chevauchement == 0 ? k('attendre_fin') : k('chevauchement', {'n': v.chevauchement.toStringAsFixed(1)}),
                v.chevauchement,
                0,
                10,
                20,
                (x) => change((v) => v.chevauchement = x),
                suffixe: 's',
              ),
            ]),
            SectionDestiny(titre: k('bruitage'), enfants: [
              Text(k('bruitage_fin'), style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 6),
              _PucesActes(
                  valeurs: v.bruitageFinMusique, k: k, onChange: (a, x) => change((v) => v.bruitageFinMusique[a] = x)),
              const SizedBox(height: 10),
              Text(k('bruitage_auto'), style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 6),
              _PucesActes(valeurs: v.bruitageAuto, k: k, onChange: (a, x) => change((v) => v.bruitageAuto[a] = x)),
              _Curseur(k('volume'), v.volumeBruitage, 0, 1, 20, (x) => change((v) => v.volumeBruitage = x), pourcent: true),
              _Curseur(k('duree_max'), v.dureeMaxBruitage, 2, 30, 28, (x) => change((v) => v.dureeMaxBruitage = x),
                  suffixe: 's'),
              _Curseur(k('fondu_bruitage'), v.fonduBruitage, 0, 5, 10, (x) => change((v) => v.fonduBruitage = x),
                  suffixe: 's'),
              _Curseur(k('decalage'), v.decalageCodes, 0, 3, 15, (x) => change((v) => v.decalageCodes = x), suffixe: 's'),
              _Curseur(k('attenuation'), v.attenuation, 0, 1, 20, (x) => change((v) => v.attenuation = x), pourcent: true),
              _Curseur(k('remontee'), v.remontee, 0, 5, 10, (x) => change((v) => v.remontee = x), suffixe: 's'),
            ]),
            SectionDestiny(titre: k('reveal'), enfants: [
              Paragraphe(k('reveal_aide'), italique: true),
              _PucesActes(valeurs: v.revealActe, k: k, onChange: (a, x) => change((v) => v.revealActe[a] = x)),
              const SizedBox(height: 6),
              _ChoixReveal(regieSon: regieSon, k: k),
              _Curseur(k('reveal_max'), v.revealMax, 2, 15, 13, (x) => change((v) => v.revealMax = x), suffixe: 's'),
            ]),
            SectionDestiny(titre: k('fin'), enfants: [
              _Bascule(k('conclusion_fin'), v.conclusionFinChrono, (x) => change((v) => v.conclusionFinChrono = x),
                  aide: k('conclusion_fin_aide')),
              _Bascule(k('coupure_fin'), v.coupureFinChrono, (x) => change((v) => v.coupureFinChrono = x),
                  aide: k('coupure_fin_aide')),
              _Curseur(k('fondu_fin'), v.fonduFin, 2, 20, 18, (x) => change((v) => v.fonduFin = x), suffixe: 's'),
            ]),
            SectionDestiny(titre: k('banque'), enfants: [
              Paragraphe(k('banque_aide'), italique: true),
              if (pack.disponible) _BanqueSons(regieSon: regieSon, k: k) else Paragraphe(t.t('regie_son.banque_vide')),
            ]),
            SectionDestiny(titre: k('tester'), enfants: [
              Paragraphe(k('tester_aide'), italique: true),
              if (pack.disponible) _BancEssai(regieSon: regieSon, k: k) else Paragraphe(t.t('regie_son.banque_vide')),
            ]),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _r.remettre,
                icon: const Icon(Icons.restart_alt_rounded),
                label: Text(k('remettre')),
              ),
            ),
          ],
        );
      },
    );
  }
}

// --------------------------------------------------------------- éléments

typedef _Texte = String Function(String, [Map<String, String>]);

class _Bascule extends StatelessWidget {
  const _Bascule(this.titre, this.valeur, this.onChange, {this.aide});

  final String titre;
  final bool valeur;
  final ValueChanged<bool> onChange;
  final String? aide;

  @override
  Widget build(BuildContext context) => SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(titre),
        subtitle: aide == null ? null : Text(aide!),
        value: valeur,
        onChanged: onChange,
      );
}

class _Curseur extends StatelessWidget {
  const _Curseur(this.titre, this.valeur, this.min, this.max, this.divisions, this.onChange,
      {this.suffixe = '', this.pourcent = false});

  final String titre;
  final double valeur;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChange;
  final String suffixe;
  final bool pourcent;

  String get _texte => pourcent
      ? '${(valeur * 100).round()} %'
      : '${valeur == valeur.roundToDouble() ? valeur.toStringAsFixed(0) : valeur.toStringAsFixed(1)} $suffixe';

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(titre)),
            Text(_texte, style: Theme.of(context).textTheme.labelLarge),
          ]),
          Slider(
            value: valeur.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            label: _texte,
            onChanged: onChange,
          ),
        ]),
      );
}

class _PucesActes extends StatelessWidget {
  const _PucesActes({required this.valeurs, required this.k, required this.onChange});

  final List<bool> valeurs;
  final _Texte k;
  final void Function(int acte, bool valeur) onChange;

  @override
  Widget build(BuildContext context) => Wrap(spacing: 8, runSpacing: 6, children: [
        for (var a = 0; a < 4; a++)
          FilterChip(
            label: Text(k('acte', {'n': '${a + 1}'})),
            selected: valeurs[a],
            onSelected: (x) => onChange(a, x),
          ),
      ]);
}

class _CarteActe extends StatelessWidget {
  const _CarteActe({required this.acte, required this.titre, required this.v, required this.k, required this.change});

  final int acte;
  final String titre;
  final ValeursRegieSon v;
  final _Texte k;
  final void Function(void Function(ValeursRegieSon v) f) change;

  @override
  Widget build(BuildContext context) {
    final i = acte - 1;
    return CadreLisere(
      couleur: Theme.of(context).colorScheme.primary,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(titre, style: Theme.of(context).textTheme.titleMedium)),
          Switch(value: v.musiqueActe[i], onChanged: (x) => change((v) => v.musiqueActe[i] = x)),
        ]),
        if (v.musiqueActe[i]) ...[
          _Curseur(k('volume_depart'), v.volumeActe[i], 0, 1, 20, (x) => change((v) => v.volumeActe[i] = x),
              pourcent: true),
          _Curseur(k('fondu_entree'), v.fonduEntree[i], 0, 10, 20, (x) => change((v) => v.fonduEntree[i] = x),
              suffixe: 's'),
          _EditeurCourbe(acte: acte, v: v, k: k, change: change),
        ],
      ]),
    );
  }
}

/// La courbe de volume d'un acte : le volume de départ, puis des repères
/// « à tant de secondes, tant de pour cent », et 0 % à la fin du morceau.
/// Entre deux repères, le volume change tout seul, en ligne droite.
class _EditeurCourbe extends StatelessWidget {
  const _EditeurCourbe({required this.acte, required this.v, required this.k, required this.change});

  final int acte;
  final ValeursRegieSon v;
  final _Texte k;
  final void Function(void Function(ValeursRegieSon v) f) change;

  int get _i => acte - 1;

  void _ajouter() => change((v) {
        final c = v.courbes[_i];
        final dernier = c.isEmpty ? PointVolume(0, v.volumeActe[_i]) : c.last;
        c.add(PointVolume((dernier.secondes + 30).clamp(5, 600), (dernier.volume - 0.1).clamp(0.0, 1.0)));
      });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final points = v.courbes[_i];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height: 6),
      Text(k('courbe'), style: theme.textTheme.titleSmall),
      Text(k('courbe_aide'), style: theme.textTheme.bodySmall),
      const SizedBox(height: 8),
      SizedBox(
        height: 70,
        child: CustomPaint(
          painter: _PeintreCourbe(
            depart: v.volumeActe[_i],
            points: [for (final p in points) (p.secondes, p.volume)],
            finAZero: v.finAZero[_i],
            couleur: theme.colorScheme.primary,
            trait: theme.dividerColor,
          ),
        ),
      ),
      for (var j = 0; j < points.length; j++)
        Container(
          key: ValueKey('repere_${acte}_$j'),
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.fromLTRB(10, 4, 0, 4),
          decoration: BoxDecoration(
            border: Border.all(color: theme.dividerColor),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            Expanded(
              child: Column(children: [
                _Curseur(k('repere_temps'), points[j].secondes, 5, 600, 119,
                    (x) => change((v) => v.courbes[_i][j].secondes = x.roundToDouble()),
                    suffixe: 's'),
                _Curseur(k('repere_volume'), points[j].volume, 0, 1, 20,
                    (x) => change((v) => v.courbes[_i][j].volume = x),
                    pourcent: true),
              ]),
            ),
            IconButton(
              tooltip: k('repere_retirer'),
              icon: const Icon(Icons.close_rounded),
              onPressed: () => change((v) => v.courbes[_i].removeAt(j)),
            ),
          ]),
        ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          key: ValueKey('ajouter_repere_$acte'),
          onPressed: points.length >= 8 ? null : _ajouter,
          icon: const Icon(Icons.add_rounded),
          label: Text(k('repere_ajouter')),
        ),
      ),
      _Bascule(k('fin_zero'), v.finAZero[_i], (x) => change((v) => v.finAZero[_i] = x), aide: k('fin_zero_aide')),
    ]);
  }
}

/// Le dessin de la courbe : le volume (en hauteur) au fil de la musique.
class _PeintreCourbe extends CustomPainter {
  _PeintreCourbe({
    required this.depart,
    required this.points,
    required this.finAZero,
    required this.couleur,
    required this.trait,
  });

  final double depart;
  final List<(double, double)> points;
  final bool finAZero;
  final Color couleur;
  final Color trait;

  @override
  void paint(Canvas canvas, Size size) {
    final tries = [...points]..sort((a, b) => a.$1.compareTo(b.$1));
    final dernier = tries.isEmpty ? 0.0 : tries.last.$1;
    // La fin du morceau, dessinée un peu après le dernier repère.
    final fin = max(dernier * 1.25, 60.0);
    final cles = [(0.0, depart), ...tries, if (finAZero) (fin, 0.0) else (fin, tries.isEmpty ? depart : tries.last.$2)];
    Offset pt((double, double) c) => Offset(c.$1 / fin * size.width, size.height - c.$2 * size.height);
    final fond = Paint()
      ..color = trait
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height), fond);
    final chemin = Path()..moveTo(pt(cles.first).dx, pt(cles.first).dy);
    for (final c in cles.skip(1)) {
      chemin.lineTo(pt(c).dx, pt(c).dy);
    }
    final aire = Path.from(chemin)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(aire, Paint()..color = couleur.withValues(alpha: 0.15));
    canvas.drawPath(
        chemin,
        Paint()
          ..color = couleur
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke);
    for (final c in cles) {
      canvas.drawCircle(pt(c), 4, Paint()..color = couleur);
    }
  }

  @override
  bool shouldRepaint(_PeintreCourbe old) => true;
}

class _ChoixEffet extends StatelessWidget {
  const _ChoixEffet(this.titre, this.valeur, this.onChange);

  final String titre;
  final String valeur;
  final ValueChanged<String> onChange;

  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(child: Text(titre)),
        DropdownButton<String>(
          value: AudioService.effets.containsKey(valeur) ? valeur : 'storm',
          items: [
            for (final e in AudioService.effets.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
          ],
          onChanged: (x) {
            if (x != null) onChange(x);
          },
        ),
      ]);
}

class _ChoixReveal extends StatelessWidget {
  const _ChoixReveal({required this.regieSon, required this.k});

  final RegieSon regieSon;
  final _Texte k;

  @override
  Widget build(BuildContext context) {
    final m = regieSon.pack.manifeste;
    final candidats = m == null ? const <String>[] : candidatsReveal(m, regieSon.pack.index);
    final v = regieSon.reglages.v;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 8, runSpacing: 6, children: [
        ChoiceChip(
          label: Text(k('au_hasard')),
          selected: v.revealFichier == kCandidatAleatoire,
          onSelected: (_) => regieSon.reglages.modifier((v) => v.revealFichier = kCandidatAleatoire),
        ),
        for (var i = 0; i < candidats.length; i++)
          InputChip(
            label: Text(k('fichier', {'n': '${i + 1}'})),
            selected: v.revealFichier == i,
            onSelected: (_) => regieSon.reglages.modifier((v) => v.revealFichier = i),
            avatar: const Icon(Icons.play_arrow_rounded, size: 18),
            onPressed: () {
              regieSon.reglages.modifier((v) => v.revealFichier = i);
              regieSon.conduite.jouerEffet(SourcePack(candidats[i], titre: 'REVEAL'));
            },
          ),
      ]),
    ]);
  }
}

/// La banque de sons : pour un danger, ses codes par palier ; pour chaque
/// code, l'écoute de chaque candidat, le fichier par défaut (ou au hasard)
/// et le volume.
class _BanqueSons extends StatefulWidget {
  const _BanqueSons({required this.regieSon, required this.k});

  final RegieSon regieSon;
  final _Texte k;

  @override
  State<_BanqueSons> createState() => _BanqueSonsState();
}

class _BanqueSonsState extends State<_BanqueSons> {
  String? _danger;

  @override
  Widget build(BuildContext context) {
    final rs = widget.regieSon;
    final m = rs.pack.manifeste!;
    final k = widget.k;
    final dangers = m.dangers.values.toList()..sort((a, b) => a.nom.compareTo(b.nom));
    final d = m.dangers[_danger] ?? dangers.first;
    final v = rs.reglages.v;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      DropdownButtonFormField<String>(
        initialValue: d.id,
        isExpanded: true,
        decoration: InputDecoration(labelText: k('danger')),
        items: [for (final x in dangers) DropdownMenuItem(value: x.id, child: Text(x.nom))],
        onChanged: (x) => setState(() => _danger = x),
      ),
      const SizedBox(height: 8),
      for (var palier = 1; palier <= 4; palier++) ...[
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: Text(k('palier', {'n': '$palier'}), style: Theme.of(context).textTheme.titleSmall),
        ),
        for (final code in d.codes(palier))
          Builder(builder: (context) {
            final style = styleCode(code);
            final candidats = candidatsBruitage(m, rs.pack.index, code);
            final remplacant = m.remplacements[code];
            final choix = v.choixCandidat[code] ?? 0;
            return ExpansionTile(
              key: PageStorageKey('banque_$code'),
              tilePadding: EdgeInsets.zero,
              leading: Icon(style.icone, color: style.couleur),
              title: Text(m.sons[code]?.nom ?? code),
              subtitle: Text(candidats.isEmpty
                  ? (remplacant == null ? k('vide') : k('remplace_par', {'nom': m.sons[remplacant]?.nom ?? remplacant}))
                  : (choix == kCandidatAleatoire ? k('au_hasard') : k('fichier', {'n': '${choix + 1}'}))),
              children: [
                if (candidats.isNotEmpty) ...[
                  RadioGroup<int>(
                    groupValue: choix,
                    onChanged: (x) {
                      if (x != null) rs.reglages.modifier((v) => v.choixCandidat[code] = x);
                    },
                    child: Column(children: [
                      RadioListTile<int>(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        value: kCandidatAleatoire,
                        title: Text(k('au_hasard')),
                      ),
                      for (var i = 0; i < candidats.length; i++)
                        RadioListTile<int>(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          value: i,
                          title: Text(candidats[i].split('/').last, maxLines: 2, overflow: TextOverflow.ellipsis),
                          subtitle: Text(_duree(m.dureeDe(candidats[i]))),
                          secondary: IconButton(
                            tooltip: k('ecouter'),
                            icon: const Icon(Icons.play_circle_rounded),
                            onPressed: () => rs.conduite.jouerEffet(
                              SourcePack(candidats[i], titre: m.sons[code]?.nom),
                              bus: BusSon.bruitageA,
                              niveau: (v.volumeBruitage * v.volumeDe(code)).clamp(0.0, 1.0),
                            ),
                          ),
                        ),
                    ]),
                  ),
                  Row(children: [
                    Text(k('volume')),
                    Expanded(
                      child: Slider(
                        value: v.volumeDe(code),
                        divisions: 20,
                        label: '${(v.volumeDe(code) * 100).round()} %',
                        onChanged: (x) => rs.reglages.modifier((v) => v.volumeCode[code] = x),
                      ),
                    ),
                    IconButton(
                      tooltip: k('arreter'),
                      icon: const Icon(Icons.stop_rounded),
                      onPressed: () => rs.conduite.arreterBus(BusSon.bruitageA),
                    ),
                  ]),
                ],
              ],
            );
          }),
      ],
    ]);
  }

  String _duree(double? s) {
    if (s == null) return '';
    final m = s ~/ 60;
    final r = (s - m * 60).round();
    return m > 0 ? '$m min ${r.toString().padLeft(2, '0')} s' : '${s.toStringAsFixed(1)} s';
  }
}

/// Le banc d'essai : un lieu, un danger, et la conduite rejouée sans chrono
/// (l'ouverture puis les trois DESTINY), pour répéter la régie.
class _BancEssai extends StatefulWidget {
  const _BancEssai({required this.regieSon, required this.k});

  final RegieSon regieSon;
  final _Texte k;

  @override
  State<_BancEssai> createState() => _BancEssaiState();
}

class _BancEssaiState extends State<_BancEssai> {
  String? _lieu;
  String? _danger;
  double _parActe = 20;
  int _essai = 0;
  bool _enCours = false;

  ConduiteSon get _c => widget.regieSon.conduite;

  @override
  void dispose() {
    if (_enCours) unawaited(_c.stopTout());
    _essai++;
    super.dispose();
  }

  void _preparer(String lieu, String danger) => _c.preparer(lieuId: lieu, dangerId: danger);

  /// Ouverture, puis DESTINY 1 à 3, avec [_parActe] secondes de musique entre
  /// chaque. « Stop » arrête tout.
  Future<void> _toutEnchainer(String lieu, String danger) async {
    final essai = ++_essai;
    setState(() => _enCours = true);
    _preparer(lieu, danger);
    await _c.ouverture();
    for (var n = 1; n <= 3; n++) {
      await Future<void>.delayed(Duration(seconds: _parActe.round()));
      if (essai != _essai || !mounted) return;
      await _c.destiny(n);
    }
    if (mounted && essai == _essai) setState(() => _enCours = false);
  }

  Future<void> _stop() async {
    _essai++;
    await _c.stopTout();
    if (mounted) setState(() => _enCours = false);
  }

  @override
  Widget build(BuildContext context) {
    final k = widget.k;
    final m = widget.regieSon.pack.manifeste!;
    final lieux = m.lieux.values.toList()..sort((a, b) => a.nom.compareTo(b.nom));
    final dangers = m.dangers.values.toList()..sort((a, b) => a.nom.compareTo(b.nom));
    final lieu = _lieu ?? 'eglise';
    final danger = _danger ?? dangers.first.id;
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        DropdownButtonFormField<String>(
          initialValue: m.lieux.containsKey(lieu) ? lieu : lieux.first.id,
          isExpanded: true,
          decoration: InputDecoration(labelText: k('lieu')),
          items: [for (final l in lieux) DropdownMenuItem(value: l.id, child: Text(l.nom))],
          onChanged: (x) => setState(() => _lieu = x),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: danger,
          isExpanded: true,
          decoration: InputDecoration(labelText: k('danger')),
          items: [for (final d in dangers) DropdownMenuItem(value: d.id, child: Text(d.nom))],
          onChanged: (x) => setState(() => _danger = x),
        ),
        _Curseur(k('par_acte'), _parActe, 5, 90, 17, (x) => setState(() => _parActe = x), suffixe: 's'),
        if (_c.etape != EtapeConduite.repos)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('${k('acte', {'n': '${_c.acte}'})} · ${context.textes.t('regie_son.etapes.${_c.etape.name}')}',
                style: Theme.of(context).textTheme.titleSmall),
          ),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton.icon(
            key: const ValueKey('essai_tout'),
            onPressed: _enCours ? null : () => _toutEnchainer(lieu, danger),
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(k('tout_enchainer')),
          ),
          OutlinedButton(
            onPressed: () {
              _preparer(lieu, danger);
              _c.ouverture();
            },
            child: Text(k('ouverture')),
          ),
          for (var n = 1; n <= 3; n++)
            OutlinedButton(
              onPressed: () {
                if (_c.lieuId != lieu || _c.dangerId != danger) _preparer(lieu, danger);
                _c.destiny(n);
              },
              child: Text(k('destiny_n', {'n': '$n'})),
            ),
          OutlinedButton.icon(
            onPressed: () {
              if (_c.lieuId != lieu || _c.dangerId != danger) _preparer(lieu, danger);
              _c.danger();
            },
            icon: const Icon(Icons.warning_rounded),
            label: Text(context.textes.t('regie_son.danger')),
          ),
          FilledButton.tonalIcon(
            onPressed: _stop,
            icon: const Icon(Icons.stop_rounded),
            label: Text(k('stop')),
          ),
        ]),
      ]),
    );
  }
}

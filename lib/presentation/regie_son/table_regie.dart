import 'dart:math';

import 'package:flutter/material.dart';

import '../../application/services/audio_service.dart';
import '../../application/son/conduite_son.dart';
import '../../application/son/lecteur_son.dart';
import '../../application/son/regie_son.dart';
import '../../application/state/music_controller.dart';
import '../../application/state/reglages_destiny.dart';
import '../../domain/grammaire/modeles.dart';
import '../../domain/son/categories_son.dart';
import '../../domain/son/resolution_son.dart';
import '../../domain/troupe/session.dart';
import '../destiny/donnees.dart';
import '../theme/destiny_theme.dart';
import '../troupe/troupe_screen.dart';
import '../widgets/sound_mixer_sheet.dart';
import 'apparence_sons.dart';
import 'pack_audio_screen.dart';
import 'regie_son_screen.dart';

/// Le spectacle vu depuis la table de régie : le chrono, l'acte, la pause et
/// DESTINY. La table ne fait jamais perdre le spectacle de vue.
class PiloteSpectacle {
  const PiloteSpectacle({
    required this.change,
    required this.reste,
    required this.acte,
    required this.enMarche,
    required this.basculer,
    required this.libelleBasculer,
    required this.destiny,
    required this.libelleDestiny,
  });

  /// Prévient à chaque seconde et à chaque changement de la régie.
  final Listenable change;

  /// Le temps qui reste (« 28:43 »).
  final String Function() reste;

  /// « Acte 2 — Il enferme ».
  final String Function() acte;
  final bool Function() enMarche;
  final VoidCallback basculer;

  /// « Démarrer », « Pause » ou « Reprendre ».
  final String Function() libelleBasculer;

  /// L'action du bouton DESTINY, ou null quand aucun ne peut partir.
  final VoidCallback? Function() destiny;
  final String Function() libelleDestiny;
}

/// Ouvre la table de régie en pop-up, par-dessus la régie : par le bas sur un
/// téléphone, au centre sur un grand écran. Un appui à côté ou la croix la
/// ferme. Avec [pilote], le chrono et DESTINY restent sous la main. [contenu]
/// remplace la table (la régie y met sa tablette son, qui l'enveloppe).
Future<void> ouvrirTableRegie(
  BuildContext context,
  ContexteTroupe contexte,
  SessionTroupe session, {
  Widget? contenu,
  PiloteSpectacle? pilote,
}) {
  final t = context.textes;
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: t.t('regie.son_fermer'),
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (ctx, _, __) {
      final taille = MediaQuery.sizeOf(ctx);
      final large = taille.width >= 720;
      return Theme(
        data: themeConsole(Theme.of(ctx)),
        child: SafeArea(
          child: Align(
            alignment: large ? Alignment.center : Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.all(large ? 24 : 6),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 1100, maxHeight: taille.height * (large ? 0.9 : 0.86)),
                child: Material(
                  color: Console.fond,
                  elevation: 18,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(22),
                    side: BorderSide(color: Console.or.withValues(alpha: 0.35)),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 6, 4, 0),
                      child: Row(children: [
                        const Icon(Icons.tune_rounded, color: Console.or),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            t.t('regie_son.titre').toUpperCase(),
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: kPoliceTitres,
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              letterSpacing: 2,
                              color: Console.or,
                            ),
                          ),
                        ),
                        if (contexte.regieSon != null)
                          IconButton(
                            tooltip: t.t('regie_son.reglages'),
                            icon: const Icon(Icons.settings_rounded, color: Console.doux),
                            onPressed: () => Navigator.of(ctx).push(MaterialPageRoute<void>(
                                builder: (_) => RegieSonScreen(regieSon: contexte.regieSon!, musique: contexte.musique))),
                          ),
                        IconButton(
                          key: const ValueKey('fermer_regie_son'),
                          tooltip: t.t('regie.son_fermer'),
                          icon: const Icon(Icons.close_rounded, color: Console.texte),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ]),
                    ),
                    if (pilote != null)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                        child: BarrePilote(pilote: pilote),
                      ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(12, 6, 12, 20),
                        child: contenu ?? TableRegie(contexte: contexte, session: session),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (ctx, a, _, enfant) {
      final courbe = CurvedAnimation(parent: a, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: courbe,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.06), end: Offset.zero).animate(courbe),
          child: enfant,
        ),
      );
    },
  );
}

/// Le chrono en petit, en haut de la table : le temps qui reste, l'acte, la
/// pause et DESTINY.
class BarrePilote extends StatelessWidget {
  const BarrePilote({super.key, required this.pilote});

  final PiloteSpectacle pilote;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: pilote.change,
        builder: (context, _) {
          final destiny = pilote.destiny();
          final enMarche = pilote.enMarche();
          return Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
            decoration: BoxDecoration(
              color: Console.panneau,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Console.trait),
            ),
            child: LayoutBuilder(builder: (context, contraintes) {
              final temps = Text(
                pilote.reste(),
                key: const ValueKey('pilote_reste'),
                style: const TextStyle(
                  fontFamily: kPoliceTitres,
                  fontWeight: FontWeight.w900,
                  fontSize: 30,
                  height: 1,
                  color: Console.or,
                ),
              );
              final acte = Text(
                pilote.acte(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontFamily: kPoliceTexte, fontWeight: FontWeight.w700, fontSize: 13, color: Console.texte),
              );
              final basculer = IconButton.filled(
                key: const ValueKey('pilote_basculer'),
                tooltip: pilote.libelleBasculer(),
                style: const ButtonStyle(
                  backgroundColor: WidgetStatePropertyAll(Console.or),
                  foregroundColor: WidgetStatePropertyAll(Color(0xFF141414)),
                ),
                onPressed: pilote.basculer,
                icon: Icon(enMarche ? Icons.pause_rounded : Icons.play_arrow_rounded),
              );
              final bouton = FilledButton.icon(
                key: const ValueKey('pilote_destiny'),
                style: FilledButton.styleFrom(
                  backgroundColor: Console.bleuDestiny,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Console.trait,
                  minimumSize: const Size(48, 44),
                  textStyle: const TextStyle(fontFamily: kPoliceTitres, fontWeight: FontWeight.w900, fontSize: 15),
                ),
                onPressed: destiny,
                icon: const Icon(Icons.flash_on_rounded, size: 18),
                label: Text(pilote.libelleDestiny().toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis),
              );
              final ligne = Row(children: [
                Flexible(child: FittedBox(fit: BoxFit.scaleDown, child: temps)),
                const SizedBox(width: 12),
                Expanded(child: acte),
                basculer,
              ]);
              // Étroit (téléphone) : DESTINY sur sa propre ligne, en grand.
              if (contraintes.maxWidth < 560) {
                return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  ligne,
                  const SizedBox(height: 8),
                  bouton,
                ]);
              }
              return Row(children: [
                Expanded(child: ligne),
                const SizedBox(width: 8),
                bouton,
              ]);
            }),
          );
        },
      );
}

/// Le thème sombre de la console, quel que soit celui de l'appli.
ThemeData themeConsole(ThemeData base) => base.copyWith(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Console.fond,
      colorScheme: ColorScheme.fromSeed(seedColor: Console.or, brightness: Brightness.dark).copyWith(
        primary: Console.or,
        surface: Console.panneau,
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: Console.or,
        inactiveTrackColor: Console.trait,
        thumbColor: Console.texte,
        trackHeight: 4,
      ),
      iconTheme: const IconThemeData(color: Console.texte),
      textTheme: base.textTheme.apply(bodyColor: Console.texte, displayColor: Console.texte),
    );

/// Une banque de la table : son identifiant, son libellé, son style.
typedef _Banque = ({String id, String libelle, StyleSon style});

/// La table de régie : la conduite du spectacle (actes, Destiny, Danger…),
/// les tranches (une par voie, avec vumètre et fader) et les banques de sons
/// rangées par catégorie, chacune avec son icône et sa couleur.
///
/// Sans régie son branchée, les pads de la conduite jouent comme l'ancienne
/// tablette : les musiques des réglages, l'ambiance du lieu, le son Destiny.
class TableRegie extends StatefulWidget {
  const TableRegie({super.key, required this.contexte, required this.session});

  final ContexteTroupe contexte;
  final SessionTroupe session;

  @override
  State<TableRegie> createState() => _TableRegieState();
}

class _TableRegieState extends State<TableRegie> with SingleTickerProviderStateMixin {
  late final AnimationController _vu = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
  String? _banque;

  SessionTroupe get s => widget.session;
  RegieSon? get _rs => widget.contexte.regieSon;
  ConduiteSon? get _c => _rs?.conduite;
  MusicController get _musique => widget.contexte.musique;
  AudioService get _audio => widget.contexte.audio;
  ReglagesDestiny get _r => widget.contexte.reglages;
  bool get _pack => _c?.active ?? false;

  @override
  void initState() {
    super.initState();
    final c = _c;
    if (c != null && (c.lieuId != s.lieuId || c.dangerId != s.dangerId)) {
      c.preparer(lieuId: s.lieuId, dangerId: s.dangerId, acte: s.palierAtteint);
    }
    c?.addListener(_majVu);
    _majVu();
  }

  @override
  void dispose() {
    _c?.removeListener(_majVu);
    _vu.dispose();
    super.dispose();
  }

  /// Les vumètres ne s'animent que si quelque chose joue.
  void _majVu() {
    final actif = _c?.lecteurs.values.any((l) => l.actif) ?? false;
    if (actif && !_vu.isAnimating) _vu.repeat();
    if (!actif && _vu.isAnimating) _vu.stop();
  }

  // ------------------------------------------------ l'ancienne tablette

  String _ou(String choix, String defaut) => choix.isEmpty || choix == ChoixMusique.aucune ? defaut : choix;

  static const _defauts = [ChoixMusique.commencement, ChoixMusique.lieu, ChoixMusique.lieu, ChoixMusique.conclusion];

  String _choixActe(int acte) => _ou(_r.musiqueActe(acte), _defauts[acte - 1]);

  /// La piste de l'ambiance du lieu joué, dans la bibliothèque.
  MusicTrack? get _pisteLieu {
    final nom = s.lieuNom.trim().toLowerCase();
    for (final piste in _musique.tracks) {
      if (piste.category == 'Lieux' && piste.title.trim().toLowerCase() == nom) return piste;
    }
    return null;
  }

  String? _fichier(String choix) => choix == ChoixMusique.lieu ? _pisteLieu?.file : choix;

  /// Joue un choix des réglages : par la conduite si elle est là (une seule
  /// musique à la fois, faders et Stop compris), sinon par la bibliothèque.
  void _jouerChoix(String choix) {
    if (_audio.muted) return;
    final c = _c;
    if (c == null) {
      _musique.jouerChoix(choix, lieu: s.lieuNom);
      return;
    }
    final fichier = _fichier(choix);
    if (fichier == null) return;
    c.jouerMusique(SourceAsset(fichier, titre: _titrePiste(fichier)));
  }

  String _titrePiste(String fichier) {
    for (final p in _musique.tracks) {
      if (p.file == fichier) return p.title;
    }
    return fichier.split('/').last;
  }

  void _acte(int acte) {
    if (_audio.muted) return;
    if (_pack) {
      _c!.musiqueActe(acte);
    } else {
      _jouerChoix(_choixActe(acte));
    }
  }

  void _sonDestiny() {
    if (_audio.muted) return;
    final c = _c;
    if (c != null) {
      c.jouerSonDestiny();
    } else {
      _audio.playEffet(_r.sonDestiny == 'aucun' ? 'storm' : _r.sonDestiny);
    }
  }

  void _stop() {
    _c?.stopTout();
    _musique.stop();
    _audio.stopStorm();
  }

  // ----------------------------------------------------------- l'état

  /// Les sources qui jouent en ce moment (clés), toutes voies confondues.
  Set<String> get _joue {
    final c = _c;
    final cles = <String>{};
    if (c != null) {
      for (final l in c.lecteurs.values) {
        if (l.enCours != null) cles.add(l.enCours!.cle);
      }
    }
    if (_musique.playing && _musique.current != null) cles.add('asset:${_musique.current!.file}');
    return cles;
  }

  bool _acteJoue(int acte, Set<String> joue) {
    if (_pack) {
      final chemin = _c!.musiqueDe(acte).chemin;
      return chemin != null && joue.contains('pack:$chemin');
    }
    final f = _fichier(_choixActe(acte));
    return f != null && joue.contains('asset:$f');
  }

  bool _codeJoue(String code, Set<String> joue) {
    final rs = _rs;
    final m = rs?.pack.manifeste;
    if (rs == null || m == null) return false;
    final candidats = candidatsBruitage(m, rs.pack.index, code);
    final remplacant = m.remplacements[code];
    return [
      ...candidats,
      if (candidats.isEmpty && remplacant != null) ...candidatsBruitage(m, rs.pack.index, remplacant),
    ].any((c) => joue.contains('pack:$c'));
  }

  // ---------------------------------------------------------- l'écran

  @override
  Widget build(BuildContext context) {
    final t = context.textes;
    String rs(String k, [Map<String, String> v = const {}]) => t.t('regie_son.$k', v);
    String rg(String k, [Map<String, String> v = const {}]) => t.t('regie.$k', v);
    final c = _c;
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.3,
      child: ListenableBuilder(
        listenable: Listenable.merge([
          _musique,
          if (c != null) c,
          if (_rs != null) _rs!.pack,
          if (_rs != null) _rs!.reglages,
        ]),
        builder: (context, _) {
          final joue = _joue;
          final muet = _audio.muted;
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _entete(context, rs),
            if (muet)
              _Bandeau(
                icone: Icons.volume_off_rounded,
                couleur: Console.rouge,
                texte: rg('son_coupe'),
                action: rg('son_remettre'),
                onAction: () => setState(() => _audio.setMuted(false)),
              ),
            const SizedBox(height: 12),
            _Titre(rs('conduite'), icone: Icons.theater_comedy_rounded),
            _conduite(context, rs, rg, joue, muet),
            if (c != null) ...[
              const SizedBox(height: 18),
              _Titre(rs('tranches'), icone: Icons.equalizer_rounded),
              _tranches(rs),
            ],
            const SizedBox(height: 18),
            _Titre(rs('banques'), icone: Icons.grid_view_rounded),
            _banques(context, rs, joue, muet),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => showSoundMixer(context, _musique),
                icon: const Icon(Icons.graphic_eq_rounded, color: Console.or),
                label: Text(rg('son_mixeur'), style: const TextStyle(color: Console.or, fontFamily: kPoliceTexte)),
              ),
            ),
          ]);
        },
      ),
    );
  }

  Widget _entete(BuildContext context, String Function(String, [Map<String, String>]) rs) {
    final g = context.grammaire;
    final c = _c;
    final palier = g.palier(PalierId.deNumero(c?.acte ?? s.palierAtteint));
    final enDirect = c?.lecteurs.values.any((l) => l.actif) ?? _musique.playing;
    final etape = c?.etape ?? EtapeConduite.repos;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: Console.panneau,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Console.trait),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _Led(allumee: enDirect, couleur: Console.rouge),
          const SizedBox(width: 8),
          Text(
            (enDirect ? rs('en_direct') : rs('au_repos')).toUpperCase(),
            style: TextStyle(
              fontFamily: kPoliceTexte,
              fontWeight: FontWeight.w800,
              fontSize: 12,
              letterSpacing: 1.6,
              color: enDirect ? Console.rouge : Console.doux,
            ),
          ),
          const Spacer(),
          if (_rs != null) _PuceEtat(pack: _rs!.pack.disponible, actif: _pack, rs: rs),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 14, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
          _Info(Icons.place_rounded, s.lieuNom),
          _Info(Icons.warning_amber_rounded, s.dangerNom),
          _Info(Icons.stairs_rounded, '${rs('acte', {'n': '${palier.acte}'})} — ${palier.nom}', fort: true),
        ]),
        if (etape != EtapeConduite.repos) ...[
          const SizedBox(height: 8),
          Row(children: [
            const SizedBox(width: 2, height: 14),
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: Console.or.withValues(alpha: 0.9)),
            ),
            const SizedBox(width: 10),
            Text(rs('etapes.${etape.name}'),
                style: const TextStyle(fontFamily: kPoliceTexte, color: Console.or, fontWeight: FontWeight.w600)),
          ]),
        ],
      ]),
    );
  }

  Widget _conduite(BuildContext context, String Function(String, [Map<String, String>]) rs,
      String Function(String, [Map<String, String>]) rg, Set<String> joue, bool muet) {
    final c = _c;
    final pack = _pack;
    final acteCourant = c?.acte ?? s.palierAtteint;
    String? origine(int acte) {
      if (!pack) return null;
      return switch (c!.musiqueDe(acte).origine) {
        OrigineMusique.nomAttendu || OrigineMusique.manifeste => rs('origine_propre'),
        OrigineMusique.famille => rs('origine_famille'),
        OrigineMusique.aucune => rs('origine_aucune'),
      };
    }

    const icones = [Icons.looks_one_rounded, Icons.looks_two_rounded, Icons.looks_3_rounded, Icons.looks_4_rounded];
    final pads = <Widget>[
      for (var acte = 1; acte <= 4; acte++)
        _Pad(
          icone: icones[acte - 1],
          couleur: Console.or,
          libelle: rg('son_acte', {'n': '$acte'}),
          detail: origine(acte),
          actif: _acteJoue(acte, joue),
          repere: acte == acteCourant,
          onTap: muet ? null : () => _acte(acte),
        ),
      _Pad(
        icone: Icons.place_rounded,
        couleur: const Color(0xFF4FC3F7),
        libelle: rg('son_lieu'),
        actif: _pisteLieu != null && joue.contains('asset:${_pisteLieu!.file}'),
        onTap: muet ? null : () => _jouerChoix(ChoixMusique.lieu),
      ),
      _Pad(
        icone: Icons.flash_on_rounded,
        couleur: Console.bleuDestiny,
        libelle: rg('son_destiny'),
        actif: c?.lecteurs[BusSon.destiny]!.actif ?? false,
        onTap: muet ? null : _sonDestiny,
      ),
      if (pack) ...[
        _Pad(
          icone: Icons.warning_rounded,
          couleur: const Color(0xFFFF7043),
          libelle: rs('danger'),
          detail: rs('palier', {'n': '${c!.acte}'}),
          actif: c.lecteurs[BusSon.bruitageA]!.actif || c.lecteurs[BusSon.bruitageB]!.actif,
          onTap: muet ? null : c.danger,
        ),
        _Pad(
          icone: Icons.shuffle_rounded,
          couleur: const Color(0xFFFFAB91),
          libelle: rs('autre'),
          onTap: muet ? null : c.autre,
        ),
        _Pad(
          icone: Icons.visibility_rounded,
          couleur: const Color(0xFFE879F9),
          libelle: rs('reveal'),
          actif: c.lecteurs[BusSon.stinger]!.actif,
          onTap: muet ? null : c.jouerReveal,
        ),
        _Pad(
          icone: Icons.wb_twilight_rounded,
          couleur: const Color(0xFFFFCC80),
          libelle: rs('fondu_fin'),
          onTap: () => c.fonduFin(),
        ),
      ],
      _Pad(
        icone: Icons.stop_rounded,
        couleur: Console.rouge,
        libelle: rg('son_stop'),
        plein: true,
        onTap: _stop,
      ),
    ];
    return _Grille(pads: pads, largeurMin: 108);
  }

  Widget _tranches(String Function(String, [Map<String, String>]) rs) {
    final c = _c!;
    return SizedBox(
      height: 232,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final b in BusSon.values)
            _Tranche(
              nom: rs('bus.${b.name}'),
              lecteur: c.lecteurs[b]!,
              gain: c.gain(b),
              niveau: c.niveau(b),
              attenue: b == BusSon.musique && c.attenue,
              libelleAttenue: rs('attenuee'),
              libelleStop: rs('arreter_voie'),
              vu: _vu,
              phase: b.index * 1.3,
              onGain: (g) => c.reglerGain(b, g),
              onStop: () => c.arreterBus(b),
            ),
        ],
      ),
    );
  }

  List<_Banque> _listeBanques(String Function(String, [Map<String, String>]) rs) {
    final rsOk = _rs;
    final m = rsOk?.pack.manifeste;
    final avecPack = rsOk != null && rsOk.pack.disponible && m != null;
    return [
      if (avecPack && m.dangers.containsKey(s.dangerId))
        (id: 'danger', libelle: rs('onglets.danger'), style: const StyleSon(Icons.warning_rounded, Color(0xFFFF7043))),
      if (avecPack)
        for (final cat in CategorieBruitage.values)
          if (m.sons.keys.any((code) => CategorieBruitage.de(code) == cat))
            (id: 'cat:${cat.name}', libelle: rs('categories.${cat.name}'), style: kStylesCategories[cat]!),
      (id: 'emotions', libelle: rs('onglets.emotions'), style: const StyleSon(Icons.mood_rounded, Color(0xFFFFD54F))),
      (id: 'ambiances', libelle: rs('onglets.ambiances'), style: const StyleSon(Icons.landscape_rounded, Color(0xFF4FC3F7))),
      (id: 'lieux', libelle: rs('onglets.lieux'), style: const StyleSon(Icons.place_rounded, Color(0xFF81C784))),
      (id: 'univers', libelle: rs('onglets.univers'), style: const StyleSon(Icons.public_rounded, Color(0xFF90CAF9))),
      (id: 'themes', libelle: rs('onglets.themes'), style: const StyleSon(Icons.auto_awesome_rounded, Console.or)),
    ];
  }

  Widget _banques(BuildContext context, String Function(String, [Map<String, String>]) rs, Set<String> joue, bool muet) {
    final banques = _listeBanques(rs);
    final choisie = banques.firstWhere((b) => b.id == _banque, orElse: () => banques.first);
    final rsOk = _rs;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (rsOk != null && !rsOk.pack.disponible)
        _Bandeau(
          icone: Icons.library_music_rounded,
          couleur: Console.or,
          texte: rs('banque_vide'),
          action: rsOk.pack.importPossible ? rs('importer') : null,
          onAction: () => Navigator.of(context)
              .push(MaterialPageRoute<void>(builder: (_) => PackAudioScreen(regieSon: rsOk))),
        ),
      SizedBox(
        height: 46,
        child: ListView(scrollDirection: Axis.horizontal, children: [
          for (final b in banques)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _Onglet(
                key: ValueKey('banque_${b.id}'),
                libelle: b.libelle,
                style: b.style,
                choisi: b.id == choisie.id,
                onTap: () => setState(() => _banque = b.id),
              ),
            ),
        ]),
      ),
      const SizedBox(height: 12),
      _contenuBanque(context, choisie, rs, joue, muet),
    ]);
  }

  Widget _contenuBanque(BuildContext context, _Banque b, String Function(String, [Map<String, String>]) rs,
      Set<String> joue, bool muet) {
    final c = _c;
    Widget padCode(String code) {
      final style = styleCode(code);
      final nom = _rs?.pack.manifeste?.sons[code]?.nom ?? code;
      return _Pad(
        icone: style.icone,
        couleur: style.couleur,
        libelle: nom,
        actif: _codeJoue(code, joue),
        onTap: muet || c == null ? null : () => c.jouerCode(code),
        onLongPress: muet || c == null ? null : () => c.autreCode(code),
      );
    }

    Widget padPiste(MusicTrack p, StyleSon style, {String? image}) => _Pad(
          icone: style.icone,
          couleur: style.couleur,
          libelle: p.title,
          image: image,
          actif: joue.contains('asset:${p.file}'),
          onTap: muet
              ? null
              : () {
                  if (joue.contains('asset:${p.file}')) {
                    c != null ? c.arreterBus(BusSon.musique) : _musique.stop();
                  } else if (c != null) {
                    c.jouerMusique(SourceAsset(p.file, titre: p.title));
                  } else {
                    _musique.playTrack(p, forceLoop: true);
                  }
                },
        );

    final m = _rs?.pack.manifeste;
    if (b.id == 'danger' && m != null) {
      final g = context.grammaire;
      final d = m.dangers[s.dangerId]!;
      final courant = c?.acte ?? s.palierAtteint;
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (var palier = 1; palier <= 4; palier++) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 8, top: 4),
            child: Row(children: [
              _Led(allumee: palier == courant, couleur: const Color(0xFFFF7043)),
              const SizedBox(width: 8),
              Text(
                '${rs('palier', {'n': '$palier'})} · ${g.palier(PalierId.deNumero(palier)).nom}',
                style: TextStyle(
                  fontFamily: kPoliceTexte,
                  fontWeight: FontWeight.w700,
                  color: palier == courant ? Console.texte : Console.doux,
                ),
              ),
            ]),
          ),
          _Grille(pads: [for (final code in d.codes(palier)) padCode(code)], largeurMin: 108),
          const SizedBox(height: 8),
        ],
      ]);
    }
    if (b.id.startsWith('cat:') && m != null) {
      final cat = CategorieBruitage.values.byName(b.id.substring(4));
      final codes = [for (final code in m.sons.keys) if (CategorieBruitage.de(code) == cat) code];
      return _Grille(pads: [for (final code in codes) padCode(code)], largeurMin: 108);
    }
    switch (b.id) {
      case 'emotions':
        return _Grille(
            pads: [for (final p in _musique.tracksOf('Émotions')) padPiste(p, styleEmotion(p.title))], largeurMin: 108);
      case 'ambiances':
        return _Grille(
            pads: [for (final p in _musique.tracksOf('Ambiances')) padPiste(p, styleAmbiance(p.title))], largeurMin: 108);
      case 'lieux':
        final pistes = [..._musique.tracksOf('Lieux')]
          ..sort((a, b) => (b.title == s.lieuNom ? 1 : 0) - (a.title == s.lieuNom ? 1 : 0));
        return _Grille(pads: [
          for (final p in pistes)
            padPiste(p, const StyleSon(Icons.place_rounded, Color(0xFF81C784)),
                image: 'assets/images/locations/${p.file.split('/').last.split('.').first}.jpg'),
        ], largeurMin: 120);
      case 'univers':
        return _Grille(pads: [
          for (final p in _musique.tracksOf('Univers'))
            padPiste(p, const StyleSon(Icons.public_rounded, Color(0xFF90CAF9))),
        ], largeurMin: 108);
      default:
        return _Grille(pads: [
          for (final p in _musique.tracksOf('Thèmes')) padPiste(p, styleTheme(p.title)),
          for (final e in AudioService.effets.entries)
            if (e.key != 'aucun')
              _Pad(
                icone: styleEffet(e.key).icone,
                couleur: styleEffet(e.key).couleur,
                libelle: e.value,
                onTap: muet
                    ? null
                    : () => c != null
                        ? c.jouerEffet(SourceAsset(AudioService.assetsEffets[e.key]!, titre: e.value))
                        : _audio.playEffet(e.key),
              ),
        ], largeurMin: 108);
    }
  }
}

// ------------------------------------------------------------ composants

class _Titre extends StatelessWidget {
  const _Titre(this.texte, {required this.icone});

  final String texte;
  final IconData icone;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(children: [
          Icon(icone, size: 18, color: Console.doux),
          const SizedBox(width: 8),
          Text(
            texte.toUpperCase(),
            style: const TextStyle(
              fontFamily: kPoliceTexte,
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
              letterSpacing: 1.8,
              color: Console.doux,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(child: Divider(color: Console.trait, height: 1)),
        ]),
      );
}

class _Info extends StatelessWidget {
  const _Info(this.icone, this.texte, {this.fort = false});

  final IconData icone;
  final String texte;
  final bool fort;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icone, size: 17, color: fort ? Console.or : Console.doux),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            texte,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: kPoliceTexte,
              fontWeight: fort ? FontWeight.w800 : FontWeight.w600,
              fontSize: 14.5,
              color: fort ? Console.or : Console.texte,
            ),
          ),
        ),
      ]);
}

class _PuceEtat extends StatelessWidget {
  const _PuceEtat({required this.pack, required this.actif, required this.rs});

  final bool pack;
  final bool actif;
  final String Function(String, [Map<String, String>]) rs;

  @override
  Widget build(BuildContext context) {
    final couleur = actif ? Console.vert : (pack ? Console.or : Console.doux);
    final texte = actif ? rs('pack_actif') : (pack ? rs('pack_inactif') : rs('pack_absent'));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: couleur.withValues(alpha: 0.7)),
        color: couleur.withValues(alpha: 0.12),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(actif ? Icons.auto_mode_rounded : Icons.library_music_outlined, size: 14, color: couleur),
        const SizedBox(width: 6),
        Text(texte, style: TextStyle(fontFamily: kPoliceTexte, fontSize: 12, fontWeight: FontWeight.w700, color: couleur)),
      ]),
    );
  }
}

class _Bandeau extends StatelessWidget {
  const _Bandeau({required this.icone, required this.couleur, required this.texte, this.action, this.onAction});

  final IconData icone;
  final Color couleur;
  final String texte;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(top: 10, bottom: 4),
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        decoration: BoxDecoration(
          color: couleur.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: couleur.withValues(alpha: 0.5)),
        ),
        child: Row(children: [
          Icon(icone, color: couleur),
          const SizedBox(width: 10),
          Expanded(
            child: Text(texte, style: const TextStyle(fontFamily: kPoliceTexte, color: Console.texte, height: 1.3)),
          ),
          if (action != null) TextButton(onPressed: onAction, child: Text(action!, style: TextStyle(color: couleur))),
        ]),
      );
}

class _Led extends StatelessWidget {
  const _Led({required this.allumee, required this.couleur});

  final bool allumee;
  final Color couleur;

  @override
  Widget build(BuildContext context) => Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: allumee ? couleur : Console.trait,
          boxShadow: allumee ? [BoxShadow(color: couleur.withValues(alpha: 0.8), blurRadius: 8, spreadRadius: 1)] : null,
        ),
      );
}

/// Une grille de pads qui remplit la largeur.
class _Grille extends StatelessWidget {
  const _Grille({required this.pads, required this.largeurMin});

  final List<Widget> pads;
  final double largeurMin;

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        const ecart = 10.0;
        final colonnes = max(3, ((c.maxWidth + ecart) / (largeurMin + ecart)).floor());
        final largeur = (c.maxWidth - ecart * (colonnes - 1)) / colonnes;
        return Wrap(spacing: ecart, runSpacing: ecart, children: [
          for (final p in pads) SizedBox(width: largeur, height: largeur.clamp(92, 118), child: p),
        ]);
      });
}

/// Un pad de la table : une icône dans sa couleur, un libellé, une LED qui
/// s'allume quand il joue.
class _Pad extends StatelessWidget {
  const _Pad({
    required this.icone,
    required this.couleur,
    required this.libelle,
    required this.onTap,
    this.onLongPress,
    this.detail,
    this.image,
    this.actif = false,
    this.repere = false,
    this.plein = false,
  });

  final IconData icone;
  final Color couleur;
  final String libelle;
  final String? detail;

  /// Une vignette (lieux) derrière le libellé.
  final String? image;
  final bool actif;

  /// Souligné (l'acte en cours).
  final bool repere;

  /// Tout en couleur (Stop).
  final bool plein;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final fond = plein
        ? couleur.withValues(alpha: 0.85)
        : Color.alphaBlend(couleur.withValues(alpha: actif ? 0.30 : 0.07), Console.pad);
    final bord = actif ? couleur : (repere ? couleur.withValues(alpha: 0.6) : Console.trait);
    final contenu = Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _Led(allumee: actif, couleur: couleur),
          const Spacer(),
          if (onLongPress != null) const Icon(Icons.more_horiz_rounded, size: 14, color: Console.doux),
        ]),
        const Spacer(),
        if (image == null)
          Center(
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: plein ? Colors.black26 : couleur.withValues(alpha: actif ? 0.35 : 0.16),
                boxShadow: actif ? [BoxShadow(color: couleur.withValues(alpha: 0.55), blurRadius: 16)] : null,
              ),
              child: Icon(icone, color: plein ? Colors.white : couleur, size: 24),
            ),
          ),
        const Spacer(),
        Text(
          libelle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: kPoliceTexte,
            fontWeight: FontWeight.w700,
            // Un mot long (« Émerveillement ») passe en plus petit plutôt que
            // d'être coupé au milieu.
            fontSize: libelle.split(' ').any((m) => m.length > 11) ? 10.5 : 12.5,
            height: 1.15,
            color: plein ? Colors.white : Console.texte,
          ),
        ),
        if (detail != null)
          Text(detail!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: kPoliceTexte, fontSize: 11, color: couleur.withValues(alpha: 0.9))),
      ]),
    );
    return Semantics(
      button: true,
      selected: actif,
      enabled: onTap != null,
      child: Opacity(
        opacity: onTap == null && onLongPress == null ? 0.45 : 1,
        child: Material(
          color: fond,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: bord, width: actif || repere ? 2 : 1),
          ),
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            splashColor: couleur.withValues(alpha: 0.35),
            child: Stack(fit: StackFit.expand, children: [
              if (image != null) ...[
                Image.asset(image!, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x33000000), Color(0xE6000000)],
                    ),
                  ),
                ),
              ],
              contenu,
            ]),
          ),
        ),
      ),
    );
  }
}

class _Onglet extends StatelessWidget {
  const _Onglet({super.key, required this.libelle, required this.style, required this.choisi, required this.onTap});

  final String libelle;
  final StyleSon style;
  final bool choisi;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: choisi ? style.couleur.withValues(alpha: 0.22) : Console.panneau,
        shape: StadiumBorder(side: BorderSide(color: choisi ? style.couleur : Console.trait, width: choisi ? 1.6 : 1)),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(style.icone, size: 18, color: style.couleur),
              const SizedBox(width: 8),
              Text(
                libelle,
                style: TextStyle(
                  fontFamily: kPoliceTexte,
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                  color: choisi ? Console.texte : Console.doux,
                ),
              ),
            ]),
          ),
        ),
      );
}

/// Une tranche de console : LED, vumètre, fader, ce qui joue, et stop.
class _Tranche extends StatelessWidget {
  const _Tranche({
    required this.nom,
    required this.lecteur,
    required this.gain,
    required this.niveau,
    required this.attenue,
    required this.libelleAttenue,
    required this.libelleStop,
    required this.vu,
    required this.phase,
    required this.onGain,
    required this.onStop,
  });

  final String nom;
  final LecteurSon lecteur;
  final double gain;
  final double niveau;
  final bool attenue;
  final String libelleAttenue;
  final String libelleStop;
  final Animation<double> vu;
  final double phase;
  final ValueChanged<double> onGain;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final actif = lecteur.actif;
    return Container(
      width: 112,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 6),
      decoration: BoxDecoration(
        color: Console.panneau,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: actif ? Console.or.withValues(alpha: 0.6) : Console.trait),
      ),
      child: Column(children: [
        Row(children: [
          _Led(allumee: actif, couleur: Console.vert),
          const SizedBox(width: 6),
          Expanded(
            child: Text(nom.toUpperCase(),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontFamily: kPoliceTexte, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.4, color: Console.doux)),
          ),
        ]),
        const SizedBox(height: 6),
        Expanded(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            AnimatedBuilder(
              animation: vu,
              builder: (_, __) => CustomPaint(
                size: const Size(14, double.infinity),
                painter: _Vumetre(
                  niveau: actif ? (niveau * gain).clamp(0.0, 1.0) : 0,
                  t: vu.value,
                  phase: phase,
                ),
              ),
            ),
            Expanded(
              child: RotatedBox(
                quarterTurns: 3,
                child: Slider(value: gain, onChanged: onGain),
              ),
            ),
          ]),
        ),
        SizedBox(
          height: 30,
          child: Text(
            attenue ? libelleAttenue : (lecteur.enCours?.titre ?? lecteur.enCours?.chemin.split('/').last ?? '—'),
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontFamily: kPoliceTexte, fontSize: 10.5, height: 1.2, color: attenue ? Console.or : Console.texte),
          ),
        ),
        SizedBox(
          height: 30,
          child: IconButton(
            tooltip: libelleStop,
            padding: EdgeInsets.zero,
            iconSize: 20,
            onPressed: actif ? onStop : null,
            icon: Icon(Icons.stop_circle_rounded, color: actif ? Console.rouge : Console.trait),
          ),
        ),
      ]),
    );
  }
}

/// Un vumètre à LED : vert, jaune puis rouge, qui bat tant que la voie joue.
class _Vumetre extends CustomPainter {
  _Vumetre({required this.niveau, required this.t, required this.phase});

  final double niveau;
  final double t;
  final double phase;

  static const int segments = 14;

  @override
  void paint(Canvas canvas, Size size) {
    final battement = 0.62 + 0.38 * (sin(t * 2 * pi * 3 + phase).abs() * 0.7 + sin(t * 2 * pi * 7 + phase * 2).abs() * 0.3);
    final allumes = (niveau * battement * segments).round();
    final h = size.height / segments;
    for (var i = 0; i < segments; i++) {
      final y = size.height - (i + 1) * h;
      final couleur = i >= segments - 2
          ? Console.rouge
          : i >= segments - 5
              ? const Color(0xFFFFD54F)
              : Console.vert;
      final peinture = Paint()..color = i < allumes ? couleur : couleur.withValues(alpha: 0.12);
      canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(1, y + 1, size.width - 2, h - 2), const Radius.circular(2)), peinture);
    }
  }

  @override
  bool shouldRepaint(_Vumetre old) => old.niveau != niveau || old.t != t;
}

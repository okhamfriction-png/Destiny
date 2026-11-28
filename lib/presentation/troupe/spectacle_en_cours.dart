import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../application/son/conduite_son.dart';
import '../../application/son/regie_son.dart';
import '../../application/state/reglages_destiny.dart';
import '../../domain/entities/danger.dart';
import '../../domain/grammaire/chronos.dart';
import '../../domain/exercices/exercices_destiny.dart';
import '../../domain/grammaire/modeles.dart';
import '../../domain/troupe/annonce_destiny.dart';
import '../../domain/troupe/session.dart';
import '../destiny/composants.dart';
import '../destiny/donnees.dart';
import '../destiny/rituel_destiny.dart';
import '../regie_son/table_regie.dart';
import '../theme/destiny_theme.dart';
import 'composants_troupe.dart';
import 'regie_screen.dart';
import 'troupe_screen.dart';

/// Ce qui se joue : le chrono, les trois Destiny, le rituel et la conduite
/// son. Il vit avec l'écran du jeu, pas avec la régie : la régie s'ouvre en
/// pop-up et se ferme sans rien arrêter. Le même sert au théâtre (une
/// session de la Troupe) et au jeu de rôle (un épisode de la Série).
class SpectacleEnCours extends ChangeNotifier {
  SpectacleEnCours({
    required this.contexte,
    required this.session,
    required this.contexteRituel,
    required this.enregistrer,
    this.aLaFin,
    this.dangers,
    this.protagonistes = 0,
    Random? hasard,
  }) : _hasard = hasard ?? Random() {
    if (session.destinys.isNotEmpty) _ecoule = session.destinys.last.secondes;
    conduite?.preparer(lieuId: session.lieuId, dangerId: session.dangerId, acte: session.acteAtteint);
  }

  /// Le spectacle d'une session de la Troupe.
  factory SpectacleEnCours.troupe(ContexteTroupe c, SessionTroupe s, {required BuildContext? Function() contexteRituel}) =>
      SpectacleEnCours(
        contexte: c,
        session: s,
        contexteRituel: contexteRituel,
        enregistrer: () => c.store.enregistrer(s),
        aLaFin: () => s.etape = EtapeSession.terminee,
        dangers: c.catalogue.getDangers,
        protagonistes: s.personnages.length,
      );

  final SourcesSon contexte;
  final SceneJouee session;

  /// Enregistre la scène (après un Destiny, une frise déplacée, la fin).
  final Future<void> Function() enregistrer;

  /// Marque la scène terminée, avant le dernier enregistrement.
  final void Function()? aLaFin;

  /// L'écran d'où ouvrir le rituel Destiny (null s'il n'est plus là).
  BuildContext? Function() contexteRituel;

  /// Le catalogue des dangers : sans danger au départ (la Troupe), le
  /// DESTINY n°1 le tire au dé. Null : le danger est déjà là (la Série).
  final Future<List<Danger>> Function()? dangers;

  /// Le nombre de protagonistes, pour le dé des survivants du DESTINY n°3
  /// (0 : pas de dé).
  final int protagonistes;

  final Random _hasard;
  List<Danger> _catalogueDangers = const [];

  /// Le type tiré au dé du danger (DESTINY n°1).
  TypeDanger? typeDanger;

  Timer? _minuteur;
  int _ecoule = 0;
  bool _demarre = false;
  bool _rituelEnCours = false;
  bool _libere = false;
  final List<Timer> _musiques = [];

  SceneJouee get s => session;
  ReglagesDestiny get r => contexte.reglages;
  int get ecoule => _ecoule;
  bool get demarre => _demarre;
  bool get rituelEnCours => _rituelEnCours;
  bool get enMarche => _minuteur?.isActive ?? false;
  int get total => s.dureeMinutes * 60;
  /// L'acte en cours (1 à 4).
  int get acte => s.acteAtteint.clamp(1, kNombreActes);

  /// Le niveau du danger (null à l'acte 1, sans danger).
  PalierId? get palier => PalierId.pourActe(acte);

  /// La conduite son du spectacle : avec le pack audio, ses musiques et ses
  /// bruitages ; sans, les musiques des réglages et l'ambiance du lieu. Les
  /// deux enchaînent pareil.
  ConduiteSon? get conduite => contexte.regieSon?.conduite;
  bool get conduiteActive => conduite != null;

  /// Sans chrono : les Destiny partent à la main, quand on veut.
  bool get avecChrono => s.dureeMinutes > 0 && s.destinyMinutes.isNotEmpty;

  /// L'index (0 à 2) du prochain Destiny, ou null s'ils sont tous passés.
  int? get prochain {
    final nombre = avecChrono ? s.destinyMinutes.length : 3;
    return s.destinys.length < nombre && acte < kNombreActes ? s.destinys.length : null;
  }

  void _changer() {
    if (!_libere) notifyListeners();
  }

  /// Démarre, met en pause ou reprend le chrono.
  void basculer() {
    if (enMarche) {
      _minuteur?.cancel();
      // Pause : une séquence Destiny en cours s'arrête net, et la musique se
      // met en pause avec le chrono.
      if (conduiteActive) {
        unawaited(conduite!.pause());
      } else if (contexte.musique.playing) {
        unawaited(contexte.musique.togglePlayPause());
      }
      _changer();
      return;
    }
    if (_demarre) {
      // Reprise : la musique repart où elle en était.
      if (conduiteActive) {
        unawaited(conduite!.reprendre());
      } else if (contexte.musique.current != null && !contexte.musique.playing) {
        unawaited(contexte.musique.togglePlayPause());
      }
    } else {
      _demarre = true;
      if (conduiteActive) {
        // La musique de l'acte 1 (puis le bruitage du palier 1 et l'ambiance
        // du lieu) ; un spectacle repris en cours repart sur son acte.
        conduite!.preparer(lieuId: s.lieuId, dangerId: s.dangerId, acte: s.acteAtteint);
        if (s.destinys.isEmpty) {
          // Déjà ouverte par le minuteur du jeu : la musique continue.
          if (!conduite!.ouverte) unawaited(conduite!.ouverture());
        } else {
          unawaited(conduite!.musiqueActe(s.acteAtteint));
        }
      } else if (!contexte.audio.muted && r.musiqueActe(1) != ChoixMusique.aucune) {
        conduite?.arreterBus(BusSon.musique);
        contexte.musique.jouerChoix(r.musiqueActe(1), lieu: s.lieuNom);
      }
    }
    _minuteur = Timer.periodic(const Duration(seconds: 1), (_) => _seconde());
    _changer();
  }

  void _seconde() {
    if (_libere) return;
    _ecoule++;
    _changer();
    if (_ecoule == total) {
      contexte.audio.playCrack();
      // Pas de coupure automatique (l'impro peut déborder), sauf si on la veut.
      final regie = contexte.regieSon;
      if (conduiteActive && regie != null) {
        if (regie.reglages.v.conclusionFinChrono) {
          unawaited(conduite!.conclusion());
        } else if (regie.reglages.v.coupureFinChrono) {
          unawaited(conduite!.fonduFin());
        }
      }
    }
    if (_ecoule == total - 10) contexte.audio.playThunder();
    final auto = avecChrono && r.declenchement != Declenchement.manuel;
    final p = prochain;
    if (auto && !_rituelEnCours && p != null && _ecoule >= s.destinyMinutes[p] * 60) {
      destiny(manuel: false);
    }
  }

  /// Lance le prochain Destiny : à la main (le bouton, quel que soit le
  /// réglage du déclenchement) ou par le chrono.
  Future<void> destiny({required bool manuel}) async {
    if (_rituelEnCours || prochain == null) return;
    _rituelEnCours = true;
    final numero = s.destinys.length + 1;
    final niveau = PalierId.deNumero(numero);
    s.destinys.add(EvenementDestiny(numero: numero, secondes: _ecoule, manuel: manuel));
    s.acteAtteint = niveau.acte;
    // Le spectacle commence avec un lieu seulement : le danger tombe au
    // DESTINY n°1. Au n°3, le nombre de survivants.
    if (numero == 1 && s.dangerNom.isEmpty && dangers != null) await _tirerDanger();
    final session = s;
    int? survivants;
    if (niveau == PalierId.tue && protagonistes > 0 && session is SessionTroupe) {
      survivants = tirerSurvivants(protagonistes, hasard: _hasard);
      session.survivants = survivants == null ? '' : '$survivants';
    }
    await enregistrer();
    _programmerMusiques(s.destinys.length);
    if (_libere) return;
    _changer();
    final annonce = AnnonceDestiny(
      niveau: niveau,
      danger: niveau == PalierId.enferme ? s.dangerNom : '',
      dangerId: niveau == PalierId.enferme ? s.dangerId : '',
      survivants: survivants,
    );
    final ctx = contexteRituel();
    if (ctx != null && ctx.mounted) {
      await lancerRituelDestiny(
        ctx,
        annonce: annonce,
        reglages: ReglagesRituel(
          lumiereBleue: r.lumiereBleue,
          dureeFige: Duration(seconds: r.dureeFigeSecondes),
          reduireAnimations: r.reduireAnimations,
        ),
        auTonnerre: () => _sonDestiny(),
        aLAnnonce: () => unawaited(_annoncer(annonce)),
      );
    } else {
      _sonDestiny();
      unawaited(_annoncer(annonce));
    }
    _rituelEnCours = false;
    _changer();
  }

  /// La dernière annonce faite (pour les tests et la régie).
  AnnonceDestiny? derniereAnnonce;

  /// Dit l'annonce : le son du pack s'il existe, sinon la synthèse vocale.
  /// Rien si le son de l'appli est coupé.
  Future<void> _annoncer(AnnonceDestiny annonce) async {
    derniereAnnonce = annonce;
    if (_libere || contexte.audio.muted) return;
    final c = conduite;
    if (c != null && await c.jouerAnnonce(annonce.codeSon)) return;
    final ctx = contexteRituel();
    final textes = ctx != null && ctx.mounted ? ctx.textes : null;
    if (textes == null) return;
    await contexte.audio.dire(annonce.voix(textes.t));
  }

  bool get _kids => s is SessionTroupe && (s as SessionTroupe).kids;

  /// Le dé du danger : un type, puis un danger de ce type. Rend faux s'il
  /// n'y a aucun danger à tirer.
  Future<bool> _tirerDanger() async {
    try {
      _catalogueDangers = await dangers!();
    } catch (_) {
      return false;
    }
    final tirage = tirerDangerAuDe(_catalogueDangers, kids: _kids, hasard: _hasard);
    typeDanger = tirage.type;
    final d = tirage.danger;
    if (d == null) return false;
    _poserDanger(d);
    return true;
  }

  void _poserDanger(Danger d) {
    final session = s;
    if (session is SessionTroupe) {
      session
        ..dangerId = d.id
        ..dangerNom = d.name
        ..paliers = d.paliersPour(kids: session.kids);
    }
    // La conduite son joue désormais les bruitages de ce danger.
    conduite?.preparer(lieuId: s.lieuId, dangerId: s.dangerId, acte: s.acteAtteint);
    _changer();
  }

  /// Le son du Destiny, au tonnerre du rituel.
  void _sonDestiny() {
    if (contexte.audio.muted) return;
    if (conduiteActive) {
      // La conduite enchaîne tout : sortie de la musique, son Destiny,
      // REVEAL, bruitage du nouveau palier, musique de l'acte.
      unawaited(conduite!.destiny(s.destinys.length));
      return;
    }
    contexte.audio.playEffet(r.sonDestiny);
    contexte.musique.jouerDestiny(r.musiqueDestiny);
  }

  /// La musique de l'acte qui commence, 15 s après le Destiny [numero] (celle
  /// des réglages : l'acte 2 après le 1er Destiny, et ainsi de suite).
  void _programmerMusiques(int numero) {
    if (contexte.audio.muted || conduiteActive) return;
    final choix = r.musiqueActe(numero + 1);
    if (choix == ChoixMusique.aucune) return;
    _musiques.add(Timer(const Duration(seconds: 15), () {
      if (_libere) return;
      conduite?.arreterBus(BusSon.musique);
      contexte.musique.jouerChoix(choix, lieu: s.lieuNom);
    }));
  }

  /// Place le Destiny [index] à [minute], au doigt sur la frise. Rend faux
  /// si les règles le refusent.
  bool placer(int index, int minute) {
    if (refusDestiny(s, index: index, minute: minute, ecouleSecondes: _ecoule) != null) return false;
    s.destinyMinutes = [...s.destinyMinutes]..[index] = minute;
    enregistrer();
    _changer();
    return true;
  }

  /// La durée la plus courte qu'on peut encore choisir, en minutes.
  int get dureeMini =>
      dureeMiniSpectacle(s.destinyMinutes, lances: s.destinys.length, ecouleSecondes: _ecoule);

  /// Change la durée du chrono : les Destiny pas encore lancés suivent, au
  /// prorata. Rend faux si la durée est trop courte pour ce qui reste.
  bool changerDuree(int minutes) {
    if (!avecChrono || minutes == s.dureeMinutes) return avecChrono;
    final d = adapterDestinys(
      s.destinyMinutes,
      ancienneDuree: s.dureeMinutes,
      nouvelleDuree: minutes,
      lances: s.destinys.length,
      ecouleSecondes: _ecoule,
    );
    if (d == null) return false;
    s
      ..dureeMinutes = minutes
      ..destinyMinutes = d;
    enregistrer();
    _changer();
    return true;
  }

  /// Termine le spectacle : plus de chrono, plus de son. La scène est
  /// marquée terminée ([aLaFin]) et enregistrée.
  Future<void> terminer() async {
    _minuteur?.cancel();
    for (final t in _musiques) {
      t.cancel();
    }
    await conduite?.stopTout();
    aLaFin?.call();
    await enregistrer();
    _changer();
  }

  @override
  void dispose() {
    _libere = true;
    _minuteur?.cancel();
    for (final t in _musiques) {
      t.cancel();
    }
    // Le spectacle quitté : plus rien ne joue, ni séquence ni son orphelin.
    final c = conduite;
    if (c != null) unawaited(c.stopTout());
    super.dispose();
  }
}

/// Le spectacle vu depuis la table de régie ou l'écran du jeu : le chrono,
/// l'acte, la pause et DESTINY, toujours sous la main.
PiloteSpectacle piloteDe(BuildContext context, SpectacleEnCours sp) => PiloteSpectacle(
      change: sp,
      // Sans chrono, le temps passé.
      reste: () => horloge(sp.avecChrono ? sp.total - sp.ecoule : sp.ecoule),
      acte: () => libelleActe(context, sp.acte),
      enMarche: () => sp.enMarche,
      changerDuree: () => sp.avecChrono ? () => choisirDureeSpectacle(context, sp) : null,
      basculer: sp.basculer,
      libelleBasculer: () =>
          context.textes.t(sp.enMarche ? 'regie.pause' : (sp.demarre ? 'regie.reprendre' : 'regie.demarrer')),
      destiny: () => sp.prochain == null || sp.rituelEnCours ? null : () => sp.destiny(manuel: true),
      libelleDestiny: () {
        final t = context.textes;
        final p = sp.prochain;
        return p == null ? t.t('regie.destiny') : t.t('regie.destiny_n', {'n': '${p + 1}'});
      },
    );

/// Touché sur le chrono : on choisit une autre durée, et les Destiny pas
/// encore lancés suivent, au prorata. Le chrono continue pendant ce temps.
Future<void> choisirDureeSpectacle(BuildContext context, SpectacleEnCours sp) async {
  final t = context.textes;
  final mini = sp.dureeMini;
  var minutes = max(sp.s.dureeMinutes, mini);
  final choix = await showDialog<int>(
    context: context,
    builder: (context) => StatefulBuilder(builder: (context, setState) {
      final apercu = adapterDestinys(
            sp.s.destinyMinutes,
            ancienneDuree: sp.s.dureeMinutes,
            nouvelleDuree: minutes,
            lances: sp.s.destinys.length,
            ecouleSecondes: sp.ecoule,
          ) ??
          sp.s.destinyMinutes;
      void changer(int m) => setState(() => minutes = m.clamp(mini, 600));
      Widget pas(String libelle, int delta, {Key? key}) => OutlinedButton(
            key: key,
            onPressed: minutes + delta < mini || minutes + delta > 600 ? null : () => changer(minutes + delta),
            style: OutlinedButton.styleFrom(minimumSize: const Size(52, 44), padding: EdgeInsets.zero),
            child: Text(libelle),
          );
      return AlertDialog(
        title: Text(t.t('regie.duree_titre')),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(
            t.t('regie.duree_minutes', {'n': '$minutes'}),
            key: const ValueKey('duree_choisie'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: kPoliceTitres, fontWeight: FontWeight.w900, fontSize: 30),
          ),
          const SizedBox(height: 10),
          Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
            pas('−5', -5, key: const ValueKey('duree_moins_5')),
            pas('−1', -1, key: const ValueKey('duree_moins_1')),
            pas('+1', 1, key: const ValueKey('duree_plus_1')),
            pas('+5', 5, key: const ValueKey('duree_plus_5')),
          ]),
          const SizedBox(height: 14),
          for (var i = 0; i < apercu.length; i++)
            Text(
              t.t(i < sp.s.destinys.length ? 'regie.duree_destiny_passe' : 'regie.duree_destiny',
                  {'n': '${i + 1}', 'm': '${apercu[i]}'}),
              key: ValueKey('apercu_destiny_$i'),
              style: const TextStyle(fontFamily: kPoliceTexte, fontSize: 15),
            ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(t.t('regie.duree_annuler'))),
          FilledButton(
            key: const ValueKey('duree_valider'),
            onPressed: () => Navigator.pop(context, minutes),
            child: Text(t.t('regie.duree_valider')),
          ),
        ],
      );
    }),
  );
  if (choix != null) sp.changerDuree(choix);
}

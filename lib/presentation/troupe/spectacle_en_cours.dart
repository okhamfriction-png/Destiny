import 'dart:async';

import 'package:flutter/material.dart';

import '../../application/son/conduite_son.dart';
import '../../application/state/reglages_destiny.dart';
import '../../domain/grammaire/modeles.dart';
import '../../domain/troupe/session.dart';
import '../destiny/donnees.dart';
import '../destiny/rituel_destiny.dart';
import '../regie_son/table_regie.dart';
import 'composants_troupe.dart';
import 'regie_screen.dart';
import 'troupe_screen.dart';

/// Le spectacle qui se joue : le chrono, les trois Destiny, le rituel et la
/// conduite son. Il vit avec l'écran du jeu, pas avec la régie : la régie
/// s'ouvre en pop-up et se ferme sans rien arrêter.
class SpectacleEnCours extends ChangeNotifier {
  SpectacleEnCours({required this.contexte, required this.session, required this.contexteRituel}) {
    if (session.destinys.isNotEmpty) _ecoule = session.destinys.last.secondes;
    conduite?.preparer(lieuId: session.lieuId, dangerId: session.dangerId, acte: session.palierAtteint);
  }

  final ContexteTroupe contexte;
  final SessionTroupe session;

  /// L'écran d'où ouvrir le rituel Destiny (null s'il n'est plus là).
  BuildContext? Function() contexteRituel;

  Timer? _minuteur;
  int _ecoule = 0;
  bool _demarre = false;
  bool _rituelEnCours = false;
  bool _libere = false;
  final List<Timer> _musiques = [];

  SessionTroupe get s => session;
  ReglagesDestiny get r => contexte.reglages;
  int get ecoule => _ecoule;
  bool get demarre => _demarre;
  bool get rituelEnCours => _rituelEnCours;
  bool get enMarche => _minuteur?.isActive ?? false;
  int get total => s.dureeMinutes * 60;
  PalierId get palier => PalierId.deNumero(s.palierAtteint);

  /// La conduite son automatique du spectacle (pack audio importé et actif).
  ConduiteSon? get conduite => contexte.regieSon?.conduite;
  bool get conduiteActive => conduite?.active ?? false;

  /// L'index (0 à 2) du prochain Destiny, ou null s'ils sont tous passés.
  int? get prochain =>
      s.destinys.length < s.destinyMinutes.length && palier != PalierId.supprime ? s.destinys.length : null;

  void _changer() {
    if (!_libere) notifyListeners();
  }

  /// Démarre, met en pause ou reprend le chrono.
  void basculer() {
    if (enMarche) {
      _minuteur?.cancel();
      // Une séquence Destiny en cours s'arrête net avec le chrono.
      if (conduiteActive) unawaited(conduite!.annulerSequence());
      _changer();
      return;
    }
    if (!_demarre) {
      _demarre = true;
      if (conduiteActive) {
        // Conduite du spectacle : le son Destiny puis la musique de l'acte 1 ;
        // un spectacle repris en cours repart sur son acte.
        if (s.destinys.isEmpty) {
          unawaited(conduite!.ouverture());
        } else {
          unawaited(conduite!.musiqueActe(s.palierAtteint));
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
    final auto = r.declenchement != Declenchement.manuel;
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
    final premier = s.destinys.isEmpty;
    final nouveau = PalierId.values[palier.index + 1];
    s.destinys.add(EvenementDestiny(numero: s.destinys.length + 1, secondes: _ecoule, manuel: manuel));
    s.palierAtteint = nouveau.numero;
    await contexte.store.enregistrer(s);
    _programmerMusiques(s.destinys.length);
    if (_libere) return;
    _changer();
    final nouvelle = s.paliers.length > nouveau.index ? s.paliers[nouveau.index] : null;
    final ctx = contexteRituel();
    if (ctx != null && ctx.mounted) {
      await lancerRituelDestiny(
        ctx,
        nouveauPalier: nouveau,
        nouvelle: nouvelle,
        premierFige: premier,
        reglages: ReglagesRituel(
          lumiereBleue: r.lumiereBleue,
          dureeFige: Duration(seconds: r.dureeFigeSecondes),
          texteEllipse: r.texteEllipse.isEmpty ? null : r.texteEllipse,
          reduireAnimations: r.reduireAnimations,
          rappelPremierFige: r.rappelPremierFige,
        ),
        auTonnerre: () => _sonDestiny(),
      );
    } else {
      _sonDestiny();
    }
    _rituelEnCours = false;
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
    contexte.store.enregistrer(s);
    _changer();
    return true;
  }

  /// Termine le spectacle : plus de chrono, plus de son. La session est
  /// rangée dans l'historique (sans débrief).
  Future<void> terminer() async {
    _minuteur?.cancel();
    for (final t in _musiques) {
      t.cancel();
    }
    await conduite?.stopTout();
    s.etape = EtapeSession.terminee;
    await contexte.store.enregistrer(s);
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
      reste: () => horloge(sp.total - sp.ecoule),
      acte: () {
        final t = context.textes;
        final p = context.grammaire.palier(sp.palier);
        return '${t.t('regie.acte', {'n': '${p.acte}'})} — ${p.nom}';
      },
      enMarche: () => sp.enMarche,
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

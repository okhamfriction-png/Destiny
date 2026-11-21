import 'dart:convert';

import 'package:destiny/application/notes/acces_admin.dart';
import 'package:destiny/application/notes/notes_controller.dart';
import 'package:destiny/domain/notes/chiffrement_notes.dart';
import 'package:destiny/domain/notes/depot_notes.dart';
import 'package:destiny/domain/notes/notes.dart';
import 'package:destiny/infrastructure/datasources/cache_notes.dart';
import 'package:destiny/infrastructure/datasources/depot_notes_github.dart';
import 'package:destiny/infrastructure/platform/coffre_secret.dart';
import 'package:destiny/presentation/notes/notes_edition.dart';
import 'package:destiny/presentation/destiny/donnees.dart';
import 'package:destiny/presentation/theme/destiny_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'outils/grammaire_partagee.dart';
import 'outils/textes_utilises.dart';

/// Un dépôt en mémoire : chaque écriture change le `sha`, et une écriture
/// avec un `sha` périmé est refusée, comme sur GitHub.
class DepotMemoire implements DepotNotes {
  final Map<String, FichierDistant> fichiers = {};
  var _n = 0;
  bool horsLigne = false;

  String _sha() => 'sha${_n++}';

  /// Quelqu'un d'autre modifie le fichier.
  void modifierAilleurs(String chemin, String contenu) => fichiers[chemin] = FichierDistant(contenu: contenu, sha: _sha());

  @override
  Future<FichierDistant?> lire(String chemin) async {
    if (horsLigne) throw const HorsLigne();
    return fichiers[chemin];
  }

  @override
  Future<String> ecrire(String chemin, String contenu, {String? sha, required String message}) async {
    if (horsLigne) throw const HorsLigne();
    final actuel = fichiers[chemin];
    if (actuel != null && actuel.sha != sha) throw ConflitSha(chemin);
    final f = FichierDistant(contenu: contenu, sha: _sha());
    fichiers[chemin] = f;
    return f.sha;
  }
}

/// Des paramètres rapides pour les tests (la vraie dérivation est testée à
/// part, avec 310 000 itérations).
Map<String, Object?> parametresRapides() => ChiffrementNotes.parametres(ChiffrementNotes.nouveauSel(), iterations: 1000);

Future<List<int>> deriverDirect(String m, Map<String, Object?> p) async =>
    ChiffrementNotes.octetsDeLaCle(await ChiffrementNotes.deriverCle(m, p));

/// Une branche de notes initialisée avec le mot de passe [motDePasse].
Future<DepotMemoire> depotInitialise(String motDePasse) async {
  final depot = DepotMemoire();
  final p = parametresRapides();
  final cle = await ChiffrementNotes.deriverCle(motDePasse, p);
  depot.modifierAilleurs('crypto.json', jsonEncode(p));
  depot.modifierAilleurs('canari.enc', await ChiffrementNotes.canari(cle));
  return depot;
}

const seance = ProchaineSeance(
  date: '2026-11-22',
  heure: '14 h – 17 h',
  lieu: 'Salle Vilar',
  objectif: 'Les lieux et la spontanéité.',
  deroule: ['En duo, les objets', 'En duo, objets, prénom et relation', 'En trios : l\'acte 1'],
  prochainSpectacle: 'Jeudi 3 décembre',
  distribution: 'Marouene, Gabriel, Elena',
  devise: '_Attitude et lâchez-vous_',
);

void main() {
  group('Le chiffrement', () {
    test('aller-retour AES-256-GCM, enveloppe { v, nonce, ct } avec l\'étiquette au bout', () async {
      final p = parametresRapides();
      final cle = await ChiffrementNotes.deriverCle('un mot de passe', p);
      const texte = '{"titre": "Répète du 22/11 — Gérard ! mon frère ! 🎭"}';
      final enveloppe = await ChiffrementNotes.chiffrer(cle, texte);
      final e = jsonDecode(enveloppe) as Map<String, dynamic>;
      expect(e.keys, unorderedEquals(['v', 'nonce', 'ct']));
      expect(e['v'], 1);
      expect(base64.decode(e['nonce'] as String), hasLength(12));
      expect(base64.decode(e['ct'] as String), hasLength(utf8.encode(texte).length + 16));
      expect(enveloppe, isNot(contains('Gérard')));
      expect(await ChiffrementNotes.dechiffrer(cle, enveloppe), texte);
      // Deux chiffrements du même texte ne se ressemblent pas (nonce aléatoire).
      expect(await ChiffrementNotes.chiffrer(cle, texte), isNot(enveloppe));
    });

    test('PBKDF2-HMAC-SHA256 à 310 000 itérations, sel de 16 octets', () async {
      final p = ChiffrementNotes.parametres(ChiffrementNotes.nouveauSel());
      expect(p['iterations'], 310000);
      expect(p['kdf'], 'PBKDF2-HMAC-SHA256');
      expect(base64.decode(p['sel'] as String), hasLength(16));
      final a = await ChiffrementNotes.octetsDeLaCle(await ChiffrementNotes.deriverCle('secret', p));
      final b = await ChiffrementNotes.octetsDeLaCle(await ChiffrementNotes.deriverCle('secret', p));
      expect(a, hasLength(32));
      expect(a, b);
    });

    test('un mauvais mot de passe est refusé', () async {
      final p = parametresRapides();
      final bonne = await ChiffrementNotes.deriverCle('le bon', p);
      final mauvaise = await ChiffrementNotes.deriverCle('le mauvais', p);
      final canari = await ChiffrementNotes.canari(bonne);
      expect(await ChiffrementNotes.verifierCanari(bonne, canari), isTrue);
      expect(await ChiffrementNotes.verifierCanari(mauvaise, canari), isFalse);
      expect(() => ChiffrementNotes.dechiffrer(mauvaise, canari), throwsA(isA<MotDePasseIncorrect>()));
    });
  });

  group('L\'accès administrateur', () {
    test('mauvais mot de passe : refusé, et rien n\'est gardé', () async {
      final depot = await depotInitialise('le bon');
      final coffre = CoffreMemoire();
      final a = AccesAdmin(coffre: coffre, fabriqueDepot: (_) => depot, deriver: deriverDirect);
      expect(await a.deverrouiller(token: 'github_pat_xxxx1234', motDePasse: 'le mauvais'), ResultatAcces.motDePasseIncorrect);
      expect(a.actif, isFalse);
      expect(coffre.valeurs, isEmpty);
    });

    test('bon mot de passe : le token et la clé (pas le mot de passe) vont au coffre', () async {
      final depot = await depotInitialise('le bon');
      final coffre = CoffreMemoire();
      final a = AccesAdmin(coffre: coffre, fabriqueDepot: (_) => depot, deriver: deriverDirect);
      expect(await a.deverrouiller(token: ' github_pat_xxxx1234 ', motDePasse: 'le bon'), ResultatAcces.ok);
      expect(a.actif, isTrue);
      expect(a.tokenMasque, '••••1234');
      expect(coffre.valeurs[AccesAdmin.kToken], 'github_pat_xxxx1234');
      expect(base64.decode(coffre.valeurs[AccesAdmin.kCle]!), hasLength(32));
      expect(coffre.valeurs.values.join(), isNot(contains('le bon')));
      // Le token ne s'affiche qu'avec le mot de passe.
      expect(await a.tokenEnClair('le mauvais'), isNull);
      expect(await a.tokenEnClair('le bon'), 'github_pat_xxxx1234');
      // Rechargé au lancement suivant.
      final relu = AccesAdmin(coffre: coffre, fabriqueDepot: (_) => depot, deriver: deriverDirect);
      await relu.charger();
      expect(relu.actif, isTrue);
    });

    test('le verrouillage efface le token, la clé et le cache', () async {
      final depot = await depotInitialise('le bon');
      final coffre = CoffreMemoire();
      final a = AccesAdmin(coffre: coffre, fabriqueDepot: (_) => depot, deriver: deriverDirect);
      await a.deverrouiller(token: 'tok_abcd', motDePasse: 'le bon');
      final cache = CacheMemoire();
      final n = NotesController(acces: a, cache: cache);
      await n.enregistrerSeance(seance);
      expect(cache.fichiers, isNotEmpty);
      await a.verrouiller();
      await n.oublier();
      expect(a.actif, isFalse);
      expect(a.cle, isNull);
      expect(coffre.valeurs, isEmpty);
      expect(cache.fichiers, isEmpty);
      expect(n.seance, isNull);
      expect(a.depot, isNull);
    });

    test('token refusé, notes absentes, hors ligne : un message clair', () async {
      final vide = DepotMemoire();
      AccesAdmin avec(DepotNotes d) => AccesAdmin(coffre: CoffreMemoire(), fabriqueDepot: (_) => d, deriver: deriverDirect);
      expect(await avec(vide).deverrouiller(token: 't', motDePasse: 'm'), ResultatAcces.notesIntrouvables);
      expect(await avec(vide).deverrouiller(token: '', motDePasse: 'm'), ResultatAcces.champsVides);
      expect(await avec(vide..horsLigne = true).deverrouiller(token: 't', motDePasse: 'm'), ResultatAcces.horsLigne);
      final refuse = DepotNotesGithub(
          token: 't', client: MockClient((_) async => http.Response('{"message":"Bad credentials"}', 401)));
      expect(await avec(refuse).deverrouiller(token: 't', motDePasse: 'm'), ResultatAcces.tokenRefuse);
    });
  });

  group('Les notes', () {
    late DepotMemoire depot;
    late AccesAdmin acces;
    late NotesController n;
    setUp(() async {
      depot = await depotInitialise('le bon');
      acces = AccesAdmin(coffre: CoffreMemoire(), fabriqueDepot: (_) => depot, deriver: deriverDirect);
      await acces.deverrouiller(token: 'tok', motDePasse: 'le bon');
      n = NotesController(acces: acces, cache: CacheMemoire(), aujourdhui: () => '2026-11-21');
    });

    EntreeNote entree(String titre, {String date = '2026-11-19', TypeNote type = TypeNote.spectacle}) => EntreeNote(
          id: idEntree(date, type, titre),
          date: date,
          type: type,
          titre: titre,
          resume: 'Résumé',
          contenuMd: '- 19:46, une infirmière parle de la petite lumière',
          creeLe: '2026-11-21',
          misAJourLe: '2026-11-21',
        );

    test('une entrée s\'enregistre chiffrée, l\'index suit, le fil se filtre et se cherche', () async {
      await n.enregistrerEntree(entree('« Météorite »'));
      await n.enregistrerEntree(entree('Notes de répète', date: '2026-11-15', type: TypeNote.repetition));
      expect(depot.fichiers.keys, containsAll(['index.enc', 'entries/2026-11-19_spectacle_meteorite.enc']));
      expect(depot.fichiers['index.enc']!.contenu, isNot(contains('Météorite')));
      // Relu depuis GitHub par un autre appareil.
      final autre = NotesController(acces: acces, cache: CacheMemoire());
      await autre.rafraichir();
      expect(autre.index.map((r) => r.date), ['2026-11-19', '2026-11-15'], reason: 'du plus récent au plus ancien');
      expect(autre.fil(types: {TypeNote.repetition}).single.titre, 'Notes de répète');
      expect(autre.fil(recherche: 'meteorite').single.type, TypeNote.spectacle);
      final e = await autre.entree(autre.index.first);
      expect(e!.contenuMd, contains('infirmière'));
    });

    test('corrigée, une entrée garde sa date de création', () async {
      final e = entree('« Météorite »');
      await n.enregistrerEntree(e);
      final corrigee = e.copie(resume: 'Nouveau résumé', jour: '2026-11-22');
      await n.enregistrerEntree(corrigee);
      expect(corrigee.creeLe, '2026-11-21');
      expect(corrigee.misAJourLe, '2026-11-22');
      expect(n.index.single.resume, 'Nouveau résumé');
    });

    test('conflit de sha : on montre les deux versions, puis on garde la sienne ou la leur', () async {
      final e = entree('« Météorite »');
      await n.enregistrerEntree(e);
      // Pendant ce temps, l'entrée est modifiée ailleurs (un autre appareil).
      final cle = acces.cle!;
      final ailleurs = e.copie(resume: 'Modifié ailleurs', jour: '2026-11-21');
      depot.modifierAilleurs(e.fichier, await ChiffrementNotes.chiffrer(cle, const JsonEncoder.withIndent('  ').convert(ailleurs.versJson())));
      final mienne = e.copie(resume: 'Ma version', jour: '2026-11-21');
      ConflitNotes? conflit;
      try {
        await n.enregistrerEntree(mienne);
      } on ConflitNotes catch (c) {
        conflit = c;
      }
      expect(conflit, isNotNull);
      expect(conflit!.distante, contains('Modifié ailleurs'));
      expect(conflit.mienne, contains('Ma version'));
      final diff = differenceLignes(conflit.distante, conflit.mienne);
      expect(diff.enMoins.single, contains('Modifié ailleurs'));
      expect(diff.enPlus.single, contains('Ma version'));
      // On garde la sienne : elle passe par-dessus.
      await n.resoudreConflit(conflit, garderLaMienne: true);
      final relu = await ChiffrementNotes.dechiffrer(cle, depot.fichiers[e.fichier]!.contenu);
      expect(relu, contains('Ma version'));
      // Une autre fois, on prend celle de GitHub : rien n'est écrasé.
      depot.modifierAilleurs(e.fichier, await ChiffrementNotes.chiffrer(cle, const JsonEncoder.withIndent('  ').convert(ailleurs.versJson())));
      try {
        await n.enregistrerEntree(e.copie(resume: 'Encore moi', jour: '2026-11-21'));
      } on ConflitNotes catch (c) {
        await n.resoudreConflit(c, garderLaMienne: false);
      }
      expect(await ChiffrementNotes.dechiffrer(cle, depot.fichiers[e.fichier]!.contenu), contains('Modifié ailleurs'));
    });

    test('l\'index se fusionne tout seul si un autre appareil a ajouté une entrée', () async {
      await n.enregistrerEntree(entree('« Météorite »'));
      final autre = NotesController(acces: acces, cache: CacheMemoire());
      await autre.rafraichir();
      await autre.enregistrerEntree(entree('Conduite régie', type: TypeNote.regie));
      await n.enregistrerEntree(entree('Le cap pour la suite', date: '2026-11-20', type: TypeNote.decision));
      await autre.rafraichir();
      expect(autre.index.map((r) => r.titre), containsAll(['« Météorite »', 'Conduite régie', 'Le cap pour la suite']));
    });

    test('hors ligne : lecture depuis le cache chiffré, écritures en attente, envoyées au retour du réseau', () async {
      await n.enregistrerSeance(seance);
      await n.rafraichir();
      depot.horsLigne = true;
      await n.rafraichir();
      expect(n.horsLigne, isTrue);
      expect(n.seance!.lieu, 'Salle Vilar');
      await n.enregistrerEntree(entree('Écrite hors ligne'));
      expect(n.enAttente, 2, reason: 'l\'entrée et l\'index');
      depot.horsLigne = false;
      await n.rafraichir();
      expect(n.horsLigne, isFalse);
      expect(n.enAttente, 0);
      expect(depot.fichiers.keys, contains('entries/2026-11-19_spectacle_ecrite-hors-ligne.enc'));
    });

    test('les séances suivantes : celles qui ne sont pas passées', () {
      const s = ProchaineSeance(date: '2026-11-22', suivantes: [
        SeanceAVenir(date: '2026-11-29', lieu: 'Salle Vilar'),
        SeanceAVenir(date: '2026-12-06', lieu: 'Salle Claudel'),
        SeanceAVenir(date: '2026-11-15', lieu: 'Salle Vilar'),
      ]);
      final relue = ProchaineSeance.depuisJson(jsonDecode(jsonEncode(s.versJson())) as Map<String, dynamic>);
      expect(relue.suivantesApres('2026-11-21').map((x) => x.lieu), ['Salle Vilar', 'Salle Claudel']);
    });
  });

  group('WhatsApp', () {
    test('la prochaine séance respecte le modèle, mot pour mot', () {
      expect(whatsappSeance(seance, modeleProchaineSeance), '''🎭 *Destiny — répète du dimanche 22 novembre*
🕑 14 h – 17 h · 📍 Salle Vilar

*🎯 Objectif*
Les lieux et la spontanéité.

*🗓️ Déroulé*
1️⃣ En duo, les objets
2️⃣ En duo, objets, prénom et relation
3️⃣ En trios : l'acte 1

*🎬 Prochain spectacle*
Jeudi 3 décembre · Marouene, Gabriel, Elena

_Attitude et lâchez-vous_
À dimanche ! 🔥''');
    });

    test('un compte rendu : date, type, prochain rendez-vous ; le reste à compléter', () {
      final e = EntreeNote(
          id: 'x', date: '2026-11-19', type: TypeNote.spectacle, titre: 'M', creeLe: '', misAJourLe: '');
      final texte = whatsappCompteRendu(e, modeleCompteRendu, suivante: seance);
      expect(texte, startsWith('🎭 *Destiny — spectacle du 19/11*'));
      expect(texte, contains('dimanche 22 novembre · 14 h – 17 h · Salle Vilar'));
      expect(texte, contains('À dimanche ! 🔥'));
      expect(texte, contains('• {point 1}'), reason: 'à compléter à la main');
      final r = EntreeNote(id: 'y', date: '2026-11-15', type: TypeNote.repetition, titre: 'R', creeLe: '', misAJourLe: '');
      expect(whatsappCompteRendu(r, modeleCompteRendu), startsWith('🎭 *Destiny — répète du 15/11*'));
    });

    test('les listes gardent leur puce, et la syntaxe reste celle de WhatsApp', () {
      final t = remplirModele('*✅ Ce qui a marché*\n• {point 1}\n• {point 2}\nfin',
          listes: {'point': ['L\'intro', 'Les DESTINY', 'La fin']});
      expect(t, '*✅ Ce qui a marché*\n• L\'intro\n• Les DESTINY\n• La fin\nfin');
      final m = morceauxWhatsApp('*gras* et _italique_ !');
      expect(m.first.gras, isTrue);
      expect(m[2].italique, isTrue);
    });

    testWidgets('« Copier » met le texte dans le presse-papiers, « Recréer » repart du modèle', (tester) async {
      final chargee = (await tester.runAsync(chargerGrammaire))!;
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      String? copie;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copie = (call.arguments as Map)['text'] as String;
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      await tester.pumpWidget(MaterialApp(
        theme: themeDestiny(chargee.grammaire, sombre: true),
        builder: (context, child) => DestinyDonnees(grammaire: chargee.grammaire, textes: chargee.textes, child: child!),
        home: Scaffold(
          body: EditeurWhatsApp(texte: 'Texte modifié à la main', recreer: () => whatsappSeance(seance, modeleProchaineSeance)),
        ),
      ));
      await tester.tap(find.byKey(const ValueKey('copier_whatsapp')));
      await tester.pumpAndSettle();
      expect(copie, 'Texte modifié à la main');
      expect(find.text(chargee.textes.t('reglages.copie')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('recreer_whatsapp')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('copier_whatsapp')));
      await tester.pumpAndSettle();
      expect(copie, whatsappSeance(seance, modeleProchaineSeance));
    });
  });

  test('chaque texte de Destiny Note existe', () {
    expect(textesManquants(['lib/presentation/notes']), isEmpty);
  });
}

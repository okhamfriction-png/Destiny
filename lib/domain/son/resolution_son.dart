/// Ce que le pack contient vraiment, et la résolution d'une musique ou d'un
/// bruitage à partir du manifeste. Tout est en Dart pur (aucun lecteur, aucun
/// disque) : l'index est une simple liste de chemins relatifs.
library;

import 'dart:math';

import 'manifeste_audio.dart';
import 'nfc.dart';

/// Extensions audio reconnues dans le pack.
const Set<String> kExtensionsAudio = {'.mp3', '.m4a', '.ogg', '.wav', '.aac', '.flac', '.opus'};

/// Vrai si [chemin] est un fichier audio (d'après son extension).
bool estAudio(String chemin) {
  final i = chemin.lastIndexOf('.');
  return i > 0 && kExtensionsAudio.contains(chemin.substring(i).toLowerCase());
}

/// Les fichiers présents dans le pack importé, chemins relatifs à sa racine
/// (séparateur « / »), tels qu'écrits sur le disque. Les comparaisons se font
/// en NFC : un nom venu de macOS (NFD) retrouve son nom attendu.
class IndexPack {
  IndexPack(Iterable<String> chemins) : chemins = List.unmodifiable(chemins.where(estAudio)) {
    for (final c in this.chemins) {
      final n = nfc(c);
      _parNfc[n] = c;
      final i = n.lastIndexOf('/');
      final dossier = i < 0 ? '' : n.substring(0, i);
      final nom = n.substring(i + 1);
      (_parDossier[dossier] ??= []).add(c);
      (_parNom[nom] ??= []).add(c);
    }
    for (final l in _parDossier.values) {
      l.sort(_ordreCandidats);
    }
  }

  /// Un pack vide (rien d'importé).
  static final IndexPack vide = IndexPack(const []);

  final List<String> chemins;
  final Map<String, String> _parNfc = {};
  final Map<String, List<String>> _parDossier = {};
  final Map<String, List<String>> _parNom = {};

  bool get estVide => chemins.isEmpty;

  /// Le chemin réel de [chemin] (comparé en NFC), s'il est dans le pack.
  String? trouver(String chemin) => _parNfc[nfc(chemin)];

  /// Un fichier nommé [nom] n'importe où sous [racine] (recherche récursive).
  String? trouverNom(String nom, {required String racine}) {
    final r = '${nfc(racine)}/';
    for (final c in _parNom[nfc(nom)] ?? const <String>[]) {
      if (nfc(c).startsWith(r)) return c;
    }
    return null;
  }

  /// Les fichiers d'un dossier (directement dedans), dans l'ordre des
  /// candidats : « 1 - … », « 2 - … », puis les autres par nom.
  List<String> dossier(String dossier) => List.unmodifiable(_parDossier[nfc(dossier)] ?? const <String>[]);

  static int _numero(String chemin) {
    final nom = chemin.substring(chemin.lastIndexOf('/') + 1);
    final m = RegExp(r'^(\d+)').firstMatch(nom);
    return m == null ? 1 << 30 : int.parse(m.group(1)!);
  }

  static int _ordreCandidats(String a, String b) {
    final n = _numero(a).compareTo(_numero(b));
    return n != 0 ? n : nfc(a).compareTo(nfc(b));
  }
}

/// Comment la musique d'un acte a été trouvée.
enum OrigineMusique {
  /// Le fichier qui porte le nom attendu pour ce lieu (musique propre).
  nomAttendu,

  /// Le fichier indiqué par le manifeste.
  manifeste,

  /// La musique du lieu de référence de la famille.
  famille,

  /// Rien : silence.
  aucune,
}

/// Le résultat d'une résolution de musique.
class MusiqueResolue {
  const MusiqueResolue(this.chemin, this.origine);

  static const MusiqueResolue aucune = MusiqueResolue(null, OrigineMusique.aucune);

  /// Chemin réel dans le pack (null : silence).
  final String? chemin;
  final OrigineMusique origine;

  /// Vrai si la musique est propre au lieu (pas un repli sur la famille).
  bool get propre => origine == OrigineMusique.nomAttendu;
}

/// La musique de [lieuId] pour [acte] (1 à 4), dans cet ordre : le nom
/// attendu cherché partout dans les musiques, puis le fichier du manifeste,
/// puis la musique de la famille, sinon rien. Sans [repliFamille], une
/// musique de famille n'est jamais prise.
MusiqueResolue resoudreMusique(
  ManifesteAudio m,
  IndexPack index,
  String lieuId,
  int acte, {
  bool repliFamille = true,
}) {
  final lieu = m.lieux[lieuId];
  if (lieu == null) return MusiqueResolue.aucune;
  final attendu = lieu.nomsAttendus[acte];
  if (attendu != null) {
    final c = index.trouverNom(attendu, racine: m.dossierMusiques);
    if (c != null) return MusiqueResolue(c, OrigineMusique.nomAttendu);
  }
  final duManifeste = lieu.musiques[acte];
  if (duManifeste != null && (repliFamille || duManifeste.source == SourceMusique.lieu)) {
    final c = index.trouver(duManifeste.fichier);
    if (c != null) {
      return MusiqueResolue(
          c, duManifeste.source == SourceMusique.lieu ? OrigineMusique.manifeste : OrigineMusique.famille);
    }
  }
  if (!repliFamille) return MusiqueResolue.aucune;
  final ref = m.familles[lieu.famille]?.lieuReference;
  if (ref == null || ref == lieuId) return MusiqueResolue.aucune;
  final r = resoudreMusique(m, index, ref, acte, repliFamille: false);
  return r.chemin == null ? MusiqueResolue.aucune : MusiqueResolue(r.chemin, OrigineMusique.famille);
}

/// Les fichiers candidats d'un code de bruitage présents dans le pack (vide si
/// le dossier est vide ou absent).
List<String> candidatsBruitage(ManifesteAudio m, IndexPack index, String code) {
  final son = m.sons[code];
  if (son == null) return const [];
  final presents = index.dossier(son.dossier);
  if (presents.isNotEmpty) return presents;
  // Dossier non retrouvé tel quel : on reprend les fichiers du manifeste.
  return [
    for (final f in son.fichiers)
      if (index.trouver(f.chemin) case final c?) c,
  ];
}

/// Le choix de fichier par défaut pour un code : son rang (0 = le fichier 1).
const int kCandidatAleatoire = -1;

/// Un bruitage prêt à jouer.
class BruitageResolu {
  const BruitageResolu({required this.code, required this.codeJoue, required this.chemin, this.dureeS, this.boucle = false});

  /// Le code demandé par le palier.
  final String code;

  /// Le code réellement joué (différent si [code] a été remplacé).
  final String codeJoue;
  final String chemin;
  final double? dureeS;
  final bool boucle;
}

/// Les bruitages de [dangerId] au [palier] (1 à 4), un par code. Pour chaque
/// code : le fichier choisi dans [choix] (rang, ou [kCandidatAleatoire] ;
/// le fichier 1 par défaut), décalé de [suivant] crans (bouton « Autre »).
/// Un code sans fichier prend son remplacement (MONITEUR → COEUR) ; sans
/// remplacement (HELICO), il ne joue rien.
List<BruitageResolu> resoudreBruitage(
  ManifesteAudio m,
  IndexPack index,
  String dangerId,
  int palier, {
  Map<String, int> choix = const {},
  Map<String, int> suivant = const {},
  Random? hasard,
}) {
  final danger = m.dangers[dangerId];
  if (danger == null) return const [];
  final sortie = <BruitageResolu>[];
  for (final code in danger.codes(palier)) {
    final r = resoudreCode(m, index, code, choix: choix, suivant: suivant, hasard: hasard);
    if (r != null) sortie.add(r);
  }
  return sortie;
}

/// Un seul code (voir [resoudreBruitage]).
BruitageResolu? resoudreCode(
  ManifesteAudio m,
  IndexPack index,
  String code, {
  Map<String, int> choix = const {},
  Map<String, int> suivant = const {},
  Random? hasard,
}) {
  var joue = code;
  var candidats = candidatsBruitage(m, index, code);
  if (candidats.isEmpty) {
    final remplacant = m.remplacements[code];
    if (remplacant == null) return null;
    joue = remplacant;
    candidats = candidatsBruitage(m, index, remplacant);
    if (candidats.isEmpty) return null;
  }
  final rang = choix[joue] ?? choix[code] ?? 0;
  final base = rang == kCandidatAleatoire ? (hasard ?? Random()).nextInt(candidats.length) : rang;
  final i = (base + (suivant[code] ?? 0)) % candidats.length;
  final chemin = candidats[i < 0 ? 0 : i];
  final decrit = [
    for (final f in m.sons[joue]?.fichiers ?? const <FichierSon>[])
      if (nfc(f.chemin) == nfc(chemin)) f,
  ];
  return BruitageResolu(
    code: code,
    codeJoue: joue,
    chemin: chemin,
    dureeS: decrit.isEmpty ? null : decrit.first.dureeS,
    boucle: decrit.isEmpty ? false : decrit.first.boucle,
  );
}

/// Le dossier des stingers de révélation (celui du premier fichier listé).
String dossierReveal(ManifesteAudio m) {
  if (m.reveal.isEmpty) return '${m.dossierBruitages}/REVEAL';
  final c = m.reveal.first.chemin;
  return c.substring(0, c.lastIndexOf('/'));
}

/// Les stingers présents dans le pack.
List<String> candidatsReveal(ManifesteAudio m, IndexPack index) {
  final presents = index.dossier(dossierReveal(m));
  if (presents.isNotEmpty) return presents;
  return [
    for (final f in m.reveal)
      if (index.trouver(f.chemin) case final c?) c,
  ];
}

/// Ce que le pack importé couvre.
class BilanPack {
  const BilanPack({
    required this.fichiers,
    required this.lieuxPropres,
    required this.lieuxFamille,
    required this.lieuxSansMusique,
    required this.sonsRemplaces,
    required this.sonsManquants,
    required this.stingers,
  });

  final int fichiers;

  /// Lieux dont les 4 actes ont leur musique propre.
  final List<String> lieuxPropres;

  /// Lieux dont au moins un acte se rabat sur la musique de la famille.
  final List<String> lieuxFamille;

  /// Lieux dont au moins un acte reste muet.
  final List<String> lieuxSansMusique;

  /// Codes sans fichier, joués par leur remplaçant.
  final List<String> sonsRemplaces;

  /// Codes qui ne jouent rien (ni fichier, ni remplaçant utilisable).
  final List<String> sonsManquants;
  final int stingers;

  static BilanPack calculer(ManifesteAudio m, IndexPack index, {bool repliFamille = true}) {
    final propres = <String>[], famille = <String>[], muets = <String>[];
    for (final lieu in m.lieux.values) {
      final r = [for (var a = 1; a <= 4; a++) resoudreMusique(m, index, lieu.id, a, repliFamille: repliFamille)];
      if (r.any((x) => x.chemin == null)) {
        muets.add(lieu.id);
      } else if (r.every((x) => x.origine == OrigineMusique.nomAttendu || x.origine == OrigineMusique.manifeste)) {
        propres.add(lieu.id);
      } else {
        famille.add(lieu.id);
      }
    }
    final remplaces = <String>[], manquants = <String>[];
    for (final code in m.sons.keys) {
      if (candidatsBruitage(m, index, code).isNotEmpty) continue;
      final r = resoudreCode(m, index, code);
      (r == null ? manquants : remplaces).add(code);
    }
    return BilanPack(
      fichiers: index.chemins.length,
      lieuxPropres: propres,
      lieuxFamille: famille,
      lieuxSansMusique: muets,
      sonsRemplaces: remplaces,
      sonsManquants: manquants,
      stingers: candidatsReveal(m, index).length,
    );
  }
}

/// Nom du manifeste quand il voyage avec le pack (dossier « Pack audio
/// DestinyStory » du NAS) : importé, il remplace celui de l'appli s'il est
/// au moins aussi récent.
const String kNomManifestePack = 'destiny_audio_manifest.json';

/// Où ranger, dans le pack, le fichier [source] d'un dossier ou d'un zip
/// importé : à partir du dossier des musiques ou des bruitages, l'arborescence
/// gardée. Rend null pour tout le reste (autres dossiers, fichiers qui ne sont
/// pas de l'audio, dossiers à ignorer comme « Sonniss GDC 2026 »).
String? cheminDansPack(ManifesteAudio m, String source) {
  final parties = source.replaceAll('\\', '/').split('/').where((p) => p.isNotEmpty && p != '.').toList();
  if (parties.any((p) => p == '..' || p.startsWith('__MACOSX'))) return null;
  if (parties.isNotEmpty && parties.last.startsWith('._')) return null;
  final racines = {nfc(m.dossierMusiques), nfc(m.dossierBruitages)};
  final debut = parties.indexWhere((p) => racines.contains(nfc(p)));
  if (debut < 0) return null;
  final relatif = parties.sublist(debut).join('/');
  if (!estAudio(relatif)) return null;
  final n = nfc(relatif);
  for (final ignore in m.aIgnorer) {
    final i = nfc(ignore);
    if (n == i || n.startsWith('$i/')) return null;
  }
  return relatif;
}

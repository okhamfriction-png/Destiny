/// Le manifeste du pack audio du spectacle (`assets/data/destiny_audio.json`).
///
/// C'est la carte du pack : quelle musique pour quel lieu et quel acte, quels
/// bruitages pour quel danger et quel palier. Les fichiers eux-mêmes ne sont
/// pas dans l'appli : ils sont importés à part (voir `PackAudio`). Tous les
/// chemins sont relatifs à la racine du pack (le dossier Spectacle du NAS).
library;

import 'nfc.dart';

/// Un fichier audio décrit par le manifeste.
class FichierSon {
  const FichierSon({required this.chemin, this.dureeS, this.boucle = false});

  final String chemin;

  /// Durée annoncée par le manifeste (secondes), si connue.
  final double? dureeS;

  /// Une boucle de plusieurs minutes plutôt qu'un son ponctuel.
  final bool boucle;

  static FichierSon depuisJson(Object? j) {
    if (j is String) return FichierSon(chemin: j);
    final m = j as Map<String, dynamic>;
    return FichierSon(
      chemin: m['fichier'] as String,
      dureeS: (m['duree_s'] as num?)?.toDouble(),
      boucle: m['boucle'] as bool? ?? false,
    );
  }
}

/// Un bruitage : un code (« ALARME ») et ses fichiers candidats.
class SonPack {
  const SonPack({required this.code, required this.nom, required this.dossier, required this.fichiers});

  final String code;
  final String nom;
  final String dossier;
  final List<FichierSon> fichiers;
}

/// D'où vient la musique d'un acte, selon le manifeste.
enum SourceMusique {
  /// Composée pour ce lieu.
  lieu,

  /// Celle du lieu de référence de la famille.
  famille;

  static SourceMusique depuisTexte(String? s) => s == 'lieu' ? lieu : famille;
}

/// La musique d'un acte d'un lieu, telle que le manifeste la donne.
class MusiqueActe {
  const MusiqueActe({required this.fichier, this.dureeS, required this.source});

  final String fichier;
  final double? dureeS;
  final SourceMusique source;
}

/// Un lieu du spectacle (les ids sont ceux de `locations.json`).
class LieuPack {
  const LieuPack({
    required this.id,
    required this.nom,
    required this.numero,
    required this.famille,
    required this.nomsAttendus,
    required this.musiques,
  });

  final String id;
  final String nom;
  final int numero;
  final String famille;

  /// Le nom de fichier attendu pour chaque acte (1 à 4) : une musique propre
  /// déposée plus tard sous ce nom est prise d'office.
  final Map<int, String> nomsAttendus;
  final Map<int, MusiqueActe> musiques;
}

/// Une famille de lieux et son lieu de référence.
class FamillePack {
  const FamillePack({required this.nom, required this.lieuReference, required this.lieux});

  final String nom;
  final String lieuReference;
  final List<String> lieux;
}

/// Un danger (les ids sont ceux de `dangers.json`) et ses codes de bruitage
/// par palier (1 à 4).
class DangerPack {
  const DangerPack({required this.id, required this.nom, required this.paliers});

  final String id;
  final String nom;
  final Map<int, List<String>> paliers;

  List<String> codes(int palier) => paliers[palier] ?? const [];
}

/// Le manifeste complet.
class ManifesteAudio {
  const ManifesteAudio({
    required this.version,
    required this.dossierMusiques,
    required this.dossierBruitages,
    required this.aIgnorer,
    required this.familles,
    required this.lieux,
    required this.sons,
    required this.remplacements,
    required this.reveal,
    required this.dangers,
  });

  final int version;
  final String dossierMusiques;
  final String dossierBruitages;
  final List<String> aIgnorer;
  final Map<String, FamillePack> familles;
  final Map<String, LieuPack> lieux;
  final Map<String, SonPack> sons;

  /// Code d'un son sans fichier → code qui le remplace (null : rien).
  final Map<String, String?> remplacements;

  /// Les stingers de révélation du danger.
  final List<FichierSon> reveal;
  final Map<String, DangerPack> dangers;

  static Map<int, T> _parActe<T>(Object? j, T Function(Object?) f) => {
        for (final e in (j as Map<String, dynamic>? ?? const {}).entries)
          if (int.tryParse(e.key) != null) int.parse(e.key): f(e.value),
      };

  factory ManifesteAudio.depuisJson(Map<String, dynamic> j) {
    final dossiers = j['dossiers'] as Map<String, dynamic>? ?? const {};
    final familles = <String, FamillePack>{
      for (final e in (j['familles'] as Map<String, dynamic>? ?? const {}).entries)
        e.key: FamillePack(
          nom: e.key,
          lieuReference: (e.value as Map)['lieu_reference'] as String,
          lieux: [for (final x in ((e.value as Map)['lieux'] as List? ?? const [])) '$x'],
        ),
    };
    final lieux = <String, LieuPack>{
      for (final e in (j['lieux'] as Map<String, dynamic>? ?? const {}).entries)
        e.key: LieuPack(
          id: e.key,
          nom: (e.value as Map)['nom'] as String,
          numero: ((e.value as Map)['numero'] as num).toInt(),
          famille: (e.value as Map)['famille'] as String,
          nomsAttendus: _parActe((e.value as Map)['noms_attendus'], (x) => '$x'),
          musiques: _parActe((e.value as Map)['musiques'], (x) {
            final m = x as Map<String, dynamic>;
            return MusiqueActe(
              fichier: m['fichier'] as String,
              dureeS: (m['duree_s'] as num?)?.toDouble(),
              source: SourceMusique.depuisTexte(m['source'] as String?),
            );
          }),
        ),
    };
    final sons = <String, SonPack>{
      for (final e in (j['sons'] as Map<String, dynamic>? ?? const {}).entries)
        e.key: SonPack(
          code: e.key,
          nom: (e.value as Map)['nom'] as String? ?? e.key,
          dossier: (e.value as Map)['dossier'] as String? ?? '',
          fichiers: [for (final f in ((e.value as Map)['fichiers'] as List? ?? const [])) FichierSon.depuisJson(f)],
        ),
    };
    final reveal = j['reveal'] as Map<String, dynamic>? ?? const {};
    return ManifesteAudio(
      version: (j['version'] as num?)?.toInt() ?? 1,
      dossierMusiques: dossiers['musiques'] as String? ?? 'Musiques Destiny',
      dossierBruitages: dossiers['bruitages'] as String? ?? 'Bruitages',
      aIgnorer: [for (final x in (dossiers['a_ignorer'] as List? ?? const [])) '$x'],
      familles: familles,
      lieux: lieux,
      sons: sons,
      remplacements: {
        for (final e in (j['sons_vides_et_remplacements'] as Map<String, dynamic>? ?? const {}).entries)
          e.key: e.value as String?,
      },
      reveal: [for (final f in (reveal['fichiers'] as List? ?? const [])) FichierSon.depuisJson(f)],
      dangers: {
        for (final e in (j['dangers'] as Map<String, dynamic>? ?? const {}).entries)
          e.key: DangerPack(
            id: e.key,
            nom: (e.value as Map)['nom'] as String? ?? e.key,
            paliers: _parActe((e.value as Map)['paliers'], (x) => [for (final c in (x as List)) '$c']),
          ),
      },
    );
  }

  /// La durée annoncée pour [chemin] (n'importe quel son ou stinger),
  /// comparée en NFC : l'index du disque garde les noms tels quels.
  double? dureeDe(String chemin) {
    final cible = nfc(chemin);
    for (final s in sons.values) {
      for (final f in s.fichiers) {
        if (nfc(f.chemin) == cible) return f.dureeS;
      }
    }
    for (final f in reveal) {
      if (nfc(f.chemin) == cible) return f.dureeS;
    }
    return null;
  }
}

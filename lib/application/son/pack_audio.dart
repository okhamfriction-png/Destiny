import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../domain/son/manifeste_audio.dart';
import '../../domain/son/nfc.dart';
import '../../domain/son/resolution_son.dart';
import 'lecteur_son.dart';

/// Ce qu'a donné un import.
class ResultatImport {
  const ResultatImport({this.copies = 0, this.dejaLa = 0, this.ignores = 0, this.manifeste = false, this.erreur});

  static const ResultatImport annule = ResultatImport(erreur: 'annule');

  final int copies;

  /// Fichiers déjà présents (même taille) : pas recopiés.
  final int dejaLa;

  /// Fichiers laissés de côté (pas de l'audio, hors des deux dossiers).
  final int ignores;

  /// Le manifeste du pack a été importé avec.
  final bool manifeste;

  /// null si tout va bien ; sinon une clé : « annule », « web », « vide »,
  /// « lecture ».
  final String? erreur;
}

/// Le pack audio du spectacle : le manifeste (la carte) et les fichiers
/// importés dans l'appli (`destiny_pack/` du dossier documents). Les fichiers
/// ne sont pas embarqués : au spectacle, le téléphone n'a pas le NAS.
///
/// Sur le web, le pack est lu à côté de l'appli (`destiny_pack/index.json`) :
/// c'est ce qui sert à répéter la régie dans un navigateur, en local.
///
/// Sur Android, le pack est aussi intégré à l'appli (un asset pack livré à
/// l'installation, `assets/pack/`) : il sert tant qu'aucun pack n'a été
/// importé à la main.
class PackAudio extends ChangeNotifier {
  PackAudio();

  /// Un pack déjà chargé (tests) : rien n'est lu ni écrit.
  PackAudio.pourTests(ManifesteAudio manifeste, IndexPack index, {String racine = '/pack'})
      : _manifeste = manifeste,
        _index = index,
        _racine = racine,
        _charge = true;

  static const String dossier = 'destiny_pack';
  static const String cheminManifesteAppli = 'assets/data/destiny_audio.json';

  ManifesteAudio? _manifeste;
  IndexPack _index = IndexPack.vide;
  String? _racine;
  bool _charge = false;
  bool _manifesteDuPack = false;

  /// Le pack intégré à l'appli : chemin dans le pack → fichier sous
  /// `assets/pack/` (null : pas de pack intégré en usage).
  Map<String, String>? _embarque;

  bool _importEnCours = false;
  int _importTraites = 0;

  ManifesteAudio? get manifeste => _manifeste;
  IndexPack get index => _index;
  bool get charge => _charge;

  /// Des fichiers ont été importés (ou, sur le web, trouvés à côté).
  bool get disponible => _manifeste != null && !_index.estVide;

  /// Le pack en usage est celui intégré à l'appli (pas un pack importé).
  bool get integre => _embarque != null;

  /// Le manifeste utilisé vient du pack importé (plus récent que l'appli).
  bool get manifesteDuPack => _manifesteDuPack;

  /// On ne peut importer que là où il y a un disque (pas sur le web).
  bool get importPossible => !kIsWeb;
  bool get importEnCours => _importEnCours;
  int get importTraites => _importTraites;

  BilanPack? bilan({bool repliFamille = true}) {
    final m = _manifeste;
    return m == null ? null : BilanPack.calculer(m, _index, repliFamille: repliFamille);
  }

  /// La source audioplayers d'une [source] : asset, fichier du pack sur le
  /// disque, ou adresse à côté de l'appli sur le web.
  Source versSource(SourceSon source) => switch (source) {
        SourceAsset() => AssetSource(source.chemin),
        SourcePack() when _embarque != null =>
          AssetSource('pack/${_embarque![source.chemin] ?? _embarque![nfc(source.chemin)] ?? source.chemin}'),
        SourcePack() => kIsWeb
            ? UrlSource(Uri.base.resolve('$dossier/${source.chemin.split('/').map(Uri.encodeComponent).join('/')}').toString())
            : DeviceFileSource(p.joinAll([_racine ?? '', ...source.chemin.split('/')])),
      };

  Future<void> charger() async {
    ManifesteAudio? appli;
    try {
      appli = ManifesteAudio.depuisJson(
          jsonDecode(await rootBundle.loadString(cheminManifesteAppli)) as Map<String, dynamic>);
    } catch (e) {
      debugPrint('Pack audio : manifeste illisible ($e)');
    }
    _manifeste = appli;
    _manifesteDuPack = false;
    _embarque = null;
    try {
      if (kIsWeb) {
        await _chargerWeb(appli);
      } else {
        await _chargerDisque(appli);
      }
    } catch (e) {
      debugPrint('Pack audio : rien de chargé ($e)');
      _index = IndexPack.vide;
    }
    // Rien d'importé : le pack intégré à l'appli, s'il est là.
    if (_index.estVide && !kIsWeb) {
      _manifeste = appli;
      _manifesteDuPack = false;
      try {
        await _chargerEmbarque(appli);
      } catch (e) {
        debugPrint('Pack audio : pas de pack intégré ($e)');
        _embarque = null;
        _index = IndexPack.vide;
      }
    }
    _charge = true;
    notifyListeners();
  }

  void _prendreManifeste(ManifesteAudio? appli, Map<String, dynamic>? json) {
    if (json == null) return;
    try {
      final duPack = ManifesteAudio.depuisJson(json);
      if (appli == null || duPack.version >= appli.version) {
        _manifeste = duPack;
        _manifesteDuPack = true;
      }
    } catch (_) {}
  }

  Future<Directory> _dossierPack() async {
    final base = await getApplicationDocumentsDirectory();
    return Directory(p.join(base.path, dossier));
  }

  Future<void> _chargerDisque(ManifesteAudio? appli) async {
    final d = await _dossierPack();
    _racine = d.path;
    if (!await d.exists()) {
      _index = IndexPack.vide;
      return;
    }
    final chemins = <String>[];
    await for (final e in d.list(recursive: true, followLinks: false)) {
      if (e is File) chemins.add(p.split(p.relative(e.path, from: d.path)).join('/'));
    }
    _index = IndexPack(chemins);
    final m = File(p.join(d.path, kNomManifestePack));
    if (await m.exists()) _prendreManifeste(appli, jsonDecode(await m.readAsString()) as Map<String, dynamic>);
  }

  Future<void> _chargerWeb(ManifesteAudio? appli) async {
    final r = await http.get(Uri.base.resolve('$dossier/index.json'));
    if (r.statusCode != 200) {
      _index = IndexPack.vide;
      return;
    }
    final j = jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    _index = IndexPack([for (final c in (j['fichiers'] as List? ?? const [])) '$c']);
    final m = await http.get(Uri.base.resolve('$dossier/$kNomManifestePack'));
    if (m.statusCode == 200) _prendreManifeste(appli, jsonDecode(utf8.decode(m.bodyBytes)) as Map<String, dynamic>);
  }

  /// Le pack intégré : `assets/pack/index.json` (livré par l'asset pack
  /// Android `destiny_pack`), qui fait le lien chemin du pack → fichier.
  Future<void> _chargerEmbarque(ManifesteAudio? appli) async {
    final j = jsonDecode(await rootBundle.loadString('$dossierEmbarque/index.json', cache: false)) as Map<String, dynamic>;
    final table = <String, String>{
      for (final e in (j['fichiers'] as Map<String, dynamic>? ?? const {}).entries) nfc(e.key): '${e.value}',
    };
    if (table.isEmpty) return;
    _embarque = table;
    _index = IndexPack(table.keys);
    try {
      final m = await rootBundle.loadString('$dossierEmbarque/$kNomManifestePack', cache: false);
      _prendreManifeste(appli, jsonDecode(m) as Map<String, dynamic>);
    } catch (_) {}
  }

  /// Le dossier du pack intégré, parmi les assets de l'appli.
  static const String dossierEmbarque = 'assets/pack';

  void _progression(int n) {
    _importTraites = n;
    if (n % 10 == 0) notifyListeners();
  }

  /// Importe un .zip du dossier Spectacle (ou d'une copie qui contient
  /// « Musiques Destiny » et « Bruitages »). Lu en flux : le zip n'est jamais
  /// chargé en mémoire en entier.
  Future<ResultatImport> importerZip() async {
    if (kIsWeb) return const ResultatImport(erreur: 'web');
    final f = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['zip']);
    final chemin = f?.path;
    if (chemin == null) return ResultatImport.annule;
    return _importer((ajouter) async {
      final entree = InputFileStream(chemin);
      try {
        final archive = ZipDecoder().decodeStream(entree);
        for (final fichier in archive) {
          if (!fichier.isFile) continue;
          await ajouter(fichier.name, fichier.size, (cible) async {
            final sortie = OutputFileStream(cible);
            try {
              fichier.writeContent(sortie);
            } finally {
              await sortie.close();
            }
          });
        }
      } finally {
        await entree.close();
      }
    });
  }

  /// Importe un dossier (le dossier Spectacle, ou une copie). Sur Android, un
  /// dossier partagé n'est pas toujours lisible : le .zip est alors la voie sûre.
  Future<ResultatImport> importerDossier() async {
    if (kIsWeb) return const ResultatImport(erreur: 'web');
    final chemin = await FilePicker.getDirectoryPath();
    if (chemin == null) return ResultatImport.annule;
    return _importer((ajouter) async {
      await for (final e in Directory(chemin).list(recursive: true, followLinks: false)) {
        if (e is! File) continue;
        final source = p.split(p.relative(e.path, from: p.dirname(chemin))).join('/');
        await ajouter(source, await e.length(), (cible) => e.copy(cible));
      }
    });
  }

  /// Le cœur commun des deux imports : [parcourir] appelle `ajouter` pour
  /// chaque fichier trouvé ; seuls les fichiers audio des deux dossiers (et le
  /// manifeste) sont copiés, et ce qui est déjà là n'est pas recopié.
  Future<ResultatImport> _importer(
    Future<void> Function(Future<void> Function(String source, int taille, Future<void> Function(String cible) copier))
        parcourir,
  ) async {
    final m = _manifeste;
    if (m == null || _importEnCours) return const ResultatImport(erreur: 'lecture');
    _importEnCours = true;
    _importTraites = 0;
    notifyListeners();
    var copies = 0, dejaLa = 0, ignores = 0;
    var manifeste = false;
    try {
      final d = await _dossierPack();
      await d.create(recursive: true);
      await parcourir((source, taille, copier) async {
        _progression(copies + dejaLa + ignores);
        final nom = source.split('/').last;
        final relatif = nom == kNomManifestePack ? kNomManifestePack : cheminDansPack(m, source);
        if (relatif == null) {
          ignores++;
          return;
        }
        final cible = File(p.joinAll([d.path, ...relatif.split('/')]));
        // Garde-fou : jamais d'écriture hors du dossier du pack.
        if (!p.isWithin(d.path, cible.path)) {
          ignores++;
          return;
        }
        if (relatif != kNomManifestePack && await cible.exists() && await cible.length() == taille) {
          dejaLa++;
          return;
        }
        await cible.parent.create(recursive: true);
        await copier(cible.path);
        if (relatif == kNomManifestePack) {
          manifeste = true;
        } else {
          copies++;
        }
      });
    } catch (e) {
      debugPrint('Pack audio : import interrompu ($e)');
      _importEnCours = false;
      await charger();
      return ResultatImport(copies: copies, dejaLa: dejaLa, ignores: ignores, manifeste: manifeste, erreur: 'lecture');
    }
    _importEnCours = false;
    await charger();
    if (copies + dejaLa == 0) {
      return ResultatImport(ignores: ignores, manifeste: manifeste, erreur: 'vide');
    }
    return ResultatImport(copies: copies, dejaLa: dejaLa, ignores: ignores, manifeste: manifeste);
  }

  /// Efface le pack importé (les réglages restent).
  Future<void> supprimer() async {
    if (kIsWeb) return;
    final d = await _dossierPack();
    if (await d.exists()) await d.delete(recursive: true);
    await charger();
  }
}

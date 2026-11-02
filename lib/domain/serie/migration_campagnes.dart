/// La migration des anciennes campagnes (1.5.x, clés `campagnes_v1` et
/// `campagne_seances_v1`) vers les séries. Rien ne se perd : chaque épisode
/// joué devient un épisode de la série, marqué « ancienne grammaire », avec
/// son intitulé, sa phrase, ce qui a marché, sa transcription, ses morts et
/// ses blessés. La continuité passe des noms et des ids d'animaux aux ids :
/// les sbires tombés retrouvent l'id de leur sbire, les figurants tombés
/// gardent l'animal qui les identifiait.
library;

import 'serie.dart';
import 'univers.dart';

List<String> _ls(Object? v) => [for (final x in (v as List? ?? const [])) '$x'];
String _s(Object? v) => v is String ? v : (v == null ? '' : '$v');

/// L'id de série d'une ancienne campagne.
String idSerieDeCampagne(Object id) => 'campagne-$id';

/// Convertit les campagnes et leurs séances. [seances] est la table
/// `{ "<id de campagne>": [séances] }` de l'ancienne sauvegarde.
List<Serie> migrerCampagnes({
  required List<Map<String, dynamic>> campagnes,
  Map<String, dynamic> seances = const {},
  CatalogueUnivers catalogue = CatalogueUnivers.vide,
  required DateTime maintenant,
}) =>
    [for (final c in campagnes) migrerCampagne(c, seances: seances[_s(c['id'])], catalogue: catalogue, maintenant: maintenant)];

Serie migrerCampagne(
  Map<String, dynamic> c, {
  Object? seances,
  CatalogueUnivers catalogue = CatalogueUnivers.vide,
  required DateTime maintenant,
}) {
  final idCampagne = _s(c['id']);
  final public = PublicSerie.depuisTexte(c['public'] as String?);
  final kids = public == PublicSerie.kids;
  final univers = _s(c['univers']);

  // Les épisodes joués.
  final episodes = <EpisodeSerie>[];
  for (final brut in (seances as List? ?? const [])) {
    if (brut is! Map) continue;
    final s = Map<String, dynamic>.from(brut);
    final numero = (s['numero'] as num?)?.toInt() ?? episodes.length + 1;
    final amorce = _s(s['amorceId']).split('|');
    final lieu = amorce.isNotEmpty ? catalogue.lieu(amorce.first) : null;
    final dateMs = (s['dateMs'] as num?)?.toInt();
    episodes.add(EpisodeSerie(
      id: '${idSerieDeCampagne(idCampagne)}-$numero-${episodes.length}',
      date: dateMs == null ? maintenant : DateTime.fromMillisecondsSinceEpoch(dateMs),
      numero: numero,
      etape: EtapeEpisode.termine,
      lieuId: amorce.isNotEmpty ? amorce.first : '',
      lieuNom: lieu?.nom ?? '',
      lieuDescription: lieu?.description ?? '',
      espaces: [for (final e in lieu?.espaces ?? const <EspaceUnivers>[]) e.nom],
      mechantId: amorce.length > 1 ? amorce[1] : '',
      intituleAncien: _s(s['intitule']),
      phrase: _s(s['phrase']),
      ceQuiAMarche: _s(s['ceQuiAMarche']),
      transcription: _s(s['transcription']),
      mortsAnciens: _ls(s['morts']),
      blessesAnciens: _ls(s['blesses']),
      ancienneGrammaire: true,
    ));
  }
  episodes.sort((a, b) => a.date.compareTo(b.date));

  // La continuité, en ids.
  final mechantsDeLUnivers = catalogue.mechantsDe(univers);
  String idSbire(String nom) {
    for (final m in mechantsDeLUnivers) {
      for (final s in m.mechant.sbires) {
        if (s.nom == nom) return s.id;
      }
    }
    return 'ancien.sbire.$nom';
  }

  final sortis = <String>[];
  final registre = <EntreeRegistre>[];
  final statutSorti = kids ? StatutRegistre.parti : StatutRegistre.tombe;
  var n = 0;
  String idEntree() => '${idSerieDeCampagne(idCampagne)}.r${n++}';

  for (final nom in _ls(c['sbiresMorts'])) {
    sortis.add(idSbire(nom));
    registre.add(EntreeRegistre(id: idEntree(), categorie: CategorieRegistre.sbire, nom: nom, statut: statutSorti));
  }
  for (final animal in _ls(c['figurantsMorts'])) {
    sortis.add('ancien.figurant.$animal');
    registre.add(EntreeRegistre(
        id: idEntree(), categorie: CategorieRegistre.figurant, nom: animal, statut: statutSorti, liens: ['animal:$animal']));
  }
  for (final idMechant in _ls(c['mechantsMorts'])) {
    sortis.add(idMechant);
    final nom = catalogue.mechantUnivers(idMechant)?.mechant.nom ?? idMechant;
    registre.add(EntreeRegistre(
      id: idEntree(),
      categorie: kids ? CategorieRegistre.heritage : CategorieRegistre.mort,
      nom: nom,
      statut: statutSorti,
    ));
  }

  return Serie(
    id: idSerieDeCampagne(idCampagne),
    creee: episodes.isEmpty ? maintenant : episodes.first.date,
    nom: _s(c['nom']),
    public: public,
    univers: univers,
    ton: _s(c['ton']),
    lore: _s(c['lore']),
    contexte: _s(c['contexte']),
    episodes: episodes,
    registre: registre,
    resume: _s(c['resume']),
    accroche: _s(c['accroche']),
    pnjSortis: sortis,
    migreDe: 'campagne:$idCampagne',
  );
}

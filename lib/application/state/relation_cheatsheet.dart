import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Un lien générique : un écart de statut avec une amorce d'histoire.
class RelationLink {
  const RelationLink({required this.registre, required this.texte});
  final String registre;
  final String texte;

  RelationLink copyWith({String? registre, String? texte}) => RelationLink(
        registre: registre ?? this.registre,
        texte: texte ?? this.texte,
      );

  Map<String, dynamic> toJson() => {'registre': registre, 'texte': texte};
  factory RelationLink.fromJson(Map<String, dynamic> j) => RelationLink(
        registre: j['registre'] as String? ?? '',
        texte: j['texte'] as String? ?? '',
      );
}

/// Antisèche de relations : liste de liens génériques (points de départ) que les
/// comédiens consultent librement. Éditable (paramètres) et persistée.
class RelationCheatsheet extends ChangeNotifier {
  RelationCheatsheet() {
    _links = List.of(_defaults);
    _load();
  }

  static const _kKey = 'relation_cheatsheet_v1';

  /// Registres couverts (ordre d'affichage).
  static const List<String> registres = [
    'Affection',
    'Dette',
    'Trahison',
    'Hiérarchie / mentor',
    'Rivalité',
    'Secret partagé',
  ];

  late List<RelationLink> _links;
  List<RelationLink> get links => List.unmodifiable(_links);

  Future<void> add(RelationLink link) async {
    _links = [..._links, link];
    notifyListeners();
    await _save();
  }

  Future<void> update(int index, RelationLink link) async {
    if (index < 0 || index >= _links.length) return;
    _links = List.of(_links)..[index] = link;
    notifyListeners();
    await _save();
  }

  Future<void> removeAt(int index) async {
    if (index < 0 || index >= _links.length) return;
    _links = List.of(_links)..removeAt(index);
    notifyListeners();
    await _save();
  }

  Future<void> resetToDefault() async {
    _links = List.of(_defaults);
    notifyListeners();
    await _save();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kKey);
      if (raw == null) return;
      _links = (jsonDecode(raw) as List<dynamic>)
          .map((e) => RelationLink.fromJson(e as Map<String, dynamic>))
          .toList();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _kKey, jsonEncode(_links.map((l) => l.toJson()).toList()));
    } catch (_) {}
  }

  // ------------------------------------------------------------ défauts (12)
  static const List<RelationLink> _defaults = [
    RelationLink(
        registre: 'Affection',
        texte: 'L\'un aime l\'autre en secret et n\'a jamais osé le dire.'),
    RelationLink(
        registre: 'Affection',
        texte:
            'L\'un a élevé l\'autre après un deuil, sans aucun lien de sang.'),
    RelationLink(
        registre: 'Dette',
        texte:
            'L\'un a payé les dettes de l\'autre et attend un retour qui ne vient pas.'),
    RelationLink(
        registre: 'Dette',
        texte:
            'L\'un doit la vie à l\'autre depuis un accident dont on ne parle jamais.'),
    RelationLink(
        registre: 'Trahison',
        texte: 'L\'un a dénoncé l\'autre autrefois ; l\'autre ne l\'a jamais su.'),
    RelationLink(
        registre: 'Trahison',
        texte: 'L\'un a promis de garder un secret, puis l\'a monnayé.'),
    RelationLink(
        registre: 'Hiérarchie / mentor',
        texte: 'L\'un a tout appris à l\'autre, qui l\'a aujourd\'hui dépassé.'),
    RelationLink(
        registre: 'Hiérarchie / mentor',
        texte:
            'L\'un donne les ordres depuis toujours ; l\'autre a cessé d\'y croire.'),
    RelationLink(
        registre: 'Rivalité',
        texte: 'Les deux ont aimé la même personne, et l\'un a gagné.'),
    RelationLink(
        registre: 'Rivalité',
        texte:
            'L\'un a obtenu la place que l\'autre convoitait, sans jamais s\'en excuser.'),
    RelationLink(
        registre: 'Secret partagé',
        texte:
            'Les deux ont enterré quelque chose ensemble et n\'en parlent jamais.'),
    RelationLink(
        registre: 'Secret partagé',
        texte:
            'L\'un a couvert une faute de l\'autre ; ça les lie autant que ça les ronge.'),
  ];
}

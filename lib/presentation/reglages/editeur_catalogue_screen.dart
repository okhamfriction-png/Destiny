import 'package:flutter/material.dart';

import '../../domain/entities/danger.dart';
import '../../domain/entities/location.dart';
import '../../domain/repositories/catalog_store.dart';
import '../destiny/composants.dart';
import '../destiny/donnees.dart';
import '../destiny/page.dart';
import '../theme/destiny_theme.dart';

/// Un identifiant lisible et unique, tiré d'un nom.
String identifiantDepuis(String nom, Set<String> existants, {String defaut = 'element'}) {
  var s = nom.toLowerCase();
  const de = 'àâäáãåçéèêëíìîïñóòôöõúùûüýÿœæ';
  const vers = 'aaaaaaceeeeiiiinooooouuuuyyoa';
  for (var i = 0; i < de.length; i++) {
    s = s.replaceAll(de[i], vers[i]);
  }
  s = s.replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(RegExp(r'^_+|_+$'), '');
  final base = s.isEmpty ? defaut : s;
  var id = base;
  for (var n = 1; existants.contains(id); n++) {
    id = '${base}_$n';
  }
  return id;
}

List<String> _lignes(String texte) => [
      for (final l in texte.split('\n'))
        if (l.trim().isNotEmpty) l.trim(),
    ];

/// L'éditeur des lieux et des dangers : les espaces et les rôles d'un lieu,
/// les quatre paliers d'un danger (nommés comme dans la grammaire) et sa
/// version kids, le sigle KIDS, et ce qui est proposé à la mise en place.
class EditeurCatalogueScreen extends StatefulWidget {
  const EditeurCatalogueScreen({required this.catalogue, super.key});

  final CatalogStore catalogue;

  @override
  State<EditeurCatalogueScreen> createState() => _EditeurCatalogueScreenState();
}

class _EditeurCatalogueScreenState extends State<EditeurCatalogueScreen> with SingleTickerProviderStateMixin {
  late final TabController _onglets = TabController(length: 2, vsync: this)..addListener(_rafraichir);
  List<Location> _lieux = const [];
  List<Danger> _dangers = const [];
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  @override
  void dispose() {
    _onglets.dispose();
    super.dispose();
  }

  void _rafraichir() {
    if (mounted) setState(() {});
  }

  Future<void> _charger() async {
    final lieux = await widget.catalogue.getLocations();
    final dangers = await widget.catalogue.getDangers();
    if (!mounted) return;
    setState(() {
      _lieux = lieux;
      _dangers = dangers;
      _chargement = false;
    });
  }

  String k(String x, [Map<String, String> v = const {}]) => context.textes.t('editeurs.catalogue.$x', v);

  Future<void> _ouvrir(Widget page) async {
    final change = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => page));
    if (change == true) await _charger();
  }

  void _ajouter() {
    if (_onglets.index == 0) {
      _ouvrir(FicheLieuEditeur(catalogue: widget.catalogue, existants: {for (final l in _lieux) l.id}));
    } else {
      _ouvrir(FicheDangerEditeur(catalogue: widget.catalogue, existants: {for (final d in _dangers) d.id}));
    }
  }

  Future<void> _restaurer() async {
    final messager = ScaffoldMessenger.of(context);
    final restaure = k('restaure');
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(k('restaurer_titre')),
        content: Text(k('restaurer_texte')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(k('annuler'))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(k('valider'))),
        ],
      ),
    );
    if (ok != true) return;
    await widget.catalogue.resetToDefaults();
    await _charger();
    messager.showSnackBar(SnackBar(content: Text(restaure)));
  }

  Widget? _marques(bool kids, bool actif) {
    final c = context.destiny;
    if (!kids && actif) return null;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      if (kids) const SigleKids(petit: true),
      if (!actif) ...[
        const SizedBox(width: 6),
        Tooltip(message: k('mis_de_cote'), child: Icon(Icons.visibility_off_outlined, size: 18, color: c.texteSecondaire)),
      ],
    ]);
  }

  Widget _liste(List<Widget> enfants) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: [
          for (final e in enfants)
            Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 760), child: e)),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(k('titre')),
        actions: [IconButton(tooltip: k('restaurer'), icon: const Icon(Icons.restore_rounded), onPressed: _restaurer)],
        bottom: TabBar(
          controller: _onglets,
          tabs: [
            Tab(text: k('lieux', {'n': '${_lieux.length}'})),
            Tab(text: k('dangers', {'n': '${_dangers.length}'})),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _chargement ? null : _ajouter,
        icon: const Icon(Icons.add_rounded),
        label: Text(_onglets.index == 0 ? k('ajouter_lieu') : k('ajouter_danger')),
      ),
      body: _chargement
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(controller: _onglets, children: [
              _liste([
                for (final l in _lieux)
                  ElementListe(
                    titre: l.name,
                    sousTitre: l.espaces.isEmpty ? k('sans_espace') : l.espaces.join(' · '),
                    apres: _marques(l.kids, l.actif),
                    onTap: () => _ouvrir(FicheLieuEditeur(
                        catalogue: widget.catalogue, lieu: l, existants: {for (final x in _lieux) x.id})),
                  ),
              ]),
              _liste([
                for (final d in _dangers)
                  ElementListe(
                    titre: d.name,
                    sousTitre:
                        '${d.style} · ${k('paliers_n', {'n': '${d.paliers.where((p) => p.trim().isNotEmpty).length}'})}',
                    apres: _marques(d.kids, d.actif),
                    onTap: () => _ouvrir(FicheDangerEditeur(
                        catalogue: widget.catalogue, danger: d, existants: {for (final x in _dangers) x.id})),
                  ),
              ]),
            ]),
    );
  }
}

/// Un champ de texte à la Destiny.
class _Champ extends StatelessWidget {
  const _Champ({required this.controleur, required this.libelle, this.aide, this.lignes = 1, this.cle});

  final TextEditingController controleur;
  final String libelle;
  final String? aide;
  final int lignes;
  final Key? cle;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          key: cle,
          controller: controleur,
          minLines: lignes,
          maxLines: lignes == 1 ? 1 : lignes + 4,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: libelle,
            helperText: aide,
            helperMaxLines: 2,
            border: const OutlineInputBorder(),
          ),
        ),
      );
}

/// Les boutons du bas d'une fiche : enregistrer, et supprimer si elle existe.
class _BoutonsFiche extends StatelessWidget {
  const _BoutonsFiche({required this.onEnregistrer, this.onSupprimer});

  final VoidCallback onEnregistrer;
  final VoidCallback? onSupprimer;

  @override
  Widget build(BuildContext context) {
    final t = context.textes;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Wrap(alignment: WrapAlignment.spaceBetween, spacing: 12, runSpacing: 8, children: [
        if (onSupprimer != null)
          TextButton.icon(
            onPressed: onSupprimer,
            icon: const Icon(Icons.delete_outline_rounded),
            label: Text(t.t('editeurs.catalogue.supprimer')),
          ),
        FilledButton.icon(
          onPressed: onEnregistrer,
          icon: const Icon(Icons.check_rounded),
          label: Text(t.t('editeurs.catalogue.enregistrer')),
        ),
      ]),
    );
  }
}

Future<bool> _confirmerSuppression(BuildContext context, String nom) async {
  final t = context.textes;
  String k(String x, [Map<String, String> v = const {}]) => t.t('editeurs.catalogue.$x', v);
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(k('supprimer_titre', {'nom': nom})),
          content: Text(k('supprimer_texte')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(k('annuler'))),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(k('supprimer'))),
          ],
        ),
      ) ==
      true;
}

/// La fiche d'un lieu : nom, espaces, rôles, KIDS, proposé ou non.
class FicheLieuEditeur extends StatefulWidget {
  const FicheLieuEditeur({required this.catalogue, required this.existants, this.lieu, super.key});

  final CatalogStore catalogue;
  final Location? lieu;
  final Set<String> existants;

  @override
  State<FicheLieuEditeur> createState() => _FicheLieuEditeurState();
}

class _FicheLieuEditeurState extends State<FicheLieuEditeur> {
  late final _nom = TextEditingController(text: widget.lieu?.name ?? '');
  late final _espaces = TextEditingController(text: (widget.lieu?.espaces ?? const []).join('\n'));
  late final _roles = TextEditingController(text: (widget.lieu?.roles ?? const []).join('\n'));
  late bool _kids = widget.lieu?.kids ?? false;
  late bool _actif = widget.lieu?.actif ?? true;

  @override
  void dispose() {
    _nom.dispose();
    _espaces.dispose();
    _roles.dispose();
    super.dispose();
  }

  Future<void> _enregistrer() async {
    final t = context.textes;
    final nom = _nom.text.trim();
    if (nom.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.t('editeurs.catalogue.nom_requis'))));
      return;
    }
    final base = widget.lieu ??
        Location(id: identifiantDepuis(nom, widget.existants, defaut: 'lieu'), name: nom, roles: const []);
    await widget.catalogue.saveLocation(base.copyWith(
      name: nom,
      espaces: _lignes(_espaces.text),
      roles: _lignes(_roles.text),
      kids: _kids,
      actif: _actif,
    ));
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _supprimer() async {
    final l = widget.lieu!;
    if (!await _confirmerSuppression(context, l.name)) return;
    await widget.catalogue.deleteLocation(l.id);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.textes;
    String k(String x) => t.t('editeurs.catalogue.$x');
    return PageDestiny(
      titre: widget.lieu?.name ?? k('nouveau_lieu'),
      enfants: [
        _Champ(controleur: _nom, libelle: k('nom'), cle: const Key('nom')),
        _Champ(controleur: _espaces, libelle: k('espaces'), aide: k('espaces_aide'), lignes: 3, cle: const Key('espaces')),
        _Champ(controleur: _roles, libelle: k('roles'), aide: k('roles_aide'), lignes: 3),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(k('kids')),
          subtitle: Text(k('kids_aide')),
          secondary: const SigleKids(petit: true),
          value: _kids,
          onChanged: (v) => setState(() => _kids = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(k('actif')),
          subtitle: Text(k('actif_aide')),
          value: _actif,
          onChanged: (v) => setState(() => _actif = v),
        ),
        _BoutonsFiche(onEnregistrer: _enregistrer, onSupprimer: widget.lieu == null ? null : _supprimer),
      ],
    );
  }
}

/// La fiche d'un danger : nom, style, les quatre paliers nommés comme dans la
/// grammaire, le palier 4 en version kids, KIDS, proposé ou non.
class FicheDangerEditeur extends StatefulWidget {
  const FicheDangerEditeur({required this.catalogue, required this.existants, this.danger, super.key});

  final CatalogStore catalogue;
  final Danger? danger;
  final Set<String> existants;

  @override
  State<FicheDangerEditeur> createState() => _FicheDangerEditeurState();
}

class _FicheDangerEditeurState extends State<FicheDangerEditeur> {
  late final _nom = TextEditingController(text: widget.danger?.name ?? '');
  late final _paliers = [
    for (var i = 0; i < 4; i++)
      TextEditingController(
          text: widget.danger != null && i < widget.danger!.paliers.length ? widget.danger!.paliers[i] : ''),
  ];
  late final _palier4Kids = TextEditingController(text: widget.danger?.palier4Kids ?? '');
  late String? _style = widget.danger?.style;
  late bool _kids = widget.danger?.kids ?? false;
  late bool _actif = widget.danger?.actif ?? true;

  @override
  void dispose() {
    _nom.dispose();
    for (final c in _paliers) {
      c.dispose();
    }
    _palier4Kids.dispose();
    super.dispose();
  }

  Future<void> _enregistrer(List<String> styles) async {
    final t = context.textes;
    final nom = _nom.text.trim();
    if (nom.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.t('editeurs.catalogue.nom_requis'))));
      return;
    }
    final style = _style ?? (styles.isEmpty ? '' : styles.first);
    final base = widget.danger ??
        Danger(id: identifiantDepuis(nom, widget.existants, defaut: 'danger'), name: nom, style: style);
    await widget.catalogue.saveDanger(base.copyWith(
      name: nom,
      style: style,
      paliers: [for (final c in _paliers) c.text.trim()],
      palier4Kids: _palier4Kids.text.trim(),
      kids: _kids,
      actif: _actif,
    ));
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _supprimer() async {
    final d = widget.danger!;
    if (!await _confirmerSuppression(context, d.name)) return;
    await widget.catalogue.deleteDanger(d.id);
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.textes;
    final g = context.grammaire;
    final c = context.destiny;
    String k(String x) => t.t('editeurs.catalogue.$x');
    final styles = [...t.liste('editeurs.catalogue.styles')];
    if (_style != null && _style!.isNotEmpty && !styles.contains(_style)) styles.add(_style!);
    return PageDestiny(
      titre: widget.danger?.name ?? k('nouveau_danger'),
      enfants: [
        _Champ(controleur: _nom, libelle: k('nom'), cle: const Key('nom')),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: DropdownButtonFormField<String>(
            initialValue: _style ?? (styles.isEmpty ? null : styles.first),
            decoration: InputDecoration(labelText: k('style'), border: const OutlineInputBorder()),
            items: [for (final s in styles) DropdownMenuItem(value: s, child: Text(s))],
            onChanged: (v) => setState(() => _style = v),
          ),
        ),
        SectionDestiny(titre: k('paliers'), espace: 6, enfants: [
          for (final p in g.paliers)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextField(
                key: Key('palier_${p.id.name}'),
                controller: _paliers[p.id.index],
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: '${p.numero}. ${p.nom}',
                  helperText: k('palier_aide'),
                  border: const OutlineInputBorder(),
                  prefixIcon: Icon(Icons.circle, size: 12, color: c.palier(p.id)),
                ),
              ),
            ),
        ]),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(k('kids')),
          subtitle: Text(k('kids_aide')),
          secondary: const SigleKids(petit: true),
          value: _kids,
          onChanged: (v) => setState(() => _kids = v),
        ),
        if (_kids)
          _Champ(controleur: _palier4Kids, libelle: k('palier_4_kids'), aide: k('palier_4_kids_aide'), lignes: 2),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(k('actif')),
          subtitle: Text(k('actif_aide')),
          value: _actif,
          onChanged: (v) => setState(() => _actif = v),
        ),
        _BoutonsFiche(
          onEnregistrer: () => _enregistrer(styles),
          onSupprimer: widget.danger == null ? null : _supprimer,
        ),
      ],
    );
  }
}

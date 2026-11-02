import 'package:flutter/material.dart';

import '../../domain/entities/danger.dart';
import '../../domain/entities/dilemma.dart';
import '../../domain/repositories/catalog_store.dart';
import '../destiny/donnees.dart';
import '../destiny/page.dart';
import '../theme/destiny_theme.dart';
import 'editeur_catalogue_screen.dart' show identifiantDepuis;

/// Les dilemmes de l'acte 4, rangés par danger : la régie les propose quand
/// vient le prix à payer. Le champ « genre » s'appelait « moteur » dans les
/// données : il garde ce nom dans le fichier.
class EditeurDilemmesScreen extends StatefulWidget {
  const EditeurDilemmesScreen({required this.catalogue, super.key});

  final CatalogStore catalogue;

  @override
  State<EditeurDilemmesScreen> createState() => _EditeurDilemmesScreenState();
}

class _EditeurDilemmesScreenState extends State<EditeurDilemmesScreen> {
  List<Danger> _dangers = const [];
  List<Dilemma> _dilemmes = const [];
  bool _chargement = true;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final dangers = await widget.catalogue.getDangers();
    final dilemmes = await widget.catalogue.getDilemmas();
    if (!mounted) return;
    setState(() {
      _dangers = dangers;
      _dilemmes = dilemmes;
      _chargement = false;
    });
  }

  Future<void> _editer(Danger danger, {Dilemma? existant}) async {
    final t = context.textes;
    final messager = ScaffoldMessenger.of(context);
    final resultat = await Navigator.of(context).push<Dilemma>(
      MaterialPageRoute(builder: (_) => FicheDilemmeEditeur(danger: danger, existant: existant)),
    );
    if (resultat == null) return;
    final id = existant?.id ??
        identifiantDepuis('${danger.id}_${resultat.nom}', {for (final d in _dilemmes) d.id}, defaut: 'dilemme');
    await widget.catalogue.saveDilemma(Dilemma(
      id: id,
      nom: resultat.nom,
      sourceReelle: existant?.sourceReelle ?? '',
      moteur: resultat.moteur,
      dangerLie: danger.id,
      situation: resultat.situation,
      choixA: resultat.choixA,
      choixB: resultat.choixB,
    ));
    await _charger();
    messager.showSnackBar(SnackBar(
      content: Text(existant == null
          ? t.t('editeurs.dilemmes.ajoute', {'danger': danger.name})
          : t.t('editeurs.dilemmes.modifie')),
    ));
  }

  Future<void> _supprimer(Dilemma d) async {
    final t = context.textes;
    String k(String x) => t.t('editeurs.dilemmes.$x');
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(k('supprimer_titre')),
        content: Text(d.nom),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(k('annuler'))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(k('supprimer'))),
        ],
      ),
    );
    if (ok != true) return;
    await widget.catalogue.deleteDilemma(d.id);
    await _charger();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.textes;
    final c = context.destiny;
    String k(String x, [Map<String, String> v = const {}]) => t.t('editeurs.dilemmes.$x', v);
    if (_chargement) {
      return Scaffold(appBar: AppBar(title: Text(k('titre'))), body: const Center(child: CircularProgressIndicator()));
    }
    return PageDestiny(
      titre: k('titre'),
      enfants: [
        Paragraphe(k('intro'), italique: true),
        for (final danger in _dangers)
          Builder(builder: (context) {
            final dilemmes = [for (final d in _dilemmes) if (d.dangerLie == danger.id) d];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: c.carte,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14), side: BorderSide(color: c.filet)),
                clipBehavior: Clip.antiAlias,
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    title: Text(danger.name,
                        style: TextStyle(
                            fontFamily: kPoliceTitres, fontWeight: FontWeight.w700, fontSize: 15, color: c.texte)),
                    subtitle: Text(
                      dilemmes.isEmpty
                          ? k('aucun')
                          : dilemmes.length == 1
                              ? k('un')
                              : k('nombre', {'n': '${dilemmes.length}'}),
                      style: TextStyle(fontFamily: kPoliceTexte, fontSize: 12.5, color: c.texteSecondaire),
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                    children: [
                      for (final d in dilemmes)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(d.nom.isEmpty ? k('sans_titre') : d.nom),
                          subtitle: Text('${d.moteur} · ${d.situation}', maxLines: 2, overflow: TextOverflow.ellipsis),
                          onTap: () => _editer(danger, existant: d),
                          trailing: IconButton(
                            tooltip: k('supprimer'),
                            icon: const Icon(Icons.delete_outline_rounded),
                            onPressed: () => _supprimer(d),
                          ),
                        ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => _editer(danger),
                          icon: const Icon(Icons.add_rounded),
                          label: Text(k('ajouter')),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }
}

/// La fiche d'un dilemme : titre, genre, situation, choix A et B. Rend le
/// dilemme rempli (sans identifiant), ou rien si on revient en arrière.
class FicheDilemmeEditeur extends StatefulWidget {
  const FicheDilemmeEditeur({required this.danger, this.existant, super.key});

  final Danger danger;
  final Dilemma? existant;

  @override
  State<FicheDilemmeEditeur> createState() => _FicheDilemmeEditeurState();
}

class _FicheDilemmeEditeurState extends State<FicheDilemmeEditeur> {
  final _formulaire = GlobalKey<FormState>();
  late final _nom = TextEditingController(text: widget.existant?.nom ?? '');
  late final _situation = TextEditingController(text: widget.existant?.situation ?? '');
  late final _choixA = TextEditingController(text: widget.existant?.choixA ?? '');
  late final _choixB = TextEditingController(text: widget.existant?.choixB ?? '');
  late String? _genre = widget.existant?.moteur;

  @override
  void dispose() {
    _nom.dispose();
    _situation.dispose();
    _choixA.dispose();
    _choixB.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.textes;
    String k(String x, [Map<String, String> v = const {}]) => t.t('editeurs.dilemmes.$x', v);
    final genres = [...t.liste('editeurs.dilemmes.genres')];
    if (_genre != null && _genre!.isNotEmpty && !genres.contains(_genre)) genres.add(_genre!);
    String? requis(String? v) => (v == null || v.trim().isEmpty) ? k('requis') : null;
    Widget champ(TextEditingController c, String libelle, {String? exemple, int lignes = 1, Key? cle}) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextFormField(
            key: cle,
            controller: c,
            minLines: lignes,
            maxLines: lignes + 3,
            textCapitalization: TextCapitalization.sentences,
            validator: requis,
            decoration: InputDecoration(labelText: libelle, hintText: exemple, border: const OutlineInputBorder()),
          ),
        );
    return Form(
      key: _formulaire,
      child: PageDestiny(
        titre: widget.existant == null ? k('nouveau') : k('modifier'),
        enfants: [
          Paragraphe(k('danger', {'nom': widget.danger.name}), gras: true),
          champ(_nom, k('titre_champ'), exemple: k('titre_exemple'), cle: const Key('titre')),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: DropdownButtonFormField<String>(
              initialValue: _genre ?? genres.first,
              decoration: InputDecoration(labelText: k('genre'), border: const OutlineInputBorder()),
              items: [for (final g in genres) DropdownMenuItem(value: g, child: Text(g))],
              onChanged: (v) => setState(() => _genre = v),
            ),
          ),
          champ(_situation, k('situation'), exemple: k('situation_exemple'), lignes: 2, cle: const Key('situation')),
          champ(_choixA, k('choix_a'), cle: const Key('choix_a')),
          champ(_choixB, k('choix_b'), cle: const Key('choix_b')),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () {
                if (!(_formulaire.currentState?.validate() ?? false)) return;
                Navigator.of(context).pop(Dilemma(
                  id: widget.existant?.id ?? '',
                  nom: _nom.text.trim(),
                  sourceReelle: widget.existant?.sourceReelle ?? '',
                  moteur: _genre ?? genres.first,
                  dangerLie: widget.danger.id,
                  situation: _situation.text.trim(),
                  choixA: _choixA.text.trim(),
                  choixB: _choixB.text.trim(),
                ));
              },
              icon: const Icon(Icons.check_rounded),
              label: Text(k('enregistrer')),
            ),
          ),
        ],
      ),
    );
  }
}

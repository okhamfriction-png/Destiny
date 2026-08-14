import 'package:flutter/material.dart';

import '../../domain/entities/danger.dart';
import '../../domain/entities/dilemma.dart';
import '../../domain/repositories/catalog_store.dart';

/// Les 5 moteurs (genres) proposés pour un dilemme.
const List<String> kDilemmaMoteurs = [
  'Sacrifice',
  'Confiance/Trahison',
  'Ressource rare',
  'Vérité/Mensonge',
  'Tout ou rien',
];

/// Écran d'édition des dilemmes, regroupés PAR DANGER. On peut ajouter,
/// modifier et supprimer un dilemme rattaché à chaque danger.
class DilemmaEditorScreen extends StatefulWidget {
  const DilemmaEditorScreen({required this.catalogStore, super.key});

  final CatalogStore catalogStore;

  @override
  State<DilemmaEditorScreen> createState() => _DilemmaEditorScreenState();
}

class _DilemmaEditorScreenState extends State<DilemmaEditorScreen> {
  List<Danger> _dangers = const [];
  List<Dilemma> _dilemmas = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final dangers = await widget.catalogStore.getDangers();
    final dilemmas = await widget.catalogStore.getDilemmas();
    if (!mounted) return;
    setState(() {
      _dangers = dangers;
      _dilemmas = dilemmas;
      _loading = false;
    });
  }

  String _slug(String input) {
    var s = input.toLowerCase();
    const from = 'àâäáãåçéèêëíìîïñóòôöõúùûüýÿœæ';
    const to = 'aaaaaaceeeeiiiinooooouuuuyyoa';
    for (var i = 0; i < from.length; i++) {
      s = s.replaceAll(from[i], to[i]);
    }
    s = s
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return s.isEmpty ? 'dilemme' : s;
  }

  String _uniqueId(String base, Set<String> existing) {
    var id = base;
    var n = 1;
    while (existing.contains(id)) {
      id = '${base}_$n';
      n++;
    }
    return id;
  }

  List<Dilemma> _forDanger(String dangerId) =>
      _dilemmas.where((d) => d.dangerLie == dangerId).toList(growable: false);

  Future<void> _addOrEdit(Danger danger, {Dilemma? existing}) async {
    final result = await showModalBottomSheet<Dilemma>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF141029),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _DilemmaForm(danger: danger, existing: existing),
    );
    if (result == null) return;

    // Complète l'id (nouveau dilemme) et le danger lié.
    final id = existing?.id ??
        _uniqueId(_slug('${danger.id}_${result.nom}'),
            _dilemmas.map((d) => d.id).toSet());
    final dilemma = Dilemma(
      id: id,
      nom: result.nom,
      sourceReelle: existing?.sourceReelle ?? '',
      moteur: result.moteur,
      dangerLie: danger.id,
      situation: result.situation,
      choixA: result.choixA,
      choixB: result.choixB,
    );
    await widget.catalogStore.saveDilemma(dilemma);
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(existing == null
              ? 'Dilemme ajouté à « ${danger.name} ».'
              : 'Dilemme modifié.')),
    );
  }

  Future<void> _delete(Dilemma d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Supprimer ce dilemme ?'),
        content: Text(d.nom),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok != true) return;
    await widget.catalogStore.deleteDilemma(d.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Dilemmes par danger')),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF141029), Color(0xFF0A0818)],
          ),
        ),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
                    child: Text(
                      'Ajoute tes propres dilemmes. Chacun est rattaché à un '
                      'danger et apparaît dans le mode Dilemme quand ce danger '
                      'est tiré.',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: Colors.white60),
                    ),
                  ),
                  for (final danger in _dangers)
                    _DangerGroup(
                      danger: danger,
                      dilemmas: _forDanger(danger.id),
                      onAdd: () => _addOrEdit(danger),
                      onEdit: (d) => _addOrEdit(danger, existing: d),
                      onDelete: _delete,
                    ),
                ],
              ),
      ),
    );
  }
}

class _DangerGroup extends StatelessWidget {
  const _DangerGroup({
    required this.danger,
    required this.dilemmas,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  final Danger danger;
  final List<Dilemma> dilemmas;
  final VoidCallback onAdd;
  final ValueChanged<Dilemma> onEdit;
  final ValueChanged<Dilemma> onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Icon(Icons.warning_amber_rounded,
              color: theme.colorScheme.primary),
          title: Text(danger.name),
          subtitle: Text(dilemmas.isEmpty
              ? 'Aucun dilemme'
              : '${dilemmas.length} dilemme${dilemmas.length > 1 ? 's' : ''}'),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          children: [
            for (final d in dilemmas)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(d.nom.isEmpty ? '(sans titre)' : d.nom),
                subtitle: Text(
                  '${d.moteur} · ${d.situation}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      tooltip: 'Modifier',
                      onPressed: () => onEdit(d),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      tooltip: 'Supprimer',
                      onPressed: () => onDelete(d),
                    ),
                  ],
                ),
              ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Ajouter un dilemme'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Formulaire (bottom sheet) de création / édition d'un dilemme.
class _DilemmaForm extends StatefulWidget {
  const _DilemmaForm({required this.danger, this.existing});

  final Danger danger;
  final Dilemma? existing;

  @override
  State<_DilemmaForm> createState() => _DilemmaFormState();
}

class _DilemmaFormState extends State<_DilemmaForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nom;
  late final TextEditingController _situation;
  late final TextEditingController _choixA;
  late final TextEditingController _choixB;
  late String _moteur;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nom = TextEditingController(text: e?.nom ?? '');
    _situation = TextEditingController(text: e?.situation ?? '');
    _choixA = TextEditingController(text: e?.choixA ?? '');
    _choixB = TextEditingController(text: e?.choixB ?? '');
    _moteur = (e != null && kDilemmaMoteurs.contains(e.moteur))
        ? e.moteur
        : kDilemmaMoteurs.first;
  }

  @override
  void dispose() {
    _nom.dispose();
    _situation.dispose();
    _choixA.dispose();
    _choixB.dispose();
    super.dispose();
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Champ requis' : null;

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      Dilemma(
        id: widget.existing?.id ?? '',
        nom: _nom.text.trim(),
        sourceReelle: widget.existing?.sourceReelle ?? '',
        moteur: _moteur,
        dangerLie: widget.danger.id,
        situation: _situation.text.trim(),
        choixA: _choixA.text.trim(),
        choixB: _choixB.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottom + 16),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.existing == null
                    ? 'Nouveau dilemme'
                    : 'Modifier le dilemme',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 2),
              Text('Danger : ${widget.danger.name}',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.primary)),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nom,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Titre',
                  hintText: 'ex. Le dernier canot',
                ),
                validator: _required,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _moteur,
                decoration: const InputDecoration(labelText: 'Genre (moteur)'),
                items: [
                  for (final m in kDilemmaMoteurs)
                    DropdownMenuItem(value: m, child: Text(m)),
                ],
                onChanged: (v) => setState(() => _moteur = v ?? _moteur),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _situation,
                textCapitalization: TextCapitalization.sentences,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Le dilemme (situation)',
                  hintText: 'La mise en situation, sans les choix.',
                ),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _choixA,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Choix 1'),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _choixB,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Choix 2'),
                validator: _required,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Annuler'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _submit,
                      child: const Text('Enregistrer'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

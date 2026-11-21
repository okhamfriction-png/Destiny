import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../application/notes/notes_controller.dart';
import '../../domain/notes/notes.dart';
import '../destiny/donnees.dart';
import '../destiny/page.dart';
import '../theme/destiny_theme.dart';

/// Enregistre (chiffre et envoie). Si la note a changé sur GitHub entre-temps,
/// montre la différence et laisse choisir. Rend vrai si c'est enregistré.
Future<bool> enregistrerNote(BuildContext context, NotesController notes, Future<void> Function() action) async {
  final t = context.textes;
  final messager = ScaffoldMessenger.of(context);
  try {
    await action();
    messager.showSnackBar(SnackBar(content: Text(t.t('notes.enregistre'))));
    return true;
  } on ConflitNotes catch (c) {
    if (!context.mounted) return false;
    final garder = await showDialog<bool>(context: context, builder: (_) => DialogueConflit(conflit: c));
    if (garder == null) return false;
    await notes.resoudreConflit(c, garderLaMienne: garder);
    messager.showSnackBar(SnackBar(content: Text(t.t('notes.enregistre'))));
    return true;
  } catch (e) {
    messager.showSnackBar(SnackBar(content: Text(t.t('notes.erreur_enregistrement', {'erreur': '$e'}))));
    return false;
  }
}

/// Les lignes qui diffèrent entre deux versions (sans ordre fin : de quoi
/// voir ce qui a changé).
({List<String> enMoins, List<String> enPlus}) differenceLignes(String distante, String mienne) {
  final a = distante.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
  final b = mienne.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
  final sa = a.toSet(), sb = b.toSet();
  return (enMoins: [for (final l in a) if (!sb.contains(l)) l], enPlus: [for (final l in b) if (!sa.contains(l)) l]);
}

class DialogueConflit extends StatelessWidget {
  const DialogueConflit({required this.conflit, super.key});

  final ConflitNotes conflit;

  @override
  Widget build(BuildContext context) {
    final t = context.textes;
    final d = context.destiny;
    String k(String x) => t.t('notes.$x');
    final diff = differenceLignes(conflit.distante, conflit.mienne);
    final mono = TextStyle(fontFamily: 'monospace', fontSize: 12, color: d.texte);
    return AlertDialog(
      key: const ValueKey('dialogue_conflit'),
      title: Text(k('conflit_titre')),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(k('conflit_aide')),
            const SizedBox(height: 10),
            if (diff.enMoins.isNotEmpty) ...[
              Text(k('conflit_moins'), style: TextStyle(fontWeight: FontWeight.w700, color: Colors.red.shade400)),
              for (final l in diff.enMoins) Text('− $l', style: mono),
              const SizedBox(height: 8),
            ],
            if (diff.enPlus.isNotEmpty) ...[
              Text(k('conflit_plus'), style: TextStyle(fontWeight: FontWeight.w700, color: Colors.green.shade500)),
              for (final l in diff.enPlus) Text('+ $l', style: mono),
            ],
          ]),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(t.t('reglages.annuler'))),
        TextButton(
            key: const ValueKey('conflit_leur'), onPressed: () => Navigator.pop(context, false), child: Text(k('conflit_leur'))),
        FilledButton(
            key: const ValueKey('conflit_mienne'), onPressed: () => Navigator.pop(context, true), child: Text(k('conflit_mienne'))),
      ],
    );
  }
}

/// L'éditeur WhatsApp : le texte, son aperçu, « Copier » et « Recréer depuis
/// le modèle ». Le texte modifié est gardé avec la note.
Future<void> ouvrirWhatsApp(
  BuildContext context, {
  required String texte,
  required String Function() recreer,
  Future<void> Function(String texte)? enregistrer,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => EditeurWhatsApp(texte: texte.isEmpty ? recreer() : texte, recreer: recreer, enregistrer: enregistrer),
    );

class EditeurWhatsApp extends StatefulWidget {
  const EditeurWhatsApp({required this.texte, required this.recreer, this.enregistrer, super.key});

  final String texte;
  final String Function() recreer;
  final Future<void> Function(String texte)? enregistrer;

  @override
  State<EditeurWhatsApp> createState() => _EditeurWhatsAppState();
}

class _EditeurWhatsAppState extends State<EditeurWhatsApp> {
  late final TextEditingController _c = TextEditingController(text: widget.texte);
  late final String _initial = widget.texte;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _copier() async {
    final t = context.textes;
    final messager = ScaffoldMessenger.of(context);
    await Clipboard.setData(ClipboardData(text: _c.text));
    if (_c.text != _initial && widget.enregistrer != null) {
      try {
        await widget.enregistrer!(_c.text);
      } catch (_) {
        // La copie compte d'abord ; l'enregistrement se refera.
      }
    }
    messager.showSnackBar(SnackBar(content: Text(t.t('reglages.copie')), duration: const Duration(seconds: 2)));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.textes;
    final d = context.destiny;
    String k(String x, [Map<String, String> v = const {}]) => t.t('notes.$x', v);
    final aCompleter = RegExp(r'\{[^{}]+\}').hasMatch(_c.text);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(k('whatsapp_titre'),
              style: TextStyle(fontFamily: kPoliceTitres, fontSize: 18, fontWeight: FontWeight.w700, color: d.titre)),
          const SizedBox(height: 10),
          TextField(
            key: const ValueKey('texte_whatsapp'),
            controller: _c,
            minLines: 6,
            maxLines: 14,
            style: const TextStyle(fontSize: 14),
            onChanged: (_) => setState(() {}),
          ),
          if (aCompleter)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(k('whatsapp_a_completer', {'champs': '{…}'}),
                  style: TextStyle(fontSize: 12.5, color: d.titre, fontStyle: FontStyle.italic)),
            ),
          const SizedBox(height: 12),
          Text(k('whatsapp_apercu').toUpperCase(),
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 1, color: d.titre)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: d.sombre ? const Color(0xFF1F2C33) : const Color(0xFFDCF8C6),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ApercuWhatsApp(_c.text),
          ),
          const SizedBox(height: 12),
          Wrap(alignment: WrapAlignment.end, spacing: 8, runSpacing: 6, children: [
            TextButton.icon(
              key: const ValueKey('recreer_whatsapp'),
              onPressed: () => setState(() => _c.text = widget.recreer()),
              icon: const Icon(Icons.restart_alt_rounded, size: 18),
              label: Text(k('whatsapp_recreer')),
            ),
            FilledButton.icon(
              key: const ValueKey('copier_whatsapp'),
              onPressed: _copier,
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: Text(t.t('reglages.copier')),
            ),
          ]),
        ]),
      ),
    );
  }
}

/// L'aperçu, comme WhatsApp l'affiche : *gras*, _italique_.
class ApercuWhatsApp extends StatelessWidget {
  const ApercuWhatsApp(this.texte, {super.key});

  final String texte;

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(fontSize: 14, height: 1.35, color: context.destiny.sombre ? Colors.white : Colors.black87);
    return Text.rich(TextSpan(style: base, children: [
      for (final m in morceauxWhatsApp(texte))
        TextSpan(
          text: m.texte,
          style: TextStyle(
            fontWeight: m.gras ? FontWeight.w700 : null,
            fontStyle: m.italique ? FontStyle.italic : null,
          ),
        ),
    ]));
  }
}

List<String> _virgules(String s) => [for (final x in s.split(',')) if (x.trim().isNotEmpty) x.trim()];
List<String> _lignes(String s) => [for (final x in s.split('\n')) if (x.trim().isNotEmpty) x.trim()];
bool _dateValide(String s) => RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s) && DateTime.tryParse(s) != null;

/// Créer ou corriger une note : titre, date, type, résumé, compte rendu,
/// texte WhatsApp, tags et personnes. Une note corrigée garde sa date de
/// création.
class EditionEntreeScreen extends StatefulWidget {
  const EditionEntreeScreen({required this.notes, this.entree, super.key});

  final NotesController notes;
  final EntreeNote? entree;

  @override
  State<EditionEntreeScreen> createState() => _EditionEntreeScreenState();
}

class _EditionEntreeScreenState extends State<EditionEntreeScreen> {
  late final EntreeNote? e = widget.entree;
  late final _titre = TextEditingController(text: e?.titre ?? '');
  late final _date = TextEditingController(text: e?.date ?? widget.notes.aujourdhui);
  late TypeNote _type = e?.type ?? TypeNote.repetition;
  late final _resume = TextEditingController(text: e?.resume ?? '');
  late final _contenu = TextEditingController(text: e?.contenuMd ?? '');
  late final _whatsapp = TextEditingController(text: e?.whatsapp ?? '');
  late final _tags = TextEditingController(text: e?.tags.join(', ') ?? '');
  late final _personnes = TextEditingController(text: e?.personnes.join(', ') ?? '');
  String? _erreur;
  bool _enCours = false;

  EntreeNote _construire() {
    final jour = widget.notes.aujourdhui;
    final base = e;
    if (base != null) {
      return base.copie(
        date: _date.text.trim(),
        type: _type,
        titre: _titre.text.trim(),
        resume: _resume.text.trim(),
        contenuMd: _contenu.text,
        whatsapp: _whatsapp.text,
        tags: _virgules(_tags.text),
        personnes: _virgules(_personnes.text),
        jour: jour,
      );
    }
    return EntreeNote(
      id: idEntree(_date.text.trim(), _type, _titre.text.trim()),
      date: _date.text.trim(),
      type: _type,
      titre: _titre.text.trim(),
      resume: _resume.text.trim(),
      contenuMd: _contenu.text,
      whatsapp: _whatsapp.text,
      tags: _virgules(_tags.text),
      personnes: _virgules(_personnes.text),
      creeLe: jour,
      misAJourLe: jour,
    );
  }

  Future<void> _enregistrer() async {
    final t = context.textes;
    if (_titre.text.trim().isEmpty) return setState(() => _erreur = t.t('notes.titre_vide'));
    if (!_dateValide(_date.text.trim())) return setState(() => _erreur = t.t('notes.date_invalide'));
    setState(() {
      _erreur = null;
      _enCours = true;
    });
    final ok = await enregistrerNote(context, widget.notes, () => widget.notes.enregistrerEntree(_construire()));
    if (!mounted) return;
    setState(() => _enCours = false);
    if (ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.textes;
    String k(String x) => t.t('notes.$x');
    Widget champ(String cle, TextEditingController c, {int lignes = 1, Key? key}) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            key: key,
            controller: c,
            minLines: lignes,
            maxLines: lignes == 1 ? 1 : lignes + 10,
            decoration: InputDecoration(labelText: k(cle), alignLabelWithHint: lignes > 1),
          ),
        );
    return PageDestiny(
      titre: e == null ? k('nouvelle') : k('modifier'),
      enfants: [
        champ('champ_titre', _titre, key: const ValueKey('champ_titre')),
        champ('champ_date', _date, key: const ValueKey('champ_date')),
        Text(k('champ_type'), style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final type in TypeNote.values)
            ChoiceChip(label: Text(type.libelle), selected: _type == type, onSelected: (_) => setState(() => _type = type)),
        ]),
        const SizedBox(height: 12),
        champ('champ_resume', _resume, lignes: 2),
        champ('champ_contenu', _contenu, lignes: 10, key: const ValueKey('champ_contenu')),
        Row(children: [
          Expanded(child: champ('champ_whatsapp', _whatsapp, lignes: 4)),
          IconButton(
            tooltip: k('whatsapp_recreer'),
            onPressed: () => setState(() => _whatsapp.text =
                whatsappCompteRendu(_construire(), widget.notes.modeles.compteRenduPour(_construire().type),
                    suivante: widget.notes.seance)),
            icon: const Icon(Icons.restart_alt_rounded),
          ),
        ]),
        champ('champ_tags', _tags),
        champ('champ_personnes', _personnes),
        if (_erreur != null) Text(_erreur!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        const SizedBox(height: 8),
        FilledButton.icon(
          key: const ValueKey('enregistrer_note'),
          onPressed: _enCours ? null : _enregistrer,
          icon: const Icon(Icons.lock_rounded, size: 18),
          label: Text(k('enregistrer')),
        ),
      ],
    );
  }
}

/// Modifier la prochaine séance (et les séances suivantes).
class EditionSeanceScreen extends StatefulWidget {
  const EditionSeanceScreen({required this.notes, required this.seance, super.key});

  final NotesController notes;
  final ProchaineSeance? seance;

  @override
  State<EditionSeanceScreen> createState() => _EditionSeanceScreenState();
}

class _EditionSeanceScreenState extends State<EditionSeanceScreen> {
  late final s = widget.seance;
  late final _date = TextEditingController(text: s?.date ?? widget.notes.aujourdhui);
  late final _heure = TextEditingController(text: s?.heure ?? '14 h – 17 h');
  late final _lieu = TextEditingController(text: s?.lieu ?? '');
  late TypeNote _type = s?.type ?? TypeNote.repetition;
  late final _objectif = TextEditingController(text: s?.objectif ?? '');
  late final _ouverture = TextEditingController(text: s?.ouverture ?? '');
  late final _organisation = TextEditingController(text: s?.organisation.join('\n') ?? '');
  late final _retourTitre = TextEditingController(text: s?.retourTitre ?? '');
  late final _retour = TextEditingController(text: s?.retourMd ?? '');
  late final _deroule = TextEditingController(text: s?.deroule.join('\n') ?? '');
  late final _distribution = TextEditingController(text: s?.distribution ?? '');
  late final _aPreparer = TextEditingController(text: s?.aPreparer.join('\n') ?? '');
  late final _spectacle = TextEditingController(text: s?.prochainSpectacle ?? '');
  late final _devise = TextEditingController(text: s?.devise ?? '');
  late final _contenu = TextEditingController(text: s?.contenuMd ?? '');
  late final _suivantes = TextEditingController(
      text: s?.suivantes.map((x) => [x.date, x.heure, x.lieu, if (x.type == TypeNote.spectacle) 'spectacle'].join(' · ')).join('\n') ??
          '');
  String? _erreur;

  List<SeanceAVenir> _lireSuivantes() => [
        for (final l in _lignes(_suivantes.text))
          if (l.split('·').map((x) => x.trim()).toList() case final p when _dateValide(p.first))
            SeanceAVenir(
              date: p.first,
              heure: p.length > 1 ? p[1] : '',
              lieu: p.length > 2 ? p[2] : '',
              type: p.length > 3 && p[3].toLowerCase().startsWith('spectacle') ? TypeNote.spectacle : TypeNote.repetition,
            ),
      ];

  Future<void> _enregistrer() async {
    final t = context.textes;
    if (!_dateValide(_date.text.trim())) return setState(() => _erreur = t.t('notes.date_invalide'));
    final nouvelle = ProchaineSeance(
      date: _date.text.trim(),
      heure: _heure.text.trim(),
      lieu: _lieu.text.trim(),
      type: _type,
      objectif: _objectif.text.trim(),
      ouverture: _ouverture.text.trim(),
      organisation: _lignes(_organisation.text),
      retourTitre: _retourTitre.text.trim(),
      retourMd: _retour.text,
      deroule: _lignes(_deroule.text),
      distribution: _distribution.text.trim(),
      aPreparer: _lignes(_aPreparer.text),
      prochainSpectacle: _spectacle.text.trim(),
      devise: _devise.text.trim(),
      contenuMd: _contenu.text,
      whatsapp: s?.whatsapp ?? '',
      misAJourLe: widget.notes.aujourdhui,
      suivantes: _lireSuivantes(),
    );
    final ok = await enregistrerNote(context, widget.notes, () => widget.notes.enregistrerSeance(nouvelle));
    if (ok && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.textes;
    String k(String x) => t.t('notes.$x');
    Widget champ(String cle, TextEditingController c, {int lignes = 1}) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(
            controller: c,
            minLines: lignes,
            maxLines: lignes == 1 ? 1 : lignes + 8,
            decoration: InputDecoration(labelText: k(cle), alignLabelWithHint: lignes > 1),
          ),
        );
    return PageDestiny(titre: k('modifier_seance'), enfants: [
      champ('champ_date', _date),
      Wrap(spacing: 6, children: [
        for (final type in [TypeNote.repetition, TypeNote.spectacle])
          ChoiceChip(label: Text(type.libelle), selected: _type == type, onSelected: (_) => setState(() => _type = type)),
      ]),
      const SizedBox(height: 12),
      champ('champ_heure', _heure),
      champ('champ_lieu', _lieu),
      champ('champ_ouverture', _ouverture, lignes: 2),
      champ('champ_objectif', _objectif, lignes: 2),
      champ('champ_organisation', _organisation, lignes: 3),
      champ('champ_retour_titre', _retourTitre),
      champ('champ_retour', _retour, lignes: 5),
      champ('champ_deroule', _deroule, lignes: 4),
      champ('champ_distribution', _distribution, lignes: 2),
      champ('champ_a_preparer', _aPreparer, lignes: 2),
      champ('champ_prochain_spectacle', _spectacle),
      champ('champ_devise', _devise),
      champ('champ_contenu_seance', _contenu, lignes: 4),
      champ('champ_suivantes', _suivantes, lignes: 3),
      if (_erreur != null) Text(_erreur!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
      FilledButton.icon(
        onPressed: _enregistrer,
        icon: const Icon(Icons.lock_rounded, size: 18),
        label: Text(k('enregistrer')),
      ),
    ]);
  }
}

/// Les deux modèles WhatsApp, modifiables.
class ModelesScreen extends StatefulWidget {
  const ModelesScreen({required this.notes, super.key});

  final NotesController notes;

  @override
  State<ModelesScreen> createState() => _ModelesScreenState();
}

class _ModelesScreenState extends State<ModelesScreen> {
  late final _crRepetition = TextEditingController(text: widget.notes.modeles.compteRenduRepetition);
  late final _crSpectacle = TextEditingController(text: widget.notes.modeles.compteRenduSpectacle);
  late final _seance = TextEditingController(text: widget.notes.modeles.prochaineSeance);

  @override
  Widget build(BuildContext context) {
    final t = context.textes;
    String k(String x) => t.t('notes.$x');
    Widget champ(String titre, TextEditingController c, String defaut) => SectionDestiny(titre: titre, enfants: [
          TextField(controller: c, minLines: 8, maxLines: 30, style: const TextStyle(fontSize: 13.5)),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: () => setState(() => c.text = defaut), child: Text(t.t('reglages.remettre'))),
          ),
        ]);
    return PageDestiny(titre: k('modeles'), enfants: [
      Text(k('modele_aide'), style: Theme.of(context).textTheme.bodySmall),
      champ(k('modele_prochaine_seance'), _seance, modeleProchaineSeance),
      champ(k('modele_compte_rendu_repetition'), _crRepetition, modeleCompteRenduRepetition),
      champ(k('modele_compte_rendu_spectacle'), _crSpectacle, modeleCompteRenduSpectacle),
      const SizedBox(height: 8),
      FilledButton.icon(
        onPressed: () async {
          final ok = await enregistrerNote(context, widget.notes,
              () => widget.notes.enregistrerModeles(ModelesWhatsApp(
                  compteRenduRepetition: _crRepetition.text,
                  compteRenduSpectacle: _crSpectacle.text,
                  prochaineSeance: _seance.text)));
          if (ok && context.mounted) Navigator.of(context).pop();
        },
        icon: const Icon(Icons.lock_rounded, size: 18),
        label: Text(k('enregistrer')),
      ),
    ]);
  }
}

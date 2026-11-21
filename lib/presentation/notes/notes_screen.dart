import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../../application/notes/notes_controller.dart';
import '../../domain/notes/notes.dart';
import '../destiny/donnees.dart';
import '../destiny/page.dart';
import '../theme/destiny_theme.dart';
import 'notes_edition.dart';

/// Destiny Note : la prochaine séance, les règles en vigueur, le journal des
/// décisions, puis le fil de toutes les notes (filtres et recherche). Réservé
/// à Marouene : l'onglet n'existe que si l'accès administrateur est ouvert.
class NotesScreen extends StatefulWidget {
  const NotesScreen({required this.notes, super.key});

  final NotesController notes;

  @override
  State<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends State<NotesScreen> {
  final Set<TypeNote> _types = {};
  String _recherche = '';

  NotesController get n => widget.notes;

  @override
  void initState() {
    super.initState();
    n.ouvrir();
  }

  void _ouvrir(Widget page) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));

  @override
  Widget build(BuildContext context) {
    final t = context.textes;
    final d = context.destiny;
    String k(String x, [Map<String, String> v = const {}]) => t.t('notes.$x', v);
    return ListenableBuilder(
      listenable: n,
      builder: (context, _) {
        final fil = n.fil(types: _types, recherche: _recherche);
        return Scaffold(
          floatingActionButton: FloatingActionButton.extended(
            key: const ValueKey('nouvelle_note'),
            onPressed: () => _ouvrir(EditionEntreeScreen(notes: n)),
            icon: const Icon(Icons.edit_note_rounded),
            label: Text(k('nouvelle')),
          ),
          body: RefreshIndicator(
            onRefresh: n.rafraichir,
            child: ListView(
              key: const ValueKey('fil_notes'),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              children: [
                if (n.chargement && n.index.isEmpty) const LinearProgressIndicator(),
                if (n.erreur != null)
                  _Bandeau(k(n.erreur == 'acces_refuse' ? 'erreur_acces' : 'erreur_cle'), couleur: Colors.red),
                if (n.horsLigne) _Bandeau(k('hors_ligne'), couleur: d.texteSecondaire),
                if (n.enAttente > 0) _Bandeau(k('en_attente', {'n': '${n.enAttente}'}), couleur: d.titre),
                CarteSeance(notes: n),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const ValueKey('regles'),
                      onPressed: () => _ouvrir(PageMarkdown(
                        titre: k('regles'),
                        texte: n.regles?.contenuMd ?? '',
                        pied: n.regles == null ? '' : k('mis_a_jour', {'date': n.regles!.misAJourLe}),
                      )),
                      icon: const Icon(Icons.gavel_rounded, size: 18),
                      label: Text(k('regles'), textAlign: TextAlign.center),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const ValueKey('journal'),
                      onPressed: () => _ouvrir(JournalScreen(journal: n.journal ?? const JournalDecisions())),
                      icon: const Icon(Icons.history_edu_rounded, size: 18),
                      label: Text(k('journal'), textAlign: TextAlign.center),
                    ),
                  ),
                ]),
                const SizedBox(height: 18),
                Row(children: [
                  Text(k('fil'),
                      style: TextStyle(fontFamily: kPoliceTitres, fontSize: 18, fontWeight: FontWeight.w700, color: d.titre)),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => _ouvrir(ModelesScreen(notes: n)),
                    icon: const Icon(Icons.chat_outlined, size: 18),
                    label: Text(k('modeles')),
                  ),
                ]),
                TextField(
                  key: const ValueKey('recherche_notes'),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: k('recherche'),
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _recherche = v),
                ),
                const SizedBox(height: 10),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  FilterChip(
                    label: Text(k('tout')),
                    selected: _types.isEmpty,
                    onSelected: (_) => setState(_types.clear),
                  ),
                  for (final type in TypeNote.values)
                    FilterChip(
                      key: ValueKey('filtre_${type.id}'),
                      label: Text(type.pluriel),
                      selected: _types.contains(type),
                      onSelected: (v) => setState(() => v ? _types.add(type) : _types.remove(type)),
                    ),
                ]),
                const SizedBox(height: 12),
                if (fil.isEmpty && !n.chargement)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(k('vide'), textAlign: TextAlign.center, style: TextStyle(color: d.texteSecondaire)),
                  ),
                for (final r in fil)
                  _LigneFil(resume: r, onTap: () => _ouvrir(EntreeScreen(notes: n, resume: r))),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Bandeau extends StatelessWidget {
  const _Bandeau(this.texte, {required this.couleur});

  final String texte;
  final Color couleur;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: couleur.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: couleur.withValues(alpha: 0.5)),
        ),
        child: Text(texte, style: TextStyle(fontFamily: kPoliceTexte, fontSize: 13, color: context.destiny.texte)),
      );
}

/// La carte de la prochaine séance, en tête.
class CarteSeance extends StatefulWidget {
  const CarteSeance({required this.notes, super.key});

  final NotesController notes;

  @override
  State<CarteSeance> createState() => _CarteSeanceState();
}

class _CarteSeanceState extends State<CarteSeance> {
  /// Les sous-parties dépliées (la répète, au départ).
  final _ouvertes = <String>{'repete'};

  @override
  Widget build(BuildContext context) {
    final notes = widget.notes;
    final t = context.textes;
    final d = context.destiny;
    String k(String x, [Map<String, String> v = const {}]) => t.t('notes.$x', v);
    final s = notes.seance;
    final petit = TextStyle(fontFamily: kPoliceTexte, fontSize: 13.5, color: d.texte, height: 1.35);
    final etiquette = TextStyle(
        fontFamily: kPoliceTexte, fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 1, color: d.titre);
    final sousEtiquette = TextStyle(
        fontFamily: kPoliceTexte, fontSize: 12, fontWeight: FontWeight.w700, color: d.texteSecondaire);
    Widget puce(String texte, {String marque = '•'}) => Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: marque.length > 1 ? 26 : 16, child: Text(marque, style: petit)),
            Expanded(child: Text(texte, style: petit)),
          ]),
        );
    // Une sous-partie repliable : « 🎭 LA RÉPÈTE ».
    Widget partie(String id, String emoji, String titre, List<Widget> enfants) {
      final ouverte = _ouvertes.contains(id);
      return Container(
        margin: const EdgeInsets.only(top: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: d.filet),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          InkWell(
            key: ValueKey('partie_$id'),
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => ouverte ? _ouvertes.remove(id) : _ouvertes.add(id)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
              child: Row(children: [
                Text(emoji, style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
                Expanded(child: Text(titre.toUpperCase(), style: etiquette)),
                Icon(ouverte ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: d.texteSecondaire),
              ]),
            ),
          ),
          if (ouverte)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: enfants),
            ),
        ]),
      );
    }

    if (s == null) {
      return _cadre(d, Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(k('prochaine_seance').toUpperCase(), style: etiquette),
        const SizedBox(height: 6),
        Text(k('aucune_seance'), style: petit),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute<void>(builder: (_) => EditionSeanceScreen(notes: notes, seance: null))),
            child: Text(k('modifier_seance')),
          ),
        ),
      ]));
    }
    final ensuite = s.suivantesApres(notes.aujourdhui).where((x) => x.date != s.date).toList();
    return _cadre(
      d,
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${k('prochaine_seance')} · ${s.type.libelle}'.toUpperCase(), style: etiquette),
        const SizedBox(height: 4),
        Text(
          _majuscule(jourEtDate(s.date)),
          style: TextStyle(fontFamily: kPoliceTitres, fontSize: 21, fontWeight: FontWeight.w700, color: d.texte),
        ),
        Text(['🕑 ${s.heure}', '📍 ${s.lieu}'].where((x) => x.length > 3).join('   '),
            style: TextStyle(fontFamily: kPoliceTexte, fontSize: 14, color: d.texteSecondaire)),
        if (s.ouverture.isNotEmpty || s.objectif.isNotEmpty || s.organisation.isNotEmpty)
          partie('repete', '🎭', k('repete'), [
            if (s.ouverture.isNotEmpty) ...[
              Text('🗣️ ${k('ouverture')}', style: sousEtiquette),
              const SizedBox(height: 2),
              Text(s.ouverture, style: petit),
              const SizedBox(height: 10),
            ],
            if (s.objectif.isNotEmpty) ...[
              Text('🎯 ${k('ce_qu_on_travaille')}', style: sousEtiquette),
              const SizedBox(height: 2),
              Text(s.objectif, style: petit),
            ],
            if (s.organisation.isNotEmpty) ...[
              if (s.objectif.isNotEmpty) const SizedBox(height: 10),
              Text('🧩 ${k('organisation')}', style: sousEtiquette),
              const SizedBox(height: 2),
              for (final e in s.organisation) puce(e),
            ],
          ]),
        if (s.retourMd.isNotEmpty)
          partie('retour', '💬', s.retourTitre.isEmpty ? k('retour') : s.retourTitre, [
            TexteMarkdown(s.retourMd),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                key: const ValueKey('copier_retour'),
                onPressed: () => ouvrirWhatsApp(context, texte: whatsappRetour(s), recreer: () => whatsappRetour(s)),
                icon: const Icon(Icons.chat_rounded, size: 18),
                label: Text(k('copier_retour')),
              ),
            ),
          ]),
        if (s.deroule.isNotEmpty)
          partie('exercices', '🏋️', k('exercices'), [
            for (final (i, e) in s.deroule.indexed) puce(e, marque: '${i + 1}.'),
          ]),
        if (s.aPreparer.isNotEmpty) partie('preparer', '🎒', k('a_preparer'), [for (final e in s.aPreparer) puce(e)]),
        if (s.prochainSpectacle.isNotEmpty || s.distribution.isNotEmpty || s.devise.isNotEmpty)
          partie('spectacle', '🎬', k('prochain_spectacle'), [
            if (s.prochainSpectacle.isNotEmpty) Text(s.prochainSpectacle, style: petit.copyWith(fontWeight: FontWeight.w700)),
            if (s.distribution.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('👥 ${k('distribution')}', style: sousEtiquette),
              const SizedBox(height: 2),
              Text(s.distribution, style: petit),
            ],
            if (s.devise.isNotEmpty) ...[const SizedBox(height: 6), TexteMarkdown(s.devise)],
          ]),
        if (s.contenuMd.isNotEmpty) partie('notes', '📝', k('autres_notes'), [TexteMarkdown(s.contenuMd)]),
        if (ensuite.isNotEmpty)
          partie('ensuite', '📅', k('ensuite'), [
            for (final x in ensuite)
              puce(
                '${_majuscule(jourEtDate(x.date))} · ${[x.heure, x.lieu].where((y) => y.isNotEmpty).join(' · ')}'
                '${x.type == TypeNote.spectacle ? ' · ${x.type.libelle}' : ''}',
                marque: x.type == TypeNote.spectacle ? '🎬' : '•',
              ),
          ]),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 4, alignment: WrapAlignment.end, children: [
          TextButton.icon(
            onPressed: () => Navigator.of(context)
                .push(MaterialPageRoute<void>(builder: (_) => EditionSeanceScreen(notes: notes, seance: s))),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: Text(k('modifier')),
          ),
          FilledButton.icon(
            key: const ValueKey('copier_seance'),
            onPressed: () => ouvrirWhatsApp(
              context,
              texte: s.whatsapp,
              recreer: () => whatsappSeance(s, notes.modeles.prochaineSeance),
              enregistrer: (texte) => notes.enregistrerSeance(ProchaineSeance.depuisJson({
                ...s.versJson(),
                'whatsapp': texte,
              })),
            ),
            icon: const Icon(Icons.chat_rounded, size: 18),
            label: Text(k('copier_whatsapp')),
          ),
        ]),
      ]),
    );
  }

  Widget _cadre(DestinyCouleurs d, Widget enfant) => Container(
        key: const ValueKey('carte_seance'),
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
        decoration: BoxDecoration(
          color: d.carte,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: d.or, width: 1.2),
        ),
        child: enfant,
      );
}

String _majuscule(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

class _LigneFil extends StatelessWidget {
  const _LigneFil({required this.resume, required this.onTap});

  final ResumeNote resume;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final d = context.destiny;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: d.carte,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: d.filet)),
        child: InkWell(
          key: ValueKey('note_${resume.id}'),
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${dateCourte(resume.date)}/${resume.date.length >= 4 ? resume.date.substring(0, 4) : ''} · ${resume.type.libelle}',
                  style: TextStyle(fontFamily: kPoliceTexte, fontSize: 12, fontWeight: FontWeight.w700, color: d.titre)),
              const SizedBox(height: 2),
              Text(resume.titre,
                  style: TextStyle(fontFamily: kPoliceTexte, fontSize: 15, fontWeight: FontWeight.w700, color: d.texte)),
              if (resume.resume.isNotEmpty)
                Text(resume.resume,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontFamily: kPoliceTexte, fontSize: 13, color: d.texteSecondaire, height: 1.3)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Du markdown, aux couleurs de l'appli.
class TexteMarkdown extends StatelessWidget {
  const TexteMarkdown(this.texte, {super.key});

  final String texte;

  @override
  Widget build(BuildContext context) {
    final d = context.destiny;
    final base = TextStyle(fontFamily: kPoliceTexte, fontSize: 14.5, height: 1.45, color: d.texte);
    return MarkdownBody(
      data: texte,
      selectable: true,
      styleSheet: MarkdownStyleSheet(
        p: base,
        listBullet: base,
        strong: base.copyWith(fontWeight: FontWeight.w700),
        em: base.copyWith(fontStyle: FontStyle.italic),
        h1: TextStyle(fontFamily: kPoliceTitres, fontSize: 20, fontWeight: FontWeight.w700, color: d.titre),
        h2: TextStyle(fontFamily: kPoliceTitres, fontSize: 17, fontWeight: FontWeight.w700, color: d.titre),
        h3: TextStyle(fontFamily: kPoliceTexte, fontSize: 15, fontWeight: FontWeight.w700, color: d.titre),
        code: base.copyWith(fontFamily: 'monospace', fontSize: 13, backgroundColor: d.filet),
        blockquote: base.copyWith(color: d.texteSecondaire),
        blockquoteDecoration: BoxDecoration(border: Border(left: BorderSide(color: d.or, width: 3))),
      ),
    );
  }
}

/// Un texte markdown en pleine page (les règles en vigueur).
class PageMarkdown extends StatelessWidget {
  const PageMarkdown({required this.titre, required this.texte, this.pied = '', super.key});

  final String titre;
  final String texte;
  final String pied;

  @override
  Widget build(BuildContext context) => PageDestiny(titre: titre, enfants: [
        TexteMarkdown(texte),
        if (pied.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(pied, style: Theme.of(context).textTheme.bodySmall),
          ),
      ]);
}

/// Le journal des décisions, de la plus ancienne à la plus récente ; une
/// décision remplacée reste, avec ce qui l'a remplacée.
class JournalScreen extends StatelessWidget {
  const JournalScreen({required this.journal, super.key});

  final JournalDecisions journal;

  @override
  Widget build(BuildContext context) {
    final t = context.textes;
    final d = context.destiny;
    return PageDestiny(titre: t.t('notes.journal'), enfants: [
      for (final x in journal.decisions)
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(x.date,
                style: TextStyle(fontFamily: kPoliceTexte, fontSize: 12, fontWeight: FontWeight.w700, color: d.titre)),
            Text(x.titre,
                style: TextStyle(
                  fontFamily: kPoliceTexte,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: x.enVigueur ? d.texte : d.texteSecondaire,
                  decoration: x.enVigueur ? null : TextDecoration.lineThrough,
                )),
            if (x.texte.isNotEmpty) TexteMarkdown(x.texte),
            if (!x.enVigueur)
              Text(t.t('notes.remplacee', {'date': x.remplaceeLe, 'par': x.remplaceePar}),
                  style: TextStyle(fontFamily: kPoliceTexte, fontSize: 12.5, fontStyle: FontStyle.italic, color: d.titre)),
          ]),
        ),
    ]);
  }
}

/// Le détail d'une note : le compte rendu, puis la copie WhatsApp et la
/// modification.
class EntreeScreen extends StatefulWidget {
  const EntreeScreen({required this.notes, required this.resume, super.key});

  final NotesController notes;
  final ResumeNote resume;

  @override
  State<EntreeScreen> createState() => _EntreeScreenState();
}

class _EntreeScreenState extends State<EntreeScreen> {
  late Future<EntreeNote?> _entree = widget.notes.entree(widget.resume);

  @override
  Widget build(BuildContext context) {
    final t = context.textes;
    final d = context.destiny;
    String k(String x, [Map<String, String> v = const {}]) => t.t('notes.$x', v);
    return FutureBuilder<EntreeNote?>(
      future: _entree,
      builder: (context, snap) {
        final e = snap.data;
        return PageDestiny(
          titre: widget.resume.titre,
          enfants: [
            if (snap.connectionState != ConnectionState.done) const LinearProgressIndicator(),
            if (e != null) ...[
              Text('${jourEtDate(e.date)} · ${e.type.libelle}',
                  style: TextStyle(fontFamily: kPoliceTexte, fontSize: 13, fontWeight: FontWeight.w700, color: d.titre)),
              if (e.personnes.isNotEmpty)
                Text(e.personnes.join(', '), style: TextStyle(fontFamily: kPoliceTexte, fontSize: 13, color: d.texteSecondaire)),
              const SizedBox(height: 12),
              TexteMarkdown(e.contenuMd.isEmpty ? e.resume : e.contenuMd),
              const SizedBox(height: 16),
              Wrap(spacing: 8, runSpacing: 6, children: [
                FilledButton.icon(
                  key: const ValueKey('copier_entree'),
                  onPressed: () => ouvrirWhatsApp(
                    context,
                    texte: e.whatsapp,
                    recreer: () => whatsappCompteRendu(e, widget.notes.modeles.compteRenduPour(e.type), suivante: widget.notes.seance),
                    enregistrer: (texte) => widget.notes.enregistrerEntree(e.copie(whatsapp: texte, jour: widget.notes.aujourdhui)),
                  ),
                  icon: const Icon(Icons.chat_rounded, size: 18),
                  label: Text(k('copier_whatsapp')),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('modifier_entree'),
                  onPressed: () async {
                    await Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => EditionEntreeScreen(notes: widget.notes, entree: e)));
                    if (mounted) setState(() => _entree = widget.notes.entree(widget.resume));
                  },
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: Text(k('modifier')),
                ),
              ]),
              const SizedBox(height: 12),
              Text(
                [k('cree_le', {'date': e.creeLe}), if (e.misAJourLe != e.creeLe) k('mis_a_jour', {'date': e.misAJourLe})]
                    .join(' · '),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        );
      },
    );
  }
}

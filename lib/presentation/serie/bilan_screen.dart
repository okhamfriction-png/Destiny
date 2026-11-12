import 'package:flutter/material.dart';

import '../../application/assistant/campagne_assistant.dart';
import '../../application/state/serie_store.dart';
import '../../domain/serie/serie.dart';
import '../destiny/donnees.dart';
import '../destiny/page.dart';
import '../theme/destiny_theme.dart';
import 'composants_serie.dart';
import 'contexte_serie.dart';
import 'fiche_serie_screen.dart';
import 'sante_serie.dart';

/// Le bilan d'un épisode, simple : le compte rendu de l'IA (écrit depuis la
/// transcription, ou depuis la trame de l'épisode et vos mots), le cœur et le
/// cerveau de chacun à la fin, qui est tombé, et, en fin de saison, ce que le
/// méchant laisse. « Ranger l'épisode » le passe dans la série.
class BilanEpisodeScreen extends StatefulWidget {
  const BilanEpisodeScreen({super.key, required this.contexte, required this.serie, required this.episode});

  final ContexteSerie contexte;
  final Serie serie;
  final EpisodeSerie episode;

  @override
  State<BilanEpisodeScreen> createState() => _BilanEpisodeScreenState();
}

class _BilanEpisodeScreenState extends State<BilanEpisodeScreen> {
  final Map<String, TextEditingController> _champs = {};

  Serie get s => widget.serie;
  EpisodeSerie get e => widget.episode;
  SaisonSerie? get _saison => s.saison(e.saison);
  bool get _finDeSaison => e.saison > 0 && e.numero >= 4;
  bool get _dejaRange => e.etape == EtapeEpisode.termine;

  @override
  void initState() {
    super.initState();
    if (!_dejaRange && !e.ancienneGrammaire) widget.contexte.audio.playShine();
  }

  @override
  void dispose() {
    for (final c in _champs.values) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _champ(String cle, String valeur) => _champs[cle] ??= TextEditingController(text: valeur);

  Future<void> _sauver() => widget.contexte.store.enregistrer(s);

  void _entree(CategorieRegistre categorie, String nom, {String detail = '', StatutRegistre statut = StatutRegistre.present}) {
    if (!s.reglages.registre || nom.trim().isEmpty) return;
    s.registre.add(EntreeRegistre(
      id: widget.contexte.store.nouvelId('r'),
      categorie: categorie,
      nom: nom.trim(),
      detail: detail.trim(),
      statut: statut,
      saison: e.saison,
      episode: e.numero,
    ));
  }

  /// Range l'épisode : les morts quittent la série, les figurants, les
  /// sbires et le méchant hors jeu ne reviendront pas (une seule fois).
  Future<void> _ranger() async {
    if (!_dejaRange) {
      final sorti = s.kids ? StatutRegistre.parti : StatutRegistre.tombe;
      for (final r in e.roles) {
        final p = s.personnage(r.personnageId);
        if (p != null && r.sante == Sante.sorti) p.sorti = true;
      }
      for (final p in e.pnjs) {
        if (p.sante == Sante.sorti) {
          if (!s.pnjSortis.contains(p.id)) s.pnjSortis.add(p.id);
          _entree(p.duMechant ? CategorieRegistre.sbire : CategorieRegistre.figurant, p.nom, statut: sorti);
        }
      }
      if (e.mechantSante == Sante.sorti && e.mechantId.isNotEmpty) {
        if (!s.pnjSortis.contains(e.mechantId)) s.pnjSortis.add(e.mechantId);
        final m = widget.contexte.mechant(context.grammaire, e.mechantId);
        if (m != null) _entree(s.kids ? CategorieRegistre.heritage : CategorieRegistre.mort, m.nom, statut: sorti);
      }
      if (_finDeSaison && _saison != null) {
        _saison!.terminee = true;
        if (_saison!.ceQuIlLaisse.isNotEmpty) _entree(CategorieRegistre.heritage, _saison!.ceQuIlLaisse);
      }
      e.etape = EtapeEpisode.termine;
    }
    await _sauver();
    if (mounted) revenirALaFiche(context, widget.contexte, s);
  }

  /// La trame de l'épisode, pour l'IA quand il n'y a pas de transcription :
  /// le lieu, le danger et ses paliers, le méchant, ce que sont devenus les
  /// personnages, et ce que le maître du jeu en a noté. Jamais de prénom de
  /// joueur : le nom du personnage, sinon son archétype.
  String _trame() {
    final g = context.grammaire;
    final t = context.textes;
    String nom(PersonnageSerie p) =>
        p.nomSansPrenom.isNotEmpty ? p.nomSansPrenom : (g.archetype(p.archetypeId)?.nom ?? t.t('serie.bilan.un_personnage'));
    final mechant = widget.contexte.mechant(g, e.mechantId);
    final lignes = [
      t.t('serie.bilan.trame.lieu', {'lieu': e.lieuNom, 'danger': e.dangerNom}),
      for (final (i, x) in e.paliers.indexed)
        if (i < e.palierAtteint) t.t('serie.bilan.trame.palier', {'n': '${i + 1}', 'texte': x}),
      if (e.presage.isNotEmpty) t.t('serie.bilan.trame.presage', {'texte': e.presage}),
      if (mechant != null)
        t.t(e.mechantSante == Sante.sorti ? 'serie.bilan.trame.mechant_vaincu' : 'serie.bilan.trame.mechant',
            {'nom': mechant.nom}),
      for (final r in e.roles)
        if (s.personnage(r.personnageId) case final p?)
          t.t('serie.bilan.trame.personnage', {
            'nom': nom(p),
            'archetype': g.archetype(p.archetypeId)?.nom ?? '',
            'coeur': libelleSante(context, r.sante, kids: s.kids).toLowerCase(),
            'esprit': libelleEsprit(context, r.esprit, kids: s.kids).toLowerCase(),
          }),
      for (final p in e.pnjs)
        if (p.sante == Sante.sorti) t.t('serie.bilan.trame.hors_jeu', {'nom': p.nom}),
      if (e.notesMj.trim().isNotEmpty) t.t('serie.bilan.trame.notes', {'texte': e.notesMj.trim()}),
    ];
    return lignes.join('\n');
  }

  Future<void> _resumer() async {
    final t = context.textes;
    if (!widget.contexte.store.iaConfiguree) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.t('serie.resume.ia_absente'))));
      return;
    }
    final texte = e.transcription.trim().isNotEmpty
        ? [e.transcription.trim(), if (e.notesMj.trim().isNotEmpty) e.notesMj.trim()].join('\n\n')
        : _trame();
    final m = await Navigator.of(context).push<MemoireEpisode>(MaterialPageRoute(
      builder: (_) => DemandeResumeScreen(contexte: widget.contexte, serie: s, episode: e, texte: texte),
    ));
    if (m == null || !mounted) return;
    setState(() => widget.contexte.store.integrerMemoire(s, e, m));
    await _sauver();
  }

  @override
  Widget build(BuildContext context) {
    final g = context.grammaire;
    final t = context.textes;
    final c = context.destiny;
    String k(String x, [Map<String, String> v = const {}]) => t.t('serie.bilan.$x', v);
    final sortis = [
      for (final r in e.roles)
        if (r.sante == Sante.sorti) s.personnage(r.personnageId)?.appel ?? '',
      for (final p in e.pnjs)
        if (p.sante == Sante.sorti) p.nom,
      if (e.mechantSante == Sante.sorti) widget.contexte.mechant(g, e.mechantId)?.nom ?? '',
      ...e.mortsAnciens,
    ].where((x) => x.isNotEmpty).toList();
    final iaPrete = widget.contexte.store.iaConfiguree;

    return PageDestiny(
      titre: _dejaRange ? '${t.t('serie.episode_n', {'n': '${e.numero}'})} · ${e.intitule}' : k('titre'),
      enfants: [
        if (!_dejaRange) Text(e.intitule, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
        if (_finDeSaison) Paragraphe(k('fin_saison', {'n': '${e.saison}'}), gras: true),
        if (e.ancienneGrammaire) Paragraphe(t.t('serie.ancienne_aide'), italique: true),
        // Le compte rendu de l'épisode, par l'IA.
        if (!e.ancienneGrammaire)
          SectionDestiny(titre: k('compte_rendu'), enfants: [
            if (e.resume.isNotEmpty) ...[
              Paragraphe(e.resume),
              if (e.suite.isNotEmpty) LigneInfo(t.t('serie.resume.suite'), e.suite),
              const SizedBox(height: 8),
            ] else
              Text(e.transcription.trim().isEmpty ? k('compte_rendu_aide') : k('compte_rendu_transcription'),
                  style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 6),
            TextField(
              key: const ValueKey('notes_mj'),
              controller: _champ('notes', e.notesMj),
              maxLines: 4,
              minLines: 2,
              decoration: InputDecoration(labelText: k('notes_mj'), helperText: k('notes_mj_aide'), helperMaxLines: 2),
              onChanged: (v) {
                e.notesMj = v;
                _sauver();
              },
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              key: const ValueKey('compte_rendu_ia'),
              style: FilledButton.styleFrom(backgroundColor: DestinyCouleurs.ia, foregroundColor: Colors.white),
              onPressed: _resumer,
              icon: const Icon(Icons.auto_awesome),
              label: Text(e.resume.isEmpty ? k('resumer') : k('reresumer')),
            ),
            if (!iaPrete) Text(t.t('serie.resume.ia_absente'), style: Theme.of(context).textTheme.bodySmall),
          ]),
        if (e.roles.isNotEmpty)
          SectionDestiny(titre: k('personnages'), enfants: [for (final r in e.roles) _role(r)]),
        if (sortis.isNotEmpty)
          SectionDestiny(titre: s.kids ? k('sortis_kids') : k('sortis'), enfants: [
            Text(k('sortis_aide'), style: Theme.of(context).textTheme.bodySmall),
            for (final x in sortis) Puce(x),
          ]),
        if (e.blessesAnciens.isNotEmpty)
          SectionDestiny(titre: k('blesses_anciens'), enfants: [for (final x in e.blessesAnciens) Puce(x)]),
        if (_finDeSaison && _saison != null)
          SectionDestiny(titre: k('heritage'), enfants: [
            TextField(
              controller: _champ('heritage', _saison!.ceQuIlLaisse),
              maxLines: 2,
              minLines: 1,
              decoration: InputDecoration(helperText: k('heritage_aide'), helperMaxLines: 2),
              onChanged: (v) {
                _saison!.ceQuIlLaisse = v.trim();
                _sauver();
              },
            ),
          ]),
        if (e.transcription.trim().isNotEmpty)
          SectionDestiny(titre: k('transcription'), enfants: [
            Text(
              e.transcription.length > 400 ? '${e.transcription.substring(0, 400)}…' : e.transcription,
              style: TextStyle(fontFamily: kPoliceTexte, color: c.texteSecondaire, height: 1.4),
            ),
            Text(k('transcription_aide'), style: Theme.of(context).textTheme.bodySmall),
          ]),
        const SizedBox(height: 18),
        FilledButton.icon(
          key: const ValueKey('ranger_episode'),
          onPressed: _ranger,
          icon: const Icon(Icons.inventory_2_outlined),
          label: Text(_dejaRange ? t.t('serie.enregistrer') : k('terminer')),
        ),
      ],
    );
  }

  /// Ce qu'un personnage est devenu : son cœur et son cerveau (on peut encore
  /// les corriger avant de ranger l'épisode).
  Widget _role(RoleEpisode r) {
    final g = context.grammaire;
    final c = context.destiny;
    final p = s.personnage(r.personnageId);
    if (p == null) return const SizedBox.shrink();
    final arch = g.archetype(p.archetypeId);
    return CadreLisere(
      couleur: arch == null ? c.or : c.famille(arch.famille),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text([p.appel, arch?.nom ?? ''].where((x) => x.isNotEmpty).join(' · '),
            style: TextStyle(fontFamily: kPoliceTitres, fontWeight: FontWeight.w700, color: c.texte)),
        const SizedBox(height: 6),
        PistesSante(
          cle: p.id,
          sante: r.sante,
          esprit: r.esprit,
          kids: s.kids,
          onSante: _dejaRange
              ? null
              : (v) {
                  setState(() => r.sante = v);
                  _sauver();
                },
          onEsprit: _dejaRange
              ? null
              : (v) {
                  setState(() => r.esprit = v);
                  _sauver();
                },
        ),
      ]),
    );
  }
}

/// La demande de résumé : la SEULE fois où des paroles quittent l'appareil.
/// Le maître du jeu voit le texte exact qui partira (prénoms déjà remplacés
/// par les rôles), peut le corriger, et voit le résultat avant de l'accepter.
class DemandeResumeScreen extends StatefulWidget {
  const DemandeResumeScreen(
      {super.key, required this.contexte, required this.serie, required this.episode, this.texte});

  final ContexteSerie contexte;
  final Serie serie;
  final EpisodeSerie episode;

  /// Le texte à résumer (sinon la transcription de l'épisode).
  final String? texte;

  @override
  State<DemandeResumeScreen> createState() => _DemandeResumeScreenState();
}

class _DemandeResumeScreenState extends State<DemandeResumeScreen> {
  late final TextEditingController _texte = TextEditingController(
    text: sansPrenoms(widget.texte ?? widget.episode.transcription, SerieStore.rolesParPrenom(widget.serie)),
  );
  bool _charge = false;
  String _erreur = '';
  MemoireEpisode? _resultat;

  @override
  void dispose() {
    _texte.dispose();
    super.dispose();
  }

  Future<void> _demander() async {
    setState(() {
      _charge = true;
      _erreur = '';
    });
    try {
      final m = await widget.contexte.store.resumer(
        widget.serie,
        transcription: _texte.text,
        categories: [
          for (final c in CategorieRegistre.actives)
            if (!widget.serie.kids || c != CategorieRegistre.mort) c.name,
        ],
      );
      if (mounted) setState(() => _resultat = m);
    } catch (e) {
      if (mounted) setState(() => _erreur = context.textes.t('serie.resume.echec', {'erreur': '$e'}));
    } finally {
      if (mounted) setState(() => _charge = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.textes;
    final c = context.destiny;
    String k(String x) => t.t('serie.resume.$x');
    final r = _resultat;
    return PageDestiny(
      titre: k('titre'),
      enfants: [
        Paragraphe(k('aide')),
        TextField(controller: _texte, maxLines: 10, minLines: 4),
        const SizedBox(height: 12),
        if (_erreur.isNotEmpty) Paragraphe(_erreur),
        if (r == null)
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: DestinyCouleurs.ia, foregroundColor: Colors.white),
            onPressed: _charge ? null : _demander,
            icon: _charge
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.auto_awesome),
            label: Text(_charge ? k('en_cours') : k('demander')),
          )
        else ...[
          SectionDestiny(titre: k('resume'), enfants: [Paragraphe(r.resume)]),
          if (r.suite.isNotEmpty) SectionDestiny(titre: k('suite'), enfants: [Paragraphe(r.suite)]),
          if (r.registre.isNotEmpty)
            SectionDestiny(titre: k('registre'), enfants: [
              for (final n in r.registre)
                LigneInfo(
                  t.t('serie.registre.categories.${CategorieRegistre.depuisTexte(n.categorie).name}'),
                  [n.nom, n.detail].where((x) => x.isNotEmpty).join(' — '),
                ),
            ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => setState(() => _resultat = null), child: Text(k('redemander')))),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: c.titre),
                onPressed: () => Navigator.of(context).pop(r),
                child: Text(k('accepter')),
              ),
            ),
          ]),
        ],
      ],
    );
  }
}

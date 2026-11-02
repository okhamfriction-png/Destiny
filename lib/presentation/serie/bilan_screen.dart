import 'package:flutter/material.dart';

import '../../application/assistant/campagne_assistant.dart';
import '../../application/state/serie_store.dart';
import '../../domain/grammaire/distribution.dart';
import '../../domain/serie/pbta.dart';
import '../../domain/serie/serie.dart';
import '../destiny/donnees.dart';
import '../destiny/page.dart';
import '../theme/destiny_theme.dart';
import 'composants_serie.dart';
import 'contexte_serie.dart';
import 'fiche_serie_screen.dart';
import 'registre_screen.dart';

/// Le bilan d'un épisode : ce que chacun a vécu (son choix, le prix payé, son
/// besoin, ses blessures, et s'il quitte l'histoire), qui est passé au
/// service du méchant, le traître, la sortie vers le lieu suivant, ce qui a
/// marché, et le registre.
/// En fin de saison : ce que le méchant laisse, et le changement d'archétype
/// de ceux qui ont payé leur besoin.
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

  /// Range l'épisode : la continuité, les bascules, le traître, l'héritage et
  /// la sortie passent dans la série et dans son registre (une seule fois).
  Future<void> _ranger() async {
    if (!_dejaRange) {
      final sorti = s.kids ? StatutRegistre.parti : StatutRegistre.tombe;
      for (final r in e.roles) {
        final p = s.personnage(r.personnageId);
        if (p == null) continue;
        if (r.sante == Sante.sorti) p.sorti = true;
        if (r.choix == ChoixFinal.besoin && (_finDeSaison || e.saison == 0)) p.besoinPaye = true;
      }
      for (final p in e.pnjs) {
        if (p.sante == Sante.sorti) {
          if (!s.pnjSortis.contains(p.id)) s.pnjSortis.add(p.id);
          _entree(p.duMechant ? CategorieRegistre.sbire : CategorieRegistre.figurant, p.nom, statut: sorti);
        }
        if (p.aBascule) {
          _entree(CategorieRegistre.bascule, p.nom, detail: p.veut, statut: StatutRegistre.retourne);
        }
      }
      if (e.mechantSante == Sante.sorti && e.mechantId.isNotEmpty) {
        if (!s.pnjSortis.contains(e.mechantId)) s.pnjSortis.add(e.mechantId);
        final m = widget.contexte.mechant(context.grammaire, e.mechantId);
        if (m != null) _entree(s.kids ? CategorieRegistre.heritage : CategorieRegistre.mort, m.nom, statut: sorti);
      }
      final traitre = _saison?.traitre;
      if (traitre != null && traitre.revele && e.numero == 3 && traitre.accepte == true) {
        final m = widget.contexte.mechant(context.grammaire, _saison!.mechantId);
        final p = s.personnage(traitre.personnageId);
        // Le registre ne garde jamais un prénom de joueur : le nom du
        // personnage, sinon son archétype.
        final nom = p == null
            ? ''
            : (p.nomSansPrenom.isNotEmpty ? p.nomSansPrenom : context.grammaire.archetype(p.archetypeId)?.nom ?? '');
        _entree(CategorieRegistre.traitre, nom, detail: m?.offreAuTraitre ?? '');
      }
      if (e.sortie.isNotEmpty) _entree(CategorieRegistre.lieu, e.lieuNom, detail: e.sortie);
      if (_finDeSaison && _saison != null) {
        _saison!.terminee = true;
        if (_saison!.ceQuIlLaisse.isNotEmpty) _entree(CategorieRegistre.heritage, _saison!.ceQuIlLaisse);
      }
      e.etape = EtapeEpisode.termine;
    }
    await _sauver();
    if (mounted) revenirALaFiche(context, widget.contexte, s);
  }

  Future<void> _resumer() async {
    final t = context.textes;
    if (!widget.contexte.store.iaConfiguree) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(t.t('serie.resume.ia_absente'))));
      return;
    }
    final m = await Navigator.of(context).push<MemoireEpisode>(MaterialPageRoute(
      builder: (_) => DemandeResumeScreen(contexte: widget.contexte, serie: s, episode: e),
    ));
    if (m == null || !mounted) return;
    setState(() => widget.contexte.store.integrerMemoire(s, e, m));
    await _sauver();
  }

  Future<void> _ajouterAuRegistre() async {
    final r = await editerEntree(context,
        serie: s, id: widget.contexte.store.nouvelId('r'), saison: e.saison, episode: e.numero);
    if (r == null) return;
    setState(() => s.registre.add(r));
    await _sauver();
  }

  Future<void> _changerArchetype(PersonnageSerie p) async {
    final id = await choisirArchetype(context);
    if (id == null || id == p.archetypeId || !mounted) return;
    setState(() {
      p
        ..anciensArchetypes.add(p.archetypeId)
        ..archetypeId = id
        ..animalId = tirerAnimal(context.grammaire, id);
    });
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
    final bascules = [for (final p in e.pnjs) if (p.aBascule) p.nom];
    final traitre = _saison?.traitre;
    final nesIci = [for (final r in s.registre) if (r.saison == e.saison && r.episode == e.numero) r];

    return PageDestiny(
      titre: _dejaRange ? '${t.t('serie.episode_n', {'n': '${e.numero}'})} · ${e.intitule}' : k('titre'),
      enfants: [
        if (!_dejaRange) Text(e.intitule, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
        if (_finDeSaison) Paragraphe(k('fin_saison', {'n': '${e.saison}'}), gras: true),
        if (e.ancienneGrammaire) Paragraphe(t.t('serie.ancienne_aide'), italique: true),
        if (e.roles.isNotEmpty)
          SectionDestiny(titre: k('personnages'), enfants: [for (final r in e.roles) _role(r)]),
        if (sortis.isNotEmpty)
          SectionDestiny(titre: s.kids ? k('sortis_kids') : k('sortis'), enfants: [
            Text(k('sortis_aide'), style: Theme.of(context).textTheme.bodySmall),
            for (final x in sortis) Puce(x),
          ]),
        if (e.blessesAnciens.isNotEmpty)
          SectionDestiny(titre: k('blesses_anciens'), enfants: [for (final x in e.blessesAnciens) Puce(x)]),
        if (bascules.isNotEmpty) SectionDestiny(titre: k('bascules'), enfants: [for (final x in bascules) Puce(x)]),
        if (traitre != null && traitre.accepte != null && e.numero >= 3)
          SectionDestiny(titre: k('traitre'), enfants: [
            Paragraphe(t.t(traitre.accepte == true ? 'serie.traitre.revele_oui' : 'serie.traitre.revele_non', {
              'nom': s.personnage(traitre.personnageId)?.appel ?? '',
            })),
            if (!traitre.revele && e.numero == 3)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(t.t('serie.traitre.marquer_revele')),
                value: traitre.revele,
                onChanged: (v) {
                  setState(() => traitre.revele = v ?? false);
                  _sauver();
                },
              ),
          ]),
        if (!e.ancienneGrammaire)
          SectionDestiny(titre: k('sortie'), enfants: [
            TextField(
              controller: _champ('sortie', e.sortie),
              maxLines: 2,
              minLines: 1,
              decoration: InputDecoration(helperText: k('sortie_aide'), helperMaxLines: 2),
              onChanged: (v) {
                e.sortie = v.trim();
                _sauver();
              },
            ),
          ]),
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
        SectionDestiny(titre: k('ce_qui_a_marche'), enfants: [
          TextField(
            controller: _champ('marche', e.ceQuiAMarche),
            maxLines: 3,
            minLines: 1,
            onChanged: (v) {
              e.ceQuiAMarche = v.trim();
              _sauver();
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _champ('phrase', e.phrase),
            decoration: InputDecoration(labelText: k('phrase')),
            onChanged: (v) {
              e.phrase = v.trim();
              _sauver();
            },
          ),
        ]),
        if (e.resume.isNotEmpty || e.suite.isNotEmpty)
          SectionDestiny(titre: t.t('serie.resume.titre'), enfants: [
            Paragraphe(e.resume),
            if (e.suite.isNotEmpty) LigneInfo(t.t('serie.resume.suite'), e.suite),
          ]),
        if (s.reglages.registre)
          SectionDestiny(titre: k('registre'), enfants: [
            for (final r in nesIci) LigneRegistre(entree: r, kids: s.kids),
            OutlinedButton.icon(
              onPressed: _ajouterAuRegistre,
              icon: const Icon(Icons.add_rounded),
              label: Text(k('registre_ajouter')),
            ),
          ]),
        if (e.transcription.trim().isNotEmpty)
          SectionDestiny(titre: k('transcription'), enfants: [
            Text(
              e.transcription.length > 400 ? '${e.transcription.substring(0, 400)}…' : e.transcription,
              style: TextStyle(fontFamily: kPoliceTexte, color: c.texteSecondaire, height: 1.4),
            ),
            Text(k('transcription_aide'), style: Theme.of(context).textTheme.bodySmall),
            if (!e.ancienneGrammaire) ...[
              const SizedBox(height: 10),
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: DestinyCouleurs.ia, foregroundColor: Colors.white),
                onPressed: _resumer,
                icon: const Icon(Icons.auto_awesome),
                label: Text(k('resumer')),
              ),
            ],
          ]),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: _ranger,
          icon: const Icon(Icons.inventory_2_outlined),
          label: Text(_dejaRange ? t.t('serie.enregistrer') : k('terminer')),
        ),
      ],
    );
  }

  Widget _role(RoleEpisode r) {
    final g = context.grammaire;
    final t = context.textes;
    final c = context.destiny;
    String k(String x) => t.t('serie.bilan.$x');
    final p = s.personnage(r.personnageId);
    if (p == null) return const SizedBox.shrink();
    final arch = g.archetype(p.archetypeId);
    final blessure = ReglesPbta.depuis(t).etatBlessure(r.blessures, kids: s.kids);
    return CadreLisere(
      couleur: arch == null ? c.or : c.famille(arch.famille),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text([p.appel, arch?.nom ?? ''].where((x) => x.isNotEmpty).join(' · '),
            style: TextStyle(fontFamily: kPoliceTitres, fontWeight: FontWeight.w700, color: c.texte)),
        LigneInfo(t.t('serie.jeu.veut'), r.vouloir),
        LigneInfo(t.t('serie.jeu.besoin'), p.besoin),
        LigneInfo(t.t('pbta.blessures.titre'), blessure),
        const SizedBox(height: 6),
        Text(k('choix'), style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        Wrap(spacing: 8, runSpacing: 6, children: [
          for (final (choix, libelle) in [
            (ChoixFinal.aucun, k('choix_aucun')),
            (ChoixFinal.vouloir, t.t('debrief.choix_vouloir')),
            (ChoixFinal.besoin, t.t('debrief.choix_besoin')),
          ])
            ChoiceChip(
              label: Text(libelle),
              selected: r.choix == choix,
              onSelected: (_) {
                setState(() => r.choix = choix);
                _sauver();
              },
            ),
        ]),
        const SizedBox(height: 8),
        TextField(
          controller: _champ('prix.${p.id}', r.prixPaye),
          decoration: InputDecoration(labelText: k('prix'), isDense: true),
          onChanged: (v) {
            r.prixPaye = v.trim();
            _sauver();
          },
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(k('besoin_nomme')),
          value: p.besoinNomme,
          onChanged: (v) {
            setState(() => p.besoinNomme = v ?? false);
            _sauver();
          },
        ),
        if (!_dejaRange && !e.ancienneGrammaire)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(s.kids ? k('quitte_kids') : k('quitte')),
            subtitle: r.horsJeu ? Text(k('quitte_aide')) : null,
            value: r.sante == Sante.sorti,
            onChanged: (v) {
              setState(() => r.sante = v == true ? Sante.sorti : Sante.enForme);
              _sauver();
            },
          ),
        if (_finDeSaison && r.choix == ChoixFinal.besoin && !p.pnj && widget.contexte.reglages.evolutionArchetype) ...[
          Paragraphe(k('changer_archetype'), italique: true),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(onPressed: () => _changerArchetype(p), child: Text(k('nouvel_archetype'))),
          ),
        ],
      ]),
    );
  }
}

/// La demande de résumé : la SEULE fois où des paroles quittent l'appareil.
/// Le maître du jeu voit le texte exact qui partira (prénoms déjà remplacés
/// par les rôles), peut le corriger, et voit le résultat avant de l'accepter.
class DemandeResumeScreen extends StatefulWidget {
  const DemandeResumeScreen({super.key, required this.contexte, required this.serie, required this.episode});

  final ContexteSerie contexte;
  final Serie serie;
  final EpisodeSerie episode;

  @override
  State<DemandeResumeScreen> createState() => _DemandeResumeScreenState();
}

class _DemandeResumeScreenState extends State<DemandeResumeScreen> {
  late final TextEditingController _texte = TextEditingController(
    text: sansPrenoms(widget.episode.transcription, SerieStore.rolesParPrenom(widget.serie)),
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

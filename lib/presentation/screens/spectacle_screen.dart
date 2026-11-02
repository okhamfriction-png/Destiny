import 'package:flutter/material.dart';

import '../../application/state/spectacle_controller.dart';
import '../../domain/entities/spectacle_turn.dart';
import '../../domain/grammaire/modeles.dart';
import '../../domain/serie/univers.dart';
import '../destiny/composants.dart';
import '../destiny/donnees.dart';
import '../destiny/page.dart';
import '../jouer/univers_ia.dart';
import '../theme/destiny_theme.dart';
import 'spectacle_archives_screen.dart';

/// Une couleur d'accent rendue lisible comme texte : éclaircie en sombre,
/// assombrie en clair (contraste d'au moins 4,5).
Color _lisible(DestinyCouleurs d, Color accent) =>
    d.sombre ? Color.lerp(accent, Colors.white, 0.45)! : Color.lerp(accent, d.encre, 0.5)!;

/// Petit avatar emoji d'un animal (par son nom ou son id), ou null si inconnu.
Widget? _archEmoji(String nomOuId, {double size = 18}) {
  final emoji = emojiAnimal(nomOuId);
  if (emoji == null) return null;
  return Text(emoji, style: TextStyle(fontSize: size));
}

/// La couleur de famille d'un des quatre personnages (or s'il est inconnu).
Color _couleurPersonnage(BuildContext context, PersonnageSpectacle p) {
  final d = context.destiny;
  final a = context.grammaire.archetype(p.archetypeId);
  return a == null ? d.or : d.famille(a.famille);
}

/// Le spectacle avec l'IA : jeu d'impro long form en solo.
class SpectacleScreen extends StatefulWidget {
  const SpectacleScreen({required this.controller, this.univers = CatalogueUnivers.vide, super.key});

  final SpectacleController controller;

  /// Les univers de `univers.json`.
  final CatalogueUnivers univers;

  @override
  State<SpectacleScreen> createState() => _SpectacleScreenState();
}

class _SpectacleScreenState extends State<SpectacleScreen> {
  List<String> _universAdultes() => [for (final u in universPourIa(widget.univers, kids: false)) u.name];

  /// Les univers pour enfants qui ne sont pas déjà dans la liste adulte.
  List<String> _universEnfants() {
    final adultes = _universAdultes();
    return [
      for (final u in universPourIa(widget.univers, kids: true))
        if (!adultes.contains(u.name)) u.name,
    ];
  }

  Set<String> _valeursUnivers() => {..._universAdultes(), ..._universEnfants()};

  final _freeCtrl = TextEditingController();
  final _scroll = ScrollController();

  /// Raccourci vers les textes de l'écran.
  String k(String x, [Map<String, String> v = const {}]) => context.textes.t('spectacle_ia.$x', v);

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    _freeCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onChange() {
    if (!mounted) return;
    setState(() {});
    // Auto-scroll vers le bas quand le fil grandit.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return Scaffold(
      appBar: AppBar(
        title: Text(k('titre')),
        actions: [
          if (!c.started)
            IconButton(
              tooltip: k('historique'),
              icon: const Icon(Icons.history),
              onPressed: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => SpectacleArchivesScreen(controller: widget.controller))),
            ),
        ],
      ),
      body: SafeArea(top: false, child: c.started ? _buildGame(context, c) : _buildSetup(context, c)),
    );
  }

  // ------------------------------------------------------------------ SETUP
  Widget _buildSetup(BuildContext context, SpectacleController c) {
    final d = context.destiny;
    final theme = Theme.of(context);
    final draw = c.draw;
    final tons = [for (final x in tonsPourIa(context.textes)) x.name];
    final aide = TextStyle(fontFamily: kPoliceTexte, fontSize: 12.5, height: 1.35, color: d.texteSecondaire);
    final enfants = <Widget>[
      Paragraphe(k('intro')),
      if (c.canResume)
        ElementListe(
          titre: k('reprendre'),
          sousTitre: k('reprendre_texte'),
          couleur: d.titre,
          devant: Icon(Icons.play_circle_fill, color: d.titre),
          apres: IconButton(
            tooltip: k('oublier'),
            icon: const Icon(Icons.close),
            onPressed: c.discardSaved,
          ),
          onTap: c.resume,
        ),
      if (!c.configured) CadreLisere(couleur: DestinyCouleurs.ia, child: Text(k('sans_cle'), style: TextStyle(color: d.texte))),
      if (c.sessionIgnoree) CadreLisere(couleur: d.or, child: Text(k('ancienne'), style: TextStyle(color: d.texte))),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [Text(k('kids')), const SigleKids(petit: true)],
        ),
        subtitle: Text(k('kids_aide')),
        value: c.kids,
        onChanged: c.setKids,
      ),
      SectionDestiny(titre: k('sous_mode'), espace: 8, enfants: [
        SegmentedButton<SpectacleMode>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(value: SpectacleMode.classique, label: Text(k('classique'))),
            ButtonSegment(value: SpectacleMode.libre, label: Text(k('libre'))),
          ],
          selected: {c.mode},
          onSelectionChanged: (s) => c.setMode(s.first),
        ),
        const SizedBox(height: 6),
        Text(c.mode == SpectacleMode.classique ? k('classique_aide') : k('libre_aide'), style: aide),
      ]),
      SectionDestiny(titre: k('decor'), enfants: [
        // Univers et ton côte à côte.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _valeursUnivers().contains(c.universe) ? c.universe : null,
                isExpanded: true,
                decoration: InputDecoration(labelText: k('univers'), isDense: true),
                items: [
                  DropdownMenuItem(enabled: false, value: '__h_genres', child: Text(k('genres'))),
                  for (final u in _universAdultes()) DropdownMenuItem(value: u, child: Text(u)),
                  DropdownMenuItem(enabled: false, value: '__h_kids', child: Text(k('enfants'))),
                  for (final u in _universEnfants()) DropdownMenuItem(value: u, child: Text(u)),
                ],
                onChanged: (v) {
                  if (v == null || v.startsWith('__h')) return;
                  c.setUniverse(v);
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: tons.contains(c.tone) ? c.tone : null,
                isExpanded: true,
                decoration: InputDecoration(labelText: k('ton'), isDense: true),
                items: [for (final x in tons) DropdownMenuItem(value: x, child: Text(x))],
                onChanged: (v) {
                  if (v != null) c.setTone(v);
                },
              ),
            ),
          ],
        ),
      ]),
      SectionDestiny(titre: k('longueur'), enfants: [
        SegmentedButton<SceneLength>(
          showSelectedIcon: false,
          style: const ButtonStyle(
              visualDensity: VisualDensity.compact, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
          segments: [
            for (final l in SceneLength.values)
              ButtonSegment(value: l, label: Text(k(l.name, {'n': '${l.count}'}))),
          ],
          selected: {c.sceneLength},
          onSelectionChanged: (s) => c.setSceneLength(s.first),
        ),
        const SizedBox(height: 8),
        Text(k('explication', {'n': '${c.sceneTarget}'}), style: aide),
      ]),
      const SizedBox(height: 18),
      SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: () => c.drawDecor(),
          icon: const Icon(Icons.shuffle_rounded),
          label: Text(draw == null ? k('tirer') : k('retirer')),
        ),
      ),
      if (c.error != null)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(c.error!,
              style: TextStyle(color: _lisible(d, d.famille(FamilleId.fissure)), fontWeight: FontWeight.w600)),
        ),
      if (draw != null) ...[
        _DecorCard(draw: draw),
        SectionDestiny(titre: k('personnage_depart'), enfants: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < draw.archetypes.length; i++)
                ChoiceChip(
                  avatar: _archEmoji(draw.archetypes[i].animalId),
                  label: Text(draw.archetypes[i].name),
                  selected: c.playerIndex == i,
                  selectedColor: _couleurPersonnage(context, draw.archetypes[i]).withValues(alpha: d.sombre ? 0.35 : 0.2),
                  side: BorderSide(color: _couleurPersonnage(context, draw.archetypes[i])),
                  showCheckmark: false,
                  onSelected: (_) => c.setPlayerIndex(i),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (c.playerArchetype != null)
            Text(c.playerArchetype!.line,
                style: theme.textTheme.bodyMedium?.copyWith(color: d.titre, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: c.configured ? () => c.start() : null,
            icon: const Icon(Icons.theater_comedy),
            label: Text(k('lever')),
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
          ),
        ),
      ],
    ];
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        for (final e in enfants)
          Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 760), child: e)),
      ],
    );
  }

  // ------------------------------------------------------------------- GAME
  Widget _buildGame(BuildContext context, SpectacleController c) {
    final d = context.destiny;
    final turn = c.current;
    return Column(
      children: [
        _GameHeader(turn: turn, onQuit: () => _confirmQuit(context, c)),
        Expanded(
          child: ListView(
            controller: _scroll,
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            children: [
              if (turn?.isDestiny ?? false) const _DestinyBanner(),
              for (final item in c.log) _LogBubble(item: item),
              if (turn?.correction != null) _CorrectionCard(correction: turn!.correction!),
              if (turn?.crow != null) _CrowCard(crow: turn!.crow!),
              if (turn?.feedback != null) _FeedbackCard(child: _renderDynamic(context, turn!.feedback)),
              if (turn?.isFin ?? false) _DebriefCard(turn: turn!),
              if (c.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(c.error!,
                      style: TextStyle(color: _lisible(d, d.famille(FamilleId.fissure)), fontWeight: FontWeight.w600)),
                ),
            ],
          ),
        ),
        _ActionBar(
          controller: c,
          freeCtrl: _freeCtrl,
          onQuitToSetup: () => c.reset(),
        ),
      ],
    );
  }

  Future<void> _confirmQuit(BuildContext context, SpectacleController c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(k('jeu.quitter_titre')),
        content: Text(k('jeu.quitter_texte')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(k('jeu.continuer'))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(k('jeu.quitter_oui'))),
        ],
      ),
    );
    if (ok == true) c.reset();
  }
}

/// Rendu générique d'une valeur JSON (String / nombre / liste / objet).
Widget _renderDynamic(BuildContext context, Object? value) {
  final d = context.destiny;
  final corps = TextStyle(fontFamily: kPoliceTexte, fontSize: 14, height: 1.35, color: d.texte);
  if (value == null) return const SizedBox.shrink();
  if (value is String) return Text(value, style: corps);
  if (value is num || value is bool) return Text('$value', style: corps);
  if (value is List) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final e in value)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6, right: 8),
                  child: Text('◆', style: TextStyle(fontSize: 8, color: d.or)),
                ),
                Expanded(child: _renderDynamic(context, e)),
              ],
            ),
          ),
      ],
    );
  }
  if (value is Map) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in value.entries)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_pretty(context, entry.key.toString()),
                    style: TextStyle(
                        fontFamily: kPoliceTexte, fontSize: 12, fontWeight: FontWeight.w700, color: d.titre)),
                const SizedBox(height: 2),
                _renderDynamic(context, entry.value),
              ],
            ),
          ),
      ],
    );
  }
  return Text('$value', style: corps);
}

/// Le libellé d'une rubrique du débrief (clés de la réponse de l'IA).
String _pretty(BuildContext context, String key) {
  final libelle = context.textes.table('spectacle_ia.rubriques')[key];
  if (libelle is String && libelle.isNotEmpty) return libelle;
  return key.isEmpty ? key : '${key[0].toUpperCase()}${key.substring(1)}';
}

// ------------------------------------------------------------------ WIDGETS

class _DecorCard extends StatelessWidget {
  const _DecorCard({required this.draw});

  final SpectacleDraw draw;

  @override
  Widget build(BuildContext context) {
    final d = context.destiny;
    String k(String x, [Map<String, String> v = const {}]) => context.textes.t('spectacle_ia.$x', v);
    return SectionDestiny(titre: k('decor'), enfants: [
      CadreLisere(
        couleur: d.or,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LigneInfo(k('lieu'), draw.lieu),
            LigneInfo(k('danger'), draw.danger),
            LigneInfo(k('groupe'), draw.groupe),
            LigneInfo(k('espaces'), draw.espaces.join(', ')),
          ],
        ),
      ),
      if (draw.paliers.isNotEmpty)
        SectionDestiny(titre: k('paliers'), espace: 8, enfants: [
          FrisePaliers(textes: draw.paliers, compacte: true),
        ]),
      SectionDestiny(titre: k('personnages'), espace: 8, enfants: [
        for (final a in draw.archetypes)
          CadreLisere(
            couleur: _couleurPersonnage(context, a),
            marge: 8,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_archEmoji(a.animalId, size: 20) case final emoji?) ...[emoji, const SizedBox(width: 8)],
                Expanded(
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(
                        text: a.name,
                        style: TextStyle(fontFamily: kPoliceTexte, fontWeight: FontWeight.w700, color: d.texte),
                      ),
                      if (a.line.isNotEmpty) TextSpan(text: '\n${a.line}', style: TextStyle(color: d.texteSecondaire)),
                    ]),
                    style: const TextStyle(fontFamily: kPoliceTexte, fontSize: 13, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
      ]),
    ]);
  }
}

class _GameHeader extends StatelessWidget {
  const _GameHeader({required this.turn, required this.onQuit});

  final SpectacleTurn? turn;
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) {
    final d = context.destiny;
    String k(String x, [Map<String, String> v = const {}]) => context.textes.t('spectacle_ia.$x', v);
    final parts = <String>[
      if (turn?.acte != null) k('jeu.acte', {'n': '${turn!.acte}'}),
      if (turn?.scene != null) k('jeu.scene', {'n': '${turn!.scene}'}),
      if (turn?.palier != null) k('jeu.palier', {'n': '${turn!.palier}'}),
    ];
    final cible = turn?.cible;
    final posees = turn?.posees;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: d.filet))),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(parts.isEmpty ? k('jeu.spectacle') : parts.join(' · '),
                    style: TextStyle(fontFamily: kPoliceTexte, fontWeight: FontWeight.w700, fontSize: 16, color: d.titre)),
                if (posees != null && cible != null)
                  Text(k('jeu.repliques', {'posees': '$posees', 'cible': '$cible'}),
                      style: TextStyle(fontFamily: kPoliceTexte, fontSize: 12, color: d.texteSecondaire)),
              ],
            ),
          ),
          if (turn?.phase != null && turn!.phase.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: d.or.withValues(alpha: d.sombre ? 0.2 : 0.14),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: d.filet),
              ),
              child: Text(turn!.phase,
                  style: TextStyle(fontFamily: kPoliceTexte, fontSize: 11, fontWeight: FontWeight.w600, color: d.titre)),
            ),
          IconButton(
            tooltip: k('jeu.quitter'),
            icon: const Icon(Icons.close),
            onPressed: onQuit,
          ),
        ],
      ),
    );
  }
}

class _DestinyBanner extends StatelessWidget {
  const _DestinyBanner();

  @override
  Widget build(BuildContext context) {
    final d = context.destiny;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: d.bleuDestiny.withValues(alpha: d.sombre ? 0.22 : 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: d.bleuDestiny.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          Icon(Icons.flash_on_rounded, color: d.bleuTexte, size: 18),
          const SizedBox(width: 8),
          Text(context.textes.t('regie.destiny').toUpperCase(),
              style: TextStyle(
                  fontFamily: kPoliceTitres, color: d.bleuTexte, fontWeight: FontWeight.w900, letterSpacing: 2)),
        ],
      ),
    );
  }
}

class _LogBubble extends StatelessWidget {
  const _LogBubble({required this.item});

  final SpectacleLogItem item;

  @override
  Widget build(BuildContext context) {
    final d = context.destiny;
    String k(String x, [Map<String, String> v = const {}]) => context.textes.t('spectacle_ia.$x', v);
    final isPlayer = item.isPlayer;
    final teinte = d.sombre ? 0.2 : 0.12;

    // Fond : vert = réplique juste, rouge = à retravailler, sinon neutre.
    Color bg;
    Color border;
    if (item.success == true) {
      bg = d.famille(FamilleId.tient).withValues(alpha: teinte);
      border = d.famille(FamilleId.tient).withValues(alpha: 0.6);
    } else if (item.success == false) {
      bg = d.famille(FamilleId.fissure).withValues(alpha: teinte);
      border = d.famille(FamilleId.fissure).withValues(alpha: 0.6);
    } else {
      bg = isPlayer ? d.or.withValues(alpha: teinte) : d.carte;
      border = d.filet;
    }

    final emoji = item.archetype.isEmpty ? null : _archEmoji(item.archetype);
    final nameLabel = item.personnage;

    return Align(
      alignment: isPlayer ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment: isPlayer ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isPlayer && item.didascalie.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(item.didascalie,
                    style: TextStyle(
                        fontFamily: kPoliceTexte, fontSize: 12.5, color: d.texteSecondaire, fontStyle: FontStyle.italic)),
              ),
            // Rappel de l'archétype : icône animal + prénom.
            if (emoji != null || nameLabel.isNotEmpty || isPlayer)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (emoji != null) ...[emoji, const SizedBox(width: 4)],
                    if (nameLabel.isNotEmpty || isPlayer)
                      Flexible(
                        child: Text(
                          nameLabel.isEmpty ? k('jeu.toi') : (isPlayer ? k('jeu.toi_nom', {'nom': nameLabel}) : nameLabel),
                          style: TextStyle(fontFamily: kPoliceTexte, fontSize: 12.5, fontWeight: FontWeight.w700, color: d.titre),
                        ),
                      ),
                  ],
                ),
              ),
            Text(item.texte, style: TextStyle(fontFamily: kPoliceTexte, fontSize: 14, height: 1.35, color: d.texte)),
          ],
        ),
      ),
    );
  }
}

class _CorrectionCard extends StatelessWidget {
  const _CorrectionCard({required this.correction});

  final SpectacleCorrection correction;

  @override
  Widget build(BuildContext context) {
    final d = context.destiny;
    String k(String x, [Map<String, String> v = const {}]) => context.textes.t('spectacle_ia.$x', v);
    return CadreLisere(
      couleur: d.or,
      marge: 8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sports, size: 16, color: d.titre),
              const SizedBox(width: 6),
              Expanded(
                child: Text(k('jeu.coach', {'defaut': correction.defaut}),
                    style: TextStyle(fontFamily: kPoliceTexte, fontWeight: FontWeight.w700, color: d.titre)),
              ),
            ],
          ),
          if (correction.explication.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(correction.explication, style: TextStyle(fontSize: 13, height: 1.35, color: d.texte)),
          ],
          if (correction.modele.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(k('jeu.modele', {'modele': correction.modele}),
                style: TextStyle(fontSize: 13, height: 1.35, fontStyle: FontStyle.italic, color: d.texte)),
          ],
        ],
      ),
    );
  }
}

class _CrowCard extends StatelessWidget {
  const _CrowCard({required this.crow});

  final SpectacleCrow crow;

  @override
  Widget build(BuildContext context) {
    final d = context.destiny;
    String k(String x, [Map<String, String> v = const {}]) => context.textes.t('spectacle_ia.$x', v);
    Widget cell(String label, bool ok) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(ok ? Icons.check_circle : Icons.cancel,
                size: 14, color: d.famille(ok ? FamilleId.tient : FamilleId.fissure)),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 12.5, color: d.texte)),
          ],
        );
    return CadreLisere(
      couleur: d.bleuDestiny,
      marge: 8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(k('jeu.crow'), style: TextStyle(fontFamily: kPoliceTexte, fontWeight: FontWeight.w700, color: d.bleuTexte)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              cell(k('jeu.prenom'), crow.prenom),
              cell(k('jeu.fonction'), crow.fonction),
              cell(k('jeu.relation', {'n': '${crow.liens}'}), crow.liens >= 2),
              cell(k('jeu.objectif'), crow.objectif),
              cell(k('jeu.lieu'), crow.where),
            ],
          ),
          if (crow.trou.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(k('jeu.trou', {'trou': crow.trou}), style: TextStyle(fontSize: 12.5, color: d.texte)),
          ],
          if (crow.moyen.isNotEmpty)
            Text(k('jeu.combler', {'moyen': crow.moyen}), style: TextStyle(fontSize: 12.5, color: d.texteSecondaire)),
        ],
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final d = context.destiny;
    return CadreLisere(
      couleur: DestinyCouleurs.ia,
      marge: 8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.feedback_outlined, size: 16, color: DestinyCouleurs.ia),
              const SizedBox(width: 6),
              Text(context.textes.t('spectacle_ia.jeu.retour'),
                  style: TextStyle(fontFamily: kPoliceTexte, fontWeight: FontWeight.w700, color: d.titre)),
            ],
          ),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }
}

class _DebriefCard extends StatelessWidget {
  const _DebriefCard({required this.turn});

  final SpectacleTurn turn;

  @override
  Widget build(BuildContext context) {
    final d = context.destiny;
    String k(String x, [Map<String, String> v = const {}]) => context.textes.t('spectacle_ia.$x', v);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: d.carte,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: d.or),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BandeauAffiche(surtitre: k('jeu.fin_surtitre'), titre: k('jeu.fin')),
          const SizedBox(height: 12),
          _renderDynamic(context, turn.debrief),
        ],
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.controller,
    required this.freeCtrl,
    required this.onQuitToSetup,
  });

  final SpectacleController controller;
  final TextEditingController freeCtrl;
  final VoidCallback onQuitToSetup;

  @override
  Widget build(BuildContext context) {
    final d = context.destiny;
    final t = context.textes;
    String k(String x, [Map<String, String> v = const {}]) => t.t('spectacle_ia.$x', v);
    final c = controller;
    final turn = c.current;

    Widget content;
    if (c.loading) {
      content = Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Center(
          child: Semantics(
            label: t.t('ia_jeu.en_cours'),
            child: const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        ),
      );
    } else if (c.needsCharacterChoice && c.draw != null) {
      // Choix du personnage pour la scène courante.
      final draw = c.draw!;
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            k('jeu.quel_personnage', {'n': '${c.sceneNumber}'}),
            style: TextStyle(fontFamily: kPoliceTexte, fontWeight: FontWeight.w700, color: d.titre),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < draw.archetypes.length; i++)
                ActionChip(
                  avatar: _archEmoji(draw.archetypes[i].animalId),
                  label: Text(draw.archetypes[i].name),
                  side: BorderSide(color: _couleurPersonnage(context, draw.archetypes[i])),
                  onPressed: () => c.chooseSceneCharacter(i),
                ),
            ],
          ),
        ],
      );
    } else if (turn?.isFin ?? false) {
      content = FilledButton.icon(
        onPressed: onQuitToSetup,
        icon: const Icon(Icons.replay),
        label: Text(k('jeu.nouveau')),
      );
    } else if (c.mode == SpectacleMode.classique && (turn?.propositions.isNotEmpty ?? false)) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final p in turn!.propositions)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: OutlinedButton(
                onPressed: () => c.choose(p),
                style: OutlinedButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  foregroundColor: d.texte,
                  backgroundColor: d.champ,
                  side: BorderSide(color: d.ligne, width: 1.2),
                  minimumSize: const Size(48, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  textStyle: const TextStyle(fontFamily: kPoliceTexte, fontSize: 15, fontWeight: FontWeight.w500),
                ),
                child: Text(p.texte, textAlign: TextAlign.left),
              ),
            ),
        ],
      );
    } else {
      // Mode libre (ou classique sans propositions) : saisie de la réplique.
      content = Row(
        children: [
          Expanded(
            child: TextField(
              controller: freeCtrl,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(hintText: k('jeu.ta_replique'), isDense: true),
              onSubmitted: (_) => _sendFree(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            tooltip: t.t('accessibilite.envoyer'),
            icon: const Icon(Icons.send),
            onPressed: _sendFree,
          ),
        ],
      );
    }

    return Container(
      padding: EdgeInsets.fromLTRB(12, 10, 12, 8 + MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(
        color: d.carte,
        border: Border(top: BorderSide(color: d.filet)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (c.peutLancerDestiny)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Expanded(
                  child: Text(k('jeu.lancer_destiny', {'n': '${c.palier}'}),
                      style: TextStyle(fontFamily: kPoliceTexte, fontSize: 12.5, color: d.texteSecondaire)),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: d.bleuDestiny,
                    foregroundColor: Colors.white,
                    textStyle: const TextStyle(fontFamily: kPoliceTitres, fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                  onPressed: c.lancerDestiny,
                  icon: const Icon(Icons.flash_on_rounded),
                  label: Text(t.t('regie.destiny').toUpperCase()),
                ),
              ]),
            ),
          if (c.mode == SpectacleMode.classique &&
              !c.loading &&
              !c.needsCharacterChoice &&
              !(turn?.isFin ?? false) &&
              (turn?.propositions.isNotEmpty ?? false))
            Builder(builder: (context) {
              final name = c.currentArchetypeName;
              final emoji = name.isEmpty ? null : _archEmoji(name, size: 16);
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    if (emoji != null) ...[emoji, const SizedBox(width: 6)],
                    Expanded(
                      child: Text(
                        name.isEmpty ? k('jeu.choisis') : k('jeu.reponds', {'nom': name}),
                        style: TextStyle(fontFamily: kPoliceTexte, fontSize: 12.5, fontWeight: FontWeight.w600, color: d.titre),
                      ),
                    ),
                  ],
                ),
              );
            }),
          content,
        ],
      ),
    );
  }

  void _sendFree() {
    final t = freeCtrl.text;
    if (t.trim().isEmpty) return;
    freeCtrl.clear();
    controller.submitFree(t);
  }
}

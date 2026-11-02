import 'dart:math';

import 'package:flutter/material.dart';

import '../../domain/entities/danger.dart';
import '../../domain/entities/location.dart';
import '../../domain/troupe/session.dart';
import '../destiny/composants.dart';
import '../destiny/donnees.dart';
import '../destiny/page.dart';
import '../theme/destiny_theme.dart';
import 'troupe_screen.dart';

/// La mise en place : le public choisit le lieu et le groupe, puis le danger.
/// La régie note les trois objets et le mystère, et choisit le chrono.
class MiseEnPlaceScreen extends StatefulWidget {
  const MiseEnPlaceScreen({super.key, required this.contexte, required this.session});

  final ContexteTroupe contexte;
  final SessionTroupe session;

  @override
  State<MiseEnPlaceScreen> createState() => _MiseEnPlaceScreenState();
}

class _MiseEnPlaceScreenState extends State<MiseEnPlaceScreen> {
  final Random _hasard = Random();
  List<Location> _lieux = const [];
  List<Danger> _dangers = const [];
  List<Location> _propLieux = const [];
  List<Danger> _propDangers = const [];
  late final TextEditingController _groupe = TextEditingController(text: s.groupe);
  late final List<TextEditingController> _objets = [
    for (final o in s.objets) TextEditingController(text: o),
  ];
  late final TextEditingController _mystere = TextEditingController(text: s.mystere);
  late final TextEditingController _reponse = TextEditingController(text: s.reponseMystere);
  late int _chrono = widget.contexte.reglages.chronoChoisi;

  SessionTroupe get s => widget.session;

  @override
  void initState() {
    super.initState();
    _charger();
  }

  Future<void> _charger() async {
    final lieux = await widget.contexte.catalogue.getLocations();
    final dangers = await widget.contexte.catalogue.getDangers();
    if (!mounted) return;
    setState(() {
      _lieux = [for (final l in lieux) if (l.actif && (!s.kids || l.kids)) l];
      _dangers = [for (final d in dangers) if (d.actif && d.paliers.length == 4 && (!s.kids || d.kids)) d];
      _proposerLieux();
      _proposerDangers();
    });
  }

  List<T> _trois<T>(List<T> liste) => ([...liste]..shuffle(_hasard)).take(3).toList();
  void _proposerLieux() => _propLieux = _trois(_lieux);
  void _proposerDangers() => _propDangers = _trois(_dangers);

  @override
  void dispose() {
    _groupe.dispose();
    _mystere.dispose();
    _reponse.dispose();
    for (final o in _objets) {
      o.dispose();
    }
    super.dispose();
  }

  void _choisirLieu(Location l) => setState(() {
        s.lieuId = l.id;
        s.lieuNom = l.name;
      });

  void _choisirDanger(Danger d) => setState(() {
        s.dangerId = d.id;
        s.dangerNom = d.name;
        s.paliers = d.paliersPour(kids: s.kids);
      });

  Future<T?> _choixLibre<T>(List<T> liste, String Function(T) nom) => showModalBottomSheet<T>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.8,
          builder: (ctx, scroll) => ListView(
            controller: scroll,
            children: [for (final e in liste) ListTile(title: Text(nom(e)), onTap: () => Navigator.pop(ctx, e))],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final t = context.textes;
    final c = context.destiny;
    String m(String k, [Map<String, String> v = const {}]) => t.t('mise_en_place.$k', v);
    final chronos = widget.contexte.reglages.chronos;
    final pret = s.lieuNom.isNotEmpty && s.dangerNom.isNotEmpty && s.groupe.trim().isNotEmpty;
    final liens = (widget.contexte.relations?.links ?? const []).take(2).toList();

    return PageDestiny(
      titre: m('titre'),
      enfants: [
        Paragraphe(m('intro')),
        SectionDestiny(titre: m('lieu'), enfants: [
          Text(m('vote'), style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final l in _propLieux)
              ChoiceChip(
                label: Text(l.name),
                selected: s.lieuId == l.id,
                onSelected: (_) => _choisirLieu(l),
              ),
          ]),
          Row(children: [
            TextButton.icon(
              onPressed: () => setState(_proposerLieux),
              icon: const Icon(Icons.refresh_rounded),
              label: Text(m('nouvelles')),
            ),
            TextButton.icon(
              onPressed: () async {
                final l = await _choixLibre(_lieux, (x) => x.name);
                if (l != null) _choisirLieu(l);
              },
              icon: const Icon(Icons.list_rounded),
              label: Text(m('choix_libre')),
            ),
          ]),
          if (s.lieuNom.isNotEmpty) ...[
            Text(s.lieuNom, style: Theme.of(context).textTheme.titleLarge),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final e in _lieux.where((l) => l.id == s.lieuId).expand((l) => l.espaces)) Chip(label: Text(e)),
            ]),
          ],
        ]),
        SectionDestiny(titre: m('groupe'), enfants: [
          Text(m('groupe_aide'), style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final gr in t.liste('mise_en_place.groupes'))
              ActionChip(
                label: Text(gr),
                onPressed: () => setState(() {
                  _groupe.text = gr;
                  s.groupe = gr;
                }),
              ),
          ]),
          const SizedBox(height: 8),
          TextField(controller: _groupe, onChanged: (v) => setState(() => s.groupe = v.trim())),
          if (liens.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(m('liens'), style: Theme.of(context).textTheme.bodySmall),
            for (final l in liens) Puce(l.texte),
          ],
        ]),
        SectionDestiny(titre: m('danger'), enfants: [
          Text(m('vote'), style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final d in _propDangers)
              ChoiceChip(
                label: Text(d.name),
                selected: s.dangerId == d.id,
                onSelected: (_) => _choisirDanger(d),
              ),
          ]),
          Row(children: [
            TextButton.icon(
              onPressed: () => setState(_proposerDangers),
              icon: const Icon(Icons.refresh_rounded),
              label: Text(m('nouvelles')),
            ),
            TextButton.icon(
              onPressed: () async {
                final d = await _choixLibre(_dangers, (x) => x.name);
                if (d != null) _choisirDanger(d);
              },
              icon: const Icon(Icons.list_rounded),
              label: Text(m('choix_libre')),
            ),
          ]),
          if (s.paliers.isNotEmpty) FrisePaliers(textes: s.paliers),
        ]),
        SectionDestiny(titre: m('objets'), enfants: [
          Text(m('objets_aide'), style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          for (var i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextField(
                controller: _objets[i],
                decoration: InputDecoration(labelText: m('objet', {'n': '${i + 1}'}), isDense: true),
                onChanged: (v) => s.objets[i] = v.trim(),
              ),
            ),
        ]),
        SectionDestiny(titre: m('mystere'), enfants: [
          Text(m('mystere_aide'), style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          TextField(controller: _mystere, onChanged: (v) => s.mystere = v.trim(), maxLines: 2),
          const SizedBox(height: 8),
          TextField(
            controller: _reponse,
            decoration: InputDecoration(labelText: m('reponse'), helperText: m('reponse_aide'), helperMaxLines: 2),
            onChanged: (v) => s.reponseMystere = v.trim(),
            maxLines: 2,
          ),
        ]),
        SectionDestiny(titre: m('chrono'), enfants: [
          Wrap(spacing: 8, children: [
            for (var i = 0; i < chronos.length; i++)
              ChoiceChip(
                label: Text(m('minutes', {'n': '${chronos[i].dureeMinutes}'})),
                selected: _chrono == i,
                onSelected: (_) => setState(() => _chrono = i),
              ),
          ]),
          const SizedBox(height: 4),
          Text(m('destiny_a', {'liste': chronos[_chrono].destinyMinutes.map((x) => '$x').join(' · ')}),
              style: TextStyle(fontFamily: kPoliceTexte, color: c.texteSecondaire)),
        ]),
        if (s.kids) const Padding(padding: EdgeInsets.only(top: 12), child: Align(alignment: Alignment.centerLeft, child: SigleKids())),
        const SizedBox(height: 22),
        FilledButton.icon(
          onPressed: pret
              ? () async {
                  final ch = chronos[_chrono];
                  s
                    ..dureeMinutes = ch.dureeMinutes
                    ..destinyMinutes = [...ch.destinyMinutes]
                    ..etape = EtapeSession.regie;
                  await widget.contexte.store.enregistrer(s);
                  if (context.mounted) ouvrirEtape(context, widget.contexte, s, remplacer: true);
                }
              : null,
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text(m('lever_rideau')),
        ),
      ],
    );
  }
}

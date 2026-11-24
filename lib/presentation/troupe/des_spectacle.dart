import 'package:flutter/material.dart';

import '../../domain/entities/danger.dart';
import '../../domain/exercices/exercices_destiny.dart';
import '../destiny/donnees.dart';
import '../exercices/destiny/exercice_destiny_screen.dart';
import '../theme/destiny_theme.dart';

/// Le dé du danger du DESTINY n°1, en plein écran par-dessus le spectacle :
/// le type roule, tombe, puis le danger apparaît. « Retirer un danger » en
/// tire un autre du même type ([retirer] rend le nouveau). Le chrono tourne
/// pendant ce temps.
Future<void> ouvrirDeDanger(
  BuildContext context, {
  required TypeDanger type,
  required Danger? danger,
  Danger? Function()? retirer,
}) =>
    _ouvrir(context, _DeDanger(type: type, danger: danger, retirer: retirer));

/// Le dé des survivants du DESTINY n°3 : qui s'en sort.
Future<void> ouvrirDeSurvivants(
  BuildContext context, {
  required int protagonistes,
  required FaceSurvivants resultat,
  String? danger,
}) =>
    _ouvrir(context, _DeSurvivants(protagonistes: protagonistes, resultat: resultat, danger: danger));

Future<void> _ouvrir(BuildContext context, Widget contenu) => Navigator.of(context).push(PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: false,
      transitionDuration: const Duration(milliseconds: 200),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, __, ___) => _Fond(child: contenu),
      transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
    ));

class _Fond extends StatelessWidget {
  const _Fond({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
        key: const ValueKey('de_spectacle'),
        color: Colors.black.withValues(alpha: 0.96),
        child: SafeArea(
          child: Center(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: child)),
        ),
      );
}

TextStyle _titre(BuildContext context) =>
    TextStyle(fontFamily: kPoliceTitres, fontSize: 30, fontWeight: FontWeight.w900, color: context.destiny.orClair);
const TextStyle _texte = TextStyle(fontFamily: kPoliceTexte, fontSize: 16, color: Colors.white70);

Widget _continuer(BuildContext context) => FilledButton(
      key: const ValueKey('on_continue'),
      onPressed: () => Navigator.of(context).pop(),
      child: Text(context.textes.t('exercices.destiny.on_continue')),
    );

class _DeDanger extends StatefulWidget {
  const _DeDanger({required this.type, required this.danger, this.retirer});

  final TypeDanger type;
  final Danger? danger;
  final Danger? Function()? retirer;

  @override
  State<_DeDanger> createState() => _DeDangerState();
}

class _DeDangerState extends State<_DeDanger> {
  late Danger? _danger = widget.danger;

  @override
  Widget build(BuildContext context) {
    final t = context.textes;
    String k(String x, [Map<String, String> v = const {}]) => t.t('exercices.destiny.$x', v);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(k('destiny_n', {'n': '1'}), style: _titre(context)),
      Text(k('de_danger'), style: _texte),
      const SizedBox(height: 24),
      DeQuiRoule(
        key: const ValueKey('de_danger'),
        faces: [for (final x in TypeDanger.values) libelleType(context, x)],
        resultat: libelleType(context, widget.type),
        apres: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 20),
          Text(_danger?.name ?? k('aucun_danger'),
              key: const ValueKey('danger_tire'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontFamily: kPoliceTitres, fontSize: 34, fontWeight: FontWeight.w900, color: Colors.white)),
          const SizedBox(height: 18),
          Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 10, children: [
            if (widget.retirer != null)
              OutlinedButton.icon(
                key: const ValueKey('retirer_danger'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                onPressed: _danger == null ? null : () => setState(() => _danger = widget.retirer!() ?? _danger),
                icon: const Icon(Icons.casino_outlined, size: 18),
                label: Text(k('retirer_danger')),
              ),
            _continuer(context),
          ]),
        ]),
      ),
    ]);
  }
}

class _DeSurvivants extends StatelessWidget {
  const _DeSurvivants({required this.protagonistes, required this.resultat, this.danger});

  final int protagonistes;
  final FaceSurvivants resultat;
  final String? danger;

  @override
  Widget build(BuildContext context) {
    final t = context.textes;
    String k(String x, [Map<String, String> v = const {}]) => t.t('exercices.destiny.$x', v);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(k('destiny_n', {'n': '3'}), style: _titre(context)),
      Text(k('de_survivants'), style: _texte),
      const SizedBox(height: 24),
      DeQuiRoule(
        key: const ValueKey('de_survivants'),
        faces: [for (final f in facesSurvivants(protagonistes)) libelleSurvivants(context, f)],
        resultat: libelleSurvivants(context, resultat),
        apres: Column(mainAxisSize: MainAxisSize.min, children: [
          if (danger != null && danger!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text(k('danger_du_soir', {'nom': danger!}), style: _texte),
            ),
          const SizedBox(height: 18),
          _continuer(context),
        ]),
      ),
    ]);
  }
}

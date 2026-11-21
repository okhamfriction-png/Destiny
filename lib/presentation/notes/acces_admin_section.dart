import 'package:flutter/material.dart';

import '../../application/notes/acces_admin.dart';
import '../../application/notes/notes_controller.dart';
import '../destiny/donnees.dart';
import '../destiny/page.dart';
import '../theme/destiny_theme.dart';

/// La section discrète, tout en bas des Réglages : « Accès administrateur ».
/// Fermée, elle demande un token GitHub et le mot de passe ; ouverte, elle
/// montre le token masqué, permet de l'afficher (avec le mot de passe) et de
/// verrouiller Destiny Note.
class AccesAdminSection extends StatefulWidget {
  const AccesAdminSection({required this.acces, this.notes, super.key});

  final AccesAdmin acces;
  final NotesController? notes;

  @override
  State<AccesAdminSection> createState() => _AccesAdminSectionState();
}

class _AccesAdminSectionState extends State<AccesAdminSection> {
  final _token = TextEditingController();
  final _motDePasse = TextEditingController();
  bool _ouvert = false;
  bool _enCours = false;
  EtapeAcces? _etape;
  String? _message;

  @override
  void dispose() {
    _token.dispose();
    _motDePasse.dispose();
    super.dispose();
  }

  Future<void> _deverrouiller() async {
    final t = context.textes;
    setState(() {
      _enCours = true;
      _etape = null;
      _message = null;
    });
    ResultatAcces r;
    try {
      r = await widget.acces.deverrouiller(
        token: _token.text,
        motDePasse: _motDePasse.text,
        etape: (e) {
          if (mounted) setState(() => _etape = e);
        },
      );
    } catch (e) {
      widget.acces.derniereErreur = '$e';
      r = ResultatAcces.erreur;
    }
    if (!mounted) return;
    _motDePasse.clear();
    final a = widget.acces;
    setState(() {
      _enCours = false;
      _etape = null;
      _message = switch (r) {
        ResultatAcces.ok => t.t('reglages.acces_ok'),
        ResultatAcces.delai || ResultatAcces.erreur => t.t('reglages.acces_erreurs.${r.name}', {
            'etape': t.t('reglages.acces_etapes.${(a.etapeEnEchec ?? EtapeAcces.lecture).name}'),
            'detail': a.derniereErreur,
          }).trim(),
        _ => t.t('reglages.acces_erreurs.${r.name}'),
      };
    });
    if (r == ResultatAcces.ok) _token.clear();
  }

  Future<void> _afficherToken() async {
    final t = context.textes;
    final champ = TextEditingController();
    final motDePasse = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.t('reglages.acces_afficher_titre')),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t.t('reglages.acces_afficher_aide')),
          TextField(
            key: const ValueKey('mot_de_passe_afficher'),
            controller: champ,
            obscureText: true,
            autofocus: true,
            decoration: InputDecoration(labelText: t.t('reglages.acces_mot_de_passe')),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(t.t('reglages.annuler'))),
          FilledButton(onPressed: () => Navigator.pop(context, champ.text), child: Text(t.t('reglages.valider'))),
        ],
      ),
    );
    champ.dispose();
    if (motDePasse == null || motDePasse.isEmpty || !mounted) return;
    final token = await widget.acces.tokenEnClair(motDePasse);
    if (!mounted) return;
    if (token == null) {
      setState(() => _message = t.t('reglages.acces_erreurs.afficher'));
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.t('reglages.acces_token')),
        content: SelectableText(token, style: const TextStyle(fontFamily: 'monospace', fontSize: 13)),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(t.t('reglages.valider')))],
      ),
    );
  }

  Future<void> _verrouiller() async {
    await widget.acces.verrouiller();
    await widget.notes?.oublier();
    if (mounted) setState(() => _message = null);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.textes;
    final d = context.destiny;
    String k(String x, [Map<String, String> v = const {}]) => t.t('reglages.$x', v);
    return ListenableBuilder(
      listenable: widget.acces,
      builder: (context, _) {
        final a = widget.acces;
        final discret = TextStyle(fontFamily: kPoliceTexte, fontSize: 12.5, color: d.texteSecondaire);
        if (!a.actif && !_ouvert) {
          return Padding(
            padding: const EdgeInsets.only(top: 18),
            child: Center(
              child: TextButton(
                key: const ValueKey('acces_admin'),
                onPressed: () => setState(() => _ouvert = true),
                child: Text(k('acces'), style: discret),
              ),
            ),
          );
        }
        return SectionDestiny(titre: k('acces'), enfants: [
          if (!a.actif) ...[
            Text(k('acces_aide'), style: discret),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey('admin_token'),
              controller: _token,
              obscureText: true,
              enableSuggestions: false,
              autocorrect: false,
              decoration: InputDecoration(labelText: k('acces_token')),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey('admin_mot_de_passe'),
              controller: _motDePasse,
              obscureText: true,
              enableSuggestions: false,
              autocorrect: false,
              decoration: InputDecoration(labelText: k('acces_mot_de_passe')),
              onSubmitted: (_) => _deverrouiller(),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              key: const ValueKey('admin_ouvrir'),
              onPressed: _enCours ? null : _deverrouiller,
              icon: _enCours
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.lock_open_rounded, size: 18),
              label: Text(_enCours
                  ? (_etape == null ? k('acces_verification') : k('acces_etapes.${_etape!.name}'))
                  : k('acces_ouvrir')),
            ),
          ] else ...[
            Row(children: [
              Icon(Icons.verified_user_rounded, color: d.titre, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(k('acces_actif'),
                    style: TextStyle(fontFamily: kPoliceTexte, fontWeight: FontWeight.w700, color: d.texte)),
              ),
            ]),
            const SizedBox(height: 4),
            Text(k('acces_token_masque', {'token': a.tokenMasque}), key: const ValueKey('token_masque'), style: discret),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 6, children: [
              OutlinedButton.icon(
                onPressed: _afficherToken,
                icon: const Icon(Icons.visibility_outlined, size: 18),
                label: Text(k('acces_afficher')),
              ),
              OutlinedButton.icon(
                key: const ValueKey('admin_verrouiller'),
                onPressed: _verrouiller,
                icon: const Icon(Icons.lock_outline_rounded, size: 18),
                label: Text(k('acces_verrouiller')),
              ),
            ]),
            const SizedBox(height: 4),
            Text(k('acces_verrouiller_aide'), style: discret),
          ],
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_message!, key: const ValueKey('admin_message'), style: TextStyle(color: d.titre)),
            ),
        ]);
      },
    );
  }
}

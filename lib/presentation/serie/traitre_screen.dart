import 'package:flutter/material.dart';

import '../../domain/grammaire/modeles.dart';
import '../../domain/serie/serie.dart';
import '../destiny/donnees.dart';
import '../destiny/page.dart';
import '../theme/destiny_theme.dart';
import 'contexte_serie.dart';

/// L'écran caché du traître : un seul joueur voit l'offre du méchant, et
/// accepte ou refuse. Personne d'autre ne sait. Il se révèle à l'épisode 3.
class TraitreScreen extends StatefulWidget {
  const TraitreScreen({
    super.key,
    required this.contexte,
    required this.serie,
    required this.saison,
    required this.mechant,
  });

  final ContexteSerie contexte;
  final Serie serie;
  final SaisonSerie saison;
  final Mechant mechant;

  @override
  State<TraitreScreen> createState() => _TraitreScreenState();
}

class _TraitreScreenState extends State<TraitreScreen> {
  /// 0 : passer le téléphone ; 1 : l'offre ; 2 : rendre le téléphone.
  int _etape = 0;

  Future<void> _repondre(bool accepte) async {
    widget.saison.traitre?.accepte = accepte;
    await widget.contexte.store.enregistrer(widget.serie);
    if (mounted) setState(() => _etape = 2);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.textes;
    final c = context.destiny;
    String k(String x, [Map<String, String> v = const {}]) => t.t('serie.traitre.$x', v);
    final p = widget.serie.personnage(widget.saison.traitre?.personnageId ?? '');
    final qui = p == null ? '' : (p.joueur.isNotEmpty ? p.joueur : p.appel);
    final offre = widget.mechant.offreAuTraitre.isEmpty ? k('offre_par_defaut') : widget.mechant.offreAuTraitre;

    return PopScope(
      canPop: _etape != 1,
      child: PageDestiny(
        titre: k('titre'),
        enfants: [
          const SizedBox(height: 24),
          Icon(Icons.visibility_off_rounded, size: 56, color: c.titre),
          const SizedBox(height: 16),
          ...switch (_etape) {
            0 => [
                Paragraphe(k('passer', {'joueur': qui}), gras: true),
                Paragraphe(k('ecran')),
                const SizedBox(height: 16),
                FilledButton(onPressed: () => setState(() => _etape = 1), child: Text(k('voir'))),
              ],
            1 => [
                Paragraphe(k('offre')),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: c.famille(FamilleId.fissure), width: 2),
                  ),
                  child: Text(offre,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontFamily: kPoliceTitres, fontWeight: FontWeight.w700, fontSize: 18, color: c.texte)),
                ),
                const SizedBox(height: 8),
                Text(widget.mechant.nom, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 20),
                FilledButton(onPressed: () => _repondre(true), child: Text(k('accepte'))),
                const SizedBox(height: 8),
                OutlinedButton(onPressed: () => _repondre(false), child: Text(k('refuse'))),
              ],
            _ => [
                Paragraphe(k('fin'), gras: true),
                const SizedBox(height: 16),
                FilledButton(onPressed: () => Navigator.of(context).pop(), child: Text(k('rendu'))),
              ],
          },
        ],
      ),
    );
  }
}

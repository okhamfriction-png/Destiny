import 'package:flutter/material.dart';

import '../../application/version.dart';
import '../destiny/composants.dart';
import '../destiny/donnees.dart';
import '../destiny/page.dart';
import '../theme/destiny_theme.dart';

/// À propos : ce qu'on fait dans l'appli, et sa version.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const _icones = <String, IconData>{
    'troupe': Icons.theater_comedy_outlined,
    'jouer': Icons.auto_stories_outlined,
    'exercices': Icons.fitness_center_outlined,
    'bibliotheque': Icons.menu_book_outlined,
    'musique': Icons.library_music_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final g = context.grammaire;
    final t = context.textes;
    final c = context.destiny;
    String k(String x, [Map<String, String> v = const {}]) => t.t('page_a_propos.$x', v);
    return PageDestiny(
      titre: k('titre'),
      enfants: [
        const SizedBox(height: 8),
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Image.asset('assets/images/logo_destiny.png', width: 92, height: 92,
                errorBuilder: (_, __, ___) => Icon(Icons.flash_on_rounded, size: 60, color: c.or)),
          ),
        ),
        const SizedBox(height: 14),
        BandeauAffiche(titre: g.nom.toUpperCase(), surtitre: g.promesse, sousTitre: k('sous_titre')),
        const SizedBox(height: 6),
        Center(
          child: Text(k('version', {'version': kVersionAppli}),
              style: TextStyle(fontFamily: kPoliceTexte, fontSize: 13.5, color: c.texteSecondaire)),
        ),
        SectionDestiny(titre: k('ce_qu_on_y_fait'), enfants: [
          for (final f in t.tables('page_a_propos.fonctions'))
            ElementListe(
              titre: '${f['titre']}',
              sousTitre: '${f['texte']}',
              devant: Icon(_icones['${f['id']}'] ?? Icons.star_outline_rounded, color: c.titre),
            ),
          Paragraphe(k('hors_ligne'), italique: true),
        ]),
      ],
    );
  }
}

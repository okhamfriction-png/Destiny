import 'package:flutter/material.dart';

import '../destiny/donnees.dart';
import '../destiny/page.dart';
import '../social_links.dart';
import '../theme/destiny_theme.dart';

/// Me contacter : Instagram et TikTok.
class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.textes;
    final c = context.destiny;
    String k(String x) => t.t('contact.$x');
    return PageDestiny(
      titre: k('titre'),
      enfants: [
        const SizedBox(height: 8),
        Text(k('accroche'),
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: kPoliceTitres, fontSize: 22, fontWeight: FontWeight.w900, color: c.titre)),
        const SizedBox(height: 6),
        Text(k('texte'),
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: kPoliceTexte, fontSize: 14.5, height: 1.4, color: c.texte)),
        const SizedBox(height: 24),
        _CarteReseau(
          icone: instagramIcon,
          titre: 'Instagram',
          pseudo: kHandle,
          degrade: kInstagramGradient,
          onTap: () => openSocial(kInstagramUrl),
        ),
        const SizedBox(height: 14),
        _CarteReseau(
          icone: tiktokIcon,
          titre: 'TikTok',
          pseudo: kHandle,
          degrade: const [Color(0xFF010101), Color(0xFF25F4EE)],
          accent: const Color(0xFFFE2C55),
          onTap: () => openSocial(kTiktokUrl),
        ),
      ],
    );
  }
}

class _CarteReseau extends StatelessWidget {
  const _CarteReseau({
    required this.icone,
    required this.titre,
    required this.pseudo,
    required this.degrade,
    required this.onTap,
    this.accent,
  });

  final IconData icone;
  final String titre;
  final String pseudo;
  final List<Color> degrade;
  final Color? accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: degrade),
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.all(18),
          child: Row(children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.25), shape: BoxShape.circle),
              child: Icon(icone, color: accent ?? Colors.white, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(titre, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
                Text(pseudo, style: const TextStyle(color: Colors.white70)),
              ]),
            ),
            const Icon(Icons.open_in_new_rounded, color: Colors.white, size: 20),
          ]),
        ),
      ),
    );
  }
}

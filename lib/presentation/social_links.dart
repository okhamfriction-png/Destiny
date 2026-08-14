import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

const String kInstagramUrl = 'https://www.instagram.com/destinyimpro/';
const String kTiktokUrl = 'https://www.tiktok.com/@destinyimpro';
const String kHandle = '@destinyimpro';

/// Couleur de marque (dégradé Instagram, noir TikTok).
const List<Color> kInstagramGradient = [
  Color(0xFFF58529),
  Color(0xFFDD2A7B),
  Color(0xFF8134AF),
];

Future<void> openSocial(String url) async {
  final uri = Uri.parse(url);
  try {
    // Web : ouvre un nouvel onglet ; mobile/desktop : app ou navigateur.
    final ok = await launchUrl(
      uri,
      mode: LaunchMode.platformDefault,
      webOnlyWindowName: '_blank',
    );
    if (!ok) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  } catch (_) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

const IconData instagramIcon = FontAwesomeIcons.instagram;
const IconData tiktokIcon = FontAwesomeIcons.tiktok;

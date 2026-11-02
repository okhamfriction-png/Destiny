import 'dart:io';

import 'package:flutter/services.dart';

/// Charge Cinzel et Montserrat pour que les rendus de test ressemblent à
/// l'appli (sinon Flutter dessine des carrés).
Future<void> chargerPolices() async {
  Future<ByteData> lire(String f) async =>
      ByteData.sublistView(Uint8List.fromList(await File('assets/fonts/$f').readAsBytes()));
  final cinzel = FontLoader('Cinzel')
    ..addFont(lire('Cinzel-Bold.ttf'))
    ..addFont(lire('Cinzel-Black.ttf'));
  final montserrat = FontLoader('Montserrat')
    ..addFont(lire('Montserrat-Regular.ttf'))
    ..addFont(lire('Montserrat-Italic.ttf'))
    ..addFont(lire('Montserrat-Medium.ttf'))
    ..addFont(lire('Montserrat-SemiBold.ttf'))
    ..addFont(lire('Montserrat-Bold.ttf'));
  await Future.wait([cinzel.load(), montserrat.load()]);
}

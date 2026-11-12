import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:destiny/application/son/lecteur_son.dart';
import 'package:destiny/application/son/pack_audio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Le pack audio intégré à l'appli Android (asset pack `destiny_pack`) : sans
/// pack importé, l'appli le prend, et ses sons se lisent comme des assets.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const musique = 'Musiques Destiny/Camping/Acte 1 - Camping.mp3';
  const bruitage = 'Bruitages/ALARME - Alarme générique/1 - Alarme.ogg';

  void servir(Map<String, String> fichiers) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler('flutter/assets', (m) async {
      final cle = Uri.decodeFull(utf8.decode(m!.buffer.asUint8List()));
      final texte = fichiers[cle];
      if (texte != null) return ByteData.sublistView(Uint8List.fromList(utf8.encode(texte)));
      final f = File(cle);
      return f.existsSync() ? ByteData.sublistView(f.readAsBytesSync()) : null;
    });
  }

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler('flutter/assets', null);
  });

  test('sans pack importé, le pack intégré sert : ses sons sont des assets', () async {
    servir({
      'assets/pack/index.json': jsonEncode({
        'fichiers': {musique: 'f/aaa.mp3', bruitage: 'f/bbb.ogg'},
      }),
    });
    final pack = PackAudio();
    await pack.charger();
    expect(pack.disponible, isTrue);
    expect(pack.integre, isTrue);
    expect(pack.index.trouver(musique), musique);
    final s = pack.versSource(const SourcePack(musique));
    expect(s, isA<AssetSource>());
    expect((s as AssetSource).path, 'pack/f/aaa.mp3');
    expect((pack.versSource(const SourcePack(bruitage)) as AssetSource).path, 'pack/f/bbb.ogg');
  });

  test('sans pack intégré ni importé : sans pack, comme avant', () async {
    servir({});
    final pack = PackAudio();
    await pack.charger();
    expect(pack.disponible, isFalse);
    expect(pack.integre, isFalse);
    expect(pack.manifeste, isNotNull);
  });
}

import 'package:flutter/foundation.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart'
    show ExternalLibrary;

import '../../src/rust/frb_generated.dart';

/// Chargement du cœur Rust (`rust/`, compilé par cargokit pour Android / iOS).
///
/// Sur le web, ou si la librairie native ne se charge pas, l'app continue avec
/// l'implémentation Dart : [isReady] reste faux.
class RustCore {
  RustCore._();

  static bool _ready = false;

  static bool get isReady => _ready;

  /// [externalLibrary] : chemin explicite de la librairie (tests sur l'hôte).
  static Future<void> init({ExternalLibrary? externalLibrary}) async {
    if (kIsWeb || _ready) return;
    try {
      await RustLib.init(externalLibrary: externalLibrary);
      _ready = true;
    } catch (e) {
      debugPrint('Cœur Rust indisponible, repli sur Dart : $e');
    }
  }
}

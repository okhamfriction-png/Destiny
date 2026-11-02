import 'dart:io' show Platform;

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Implémentation native (mobile et desktop).
void configureDatabasePlatform() {
  // Sur desktop, sqflite a besoin de l'implémentation FFI.
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
}

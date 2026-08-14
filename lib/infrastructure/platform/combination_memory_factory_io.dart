import 'dart:io' show Platform;

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../domain/repositories/combination_memory.dart';
import '../datasources/sqlite_combination_memory.dart';

/// Implémentation native (mobile + desktop).
void configureDatabasePlatform() {
  // Sur desktop, sqflite a besoin de l'implémentation FFI.
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
}

CombinationMemory createCombinationMemory() => SqliteCombinationMemory();

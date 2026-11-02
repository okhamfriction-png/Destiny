import 'base_de_donnees_io.dart' if (dart.library.html) 'base_de_donnees_web.dart' as impl;

/// Configure le moteur de base de données selon la plateforme courante
/// (FFI sur desktop, défaut sur mobile, rien sur le web).
void configureDatabasePlatform() => impl.configureDatabasePlatform();

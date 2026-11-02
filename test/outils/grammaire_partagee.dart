import 'dart:io';

import 'package:destiny/infrastructure/datasources/grammaire_source.dart';
import 'package:destiny/infrastructure/datasources/local_json_datasource.dart';

/// Lit un fichier du projet (les tests tournent à la racine du dépôt).
Future<String> lireFichier(String chemin) => File(chemin).readAsString();

/// La vraie grammaire du dépôt, lue depuis le disque.
final GrammaireSource sourceDeTest = GrammaireSource(lire: lireFichier);

Future<GrammaireChargee> chargerGrammaire() => sourceDeTest.charger();

/// La source de données du catalogue, branchée sur la vraie grammaire.
LocalJsonDataSource donneesDeTest() =>
    LocalJsonDataSource(grammaire: sourceDeTest, lire: lireFichier);

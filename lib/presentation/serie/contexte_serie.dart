import 'package:flutter/material.dart';

import '../../application/services/audio_service.dart';
import '../../application/state/music_controller.dart';
import '../../application/state/reglages_destiny.dart';
import '../../application/state/serie_store.dart';
import '../../application/state/visual_settings.dart';
import '../../domain/grammaire/modeles.dart';
import '../../domain/repositories/catalog_store.dart';
import '../../domain/serie/regles_serie.dart';
import '../../domain/serie/serie.dart';
import 'bilan_screen.dart';
import 'jeu_screen.dart';
import 'preparation_screen.dart';

/// Ce dont les écrans de la Série ont besoin.
class ContexteSerie {
  const ContexteSerie({
    required this.store,
    required this.reglages,
    required this.catalogue,
    required this.audio,
    required this.musique,
    required this.visuels,
  });

  final SerieStore store;
  final ReglagesDestiny reglages;

  /// Le catalogue de l'appli (lieux et dangers de Destiny).
  final CatalogStore catalogue;
  final AudioService audio;
  final MusicController musique;
  final VisualSettings visuels;

  /// Le méchant d'une saison ou d'un épisode.
  Mechant? mechant(Grammaire g, String id) => trouverMechant(g, store.catalogue, id);
}

/// Ouvre l'écran où en est un épisode.
Future<void> ouvrirEpisode(
  BuildContext context,
  ContexteSerie ctx,
  Serie serie,
  EpisodeSerie episode, {
  bool remplacer = false,
}) {
  final Widget page = switch (episode.etape) {
    EtapeEpisode.preparation => PreparationEpisodeScreen(contexte: ctx, serie: serie, episode: episode),
    EtapeEpisode.jeu => JeuEpisodeScreen(contexte: ctx, serie: serie, episode: episode),
    EtapeEpisode.bilan || EtapeEpisode.termine => BilanEpisodeScreen(contexte: ctx, serie: serie, episode: episode),
  };
  final route = MaterialPageRoute<void>(builder: (_) => page);
  final nav = Navigator.of(context);
  return remplacer ? nav.pushReplacement(route) : nav.push(route);
}

/// Crée l'épisode suivant de la série (dans la saison en cours s'il y en a
/// une, sinon hors saison) et l'enregistre.
Future<EpisodeSerie> nouvelEpisode(ContexteSerie ctx, Serie s) async {
  final saison = s.saisonEnCours;
  final numero = s.prochainNumero;
  final enSaison = saison != null && !saison.terminee && numero != null;
  final e = EpisodeSerie(
    id: ctx.store.nouvelId('e'),
    date: DateTime.now(),
    saison: enSaison ? saison.numero : 0,
    numero: enSaison ? numero : s.episodesDe(0).length + 1,
    presage: enSaison ? saison.presageDe(numero) : '',
    mechantId: enSaison ? saison.mechantId : '',
    dureeMinutes: s.kids ? 0 : ctx.reglages.chronos[ctx.reglages.chronoChoisi].dureeMinutes,
    destinyMinutes: s.kids ? [] : [...ctx.reglages.chronos[ctx.reglages.chronoChoisi].destinyMinutes],
  );
  s.episodes.add(e);
  await ctx.store.enregistrer(s);
  return e;
}

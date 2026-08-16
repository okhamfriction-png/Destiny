import 'package:flutter/material.dart';

import '../../application/services/poster_service.dart';

/// Affiche d'un film : image officielle récupérée sur Wikipédia (sans clé,
/// via [PosterService]). Pendant la recherche → un chargeur ; si aucune
/// affiche n'est trouvée → une affiche stylisée de secours (titre + année +
/// genre). Utilisée par la carte du spin-off ET par le chrono du spin-off.
class FilmPoster extends StatefulWidget {
  const FilmPoster({
    required this.film,
    required this.annee,
    required this.genre,
    this.width = 210,
    super.key,
  });

  final String film;
  final String annee;
  final String genre;
  final double width;

  @override
  State<FilmPoster> createState() => _FilmPosterState();
}

class _FilmPosterState extends State<FilmPoster> {
  late Future<String?> _future;

  @override
  void initState() {
    super.initState();
    _future = PosterService.instance.posterUrl(widget.film, annee: widget.annee);
  }

  @override
  void didUpdateWidget(covariant FilmPoster old) {
    super.didUpdateWidget(old);
    if (old.film != widget.film || old.annee != widget.annee) {
      _future =
          PosterService.instance.posterUrl(widget.film, annee: widget.annee);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      child: AspectRatio(
        aspectRatio: 2 / 3,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: const Color(0xFFFFC24B).withValues(alpha: 0.45)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: FutureBuilder<String?>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return _fallback(loading: true);
                }
                final url = snap.data;
                if (url == null || url.isEmpty) {
                  return _fallback(loading: false);
                }
                return Image.network(
                  url,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return _fallback(loading: true);
                  },
                  errorBuilder: (_, __, ___) => _fallback(loading: false),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  /// Affiche stylisée (chargement ou secours), toujours au bon ratio 2:3.
  Widget _fallback({required bool loading}) {
    final theme = Theme.of(context);
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A2350), Color(0xFF160F30)],
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_movies, color: Color(0xFFFFC24B), size: 20),
              const SizedBox(width: 6),
              if (widget.genre.isNotEmpty)
                Flexible(
                  child: Text(
                    widget.genre.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: const Color(0xFFFFC24B),
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          if (loading)
            const Center(
              child: SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                    strokeWidth: 2.4, color: Color(0xFFFFC24B)),
              ),
            )
          else
            const Center(
              child: Icon(Icons.movie_creation_outlined,
                  color: Colors.white24, size: 54),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.film,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
              if (widget.annee.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  widget.annee,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: Colors.white54),
                ),
              ],
              if (loading) ...[
                const SizedBox(height: 6),
                Text(
                  'Recherche de l\'affiche…',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: Colors.white38),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

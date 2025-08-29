import 'package:flutter/material.dart';
import 'package:jikan_api/jikan_api.dart';
import '../models/genre_model.dart';
import '../widgets/cached_image.dart';

class GenreCard extends StatelessWidget {
  final dynamic genre; // Can be Genre or EnhancedGenre
  final VoidCallback? onTap;

  const GenreCard({
    super.key,
    required this.genre,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final genreName = _getGenreName();
    final imagePath = _getImagePath();
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        child: Column(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: imagePath != null && imagePath.isNotEmpty
                    ? Stack(
                        children: [
                          // Background image
                          CachedImage(
                            imageUrl: imagePath,
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                          ),
                          // Gradient overlay for better text visibility
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.7),
                                ],
                              ),
                            ),
                          ),
                          // Icon overlay
                          Center(
                            child: Icon(
                              _getGenreIcon(genreName),
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                        ],
                      )
                    : Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              theme.colorScheme.primary,
                              theme.colorScheme.secondary,
                              theme.colorScheme.tertiary,
                            ],
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            _getGenreIcon(genreName),
                            color: Colors.white,
                            size: 32,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 15),
            SizedBox(
              width: 80,
              child: Text(
                genreName,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getGenreName() {
    if (genre is EnhancedGenre) {
      return (genre as EnhancedGenre).name;
    } else if (genre is Genre) {
      return (genre as Genre).name;
    }
    return 'Unknown';
  }

  String? _getImagePath() {
    if (genre is EnhancedGenre) {
      return (genre as EnhancedGenre).imagePath;
    }
    return null;
  }

  IconData _getGenreIcon(String genreName) {
    switch (genreName.toLowerCase()) {
      case 'action':
        return Icons.flash_on;
      case 'adventure':
        return Icons.explore;
      case 'comedy':
        return Icons.sentiment_very_satisfied;
      case 'drama':
        return Icons.theater_comedy;
      case 'fantasy':
        return Icons.auto_fix_high;
      case 'horror':
        return Icons.psychology;
      case 'mystery':
        return Icons.help_outline;
      case 'romance':
        return Icons.favorite;
      case 'sci-fi':
      case 'science fiction':
        return Icons.rocket_launch;
      case 'slice of life':
        return Icons.home;
      case 'sports':
        return Icons.sports_soccer;
      case 'supernatural':
        return Icons.visibility;
      case 'thriller':
        return Icons.warning;
      case 'music':
        return Icons.music_note;
      case 'school':
        return Icons.school;
      case 'military':
        return Icons.security;
      case 'historical':
        return Icons.history_edu;
      case 'mecha':
        return Icons.precision_manufacturing;
      case 'shounen':
        return Icons.sports_martial_arts;
      case 'shoujo':
        return Icons.favorite_border;
      case 'seinen':
        return Icons.person;
      case 'josei':
        return Icons.woman;
      default:
        return Icons.movie;
    }
  }
} 
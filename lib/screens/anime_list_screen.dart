import 'package:flutter/material.dart';
import 'package:jikan_api/jikan_api.dart';
import '../widgets/anime_cards.dart';
import '../models/mock_models.dart';
import 'anime_detail_screen.dart';
import '../utils/anime_utils.dart';

typedef PageLoadFunction = Future<List<Map<String, dynamic>>> Function(int page);

class AnimeListScreen extends StatefulWidget {
  final String title;
  final List<Anime>? animeList;
  final List<Map<String, dynamic>>? animeMaps;
  final bool showAsGrid;
  final PageLoadFunction? pageLoad;

  const AnimeListScreen({
    super.key,
    required this.title,
    required this.animeList,
    this.showAsGrid = false,
    this.pageLoad,
  }) : animeMaps = null;

  const AnimeListScreen.fromMaps({
    super.key,
    required this.title,
    required this.animeMaps,
    this.showAsGrid = false,
    this.pageLoad,
  }) : animeList = null;

  const AnimeListScreen.withPageLoad({
    super.key,
    required this.title,
    required this.pageLoad,
    this.showAsGrid = true,
  }) : animeList = null, animeMaps = null;

  @override
  State<AnimeListScreen> createState() => _AnimeListScreenState();
}

class _AnimeListScreenState extends State<AnimeListScreen> {
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _allAnimes = [];
  bool _isLoading = false;
  bool _hasMoreData = true;
  int _currentPage = 1;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _initializeData() {
    if (widget.pageLoad != null) {
      // Use pageLoad function for infinite scroll
      _loadNextPage();
    } else if (widget.animeList != null) {
      // Convert existing animeList to maps and deduplicate
      final convertedList = widget.animeList!.map((anime) => _convertJikanAnimeToMap(anime)).toList();
      _allAnimes = AnimeUtils.deduplicateAnimeMaps(convertedList);
    } else if (widget.animeMaps != null) {
      // Use existing animeMaps and deduplicate
      _allAnimes = AnimeUtils.deduplicateAnimeMaps(List.from(widget.animeMaps!));
    }
  }

  void _onScroll() {
    if (widget.pageLoad == null || _isLoading || !_hasMoreData) return;
    
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadNextPage();
    }
  }

  Future<void> _loadNextPage() async {
    if (_isLoading || !_hasMoreData || widget.pageLoad == null) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final newAnimes = await widget.pageLoad!(_currentPage);
      
      setState(() {
        if (newAnimes.isEmpty) {
          _hasMoreData = false;
        } else {
          _allAnimes.addAll(newAnimes);
          // Deduplicate the combined list to avoid duplicates from pagination
          _allAnimes = AnimeUtils.deduplicateAnimeMaps(_allAnimes);
          _currentPage++;
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  bool _isEmpty() {
    return _allAnimes.isEmpty && !_isLoading;
  }

  MockAnime _getAnimeAt(int index) {
    return _convertMapToMockAnime(_allAnimes[index]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(
          widget.title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        foregroundColor: theme.colorScheme.onSurface,
      ),
      body: _buildBody(theme),
    );
  }

  Widget _buildBody(ThemeData theme) {
    if (_isEmpty() && !_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.movie_outlined,
              size: 64,
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              _error != null ? 'Error loading anime' : 'No anime found',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _currentPage = 1;
                    _allAnimes.clear();
                    _hasMoreData = true;
                    _error = null;
                  });
                  _loadNextPage();
                },
                child: const Text('Retry'),
              ),
            ],
          ],
        ),
      );
    }

    if (_isLoading && _allAnimes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return widget.showAsGrid ? _buildGridView(theme) : _buildListView(theme);
  }

  Widget _buildGridView(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: GridView.builder(
        controller: _scrollController,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.65,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: _allAnimes.length + (_isLoading ? 3 : 0), // Add loading placeholders
        itemBuilder: (context, index) {
          if (index >= _allAnimes.length) {
            // Loading placeholder
            return Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: theme.colorScheme.outline.withOpacity(0.2),
                ),
              ),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          final mockAnime = _getAnimeAt(index);
          return SeasonAnimeCard(
            anime: mockAnime,
            onTap: () => _showAnimeDetails(context, mockAnime),
          );
        },
      ),
    );
  }

  Widget _buildListView(ThemeData theme) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(16.0),
      itemCount: _allAnimes.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _allAnimes.length) {
          // Loading indicator
          return const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final mockAnime = _getAnimeAt(index);
        
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: TrendingAnimeCard(
            anime: mockAnime,
            onTap: () => _showAnimeDetails(context, mockAnime),
          ),
        );
      },
    );
  }

  // Convert Jikan API Anime to Map
  Map<String, dynamic> _convertJikanAnimeToMap(Anime anime) {
    return {
      'malId': anime.malId,
      'url': anime.url ?? '',
      'imageUrl': anime.imageUrl ?? '',
      'title': anime.title ?? '',
      'titleEnglish': anime.titleEnglish,
      'titleJapanese': anime.titleJapanese,
      'episodes': anime.episodes,
      'status': anime.status ?? '',
      'aired': anime.aired ?? '',
      'score': anime.score,
      'scoredBy': anime.scoredBy,
      'rank': anime.rank,
      'popularity': anime.popularity,
      'members': anime.members,
      'favorites': anime.favorites,
      'synopsis': anime.synopsis,
      'background': anime.background,
      'season': anime.season,
      'year': anime.year,
      'broadcast': anime.broadcast,
      'source': anime.source,
      'duration': anime.duration,
      'rating': anime.rating,
      'genres': anime.genres?.map((genre) => {
        'malId': genre.malId,
        'name': genre.name,
      }).toList() ?? [],
      'studios': anime.studios?.map((studio) => {
        'malId': studio.malId,
        'name': studio.name,
      }).toList() ?? [],
    };
  }

  // Convert Map format to MockAnime for compatibility with existing widgets
  MockAnime _convertMapToMockAnime(Map<String, dynamic> animeMap) {
    return MockAnime(
      malId: animeMap['malId'] ?? 0,
      url: animeMap['url'] ?? '',
      imageUrl: animeMap['imageUrl'] ?? '',
      title: animeMap['title'] ?? '',
      titleEnglish: animeMap['titleEnglish'],
      titleJapanese: animeMap['titleJapanese'],
      episodes: animeMap['episodes'],
      status: animeMap['status'],
      aired: animeMap['aired'],
      score: animeMap['score']?.toDouble(),
      scoredBy: animeMap['scoredBy'],
      rank: animeMap['rank'],
      popularity: animeMap['popularity'],
      members: animeMap['members'],
      favorites: animeMap['favorites'],
      synopsis: animeMap['synopsis'],
      background: animeMap['background'],
      season: animeMap['season'],
      year: animeMap['year'],
      broadcast: animeMap['broadcast'],
      source: animeMap['source'],
      duration: animeMap['duration'],
      rating: animeMap['rating'],
      genres: (animeMap['genres'] as List?)?.map((genreMap) => 
        MockGenre(
          malId: genreMap['malId'] ?? 0, 
          name: genreMap['name'] ?? ''
        )
      ).toList() ?? [],
      studios: (animeMap['studios'] as List?)?.map((studioMap) => 
        MockStudio(
          malId: studioMap['malId'] ?? 0, 
          name: studioMap['name'] ?? ''
        )
      ).toList() ?? [],
    );
  }

  void _showAnimeDetails(BuildContext context, MockAnime anime) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AnimeDetailScreen(animeId: anime.malId),
      ),
    );
  }
} 
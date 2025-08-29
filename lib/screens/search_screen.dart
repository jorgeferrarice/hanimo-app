import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/jikan_service.dart';
import '../models/mock_models.dart';
import 'anime_detail_screen.dart';
import '../widgets/cached_image.dart';
import '../services/analytics_service.dart';
import '../utils/anime_utils.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final JikanService _jikanService = JikanService();
  final ScrollController _scrollController = ScrollController();
  
  List<Map<String, dynamic>> _animeResults = [];
  bool _isLoading = false;
  String? _error;
  int _currentPage = 1;
  bool _hasMoreResults = true;
  String _currentQuery = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMoreResults();
    }
  }

  void _resetSearchState() {
    setState(() {
      _isLoading = false;
      _error = null;
      _animeResults = [];
      _currentPage = 1;
      _hasMoreResults = true;
      _currentQuery = '';
    });
  }

  Future<void> _searchAnime(String query, {bool isLoadMore = false}) async {
    if (query.trim().isEmpty) {
      _resetSearchState();
      return;
    }

    if (_isLoading) return;

    try {
      setState(() {
        _isLoading = true;
        if (!isLoadMore) {
          _error = null;
          _animeResults = [];
          _currentPage = 1;
          _currentQuery = query;
        }
      });

      debugPrint('🔍 [SearchScreen] Searching for: "$query" (page: $_currentPage)');

      final results = await _jikanService.searchAnime(
        query: query,
        page: _currentPage,
      );

      setState(() {
        if (isLoadMore) {
          _animeResults.addAll(results);
          // Deduplicate the combined results to avoid duplicates from pagination
          _animeResults = AnimeUtils.deduplicateAnimeMaps(_animeResults);
        } else {
          _animeResults = AnimeUtils.deduplicateAnimeMaps(results);
        }
        _hasMoreResults = results.length >= 20; // Jikan typically returns 20+ per page
        _currentPage++;
        _isLoading = false;
      });

      // Log analytics event for search (only on first page, not for load more)
      if (!isLoadMore) {
        await _logSearchEvent(query, results.length);
      }

      debugPrint('✅ [SearchScreen] Found ${results.length} anime results');
    } catch (e, stackTrace) {
      debugPrint('❌ [SearchScreen] Search failed: $e');
      debugPrint('   Stack trace: $stackTrace');
      
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _loadMoreResults() {
    if (_hasMoreResults && !_isLoading && _currentQuery.isNotEmpty) {
      _searchAnime(_currentQuery, isLoadMore: true);
    }
  }

  void _onSearchChanged(String query) {
    // Debounce search to avoid too many API calls
    Future.delayed(const Duration(milliseconds: 500), () {
      if (_searchController.text == query) {
        _searchAnime(query);
      }
    });
  }

  Future<void> _logSearchEvent(String query, int resultCount) async {
    try {
      await AnalyticsService.instance.logSearch(
        searchTerm: query,
        resultCount: resultCount,
      );
    } catch (e) {
      debugPrint('❌ [SearchScreen] Failed to log search analytics: $e');
    }
  }

  Future<void> _showAnimeDetails(Map<String, dynamic> animeData) async {
    // Log search result click analytics
    if (_currentQuery.isNotEmpty) {
      final position = _animeResults.indexWhere((anime) => anime['malId'] == animeData['malId']);
      if (position >= 0) {
        await _logSearchResultClick(animeData, position);
      }
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AnimeDetailScreen(animeId: animeData['malId']),
      ),
    );
  }

  Future<void> _logSearchResultClick(Map<String, dynamic> animeData, int position) async {
    try {
      await AnalyticsService.instance.logSearchResultClick(
        searchTerm: _currentQuery,
        animeId: (animeData['malId'] ?? 0).toString(),
        animeTitle: animeData['title'] ?? 'Unknown',
        position: position + 1, // Make it 1-based for analytics
        totalResults: _animeResults.length,
      );
    } catch (e) {
      debugPrint('❌ [SearchScreen] Failed to log search result click analytics: $e');
    }
  }

  Widget _buildAnimeCard(Map<String, dynamic> animeData) {
    final theme = Theme.of(context);
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: () => _showAnimeDetails(animeData),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Anime Cover
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 60,
                  height: 80,
                  color: theme.colorScheme.surfaceVariant,
                  child: CachedImage.animeCover(
                    imageUrl: animeData['imageUrl'] ?? '',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Anime Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      animeData['title'] ?? 'Unknown Title',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (animeData['titleEnglish'] != null && 
                        animeData['titleEnglish'] != animeData['title']) ...[
                      const SizedBox(height: 4),
                      Text(
                        animeData['titleEnglish'],
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (animeData['score'] != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.star,
                                  color: Colors.white,
                                  size: 12,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  animeData['score'].toStringAsFixed(1),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        if (animeData['episodes'] != null) ...[
                          Text(
                            '${animeData['episodes']} eps',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            animeData['status'] ?? 'Unknown',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.secondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, int count, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$count results',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // Search App Bar
          SliverAppBar(
            floating: true,
            pinned: false,
            snap: true,
            backgroundColor: theme.colorScheme.surface,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.pop(context),
            ),
            title: Container(
              height: 40,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search anime...',
                  hintStyle: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ),
          
          // Content
          if (_error != null)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Search failed',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        _error!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => _searchAnime(_currentQuery),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          else if (_isLoading && _animeResults.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(),
              ),
            )
          else if (_animeResults.isEmpty && _currentQuery.isNotEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search_off,
                      size: 64,
                      color: theme.colorScheme.onSurface.withOpacity(0.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No anime found',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Try different keywords',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.4),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (_animeResults.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search,
                      size: 64,
                      color: theme.colorScheme.onSurface.withOpacity(0.3),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Search for anime',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter anime title to get started',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.4),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildListDelegate([
                // Anime Results
                _buildSectionHeader('Anime', _animeResults.length, theme),
                ..._animeResults.map((anime) => _buildAnimeCard(anime)).toList(),
                
                // Load More Indicator
                if (_isLoading && _animeResults.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                
                // End of Results Indicator
                if (!_hasMoreResults && _animeResults.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: Text(
                        'No more results',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ),
                  ),
                
                const SizedBox(height: 20),
              ]),
            ),
        ],
      ),
    );
  }
} 
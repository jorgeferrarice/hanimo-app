import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_redux/flutter_redux.dart';

import 'package:url_launcher/url_launcher.dart';
import '../services/jikan_service.dart';
import '../services/followed_anime_service.dart';
import '../services/youtube_service.dart';
import '../widgets/banner_ad_widget.dart';
import '../widgets/add_to_watchlist_dialog.dart';
import '../widgets/cached_image.dart';
import '../widgets/episode_calendar_sync_dialog.dart';
import '../redux/app_state.dart' as redux;
import '../redux/actions.dart';
import '../services/analytics_service.dart';

class AnimeDetailScreen extends StatefulWidget {
  final int animeId;

  const AnimeDetailScreen({
    super.key,
    required this.animeId,
  });

  @override
  State<AnimeDetailScreen> createState() => _AnimeDetailScreenState();
}

class _AnimeDetailScreenState extends State<AnimeDetailScreen> with TickerProviderStateMixin {
  final JikanService _jikanService = JikanService();
  final YouTubeService _youtubeService = YouTubeService();
  
  bool _isLoading = true;
  bool _isUpdatingWatchlist = false;
  bool _isUpdatingFavorite = false;
  String? _error;
  
  Map<String, dynamic>? _animeData;
  List<Map<String, dynamic>>? _episodes;
  
  // Reviews state
  List<Map<String, dynamic>>? _reviews;
  bool _reviewsLoading = false;
  bool _hasMoreReviews = true;
  int _reviewsPage = 1;
  String? _reviewsError;
  final ScrollController _reviewsScrollController = ScrollController();
  
  // Pictures state
  List<Map<String, dynamic>>? _pictures;
  
  // YouTube trailer state
  Map<String, dynamic>? _trailer;
  bool _isLoadingTrailer = false;
  String? _trailerError;
  
  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _loadAnimeData();
    
    // Add scroll listener for infinite scrolling
    _reviewsScrollController.addListener(_onReviewsScroll);
  }

  void _initializeTabController() {
    // Dispose old controller if it exists
    _tabController?.dispose();
    
    // Determine available tabs
    List<String> availableTabs = ['Info'];
    
    // Add Episodes tab if episodes are available
    if (_episodes != null && _episodes!.isNotEmpty) {
      availableTabs.add('Episodes');
      // Add Reviews tab only if episodes are available
      availableTabs.add('Reviews');
    }
    
    _tabController = TabController(length: availableTabs.length, vsync: this);
    
    // Add listener for reviews tab (if it exists)
    if (availableTabs.contains('Reviews')) {
      _tabController!.addListener(() {
        int reviewsIndex = availableTabs.indexOf('Reviews');
        if (_tabController!.index == reviewsIndex && _reviews == null && !_reviewsLoading) {
          _loadReviews();
        }
      });
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _reviewsScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadAnimeData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      debugPrint('🎯 [AnimeDetailScreen] Loading anime data for ID: ${widget.animeId}');

      // Fetch anime data, episodes, and pictures in parallel
      final results = await Future.wait([
        _jikanService.getAnime(widget.animeId),
        _jikanService.getAnimeEpisodes(widget.animeId, page: 1),
        _jikanService.getAnimePicturesAsMap(widget.animeId),
      ]);

      final animeData = results[0] as Map<String, dynamic>;
      final episodesData = results[1] as List<Map<String, dynamic>>;
      final picturesData = results[2] as List<Map<String, dynamic>>;

      setState(() {
        _animeData = animeData;
        _episodes = episodesData;
        _pictures = picturesData;
        _isLoading = false;
      });
      
      // Log analytics event for anime details view
      await _logAnimeDetailsView(animeData);
      
      // Load trailer asynchronously after page is rendered
      _loadTrailerAsync(animeData['title'] ?? '');
      
      // Initialize tab controller after data is loaded
      _initializeTabController();

      debugPrint('✅ [AnimeDetailScreen] Successfully loaded anime "${animeData['title']}" with ${episodesData.length} episodes');
    } catch (e, stackTrace) {
      debugPrint('❌ [AnimeDetailScreen] Failed to load anime data:');
      debugPrint('   • Error: $e');
      debugPrint('   • Stack trace: $stackTrace');
      
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadReviews({bool isLoadMore = false}) async {
    if (_reviewsLoading || (!_hasMoreReviews && isLoadMore)) return;

    try {
      setState(() {
        _reviewsLoading = true;
        if (!isLoadMore) {
          _reviewsError = null;
          _reviewsPage = 1;
        }
      });

      debugPrint('📝 [AnimeDetailScreen] Loading reviews page ${_reviewsPage} for anime ID: ${widget.animeId}');

      final newReviews = await _jikanService.getAnimeReviews(widget.animeId, page: _reviewsPage);

      setState(() {
        if (isLoadMore) {
          _reviews!.addAll(newReviews);
        } else {
          _reviews = newReviews;
        }
        
        _hasMoreReviews = newReviews.isNotEmpty && newReviews.length >= 25; // Jikan typically returns 25 per page
        _reviewsPage++;
        _reviewsLoading = false;
      });

      debugPrint('✅ [AnimeDetailScreen] Successfully loaded ${newReviews.length} reviews (total: ${_reviews!.length})');
    } catch (e, stackTrace) {
      debugPrint('❌ [AnimeDetailScreen] Failed to load reviews:');
      debugPrint('   • Error: $e');
      debugPrint('   • Stack trace: $stackTrace');
      
      setState(() {
        _reviewsError = e.toString();
        _reviewsLoading = false;
      });
    }
  }

  void _onReviewsScroll() {
    if (_reviewsScrollController.position.pixels >= _reviewsScrollController.position.maxScrollExtent - 200) {
      _loadReviews(isLoadMore: true);
    }
  }

  /// Load YouTube trailer asynchronously without blocking page rendering
  Future<void> _loadTrailerAsync(String animeTitle) async {
    if (animeTitle.isEmpty) return;
    
    setState(() {
      _isLoadingTrailer = true;
      _trailerError = null;
    });

    try {
      final searchQuery = 'Anime Trailer Official Eng Sub $animeTitle';
      debugPrint('🎬 [AnimeDetailScreen] Loading trailer asynchronously: $searchQuery');
      
      final videos = await _youtubeService.searchAnimeVideos(widget.animeId, searchQuery, maxResults: 1);
      
      if (mounted) {
        setState(() {
          if (videos.isNotEmpty) {
            _trailer = videos.first;
            debugPrint('✅ [AnimeDetailScreen] Trailer loaded asynchronously: ${_trailer!['title']}');
          } else {
            debugPrint('⚠️ [AnimeDetailScreen] No trailer found for: $searchQuery');
          }
          _isLoadingTrailer = false;
        });
      }
    } catch (e) {
      debugPrint('❌ [AnimeDetailScreen] Failed to load trailer asynchronously: $e');
      if (mounted) {
        setState(() {
          _trailerError = e.toString();
          _isLoadingTrailer = false;
        });
      }
    }
  }

  Future<void> _logAnimeDetailsView(Map<String, dynamic> animeData) async {
    try {
      await AnalyticsService.instance.logAnimeDetailsView(
        animeId: (animeData['malId'] ?? 0).toString(),
        animeTitle: animeData['title'] ?? 'Unknown',
        genre: animeData['genres']?.isNotEmpty == true 
            ? animeData['genres'][0]['name'] 
            : null,
        status: animeData['status'],
        year: animeData['year'],
        score: animeData['score']?.toDouble(),
      );
    } catch (e) {
      debugPrint('❌ [AnimeDetailScreen] Failed to log analytics: $e');
    }
  }

  Widget _buildBackgroundCarousel() {
    if (_pictures != null && _pictures!.isNotEmpty) {
      // Use PageView if pictures are available
      final allImages = [
        _animeData!['imageUrl'], // Original image first
        ..._pictures!.map((pic) => pic['largeImageUrl'] ?? pic['imageUrl']).where((url) => url != null && url.isNotEmpty),
      ].where((url) => url != null && url.isNotEmpty).toList();

      if (allImages.length > 1) {
        return PageView.builder(
          itemCount: allImages.length,
          itemBuilder: (context, index) {
            return CachedImage.animeCover(
              imageUrl: allImages[index],
              fit: BoxFit.cover,
              borderRadius: BorderRadius.zero,
            );
          },
        );
      }
    }
    
    // Fallback to single image
    return CachedImage.animeCover(
      imageUrl: _animeData!['imageUrl'],
      fit: BoxFit.cover,
      borderRadius: BorderRadius.zero,
    );
  }

  Widget _buildTrailerSection(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Video',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 2,
            width: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.secondary,
                ],
              ),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          const SizedBox(height: 20),
          _buildTrailerContent(theme),
        ],
      ),
    );
  }

  Widget _buildTrailerContent(ThemeData theme) {
    if (_isLoadingTrailer) {
      return _buildTrailerLoadingState(theme);
    }
    
    if (_trailerError != null) {
      return _buildTrailerErrorState(theme);
    }
    
    if (_trailer != null) {
      return _buildTrailerPlayer(theme);
    }
    
    // No trailer available
    return _buildNoTrailerState(theme);
  }

  Widget _buildTrailerLoadingState(ThemeData theme) {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading trailer...',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrailerErrorState(ThemeData theme) {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.error.withOpacity(0.3),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: theme.colorScheme.error.withOpacity(0.7),
          ),
          const SizedBox(height: 16),
          Text(
            'Failed to load trailer',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.error,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Unable to fetch video content',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoTrailerState(ThemeData theme) {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.videocam_off_outlined,
            size: 48,
            color: theme.colorScheme.onSurface.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No trailer available',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Trailer not found for this anime',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrailerPlayer(ThemeData theme) {
    return GestureDetector(
      onTap: () async {
        final url = _trailer!['url'];
        if (await canLaunchUrl(Uri.parse(url))) {
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        width: double.infinity,
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Thumbnail
              CachedImage.animeCover(
                imageUrl: _trailer!['thumbnailUrl'] ?? '',
                fit: BoxFit.cover,
                borderRadius: BorderRadius.zero,
              ),
              // Dark overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.2),
                      Colors.black.withOpacity(0.6),
                    ],
                  ),
                ),
              ),
              // Play button
              Center(
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.9),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
              // Video info
              Positioned(
                bottom: 12,
                left: 12,
                right: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _trailer!['title'] ?? 'Trailer',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          const Shadow(
                            color: Colors.black,
                            offset: Offset(1, 1),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _trailer!['channelTitle'] ?? '',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withOpacity(0.9),
                        shadows: [
                          const Shadow(
                            color: Colors.black,
                            offset: Offset(1, 1),
                            blurRadius: 2,
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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

  Widget _buildPicturesSection(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Images',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 2,
            width: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.secondary,
                ],
              ),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          _buildPicturesGrid(theme),
        ],
      ),
    );
  }

  Widget _buildPicturesGrid(ThemeData theme) {
    final totalPictures = _pictures!.length;
    final displayCount = totalPictures > 4 ? 4 : totalPictures;
    final hasMore = totalPictures > 4;
    
    return GridView.builder(
      padding: const EdgeInsets.only(top: 20),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 16 / 9,
      ),
      itemCount: displayCount,
      itemBuilder: (context, index) {
        // Show "+N" on the 4th slot if there are more than 4 images
        if (hasMore && index == 3) {
          final remainingCount = totalPictures - 3;
          return GestureDetector(
            onTap: () => _showImageGallery(0), // Start from first image
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Background image (4th image)
                    CachedImage.animeCover(
                      imageUrl: _pictures![3]['imageUrl'] ?? '',
                      fit: BoxFit.cover,
                      borderRadius: BorderRadius.zero,
                    ),
                    // Dark overlay
                    Container(
                      color: Colors.black.withOpacity(0.7),
                      child: Center(
                        child: Text(
                          '+$remainingCount',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        
        // Regular image display
        final picture = _pictures![index];
        return GestureDetector(
          onTap: () => _showImageGallery(index),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Picture thumbnail
                  CachedImage.animeCover(
                    imageUrl: picture['imageUrl'] ?? '',
                    fit: BoxFit.cover,
                    borderRadius: BorderRadius.zero,
                  ),
                  // Gallery icon overlay (only for first 3 images)
                  if (!hasMore || index < 3)
                    Container(
                      color: Colors.black.withOpacity(0.3),
                      child: const Center(
                        child: Icon(
                          Icons.photo_library,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showImageGallery(int initialIndex) {
    showDialog(
      context: context,
      barrierColor: Colors.black,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: ImageGalleryViewer(
          pictures: _pictures!,
          initialIndex: initialIndex,
          animeTitle: _animeData!['title'] ?? 'Unknown Title',
        ),
      ),
    );
  }

  void _showAddToWatchlistDialog() {
    showDialog(
      context: context,
      builder: (context) => AddToWatchlistDialog(
        animeTitle: _animeData!['title'] ?? 'Unknown Title',
        totalEpisodes: _animeData!['episodes'],
        animeData: _animeData,
        isEditMode: false,
        onSave: (data) {
          // The dialog now handles the Redux action internally
          debugPrint('Dialog data: $data');
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Added to watchlist'),
            ),
          );
        },
      ),
    );
  }

  void _showEditWatchlistDialog() {
    // Get current user anime data from Redux store
    final store = StoreProvider.of<redux.AppState>(context);
    final userAnime = store.state.myAnimes.firstWhere(
      (anime) => anime.malId == widget.animeId,
      orElse: () => throw StateError('Anime not found in user collection'),
    );

    showDialog(
      context: context,
      builder: (context) => AddToWatchlistDialog(
        animeTitle: _animeData!['title'] ?? 'Unknown Title',
        totalEpisodes: _animeData!['episodes'],
        animeData: _animeData,
        isEditMode: true,
        currentUserAnime: userAnime,
        onSave: (data) {
          debugPrint('Dialog data: $data');
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['removed'] == true ? 'Removed from watchlist' : 'Updated watchlist'),
            ),
          );
        },
      ),
    );
  }

  void _showEpisodeCalendarDialog() {
    if (_animeData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Anime data not available')),
      );
      return;
    }

    if (_episodes == null || _episodes!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No episodes available for calendar sync')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => EpisodeCalendarSyncDialog(
        animeData: _animeData!,
        episodes: _episodes!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Loading...'),
          backgroundColor: theme.colorScheme.surface,
          foregroundColor: theme.colorScheme.onSurface,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Error'),
          backgroundColor: theme.colorScheme.surface,
          foregroundColor: theme.colorScheme.onSurface,
        ),
        body: Center(
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
                'Failed to load anime',
                style: theme.textTheme.titleLarge?.copyWith(
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
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _loadAnimeData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_animeData == null || _tabController == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Not Found'),
          backgroundColor: theme.colorScheme.surface,
          foregroundColor: theme.colorScheme.onSurface,
        ),
        body: const Center(
          child: Text('Anime not found'),
        ),
      );
    }

    return Scaffold(
      body: Column(
        children: [
          // Main content
          Expanded(
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  // Hero Image App Bar
                  SliverAppBar(
                    expandedHeight: 400,
                    pinned: true,
                    stretch: true,
                    backgroundColor: theme.colorScheme.surface,
                    leading: Container(
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                    flexibleSpace: FlexibleSpaceBar(
                      background: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Background Image or Carousel
                          _buildBackgroundCarousel(),
                          // Gradient Overlay
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.3),
                                  Colors.black.withOpacity(0.8),
                                ],
                                stops: const [0.0, 0.5, 1.0],
                              ),
                            ),
                          ),
                          // Title and basic info
                          Positioned(
                            bottom: 20,
                            left: 20,
                            right: 20,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _animeData!['title'] ?? 'Unknown Title',
                                  style: theme.textTheme.headlineMedium?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    shadows: [
                                      Shadow(
                                        offset: const Offset(0, 2),
                                        blurRadius: 4,
                                        color: Colors.black.withOpacity(0.8),
                                      ),
                                    ],
                                  ),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (_animeData!['titleEnglish'] != null && 
                                    _animeData!['titleEnglish'] != _animeData!['title']) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    _animeData!['titleEnglish'],
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      color: Colors.white.withOpacity(0.9),
                                      shadows: [
                                        Shadow(
                                          offset: const Offset(0, 1),
                                          blurRadius: 2,
                                          color: Colors.black.withOpacity(0.8),
                                        ),
                                      ],
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    if (_animeData!['score'] != null) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.amber,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.star,
                                              color: Colors.white,
                                              size: 16,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              _animeData!['score'].toStringAsFixed(1),
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                    ],
                                    if (_animeData!['rank'] != null) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.primary,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          '#${_animeData!['rank']}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                    ],
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(_animeData!['status']),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        _animeData!['status'] ?? 'Unknown',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
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
                    actions: [
                      Container(
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: StoreConnector<redux.AppState, bool>(
                          converter: (store) => store.state.isAnimeFavorited(widget.animeId),
                          builder: (context, isFavorited) {
                            return IconButton(
                              icon: _isUpdatingFavorite
                                  ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : Icon(
                                      isFavorited ? Icons.favorite : Icons.favorite_border,
                                      color: isFavorited ? Colors.red : Colors.white,
                                    ),
                              onPressed: _isUpdatingFavorite ? null : () async {
                                try {
                                  setState(() {
                                    _isUpdatingFavorite = true;
                                  });

                                  final store = StoreProvider.of<redux.AppState>(context);
                                  
                                  if (isFavorited) {
                                    // Remove from favorites
                                    await store.dispatch(removeFavoriteAction(widget.animeId));
                                    
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Removed from favorites'),
                                        ),
                                      );
                                    }
                                  } else {
                                    // Add to favorites
                                    await store.dispatch(addFavoriteAction(_animeData!));
                                    
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Added to favorites'),
                                        ),
                                      );
                                    }
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Failed to update favorites: $e'),
                                        backgroundColor: Theme.of(context).colorScheme.error,
                                      ),
                                    );
                                  }
                                } finally {
                                  if (mounted) {
                                    setState(() {
                                      _isUpdatingFavorite = false;
                                    });
                                  }
                                }
                              },
                            );
                          },
                        ),
                      ),
                      // Only show calendar button if episodes are available
                      if (_episodes != null && _episodes!.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            icon: const Icon(Icons.calendar_today, color: Colors.white),
                            onPressed: () {
                              _showEpisodeCalendarDialog();
                            },
                          ),
                        ),
                    ],
                  ),
                  
                  // Action Button
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                        width: double.infinity,
                        child: StoreConnector<redux.AppState, bool>(
                          converter: (store) => store.state.isAnimeFollowed(widget.animeId),
                          builder: (context, isFollowed) {
                            return ElevatedButton.icon(
                              onPressed: _isUpdatingWatchlist ? null : () async {
                                if (isFollowed) {
                                  // If already followed, show dialog with current data for editing/removal
                                  _showEditWatchlistDialog();
                                } else {
                                  // If not followed, show dialog to add
                                  _showAddToWatchlistDialog();
                                }
                              },
                              icon: _isUpdatingWatchlist 
                                  ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : Icon(isFollowed ? Icons.check : Icons.add),
                              label: Text(_isUpdatingWatchlist 
                                  ? 'Updating...'
                                  : (isFollowed ? 'In Watchlist' : 'Add to Watchlist')),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isFollowed 
                                    ? theme.colorScheme.primary 
                                    : theme.colorScheme.secondary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  
                  // Tab Bar (only show if there are multiple tabs)
                  if (_tabController!.length > 1)
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _SliverAppBarDelegate(
                        TabBar(
                          controller: _tabController!,
                          labelColor: theme.colorScheme.primary,
                          unselectedLabelColor: theme.colorScheme.onSurface.withOpacity(0.6),
                          indicatorColor: theme.colorScheme.primary,
                          indicatorWeight: 3,
                          labelStyle: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          unselectedLabelStyle: theme.textTheme.titleMedium,
                          tabs: _buildTabs(),
                        ),
                      ),
                    ),
                ];
              },
              body: _tabController!.length > 1
                  ? TabBarView(
                      controller: _tabController!,
                      children: _buildTabViews(theme),
                    )
                  : _buildInfoTab(theme), // Show info tab directly when there's only one tab
            ),
          ),
          
          // Banner Ad at the bottom
          const BannerAdWidget(
            adSize: AdSize.banner,
            margin: EdgeInsets.all(8.0),
            adType: BannerAdType.animeDetails,
          ),
        ],
      ),
    );
}

List<Widget> _buildTabs() {
  List<Widget> tabs = [const Tab(text: 'Info')];
  
  // Add Episodes tab if episodes are available
  if (_episodes != null && _episodes!.isNotEmpty) {
    tabs.add(const Tab(text: 'Episodes'));
    // Add Reviews tab only if episodes are available
    tabs.add(const Tab(text: 'Reviews'));
  }
  
  return tabs;
}

List<Widget> _buildTabViews(ThemeData theme) {
  List<Widget> tabViews = [_buildInfoTab(theme)];
  
  // Add Episodes tab view if episodes are available
  if (_episodes != null && _episodes!.isNotEmpty) {
    tabViews.add(_buildEpisodesTab(theme));
    // Add Reviews tab view only if episodes are available
    tabViews.add(_buildReviewsTab(theme));
  }
  
  return tabViews;
}

Widget _buildEpisodeCard(Map<String, dynamic> episode, ThemeData theme) {
  return Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
        color: theme.colorScheme.outline.withOpacity(0.2),
      ),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              episode['malId'].toString(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                episode['title'] ?? 'Episode ${episode['malId']}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (episode['aired'] != null) ...[
                const SizedBox(height: 4),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatEpisodeAirDate(episode['aired']),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _getRelativeTime(episode['aired']),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary.withOpacity(0.8),
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ],
              if (episode['score'] != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.star,
                      size: 14,
                      color: Colors.amber,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      episode['score'].toStringAsFixed(1),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _buildInfoTab(ThemeData theme) {
  return SingleChildScrollView(
    padding: const EdgeInsets.only(bottom: 80),
    child: Column(
      children: [
        // Trailer (First section) - Always show section, content handles loading states
        _buildTrailerSection(theme),
        
        // Pictures (Second section)
        if (_pictures != null && _pictures!.isNotEmpty) ...[
          _buildPicturesSection(theme),
        ],
        
        // Synopsis
        if (_animeData!['synopsis'] != null && _animeData!['synopsis'].toString().trim().isNotEmpty) ...[
          _buildSection(
            'Synopsis',
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _animeData!['synopsis'],
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.6,
                ),
                textAlign: TextAlign.left,
              ),
            ),
            theme,
          ),
        ],
        
        // Information
        _buildSection(
          'Information',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_animeData!['titleJapanese'] != null)
                _buildInfoRow('Japanese Title', _animeData!['titleJapanese'], theme),
              if (_animeData!['episodes'] != null)
                _buildInfoRow('Episodes', _animeData!['episodes'].toString(), theme),
              if (_animeData!['aired'] != null)
                _buildInfoRow('Aired', _animeData!['aired'], theme),
              if (_animeData!['season'] != null && _animeData!['year'] != null)
                _buildInfoRow('Season', '${_animeData!['season']} ${_animeData!['year']}', theme),
              if (_animeData!['broadcast'] != null)
                _buildInfoRow('Broadcast', _animeData!['broadcast'], theme),
              if (_animeData!['source'] != null)
                _buildInfoRow('Source', _animeData!['source'], theme),
              if (_animeData!['duration'] != null)
                _buildInfoRow('Duration', _animeData!['duration'], theme),
              if (_animeData!['rating'] != null)
                _buildInfoRow('Rating', _animeData!['rating'], theme),
            ],
          ),
          theme,
        ),
        
        // Statistics
        _buildSection(
          'Statistics',
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_animeData!['score'] != null)
                _buildInfoRow('Score', '${_animeData!['score'].toStringAsFixed(2)}/10', theme),
              if (_animeData!['scoredBy'] != null)
                _buildInfoRow('Scored by', _formatNumber(_animeData!['scoredBy']), theme),
              if (_animeData!['rank'] != null)
                _buildInfoRow('Ranked', '#${_animeData!['rank']}', theme),
              if (_animeData!['popularity'] != null)
                _buildInfoRow('Popularity', '#${_animeData!['popularity']}', theme),
              if (_animeData!['members'] != null)
                _buildInfoRow('Members', _formatNumber(_animeData!['members']), theme),
              if (_animeData!['favorites'] != null)
                _buildInfoRow('Favorites', _formatNumber(_animeData!['favorites']), theme),
            ],
          ),
          theme,
        ),
        
        // Genres
        if (_animeData!['genres'] != null && (_animeData!['genres'] as List).isNotEmpty) ...[
          _buildSection(
            'Genres',
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                alignment: WrapAlignment.start,
                spacing: 8,
                runSpacing: 8,
                children: (_animeData!['genres'] as List).map((genre) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.primary.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    genre['name'] ?? '',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )).toList(),
              ),
            ),
            theme,
          ),
        ],
        
        // Studios
        if (_animeData!['studios'] != null && (_animeData!['studios'] as List).isNotEmpty) ...[
          _buildSection(
            'Studios',
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                alignment: WrapAlignment.start,
                spacing: 8,
                runSpacing: 8,
                children: (_animeData!['studios'] as List).map((studio) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: theme.colorScheme.secondary.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    studio['name'] ?? '',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.secondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                )).toList(),
              ),
            ),
            theme,
          ),
        ],
        
        // Background
        if (_animeData!['background'] != null && _animeData!['background'].toString().trim().isNotEmpty) ...[
          _buildSection(
            'Background',
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _animeData!['background'],
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.6,
                ),
                textAlign: TextAlign.left,
              ),
            ),
            theme,
          ),
        ],
      ],
    ),
  );
}

Widget _buildEpisodesTab(ThemeData theme) {
  if (_episodes == null || _episodes!.isEmpty) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.tv_off,
            size: 64,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'No episodes available',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  return ListView.builder(
    padding: const EdgeInsets.all(16),
    itemCount: _episodes!.length,
    itemBuilder: (context, index) {
      final episode = _episodes![index];
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _buildEpisodeCard(episode, theme),
      );
    },
  );
}

Widget _buildReviewsTab(ThemeData theme) {
  // Show loading state for initial load
  if (_reviews == null && _reviewsLoading) {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  // Show error state
  if (_reviewsError != null && (_reviews == null || _reviews!.isEmpty)) {
    return Center(
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
            'Failed to load reviews',
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _reviewsError!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => _loadReviews(),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  // Show empty state
  if (_reviews == null || _reviews!.isEmpty) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.rate_review_outlined,
            size: 64,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'No reviews available',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  // Show reviews with infinite scrolling
  return ListView.builder(
    controller: _reviewsScrollController,
    padding: const EdgeInsets.all(16),
    itemCount: _reviews!.length + (_hasMoreReviews ? 1 : 0),
    itemBuilder: (context, index) {
      if (index >= _reviews!.length) {
        // Loading indicator at the bottom
        return Container(
          padding: const EdgeInsets.all(16),
          alignment: Alignment.center,
          child: _reviewsLoading
              ? const CircularProgressIndicator()
              : const SizedBox.shrink(),
        );
      }

      final review = _reviews![index];
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: _buildReviewCard(review, theme),
      );
    },
  );
}

Widget _buildReviewCard(Map<String, dynamic> review, ThemeData theme) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: theme.colorScheme.outline.withOpacity(0.2),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with user info and rating
        Row(
          children: [
            // User avatar
            CircleAvatar(
              radius: 20,
              backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
              child: Text(
                (review['user'] != null && review['user']['username'] != null) 
                    ? review['user']['username'].substring(0, 1).toUpperCase() 
                    : 'U',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (review['user'] != null && review['user']['username'] != null) 
                        ? review['user']['username'] 
                        : 'Anonymous',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (review['date'] != null) ...[
                    Text(
                      _formatReviewDate(review['date']),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Overall rating
            if (review['score'] != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getScoreColor(review['score']),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.star,
                      size: 14,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      review['score'].toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        
        const SizedBox(height: 12),
        
        // Review content
        Text(
          review['review'] ?? 'No review text available.',
          style: theme.textTheme.bodyMedium?.copyWith(
            height: 1.5,
          ),
          maxLines: 8,
          overflow: TextOverflow.ellipsis,
        ),
        
        const SizedBox(height: 8),
        
        // Review metadata
        Row(
          children: [
            Icon(
              Icons.rate_review,
              size: 16,
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
            const SizedBox(width: 4),
            Text(
              'Review',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

Color _getScoreColor(int score) {
  if (score >= 8) return Colors.green;
  if (score >= 6) return Colors.orange;
  return Colors.red;
}

String _formatReviewDate(String dateString) {
  try {
    final date = DateTime.parse(dateString);
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 365) {
      final years = difference.inDays ~/ 365;
      return '${years} year${years > 1 ? 's' : ''} ago';
    } else if (difference.inDays > 30) {
      final months = difference.inDays ~/ 30;
      return '${months} month${months > 1 ? 's' : ''} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else {
      return 'Today';
    }
  } catch (e) {
    return dateString;
  }
}

String _formatEpisodeAirDate(String airDateString) {
  try {
    // Parse the air date string (format might vary from Jikan API)
    DateTime airDate;
    
    // Try different parsing formats that Jikan API might use
    if (airDateString.contains('T')) {
      // ISO format: 2023-10-01T15:30:00+00:00
      airDate = DateTime.parse(airDateString);
    } else if (airDateString.contains(' ')) {
      // Format: "Oct 1, 2023 at 3:30 PM JST"
      // This is a simplified parser - in production you'd want more robust parsing
      final parts = airDateString.split(' ');
      if (parts.length >= 3) {
        // Try to extract date components
        final year = int.tryParse(parts.last.replaceAll(',', ''));
        if (year != null) {
          // For now, return formatted string as-is if complex parsing fails
          return airDateString;
        }
      }
      airDate = DateTime.now(); // Fallback
    } else {
      // Simple date format
      airDate = DateTime.parse(airDateString);
    }
    
    // Format as MM/DD/YYYY (removed hours and minutes)
    final month = airDate.month.toString().padLeft(2, '0');
    final day = airDate.day.toString().padLeft(2, '0');
    final year = airDate.year;
    
    return '$month/$day/$year';
  } catch (e) {
    // If parsing fails, return the original string
    return airDateString;
  }
}

String _getRelativeTime(String airDateString) {
  try {
    DateTime airDate;
    
    // Parse the air date string
    if (airDateString.contains('T')) {
      airDate = DateTime.parse(airDateString);
    } else {
      // For complex formats, try to extract meaningful info
      // This is a simplified approach
      final currentTime = DateTime.now();
      final parts = airDateString.toLowerCase();
      
      if (parts.contains('ago') || parts.contains('aired')) {
        return 'Already aired';
      } else if (parts.contains('upcoming') || parts.contains('not yet')) {
        return 'Upcoming';
      }
      
      // Fallback parsing
      try {
        airDate = DateTime.parse(airDateString);
      } catch (e) {
        return 'Date unknown';
      }
    }
    
    final now = DateTime.now();
    final difference = airDate.difference(now);
    
    if (difference.isNegative) {
      // Past date
      final pastDifference = now.difference(airDate);
      return _formatRelativeTime(pastDifference, isPast: true);
    } else {
      // Future date
      return _formatRelativeTime(difference, isPast: false);
    }
  } catch (e) {
    return 'Date unknown';
  }
}

String _formatRelativeTime(Duration duration, {required bool isPast}) {
  final days = duration.inDays;
  final years = days ~/ 365;
  final months = (days % 365) ~/ 30;
  final remainingDays = days % 30;
  
  String result = '';
  
  // Build the time components
  if (years > 0) {
    result += years == 1 ? '1 year' : '$years years';
    if (months > 0) {
      result += months == 1 ? ' 1 month' : ' $months months';
    } else if (remainingDays > 0) {
      result += remainingDays == 1 ? ' 1 day' : ' $remainingDays days';
    }
  } else if (months > 0) {
    result += months == 1 ? '1 month' : '$months months';
    if (remainingDays > 0) {
      result += remainingDays == 1 ? ' 1 day' : ' $remainingDays days';
    }
  } else if (days > 0) {
    result += days == 1 ? '1 day' : '$days days';
  } else {
    result = 'today';
  }
  
  // Add past/future prefix/suffix
  if (result == 'today') {
    return 'today';
  } else if (isPast) {
    return '$result ago';
  } else {
    return 'in $result';
  }
}

Widget _buildSection(String title, Widget content, ThemeData theme) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 2,
          width: 60,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary,
                theme.colorScheme.secondary,
              ],
            ),
            borderRadius: BorderRadius.circular(1),
          ),
        ),
        const SizedBox(height: 12),
        content,
      ],
    ),
  );
}

Widget _buildInfoRow(String label, String value, ThemeData theme) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ],
    ),
  );
}

Color _getStatusColor(String? status) {
  switch (status?.toLowerCase()) {
    case 'currently airing':
      return Colors.green;
    case 'finished airing':
      return Colors.blue;
    case 'not yet aired':
      return Colors.orange;
    default:
      return Colors.grey;
  }
}

String _formatNumber(int number) {
  if (number >= 1000000) {
    return '${(number / 1000000).toStringAsFixed(1)}M';
  } else if (number >= 1000) {
    return '${(number / 1000).toStringAsFixed(1)}K';
  } else {
    return number.toString();
  }
}
}

class ImageGalleryViewer extends StatefulWidget {
  final List<Map<String, dynamic>> pictures;
  final int initialIndex;
  final String animeTitle;

  const ImageGalleryViewer({
    super.key,
    required this.pictures,
    required this.initialIndex,
    required this.animeTitle,
  });

  @override
  State<ImageGalleryViewer> createState() => _ImageGalleryViewerState();
}

class _ImageGalleryViewerState extends State<ImageGalleryViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          '${_currentIndex + 1} of ${widget.pictures.length}',
          style: const TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemCount: widget.pictures.length,
        itemBuilder: (context, index) {
          final picture = widget.pictures[index];
          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 3.0,
            child: Center(
              child: CachedImage.animeCover(
                imageUrl: picture['largeImageUrl'] ?? picture['imageUrl'] ?? '',
                fit: BoxFit.contain,
                borderRadius: BorderRadius.zero,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;

  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
} 
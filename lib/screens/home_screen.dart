import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:jikan_api/jikan_api.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/jikan_service.dart';
import '../services/genre_service.dart';
import '../services/user_anime_service.dart';
import '../services/followed_anime_service.dart';
import '../services/theme_service.dart';
import '../services/release_schedule_service.dart';
import '../widgets/anime_cards.dart';
import '../widgets/banner_ad_widget.dart';
import '../widgets/genre_card.dart';
import '../models/mock_models.dart';
import '../models/genre_model.dart';
import '../redux/app_state.dart' as redux;
import 'search_screen.dart';
import 'anime_detail_screen.dart';
import 'user_profile_screen.dart';
import 'settings_screen.dart';
import 'anime_list_screen.dart';
import 'login_screen.dart';
import 'calendar_screen.dart';
import '../utils/anime_utils.dart';

/// ViewModel for My Animes section
class _MyAnimesViewModel {
  final List<UserAnime> myAnimes;
  final bool isLoading;
  final String? error;
  final bool hasFollowedAnimes;

  _MyAnimesViewModel({
    required this.myAnimes,
    required this.isLoading,
    required this.error,
    required this.hasFollowedAnimes,
  });
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  final JikanService _jikanService = JikanService();
  final GenreService _genreService = GenreService();
  final UserAnimeService _userAnimeService = UserAnimeService.instance;
  


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

  // Convert UserAnime to MockAnime for compatibility with existing widgets
  MockAnime _convertUserAnimeToMockAnime(UserAnime userAnime) {
    return MockAnime(
      malId: userAnime.malId,
      url: '', // UserAnime doesn't store URL
      imageUrl: userAnime.imageUrl,
      title: userAnime.title,
      titleEnglish: userAnime.titleEnglish,
      titleJapanese: userAnime.titleJapanese,
      episodes: userAnime.totalEpisodes,
      status: userAnime.status ?? 'Unknown',
      aired: '', // Not stored in UserAnime
      score: userAnime.score,
      scoredBy: null,
      rank: null,
      popularity: null,
      members: null,
      favorites: null,
      synopsis: userAnime.synopsis,
      background: null,
      season: null,
      year: null,
      broadcast: null,
      source: null,
      duration: null,
      rating: null,
      genres: userAnime.genres?.map((genreMap) => 
        MockGenre(
          malId: genreMap['malId'] ?? 0, 
          name: genreMap['name'] ?? ''
        )
      ).toList() ?? [],
      studios: userAnime.studios?.map((studioMap) => 
        MockStudio(
          malId: studioMap['malId'] ?? 0, 
          name: studioMap['name'] ?? ''
        )
      ).toList() ?? [],
    );
  }

  // Helper method to convert DateTime weekday to jikan_api WeekDay
  WeekDay _getCurrentWeekDay() {
    final now = DateTime.now();
    switch (now.weekday) {
      case DateTime.monday:
        return WeekDay.monday;
      case DateTime.tuesday:
        return WeekDay.tuesday;
      case DateTime.wednesday:
        return WeekDay.wednesday;
      case DateTime.thursday:
        return WeekDay.thursday;
      case DateTime.friday:
        return WeekDay.friday;
      case DateTime.saturday:
        return WeekDay.saturday;
      case DateTime.sunday:
        return WeekDay.sunday;
      default:
        return WeekDay.monday;
    }
  }



  // Convert Jikan API Anime to MockAnime for compatibility with existing widgets
  MockAnime _convertJikanAnimeToMockAnime(Anime anime) {
    return MockAnime(
      malId: anime.malId,
      url: anime.url,
      imageUrl: anime.imageUrl ?? '',
      title: anime.title ?? '',
      titleEnglish: anime.titleEnglish,
      titleJapanese: anime.titleJapanese,
      episodes: anime.episodes,
      status: anime.status ?? '',
      aired: anime.aired ?? '',
      score: anime.score,
      scoredBy: anime.scoredBy,
      rank: anime.rank,
      popularity: anime.popularity,
      members: anime.members,
      favorites: anime.favorites,
      synopsis: anime.synopsis,
      background: anime.background,
      season: anime.season,
      year: anime.year,
      broadcast: anime.broadcast,
      source: anime.source,
      duration: anime.duration,
      rating: anime.rating,
      genres: anime.genres?.map((genre) => 
        MockGenre(
          malId: genre.malId, 
          name: genre.name
        )
      ).toList() ?? [],
      studios: anime.studios?.map((studio) => 
        MockStudio(
          malId: studio.malId, 
          name: studio.name
        )
      ).toList() ?? [],
    );
  }

  /// Get the user's initial letter for the profile avatar
  String _getUserInitial(User? user) {
    if (user == null) return 'A';
    
    // For anonymous users, show 'A'
    if (user.isAnonymous) return 'A';
    
    // Try to get the first letter from display name
    if (user.displayName != null && user.displayName!.isNotEmpty) {
      return user.displayName!.substring(0, 1).toUpperCase();
    }
    
    // Fall back to email first letter
    if (user.email != null && user.email!.isNotEmpty) {
      return user.email!.substring(0, 1).toUpperCase();
    }
    
    // Default fallback
    return 'U';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = FirebaseAuth.instance.currentUser;
    
    return Scaffold(
      body: Column(
        children: [
          // Main content
          Expanded(
            child: CustomScrollView(
              slivers: [
                // App Bar
                SliverAppBar(
                  toolbarHeight: 60,
                  floating: false,
                  pinned: true,
                  snap: false,
                  backgroundColor: theme.colorScheme.surface,
                  elevation: 0,
                  automaticallyImplyLeading: false,
                  leading: IconButton(
                    icon: const Icon(Icons.calendar_month),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CalendarScreen(),
                        ),
                      );
                    },
                    tooltip: 'Release Calendar',
                  ),
                  title: Text(
                    'Hanimo',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SearchScreen(),
                          ),
                        );
                      },
                    ),
                    Consumer<ThemeService>(
                      builder: (context, themeService, child) {
                        return PopupMenuButton<String>(
                          icon: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  theme.colorScheme.primary,
                                  theme.colorScheme.secondary,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: theme.colorScheme.primary.withOpacity(0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: CircleAvatar(
                              radius: 16,
                              backgroundColor: Colors.transparent,
                              child: Text(
                                _getUserInitial(user),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 8,
                          color: theme.colorScheme.surface,
                          surfaceTintColor: theme.colorScheme.surfaceTint,
                          constraints: const BoxConstraints(
                            minWidth: 200,
                            maxWidth: 280,
                          ),
                          onSelected: (String result) {
                            switch (result) {
                              case 'login':
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const LoginScreen(showStayAnonymous: true),
                                  ),
                                );
                                break;
                              case 'profile':
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const UserProfileScreen(),
                                  ),
                                );
                                break;
                              case 'settings':
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const SettingsScreen(),
                                  ),
                                );
                                break;
                              case 'theme_light':
                                themeService.setThemeMode(ThemeMode.light);
                                break;
                              case 'theme_dark':
                                themeService.setThemeMode(ThemeMode.dark);
                                break;
                              case 'logout':
                                _authService.signOut();
                                break;
                            }
                          },
                          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                            // Login Button (only show for anonymous users)
                            if (user != null && user.isAnonymous)
                              PopupMenuItem<String>(
                                value: 'login',
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.primary.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          Icons.login,
                                          size: 20,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Text(
                                          'Login',
                                          style: theme.textTheme.bodyMedium?.copyWith(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            if (user != null && user.isAnonymous)
                              PopupMenuDivider(
                                height: 1,
                                color: theme.colorScheme.outline.withOpacity(0.2),
                              ),
                            PopupMenuItem<String>(
                              value: 'profile',
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.person_outline,
                                        size: 20,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Text(
                                        'Profile',
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            PopupMenuItem<String>(
                              value: 'settings',
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.secondary.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.settings_outlined,
                                        size: 20,
                                        color: theme.colorScheme.secondary,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Text(
                                        'Settings',
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            PopupMenuDivider(
                              height: 1,
                              color: theme.colorScheme.outline.withOpacity(0.2),
                            ),
                            // Theme submenu header
                            PopupMenuItem<String>(
                              enabled: false,
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.tertiary.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Icon(
                                        Icons.palette_outlined,
                                        size: 16,
                                        color: theme.colorScheme.tertiary,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Theme',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.tertiary,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            PopupMenuItem<String>(
                              value: 'theme_light',
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 8),
                                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                                decoration: BoxDecoration(
                                  color: themeService.themeMode == ThemeMode.light 
                                      ? theme.colorScheme.primary.withOpacity(0.1)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  border: themeService.themeMode == ThemeMode.light 
                                      ? Border.all(
                                          color: theme.colorScheme.primary.withOpacity(0.3),
                                          width: 1,
                                        )
                                      : null,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: themeService.themeMode == ThemeMode.light 
                                            ? theme.colorScheme.primary.withOpacity(0.2)
                                            : theme.colorScheme.outline.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Icon(
                                        Icons.light_mode,
                                        size: 18,
                                        color: themeService.themeMode == ThemeMode.light 
                                            ? theme.colorScheme.primary 
                                            : theme.colorScheme.outline,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Light',
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: themeService.themeMode == ThemeMode.light 
                                            ? theme.colorScheme.primary 
                                            : theme.colorScheme.onSurface,
                                        fontWeight: themeService.themeMode == ThemeMode.light 
                                            ? FontWeight.w600 
                                            : FontWeight.w500,
                                      ),
                                    ),
                                    const Spacer(),
                                    if (themeService.themeMode == ThemeMode.light)
                                      Icon(
                                        Icons.check_circle,
                                        size: 18,
                                        color: theme.colorScheme.primary,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            PopupMenuItem<String>(
                              value: 'theme_dark',
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 8),
                                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                                decoration: BoxDecoration(
                                  color: themeService.themeMode == ThemeMode.dark 
                                      ? theme.colorScheme.primary.withOpacity(0.1)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  border: themeService.themeMode == ThemeMode.dark 
                                      ? Border.all(
                                          color: theme.colorScheme.primary.withOpacity(0.3),
                                          width: 1,
                                        )
                                      : null,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: themeService.themeMode == ThemeMode.dark 
                                            ? theme.colorScheme.primary.withOpacity(0.2)
                                            : theme.colorScheme.outline.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Icon(
                                        Icons.dark_mode,
                                        size: 18,
                                        color: themeService.themeMode == ThemeMode.dark 
                                            ? theme.colorScheme.primary 
                                            : theme.colorScheme.outline,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Dark',
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: themeService.themeMode == ThemeMode.dark 
                                            ? theme.colorScheme.primary 
                                            : theme.colorScheme.onSurface,
                                        fontWeight: themeService.themeMode == ThemeMode.dark 
                                            ? FontWeight.w600 
                                            : FontWeight.w500,
                                      ),
                                    ),
                                    const Spacer(),
                                    if (themeService.themeMode == ThemeMode.dark)
                                      Icon(
                                        Icons.check_circle,
                                        size: 18,
                                        color: theme.colorScheme.primary,
                                      ),
                                  ],
                                ),
                              ),
                            ),

                            PopupMenuDivider(
                              height: 1,
                              color: theme.colorScheme.outline.withOpacity(0.2),
                            ),
                            PopupMenuItem<String>(
                              value: 'logout',
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.error.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(
                                        Icons.logout,
                                        size: 20,
                                        color: theme.colorScheme.error,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Text(
                                        'Sign Out',
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          color: theme.colorScheme.error,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
                
                // Content
                SliverList(
                  delegate: SliverChildListDelegate([
                    // Your Animes Section (only show if user has followed anime)
                    _buildYourAnimesSection(),
                    
                    // Most Followed Section
                    _buildMostFollowedSection(),
                    
                    // Airing Today Section
                    _buildAiringTodaySection(),
                    
                    // This Season Section
                    _buildThisSeasonSection(),
                    
                    // Next Season Section
                    _buildNextSeasonSection(),
                    
                    // Genres Section
                    _buildGenresSection(),
                    
                    const SizedBox(height: 20), // Reduced bottom padding since banner will add space
                  ]),
                ),
              ],
            ),
          ),
          
          // Banner Ad at the bottom
          const BannerAdWidget(
            adSize: AdSize.banner,
            margin: EdgeInsets.all(8.0),
            adType: BannerAdType.home,
          ),
        ],
      ),
    );
  }
  
  Widget _buildYourAnimesSection() {
    final theme = Theme.of(context);
    
    // Only show if user is authenticated
    if (!_userAnimeService.isAuthenticated) {
      return const SizedBox.shrink();
    }
    
    return StoreConnector<redux.AppState, _MyAnimesViewModel>(
      converter: (store) => _MyAnimesViewModel(
        myAnimes: store.state.myAnimes,
        isLoading: store.state.isLoadingMyAnimes,
        error: store.state.myAnimesError,
        hasFollowedAnimes: store.state.followedAnimeIds.isNotEmpty,
      ),
      builder: (context, viewModel) {
        // Don't show if no followed anime
        if (!viewModel.hasFollowedAnimes) {
          return const SizedBox.shrink();
        }
        
        // Show loading state only if no cached data
        if (viewModel.isLoading && viewModel.myAnimes.isEmpty) {
          return const SizedBox.shrink(); // Don't show loading, just hide
        }
        
        // Don't show if there's an error and no cached data
        if (viewModel.error != null && viewModel.myAnimes.isEmpty) {
          return const SizedBox.shrink();
        }
        
        // Don't show if no data
        if (viewModel.myAnimes.isEmpty) {
          return const SizedBox.shrink();
        }
        
        final userAnimeList = viewModel.myAnimes;
        // Limit to first 50 entries
        final limitedList = userAnimeList.take(50).toList();
        
        debugPrint('🏠 [HomeScreen] Displaying ${limitedList.length} user anime from Redux state (total: ${userAnimeList.length})');
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        'My Animes',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      // Show loading indicator if refreshing in background
                      if (viewModel.isLoading && viewModel.myAnimes.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.colorScheme.primary.withOpacity(0.6),
                            ),
                          ),
                        ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${limitedList.length}${userAnimeList.length > 50 ? '+' : ''} anime',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 220,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: limitedList.map((userAnime) {
                  final mockAnime = _convertUserAnimeToMockAnime(userAnime);
                  return FeaturedAnimeCard(
                    anime: mockAnime,
                    watchedEpisodes: userAnime.watchedEpisodesCount,
                    onTap: () => _showAnimeDetails(mockAnime),
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMostFollowedSection() {
    final theme = Theme.of(context);
    
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _jikanService.getPopularAnime(page: 1),
      builder: (context, snapshot) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Most Followed',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  // Show count when data is loaded
                  if (snapshot.hasData && snapshot.data!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${snapshot.data!.length} anime',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(
              height: 260,
              child: Builder(
                builder: (context) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }
                  
                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: theme.colorScheme.error,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Failed to load popular anime',
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${snapshot.error}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.error.withOpacity(0.7),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () => setState(() {}),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  }
                  
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                      child: Text('No popular anime found'),
                    );
                  }
                  
                  final rawPopularAnime = snapshot.data!;
                  final popularAnime = AnimeUtils.deduplicateAnimeMaps(rawPopularAnime); // Remove duplicates
                  
                  debugPrint('🏠 [HomeScreen] Displaying ${popularAnime.length} popular anime from Jikan API');
                  if (popularAnime.isNotEmpty) {
                    debugPrint('🏠 [HomeScreen] First anime: ${popularAnime.first['title']}');
                    debugPrint('🏠 [HomeScreen] Last anime: ${popularAnime.last['title']}');
                  }
                  
                  return ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: popularAnime.map((animeMap) {
                      final mockAnime = _convertMapToMockAnime(animeMap);
                      return TrendingAnimeCard(
                        anime: mockAnime,
                        onTap: () => _showAnimeDetails(mockAnime),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAiringTodaySection() {
    final theme = Theme.of(context);
    final currentWeekDay = _getCurrentWeekDay();
    
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: ReleaseScheduleService.instance.getSchedule(currentWeekDay),
      builder: (context, snapshot) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Airing Today',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  // Show count when data is loaded
                  if (snapshot.hasData && snapshot.data!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${snapshot.data!.length} anime',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(
              height: 240,
              child: Builder(
                builder: (context) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }
                  
                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: theme.colorScheme.error,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Failed to load airing anime',
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${snapshot.error}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.error.withOpacity(0.7),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () => setState(() {}),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  }
                  
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                      child: Text('No anime airing today'),
                    );
                  }
                  
                  final rawAiringAnime = snapshot.data!;
                  final airingAnime = AnimeUtils.deduplicateAnimeMaps(rawAiringAnime); // Remove duplicates
                  
                  debugPrint('📅 [HomeScreen] Displaying ${airingAnime.length} anime airing today from Release Schedule Service');
                  if (airingAnime.isNotEmpty) {
                    debugPrint('📅 [HomeScreen] First anime: ${airingAnime.first['title']}');
                    debugPrint('📅 [HomeScreen] Last anime: ${airingAnime.last['title']}');
                  }
                  
                  return ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: airingAnime.map((animeMap) {
                      final mockAnime = _convertMapToMockAnime(animeMap);
                      return AiringTodayCard(
                        anime: mockAnime,
                        onTap: () => _showAnimeDetails(mockAnime),
                      );
                    }).toList(),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildThisSeasonSection() {
    final theme = Theme.of(context);
    
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _jikanService.getCurrentSeasonAnime(page: 1),
      builder: (context, snapshot) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'This Season',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  // Show count when data is loaded
                  if (snapshot.hasData && snapshot.data!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${snapshot.data!.length} anime',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(
              height: 220,
              child: Builder(
                builder: (context) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }
                  
                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: theme.colorScheme.error,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Failed to load current season',
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${snapshot.error}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.error.withOpacity(0.7),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () => setState(() {}),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  }
                  
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                      child: Text('No anime found for this season'),
                    );
                  }
                  
                  final rawSeasonAnime = snapshot.data!;
                  final seasonAnime = AnimeUtils.deduplicateAnimeMaps(rawSeasonAnime); // Remove duplicates
                  
                  debugPrint('🌸 [HomeScreen] Displaying ${seasonAnime.length} current season anime from Jikan API');
                  if (seasonAnime.isNotEmpty) {
                    debugPrint('🌸 [HomeScreen] First anime: ${seasonAnime.first['title']}');
                    debugPrint('🌸 [HomeScreen] Last anime: ${seasonAnime.last['title']}');
                  }
                  
                  return ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      // Show season anime cards
                      ...seasonAnime.map((animeMap) {
                        final mockAnime = _convertMapToMockAnime(animeMap);
                        return SeasonAnimeCard(
                          anime: mockAnime,
                          onTap: () => _showAnimeDetails(mockAnime),
                        );
                      }).toList(),
                      // Add "See More" card at the end
                      SeeMoreCard(
                        onTap: () => _navigateToAnimeListFromMaps(
                          'This Season',
                          seasonAnime,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _navigateToAnimeList(String title, List<Anime> animeList) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AnimeListScreen(
          title: title,
          animeList: animeList,
          showAsGrid: true,
        ),
      ),
    );
  }

  Widget _buildNextSeasonSection() {
    final theme = Theme.of(context);
    
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _jikanService.getSeasonUpcoming(page: 1),
      builder: (context, snapshot) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Next Season',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  // Show count when data is loaded
                  if (snapshot.hasData && snapshot.data!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${snapshot.data!.length} anime',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(
              height: 220,
              child: Builder(
                builder: (context) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }
                  
                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 48,
                            color: theme.colorScheme.error,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Failed to load upcoming season',
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${snapshot.error}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.error.withOpacity(0.7),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () => setState(() {}),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  }
                  
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                      child: Text('No upcoming anime found'),
                    );
                  }
                  
                  final rawUpcomingAnime = snapshot.data!;
                  final upcomingAnime = AnimeUtils.deduplicateAnimeMaps(rawUpcomingAnime); // Remove duplicates
                  
                  debugPrint('🔮 [HomeScreen] Displaying ${upcomingAnime.length} upcoming season anime from Jikan API');
                  if (upcomingAnime.isNotEmpty) {
                    debugPrint('🔮 [HomeScreen] First anime: ${upcomingAnime.first['title']}');
                    debugPrint('🔮 [HomeScreen] Last anime: ${upcomingAnime.last['title']}');
                  }
                  
                  return ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      // Show upcoming anime cards
                      ...upcomingAnime.map((animeMap) {
                        final mockAnime = _convertMapToMockAnime(animeMap);
                        return SeasonAnimeCard(
                          anime: mockAnime,
                          onTap: () => _showAnimeDetails(mockAnime),
                        );
                      }).toList(),
                      // Add "See More" card at the end
                      SeeMoreCard(
                        onTap: () => _navigateToAnimeListFromMaps(
                          'Next Season',
                          upcomingAnime,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _navigateToAnimeListFromMaps(String title, List<Map<String, dynamic>> animeMaps) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AnimeListScreen.fromMaps(
          title: title,
          animeMaps: animeMaps,
          showAsGrid: true,
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children, {bool isHorizontal = false}) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Text(
            title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
        if (isHorizontal)
          SizedBox(
            height: title == 'Your Animes' ? 220 : 
                   title == 'Airing Today' ? 240 : 
                   title == 'This Season' || title == 'Next Season' ? 220 : 260,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: children.map((child) => child).toList(),
            ),
          )
        else
          Column(children: children),
      ],
    );
  }
  
  void _showAnimeDetails(MockAnime anime) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AnimeDetailScreen(animeId: anime.malId),
      ),
    );
  }

  Widget _buildGenresSection() {
    final theme = Theme.of(context);
    
    return FutureBuilder<List<EnhancedGenre>>(
      future: _genreService.getAnimeGenres(),
      builder: (context, snapshot) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Browse Genres',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  if (snapshot.hasData && snapshot.data!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${snapshot.data!.length} genres',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(
              height: 280, // Increased height for 2 rows to prevent clipping
              child: Builder(
                builder: (context) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }
                  
                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 32,
                            color: theme.colorScheme.error,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Failed to load genres',
                            style: TextStyle(color: theme.colorScheme.error),
                          ),
                        ],
                      ),
                    );
                  }
                  
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                      child: Text('No genres found'),
                    );
                  }
                  
                  final genres = snapshot.data!;
                  
                  debugPrint('🎭 [HomeScreen] Displaying ${genres.length} genres from Jikan API in 2-row horizontal carousel');
                  
                  return ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: (genres.length / 2).ceil(), // Number of columns needed
                    separatorBuilder: (context, index) => const SizedBox(width: 20), // 20px spacing between columns
                    itemBuilder: (context, columnIndex) {
                      final topIndex = columnIndex * 2;
                      final bottomIndex = topIndex + 1;
                      
                      return SizedBox(
                        width: 100, // Fixed width to prevent clipping
                        child: Column(
                          children: [
                            // Top row item
                            Expanded(
                              child: GenreCard(
                                genre: genres[topIndex],
                                onTap: () => _navigateToGenreAnimes(genres[topIndex]),
                              ),
                            ),
                            // Bottom row item (if exists)
                            if (bottomIndex < genres.length)
                              Expanded(
                                child: GenreCard(
                                  genre: genres[bottomIndex],
                                  onTap: () => _navigateToGenreAnimes(genres[bottomIndex]),
                                ),
                              )
                            else
                              const Expanded(child: SizedBox()), // Empty space if odd number
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _navigateToGenreAnimes(EnhancedGenre genre) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AnimeListScreen.withPageLoad(
          title: '${genre.name} Anime',
          pageLoad: (page) => _jikanService.getAnimeByGenre(genre.malId, page: page),
          showAsGrid: true,
        ),
      ),
    );
  }
} 
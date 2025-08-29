import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import '../models/mock_models.dart';
import '../services/auth_service.dart';
import '../services/user_anime_service.dart';
import '../redux/app_state.dart' as redux;
import 'anime_detail_screen.dart';
import 'settings_screen.dart';
import 'login_screen.dart';
import '../widgets/cached_image.dart';
import '../utils/anime_utils.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

/// ViewModel for User Profile screen
class _UserProfileViewModel {
  final List<UserAnime> userAnimes;
  final bool isLoading;
  final String? error;

  _UserProfileViewModel({
    required this.userAnimes,
    required this.isLoading,
    required this.error,
  });
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final AuthService _authService = AuthService();
  final UserAnimeService _userAnimeService = UserAnimeService.instance;
  
  // Filter state
  String _selectedFilter = 'All';
  final List<String> _filterOptions = ['All', 'Planning', 'Watching', 'Completed', 'Dropped'];
  
  // Profile image state
  String? _profileImageUrl;
  bool _isLoadingProfileImage = false;
  
  @override
  void initState() {
    super.initState();
    _loadProfileImage();
  }
  
  /// Load user's profile image from Firebase if available
  Future<void> _loadProfileImage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) return;
    
    setState(() {
      _isLoadingProfileImage = true;
    });
    
    try {
      debugPrint('👤 [UserProfile] Loading profile image for user: ${user.uid}');
      
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        final profileImg = data['profileImg'] as String?;
        
        if (profileImg != null && profileImg.isNotEmpty) {
          debugPrint('✅ [UserProfile] Found profile image: $profileImg');
          setState(() {
            _profileImageUrl = profileImg;
          });
        } else {
          debugPrint('📷 [UserProfile] No profile image found in Firebase');
        }
      } else {
        debugPrint('⚠️ [UserProfile] User document does not exist');
      }
    } catch (e) {
      debugPrint('❌ [UserProfile] Failed to load profile image: $e');
    } finally {
      setState(() {
        _isLoadingProfileImage = false;
      });
    }
  }
  
  /// Get a random anime cover image from the user's anime list
  String? _getRandomAnimeCover(List<UserAnime> userAnimes) {
    if (userAnimes.isEmpty) return null;
    
    // Filter out animes without valid image URLs
    final animesWithImages = userAnimes
        .where((anime) => anime.imageUrl.isNotEmpty)
        .toList();
    
    if (animesWithImages.isEmpty) return null;
    
    // Get a random anime cover
    final random = Random();
    final randomAnime = animesWithImages[random.nextInt(animesWithImages.length)];
    
    debugPrint('🎨 [UserProfile] Using random anime cover: ${randomAnime.title} - ${randomAnime.imageUrl}');
    return randomAnime.imageUrl;
  }
  
  /// Get the profile image URL with priority: Firebase > Firebase Auth > null
  String? _getProfileImageUrl() {
    final user = FirebaseAuth.instance.currentUser;
    
    // Priority 1: Firebase profileImg field (if user is not anonymous)
    if (user != null && !user.isAnonymous && _profileImageUrl != null) {
      return _profileImageUrl;
    }
    
    // Priority 2: Firebase Auth photoURL
    if (user?.photoURL != null) {
      return user!.photoURL;
    }
    
    return null;
  }
  
  /// Build user display info (name/email) with improved logic for Apple Sign In users
  List<Widget> _buildUserDisplayInfo(User? user, ThemeData theme) {
    final hasDisplayName = user?.displayName != null && user!.displayName!.isNotEmpty;
    final hasEmail = user?.email != null && user!.email!.isNotEmpty;
    
    // If user has both name and email, show both
    if (hasDisplayName && hasEmail) {
      return [
        Text(
          user!.displayName!,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                offset: const Offset(0, 1),
                blurRadius: 2,
                color: Colors.black.withOpacity(0.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          user.email!,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: Colors.white.withOpacity(0.9),
            shadows: [
              Shadow(
                offset: const Offset(0, 1),
                blurRadius: 2,
                color: Colors.black.withOpacity(0.5),
              ),
            ],
          ),
        ),
      ];
    }
    
    // If user has no name but has email, show only email as the main display
    if (!hasDisplayName && hasEmail) {
      return [
        Text(
          user!.email!,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                offset: const Offset(0, 1),
                blurRadius: 2,
                color: Colors.black.withOpacity(0.5),
              ),
            ],
          ),
        ),
      ];
    }
    
    // If user has name but no email, show only name
    if (hasDisplayName && !hasEmail) {
      return [
        Text(
          user!.displayName!,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                offset: const Offset(0, 1),
                blurRadius: 2,
                color: Colors.black.withOpacity(0.5),
              ),
            ],
          ),
        ),
      ];
    }
    
    // Fallback: Neither name nor email (anonymous user)
    return [
      Text(
        'Anonymous User',
        style: theme.textTheme.headlineSmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          shadows: [
            Shadow(
              offset: const Offset(0, 1),
              blurRadius: 2,
              color: Colors.black.withOpacity(0.5),
            ),
          ],
        ),
      ),
    ];
  }
  
  /// Build the profile background with random anime cover or gradient fallback
  Widget _buildProfileBackground(List<UserAnime> userAnimes, ThemeData theme) {
    final randomAnimeCover = _getRandomAnimeCover(userAnimes);
    
    return Stack(
      fit: StackFit.expand,
      children: [
        // Background image or gradient
        if (randomAnimeCover != null) ...[
          // Random anime cover background
          CachedImage.animeCover(
            imageUrl: randomAnimeCover,
            fit: BoxFit.cover,
            borderRadius: BorderRadius.zero,
          ),
          // Dark overlay for better text readability
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.3),
                  Colors.black.withOpacity(0.7),
                ],
              ),
            ),
          ),
        ] else ...[
          // Fallback gradient background
          Container(
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
          ),
        ],
      ],
    );
  }
  
  // Helper method to convert UserAnime to MockAnime for compatibility
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

  // Get filtered anime based on selected filter
  List<UserAnime> _getFilteredAnimes(List<UserAnime> userAnimes) {
    // First deduplicate the user animes to avoid duplicates
    final deduplicatedAnimes = AnimeUtils.deduplicateUserAnimes(userAnimes);
    
    if (_selectedFilter == 'All') {
      return deduplicatedAnimes;
    }
    
    // Map filter names to AnimeWatchStatus
    AnimeWatchStatus? targetStatus;
    switch (_selectedFilter) {
      case 'Planning':
        targetStatus = AnimeWatchStatus.planning;
        break;
      case 'Watching':
        targetStatus = AnimeWatchStatus.watching;
        break;
      case 'Completed':
        targetStatus = AnimeWatchStatus.completed;
        break;
      case 'Dropped':
        targetStatus = AnimeWatchStatus.dropped;
        break;
    }
    
    if (targetStatus == null) return deduplicatedAnimes;
    
    return deduplicatedAnimes.where((anime) => anime.watchStatus == targetStatus).toList();
  }

  // Get display name for watch status
  String _getStatusDisplayName(AnimeWatchStatus status) {
    switch (status) {
      case AnimeWatchStatus.planning:
        return 'Planning';
      case AnimeWatchStatus.watching:
        return 'Watching';
      case AnimeWatchStatus.completed:
        return 'Completed';
      case AnimeWatchStatus.dropped:
        return 'Dropped';
    }
  }

  // Calculate stats from user anime data
  Map<String, int> _calculateStats(List<UserAnime> userAnimes) {
    int totalFollowing = userAnimes.length;
    int totalWatched = userAnimes.where((anime) => anime.watchStatus == AnimeWatchStatus.completed).length;
    int totalEpisodesWatched = userAnimes.fold(0, (sum, anime) => sum + anime.watchedEpisodesCount);
    
    return {
      'following': totalFollowing,
      'watched': totalWatched,
      'episodes': totalEpisodesWatched,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = FirebaseAuth.instance.currentUser;
    
    return Scaffold(
      body: StoreConnector<redux.AppState, _UserProfileViewModel>(
        converter: (store) => _UserProfileViewModel(
          userAnimes: store.state.myAnimes,
          isLoading: store.state.isLoadingMyAnimes,
          error: store.state.myAnimesError,
        ),
        builder: (context, viewModel) {
          final filteredAnimes = _getFilteredAnimes(viewModel.userAnimes);
          final stats = _calculateStats(viewModel.userAnimes);
          
          return CustomScrollView(
            slivers: [
              // Profile Header
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                stretch: true,
                backgroundColor: theme.colorScheme.surface,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildProfileBackground(viewModel.userAnimes, theme),
                      SafeArea(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(height: 40),
                            // Profile Picture
                            GestureDetector(
                              onTap: () {
                                final user = FirebaseAuth.instance.currentUser;
                                if (user != null && user.isAnonymous) {
                                  // User is anonymous, redirect to login screen
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const LoginScreen(showStayAnonymous: true),
                                    ),
                                  );
                                }
                              },
                              child: Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 3,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: 10,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: CircleAvatar(
                                  radius: 40,
                                  backgroundImage: _getProfileImageUrl() != null 
                                      ? NetworkImage(_getProfileImageUrl()!)
                                      : null,
                                  backgroundColor: Colors.white,
                                  child: _getProfileImageUrl() == null
                                      ? Text(
                                          user?.displayName?.substring(0, 1).toUpperCase() ?? 
                                          user?.email?.substring(0, 1).toUpperCase() ?? 
                                          'U',
                                          style: TextStyle(
                                            fontSize: 32,
                                            fontWeight: FontWeight.bold,
                                            color: theme.colorScheme.primary,
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            // User Name and Email with improved logic
                            ..._buildUserDisplayInfo(user, theme),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.settings, color: Colors.white),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SettingsScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
              
              // Profile Content
              SliverList(
                delegate: SliverChildListDelegate([
                  // Stats Row
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatCard('Following', stats['following'].toString(), theme),
                        _buildStatCard('Completed', stats['watched'].toString(), theme),
                        _buildStatCard('Episodes', stats['episodes'].toString(), theme),
                      ],
                    ),
                  ),
                  

                  
                  // Loading indicator
                  if (viewModel.isLoading && viewModel.userAnimes.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  
                  // Error state
                  if (viewModel.error != null && viewModel.userAnimes.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 64,
                            color: theme.colorScheme.error,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Failed to load anime list',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            viewModel.error!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(0.6),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  
                  // Followed Animes Section (only show if has data)
                  if (viewModel.userAnimes.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                      child: Row(
                        children: [
                          Text(
                            'Following',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              filteredAnimes.length.toString(),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Filter Tags
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: SizedBox(
                        height: 40,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _filterOptions.length,
                          itemBuilder: (context, index) {
                            final option = _filterOptions[index];
                            final isSelected = _selectedFilter == option;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(option),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() {
                                    _selectedFilter = option;
                                  });
                                },
                                backgroundColor: theme.colorScheme.surface,
                                selectedColor: theme.colorScheme.primary.withOpacity(0.2),
                                labelStyle: TextStyle(
                                  color: isSelected 
                                      ? theme.colorScheme.primary 
                                      : theme.colorScheme.onSurface.withOpacity(0.7),
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                ),
                                side: BorderSide(
                                  color: isSelected 
                                      ? theme.colorScheme.primary 
                                      : theme.colorScheme.outline.withOpacity(0.3),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    // Anime Grid
                    if (filteredAnimes.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: GridView.builder(
                          padding: EdgeInsets.fromLTRB(0, 20, 0, 0),
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 0.7,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: filteredAnimes.length,
                          itemBuilder: (context, index) {
                            final userAnime = filteredAnimes[index];
                            final mockAnime = _convertUserAnimeToMockAnime(userAnime);
                            return _buildAnimeGridCard(mockAnime, _getStatusDisplayName(userAnime.watchStatus), theme);
                          },
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(
                              Icons.favorite_border,
                              size: 64,
                              color: theme.colorScheme.onSurface.withOpacity(0.3),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No anime in ${_selectedFilter.toLowerCase()}',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Try a different filter or start following anime',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.4),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                  
                  // Empty state when no anime at all
                  if (viewModel.userAnimes.isEmpty && !viewModel.isLoading && viewModel.error == null)
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          Icon(
                            Icons.favorite_border,
                            size: 64,
                            color: theme.colorScheme.onSurface.withOpacity(0.3),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No followed anime yet',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Start following anime to see them here',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(0.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  const SizedBox(height: 80), // Bottom padding
                ]),
              ),
            ],
          );
        },
      ),
    );
  }
  
  Widget _buildStatCard(String label, String value, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildAnimeGridCard(MockAnime anime, String watchStatus, ThemeData theme) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AnimeDetailScreen(animeId: anime.malId),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Anime Image
              CachedImage.animeCover(
                imageUrl: anime.imageUrl.isNotEmpty ? anime.imageUrl : null,
                fit: BoxFit.cover,
                borderRadius: BorderRadius.zero, // Already clipped by parent
              ),
              // Gradient Overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
                    stops: const [0.6, 1.0],
                  ),
                ),
              ),
              // Title and Score
              Positioned(
                bottom: 8,
                left: 8,
                right: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      anime.title,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (anime.score != null) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            Icons.star,
                            color: Colors.amber,
                            size: 12,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            anime.score!.toStringAsFixed(1),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              // Watch status indicator
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getStatusColor(watchStatus),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _getStatusIcon(watchStatus),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
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
  
  Color _getStatusColor(String status) {
    switch (status) {
      case 'Planning':
        return Colors.blue;
      case 'Watching':
        return Colors.green;
      case 'Completed':
        return Colors.purple;
      case 'Dropped':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
  
  String _getStatusIcon(String status) {
    switch (status) {
      case 'Planning':
        return 'P';
      case 'Watching':
        return 'W';
      case 'Completed':
        return 'C';
      case 'Dropped':
        return 'X';
      default:
        return '?';
    }
  }
} 
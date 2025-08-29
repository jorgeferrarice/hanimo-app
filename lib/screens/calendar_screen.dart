import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:jikan_api/jikan_api.dart';
import '../services/release_schedule_service.dart';
import '../models/mock_models.dart';
import '../redux/app_state.dart' as redux;
import '../widgets/cached_image.dart';
import '../widgets/calendar_sync_dialog.dart';
import '../services/analytics_service.dart';
import 'anime_detail_screen.dart';
import '../utils/anime_utils.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final ReleaseScheduleService _scheduleService = ReleaseScheduleService.instance;
  
  bool _showOnlyFollowed = false;
  bool _isLoading = true;
  String? _error;
  Map<String, List<Map<String, dynamic>>> _weeklySchedule = {};
  
  @override
  void initState() {
    super.initState();
    _loadWeeklySchedule();
    _logCalendarView();
  }

  Future<void> _logCalendarView() async {
    try {
      await AnalyticsService.instance.logCalendarView();
    } catch (e) {
      debugPrint('❌ [CalendarScreen] Failed to log calendar view analytics: $e');
    }
  }
  
  Future<void> _loadWeeklySchedule() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      debugPrint('📅 [CalendarScreen] Loading weekly schedule...');
      final startTime = DateTime.now();
      
      // Get all days of the current week
      final weekDays = _getCurrentWeekDays();
      final scheduleMap = <String, List<Map<String, dynamic>>>{};
      
      // Load schedule for each day
      for (final dayInfo in weekDays) {
        final weekDay = dayInfo['weekDay'] as WeekDay;
        final dayName = dayInfo['name'] as String;
        
        try {
          final rawDaySchedule = await _scheduleService.getSchedule(weekDay);
          final daySchedule = AnimeUtils.deduplicateAnimeMaps(rawDaySchedule); // Remove duplicates
          scheduleMap[dayName] = daySchedule;
          debugPrint('📅 [CalendarScreen] Loaded ${daySchedule.length} anime for $dayName');
        } catch (e) {
          debugPrint('❌ [CalendarScreen] Failed to load schedule for $dayName: $e');
          scheduleMap[dayName] = [];
        }
      }
      
      final duration = DateTime.now().difference(startTime);
      debugPrint('✅ [CalendarScreen] Weekly schedule loaded in ${duration.inMilliseconds}ms');
      
      setState(() {
        _weeklySchedule = scheduleMap;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      debugPrint('❌ [CalendarScreen] Failed to load weekly schedule:');
      debugPrint('   • Error: $e');
      debugPrint('   • Stack trace: $stackTrace');
      
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }
  
  List<Map<String, dynamic>> _getCurrentWeekDays() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1)); // Monday
    
    return [
      {'name': 'Monday', 'date': startOfWeek, 'weekDay': WeekDay.monday},
      {'name': 'Tuesday', 'date': startOfWeek.add(const Duration(days: 1)), 'weekDay': WeekDay.tuesday},
      {'name': 'Wednesday', 'date': startOfWeek.add(const Duration(days: 2)), 'weekDay': WeekDay.wednesday},
      {'name': 'Thursday', 'date': startOfWeek.add(const Duration(days: 3)), 'weekDay': WeekDay.thursday},
      {'name': 'Friday', 'date': startOfWeek.add(const Duration(days: 4)), 'weekDay': WeekDay.friday},
      {'name': 'Saturday', 'date': startOfWeek.add(const Duration(days: 5)), 'weekDay': WeekDay.saturday},
      {'name': 'Sunday', 'date': startOfWeek.add(const Duration(days: 6)), 'weekDay': WeekDay.sunday},
    ];
  }
  
  bool _isAnimeFollowed(int malId, redux.AppState state) {
    return state.isAnimeFollowed(malId);
  }
  
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
  
  void _showAnimeDetails(MockAnime anime) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AnimeDetailScreen(animeId: anime.malId),
      ),
    );
  }
  
  Future<void> _syncCalendar() async {
    final store = StoreProvider.of<redux.AppState>(context);
    
    // Log calendar sync attempt
    await _logCalendarSyncAttempt();
    
    showDialog(
      context: context,
      builder: (context) => CalendarSyncDialog(
        weeklySchedule: _weeklySchedule,
        showOnlyFollowed: _showOnlyFollowed,
        isAnimeFollowed: (malId) => store.state.isAnimeFollowed(malId),
      ),
    );
  }

  Future<void> _logCalendarSyncAttempt() async {
    try {
      await AnalyticsService.instance.logCalendarSyncAttempt();
    } catch (e) {
      debugPrint('❌ [CalendarScreen] Failed to log calendar sync analytics: $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Release Calendar'),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadWeeklySchedule,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Schedule',
          ),
        ],
      ),
      body: Column(
        children: [
          // Toggle Section
          StoreConnector<redux.AppState, redux.AppState>(
            converter: (store) => store.state,
            builder: (context, state) {
              // Check if there are any followed anime in the weekly schedule
              bool hasFollowedAnimes = false;
              for (final daySchedule in _weeklySchedule.values) {
                if (daySchedule.any((anime) => _isAnimeFollowed(anime['malId'] ?? 0, state))) {
                  hasFollowedAnimes = true;
                  break;
                }
              }
              
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                  border: Border(
                    bottom: BorderSide(
                      color: theme.colorScheme.outline.withOpacity(0.2),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.filter_list,
                      color: hasFollowedAnimes 
                          ? theme.colorScheme.primary 
                          : theme.colorScheme.primary.withOpacity(0.3),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Show only followed anime',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: hasFollowedAnimes 
                            ? null 
                            : theme.colorScheme.onSurface.withOpacity(0.3),
                      ),
                    ),
                    const Spacer(),
                    Opacity(
                      opacity: hasFollowedAnimes ? 1.0 : 0.3,
                      child: Switch(
                        value: _showOnlyFollowed && hasFollowedAnimes,
                        onChanged: hasFollowedAnimes ? (value) {
                          setState(() {
                            _showOnlyFollowed = value;
                          });
                        } : (value) {
                          // Show snackbar when trying to toggle disabled switch
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('No followed anime found in this week\'s schedule'),
                              backgroundColor: theme.colorScheme.secondary,
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 3),
                              action: SnackBarAction(
                                label: 'OK',
                                textColor: Colors.white,
                                onPressed: () {
                                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                                },
                              ),
                            ),
                          );
                        },
                        activeColor: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          
          // Content
          Expanded(
            child: _buildContent(theme),
          ),
          
          // Sync Calendar Button
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: theme.colorScheme.outline.withOpacity(0.2),
                ),
              ),
            ),
            child: ElevatedButton.icon(
              onPressed: _syncCalendar,
              icon: const Icon(Icons.sync),
              label: const Text('Sync My Calendar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildContent(ThemeData theme) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading release schedule...'),
          ],
        ),
      );
    }
    
    if (_error != null) {
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
              'Failed to load schedule',
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
              onPressed: _loadWeeklySchedule,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    
    if (_weeklySchedule.isEmpty) {
      return const Center(
        child: Text('No release data available'),
      );
    }
    
    return StoreConnector<redux.AppState, redux.AppState>(
      converter: (store) => store.state,
      builder: (context, state) {
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 16),
          itemCount: _weeklySchedule.length,
          itemBuilder: (context, index) {
            final dayName = _weeklySchedule.keys.elementAt(index);
            final daySchedule = _weeklySchedule[dayName]!;
            
            // Filter schedule based on toggle
            final filteredSchedule = _showOnlyFollowed
                ? daySchedule.where((anime) => _isAnimeFollowed(anime['malId'] ?? 0, state)).toList()
                : daySchedule;
            
            return _buildDaySection(dayName, filteredSchedule, state, theme);
          },
        );
      },
    );
  }
  
  Widget _buildDaySection(String dayName, List<Map<String, dynamic>> daySchedule, redux.AppState state, ThemeData theme) {
    final today = DateTime.now();
    final dayInfo = _getCurrentWeekDays().firstWhere((day) => day['name'] == dayName);
    final dayDate = dayInfo['date'] as DateTime;
    final isToday = dayDate.day == today.day && dayDate.month == today.month && dayDate.year == today.year;
    
    // Count followed anime for this day
    final followedCount = daySchedule.where((anime) => _isAnimeFollowed(anime['malId'] ?? 0, state)).length;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Day Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isToday ? theme.colorScheme.primary : theme.colorScheme.surfaceVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  dayName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: isToday ? Colors.white : theme.colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${dayDate.day}/${dayDate.month}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
              const Spacer(),
              if (daySchedule.isNotEmpty) ...[
                if (followedCount > 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.favorite,
                          size: 14,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$followedCount',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${daySchedule.length} total',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        
        // Anime List
        if (daySchedule.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.outline.withOpacity(0.2),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.tv_off,
                    size: 48,
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _showOnlyFollowed ? 'No followed anime releasing' : 'No anime releasing',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...daySchedule.map((animeMap) {
            final anime = _convertMapToMockAnime(animeMap);
            final isFollowed = _isAnimeFollowed(anime.malId, state);
            
            return _buildAnimeCard(anime, isFollowed, theme);
          }).toList(),
      ],
    );
  }
  
  Widget _buildAnimeCard(MockAnime anime, bool isFollowed, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showAnimeDetails(anime),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isFollowed 
                  ? theme.colorScheme.primary.withOpacity(0.05)
                  : theme.colorScheme.surfaceVariant.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isFollowed 
                    ? theme.colorScheme.primary.withOpacity(0.3)
                    : theme.colorScheme.outline.withOpacity(0.2),
                width: isFollowed ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                // Anime Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 50,
                    height: 70,
                    child: CachedImage.animeCover(
                      imageUrl: anime.imageUrl,
                      fit: BoxFit.cover,
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                
                // Anime Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              anime.title,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: isFollowed ? theme.colorScheme.primary : null,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isFollowed) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.favorite,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      if (anime.episodes != null) ...[
                        Text(
                          'Episodes: ${anime.episodes}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: 2),
                      ],
                      if (anime.score != null) ...[
                        Row(
                          children: [
                            Icon(
                              Icons.star,
                              size: 14,
                              color: Colors.amber,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              anime.score!.toStringAsFixed(1),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.8),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (anime.status != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(anime.status!),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  anime.status!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                
                // Arrow Icon
                Icon(
                  Icons.chevron_right,
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
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
} 
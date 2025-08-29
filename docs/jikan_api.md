# Services Directory

This directory contains service classes that provide centralized access to external APIs and business logic.

## JikanService

The `JikanService` class is a comprehensive wrapper around the Jikan API (unofficial MyAnimeList API) that provides easy access to anime and manga data.

### Features

- ✅ **Complete API Coverage**: Wraps all Jikan API v4 methods
- ✅ **Built-in Caching**: 1-hour cache for improved performance
- ✅ **Error Handling**: Proper exception handling with custom error types
- ✅ **Type Safety**: Full TypeScript-like typing with Dart
- ✅ **Convenience Methods**: Helper methods for common operations

### Available Methods

#### Anime Methods
- `getAnime(int id)` - Get anime details by ID
- `getAnimeCharacters(int id)` - Get anime characters
- `getAnimeStaff(int id)` - Get anime staff
- `getAnimeEpisodes(int id, {int page})` - Get anime episodes
- `getAnimeNews(int id, {int page})` - Get anime news
- `getAnimeForum(int id, {ForumType? type})` - Get anime forum discussions
- `getAnimeVideos(int id)` - Get anime videos/promos
- `getAnimePictures(int id)` - Get anime pictures
- `getAnimeStatistics(int id)` - Get anime statistics
- `getAnimeMoreInfo(int id)` - Get additional anime info
- `getAnimeRecommendations(int id)` - Get anime recommendations
- `getAnimeUserUpdates(int id, {int page})` - Get user updates
- `getAnimeReviews(int id, {int page})` - Get anime reviews

#### Manga Methods
- `getManga(int id)` - Get manga details by ID
- `getMangaCharacters(int id)` - Get manga characters
- `getMangaNews(int id, {int page})` - Get manga news
- `getMangaForum(int id, {ForumType? type})` - Get manga forum
- `getMangaPictures(int id)` - Get manga pictures
- `getMangaStatistics(int id)` - Get manga statistics
- `getMangaMoreInfo(int id)` - Get additional manga info
- `getMangaRecommendations(int id)` - Get manga recommendations
- `getMangaUserUpdates(int id, {int page})` - Get user updates
- `getMangaReviews(int id, {int page})` - Get manga reviews

#### Character & People Methods
- `getCharacter(int id)` - Get character details
- `getCharacterPictures(int id)` - Get character pictures
- `getPerson(int id)` - Get person details
- `getPersonPictures(int id)` - Get person pictures

#### Search Methods
- `searchAnime({...params})` - Search anime with filters
- `searchManga({...params})` - Search manga with filters
- `searchCharacters({...params})` - Search characters
- `searchPeople({...params})` - Search people

#### Seasonal & Schedule Methods
- `getSeason({int? year, SeasonType? season, int page})` - Get seasonal anime
- `getSeasonUpcoming({int page})` - Get upcoming seasonal anime
- `getSeasonsList()` - Get seasons archive
- `getSchedules({WeekDay? weekday, int page})` - Get anime schedules

#### Top Lists Methods
- `getTopAnime({AnimeType? type, TopFilter? filter, int page})` - Get top anime
- `getTopManga({MangaType? type, TopFilter? filter, int page})` - Get top manga
- `getTopCharacters({int page})` - Get top characters
- `getTopPeople({int page})` - Get top people
- `getTopReviews({int page})` - Get top reviews

#### Genre & Producer Methods
- `getAnimeGenres({GenreType? type})` - Get anime genres
- `getMangaGenres({GenreType? type})` - Get manga genres
- `getProducers({...params})` - Get producers/studios
- `getMagazines({...params})` - Get manga magazines

#### User Methods
- `getUserProfile(String username)` - Get user profile
- `getUserHistory(String username, {HistoryType? type})` - Get user history
- `getUserFriends(String username, {int page})` - Get user friends
- `getUserReviews(String username, {int page})` - Get user reviews
- `getUserRecommendations(String username, {int page})` - Get user recommendations

#### Recent Content Methods
- `getRecentAnimeReviews({int page})` - Get recent anime reviews
- `getRecentMangaReviews({int page})` - Get recent manga reviews
- `getRecentAnimeRecommendations({int page})` - Get recent anime recommendations
- `getRecentMangaRecommendations({int page})` - Get recent manga recommendations

#### Watch Methods
- `getWatchEpisodes({bool popular})` - Get watch episodes
- `getWatchPromos({bool popular})` - Get watch promos

#### Convenience Methods
- `getPopularAnime({int page})` - Get popular anime
- `getAiringAnime({int page})` - Get currently airing anime
- `getFavoriteAnime({int page})` - Get favorite anime
- `getCurrentSeasonAnime({int page})` - Get current season anime
- `getAnimeByGenre(int genreId, {int page})` - Get anime by genre
- `getMangaByGenre(int genreId, {int page})` - Get manga by genre

### Usage Examples

#### Basic Usage

```dart
import '../services/jikan_service.dart';

class MyWidget extends StatefulWidget {
  @override
  _MyWidgetState createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  final JikanService _jikanService = JikanService();
  
  Future<void> loadAnime() async {
    try {
      // Get popular anime
      final popularAnime = await _jikanService.getPopularAnime(page: 1);
      
      // Get specific anime details
      final anime = await _jikanService.getAnime(1); // Cowboy Bebop
      
      // Search anime
      final searchResults = await _jikanService.searchAnime(
        query: 'attack on titan',
        type: AnimeType.tv,
      );
      
      // Update UI with data
      setState(() {
        // Update your state variables
      });
      
    } catch (e) {
      // Handle error
      print('Error loading anime: $e');
    }
  }
}
```

#### Advanced Search

```dart
Future<void> advancedSearch() async {
  try {
    final results = await _jikanService.searchAnime(
      query: 'action',
      type: AnimeType.tv,
      genres: [1], // Action genre
      orderBy: 'score',
      sort: 'desc',
      page: 1,
    );
    
    // Process results
    for (final anime in results) {
      print('${anime.title} - Score: ${anime.score}');
    }
  } catch (e) {
    print('Search error: $e');
  }
}
```

#### Loading Anime Details

```dart
Future<void> loadAnimeDetails(int animeId) async {
  try {
    // Get main details
    final anime = await _jikanService.getAnime(animeId);
    
    // Get additional information in parallel
    final results = await Future.wait([
      _jikanService.getAnimeCharacters(animeId),
      _jikanService.getAnimeEpisodes(animeId),
      _jikanService.getAnimeRecommendations(animeId),
      _jikanService.getAnimeReviews(animeId),
    ]);
    
    final characters = results[0] as BuiltList<CharacterMeta>;
    final episodes = results[1] as BuiltList<Episode>;
    final recommendations = results[2] as BuiltList<Recommendation>;
    final reviews = results[3] as BuiltList<Review>;
    
    // Update UI with all the data
    
  } catch (e) {
    print('Error loading anime details: $e');
  }
}
```

#### Seasonal Content

```dart
Future<void> loadSeasonalContent() async {
  try {
    // Get current season
    final currentSeason = await _jikanService.getCurrentSeasonAnime();
    
    // Get specific season
    final winterAnime = await _jikanService.getSeason(
      year: 2024,
      season: SeasonType.winter,
    );
    
    // Get upcoming anime
    final upcoming = await _jikanService.getSeasonUpcoming();
    
  } catch (e) {
    print('Error loading seasonal content: $e');
  }
}
```

### Caching

The service includes automatic caching with a 1-hour expiry time. This means:

- First API call fetches data from Jikan API
- Subsequent calls within 1 hour return cached data
- Improves performance and reduces API load
- Cache can be manually cleared with `clearCache()`

```dart
// Manual cache management
_jikanService.clearCache(); // Clear all cached data
```

### Error Handling

The service throws `JikanServiceException` for all errors:

```dart
try {
  final anime = await _jikanService.getAnime(999999); // Invalid ID
} on JikanServiceException catch (e) {
  print('Jikan Service Error: ${e.message}');
} catch (e) {
  print('Unexpected error: $e');
}
```

### Integration with Existing Code

Replace mock data in your screens:

#### Before (with mock data):
```dart
final List<MockAnime> popularAnime = [...]; // Hard-coded mock data
```

#### After (with JikanService):
```dart
final JikanService _jikanService = JikanService();
List<Anime> popularAnime = [];

Future<void> loadPopularAnime() async {
  try {
    final results = await _jikanService.getPopularAnime();
    setState(() {
      popularAnime = results.toList();
    });
  } catch (e) {
    // Handle error
  }
}
```

### Performance Tips

1. **Use caching**: The service automatically caches data for 1 hour
2. **Batch requests**: Use `Future.wait()` for multiple parallel requests
3. **Pagination**: Use the `page` parameter for large datasets
4. **Specific queries**: Use filters in search to reduce response size

### Available Data Types

The service returns official Jikan API models:
- `Anime` - Complete anime information
- `Manga` - Complete manga information
- `Character` - Character details
- `Person` - Person/staff details
- `Episode` - Episode information
- `Review` - User reviews
- `Recommendation` - User recommendations
- `Genre` - Genre information
- `Producer` - Studio/producer information
- And many more...

### Dependencies

- `jikan_api: ^2.2.1` - Official Jikan API wrapper
- `built_collection` - Immutable collections (included with jikan_api)

### Example Files

See `jikan_service_example.dart` for comprehensive usage examples and patterns.

## AuthService

The `AuthService` class handles Firebase authentication including Google Sign-In, Apple Sign-In, and anonymous authentication.

### Usage

```dart
final AuthService _authService = AuthService();

// Sign in with Google
final user = await _authService.signInWithGoogle();

// Sign in with Apple
final user = await _authService.signInWithApple();

// Sign in anonymously
final user = await _authService.signInAnonymously();

// Sign out
await _authService.signOut();
```

---

For more detailed examples and integration patterns, check the individual service files and example files in this directory. 
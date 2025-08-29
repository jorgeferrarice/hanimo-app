import '../models/mock_models.dart';
import '../services/user_anime_service.dart';

/// Utility functions for anime data manipulation and deduplication
class AnimeUtils {
  
  /// Deduplicate a list of Map<String, dynamic> anime data based on malId
  /// Keeps the first occurrence of each unique malId
  static List<Map<String, dynamic>> deduplicateAnimeMaps(List<Map<String, dynamic>> animeList) {
    if (animeList.isEmpty) return animeList;
    
    final seen = <int>{};
    final deduplicated = <Map<String, dynamic>>[];
    
    for (final anime in animeList) {
      final malId = anime['malId'] as int?;
      if (malId != null && !seen.contains(malId)) {
        seen.add(malId);
        deduplicated.add(anime);
      }
    }
    
    final originalCount = animeList.length;
    final finalCount = deduplicated.length;
    final duplicatesRemoved = originalCount - finalCount;
    
    if (duplicatesRemoved > 0) {
      print('🔍 [AnimeUtils] Removed $duplicatesRemoved duplicate(s) from list (${originalCount} → ${finalCount})');
    }
    
    return deduplicated;
  }
  
  /// Deduplicate a list of MockAnime objects based on malId
  /// Keeps the first occurrence of each unique malId
  static List<MockAnime> deduplicateMockAnimes(List<MockAnime> animeList) {
    if (animeList.isEmpty) return animeList;
    
    final seen = <int>{};
    final deduplicated = <MockAnime>[];
    
    for (final anime in animeList) {
      if (!seen.contains(anime.malId)) {
        seen.add(anime.malId);
        deduplicated.add(anime);
      }
    }
    
    final originalCount = animeList.length;
    final finalCount = deduplicated.length;
    final duplicatesRemoved = originalCount - finalCount;
    
    if (duplicatesRemoved > 0) {
      print('🔍 [AnimeUtils] Removed $duplicatesRemoved duplicate MockAnime(s) from list (${originalCount} → ${finalCount})');
    }
    
    return deduplicated;
  }
  
  /// Deduplicate a list of UserAnime objects based on malId
  /// Keeps the first occurrence of each unique malId
  static List<UserAnime> deduplicateUserAnimes(List<UserAnime> animeList) {
    if (animeList.isEmpty) return animeList;
    
    final seen = <int>{};
    final deduplicated = <UserAnime>[];
    
    for (final anime in animeList) {
      if (!seen.contains(anime.malId)) {
        seen.add(anime.malId);
        deduplicated.add(anime);
      }
    }
    
    final originalCount = animeList.length;
    final finalCount = deduplicated.length;
    final duplicatesRemoved = originalCount - finalCount;
    
    if (duplicatesRemoved > 0) {
      print('🔍 [AnimeUtils] Removed $duplicatesRemoved duplicate UserAnime(s) from list (${originalCount} → ${finalCount})');
    }
    
    return deduplicated;
  }
  
  /// Check if an anime exists in a list based on malId
  static bool containsAnime(List<Map<String, dynamic>> animeList, int malId) {
    return animeList.any((anime) => anime['malId'] == malId);
  }
  
  /// Remove specific anime from list based on malId
  static List<Map<String, dynamic>> removeAnimeById(List<Map<String, dynamic>> animeList, int malId) {
    return animeList.where((anime) => anime['malId'] != malId).toList();
  }
  
  /// Merge multiple anime lists and remove duplicates
  /// Later lists have priority over earlier ones for duplicate entries
  static List<Map<String, dynamic>> mergeAndDeduplicateAnimeLists(List<List<Map<String, dynamic>>> animeLists) {
    if (animeLists.isEmpty) return [];
    
    final Map<int, Map<String, dynamic>> animeMap = {};
    
    // Process lists in order, later entries override earlier ones
    for (final list in animeLists) {
      for (final anime in list) {
        final malId = anime['malId'] as int?;
        if (malId != null) {
          animeMap[malId] = anime;
        }
      }
    }
    
    final result = animeMap.values.toList();
    final totalOriginal = animeLists.fold<int>(0, (sum, list) => sum + list.length);
    final duplicatesRemoved = totalOriginal - result.length;
    
    if (duplicatesRemoved > 0) {
      print('🔍 [AnimeUtils] Merged ${animeLists.length} lists and removed $duplicatesRemoved duplicate(s) (${totalOriginal} → ${result.length})');
    }
    
    return result;
  }
  
  /// Get unique malIds from a list
  static Set<int> getUniqueIds(List<Map<String, dynamic>> animeList) {
    return animeList
        .map((anime) => anime['malId'] as int?)
        .where((id) => id != null)
        .cast<int>()
        .toSet();
  }
  
  /// Filter out animes that exist in another list (useful for removing already followed animes)
  static List<Map<String, dynamic>> filterOutExisting(
    List<Map<String, dynamic>> sourceList,
    List<Map<String, dynamic>> existingList,
  ) {
    final existingIds = getUniqueIds(existingList);
    final filtered = sourceList.where((anime) {
      final malId = anime['malId'] as int?;
      return malId != null && !existingIds.contains(malId);
    }).toList();
    
    final removedCount = sourceList.length - filtered.length;
    if (removedCount > 0) {
      print('🔍 [AnimeUtils] Filtered out $removedCount existing anime(s) (${sourceList.length} → ${filtered.length})');
    }
    
    return filtered;
  }
} 
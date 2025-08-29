import 'package:jikan_api/jikan_api.dart';
import 'package:built_collection/built_collection.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'cache_service.dart';
import 'cache_provider.dart';
import 'youtube_service.dart';

/// Service class that wraps all Jikan API methods
/// Provides centralized access to MyAnimeList data through the Jikan API
class JikanService {
  late final Jikan _jikanApi;
  final CacheService _cache = CacheService.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const Duration _defaultCacheExpiry = Duration(days: 1);

  JikanService() {
    debugPrint('🔧 [JikanService] Initializing Jikan API service...');
    try {
      _jikanApi = Jikan();
      debugPrint('✅ [JikanService] Jikan API initialized successfully');
      debugPrint('   • Cache expiry: ${_defaultCacheExpiry.inDays} days');
      debugPrint('   • Cache service: ${_cache.runtimeType}');
      debugPrint('   • Firestore integration: enabled');
    } catch (e) {
      debugPrint('❌ [JikanService] Failed to initialize Jikan API: $e');
      rethrow;
    }
  }

  /// Clear all cached data
  Future<void> clearCache() async {
    debugPrint('🧹 [JikanService] Clearing cache...');
    await _cache.clear();
    debugPrint('✅ [JikanService] Cache cleared successfully');
  }

  /// Get cache statistics
  Future<CacheStats> get cacheStats async => await _cache.stats;

  /// Test API connection health
  Future<bool> testConnection() async {
    debugPrint('🏥 [JikanService] Testing API connection...');
    try {
      final startTime = DateTime.now();
      // Try to get a simple anime (Attack on Titan) to test connection
      final testAnime = await _jikanApi.getAnime(16498);
      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);
      
      debugPrint('✅ [JikanService] API connection test successful:');
      debugPrint('   • Duration: ${duration.inMilliseconds}ms');
      debugPrint('   • Test anime: ${testAnime.title}');
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ [JikanService] API connection test failed:');
      debugPrint('   • Error: $e');
      debugPrint('   • Stack Trace: $stackTrace');
      return false;
    }
  }

  // =================
  // ANIME METHODS
  // =================

  /// Get anime by ID
  Future<Map<String, dynamic>> getAnime(int id) async {
    debugPrint('🎯 [JikanService] Getting anime by ID: $id');
    
    return await _cache.getOrSet<Map<String, dynamic>>(
      'anime_$id',
      () async {
        try {
          debugPrint('🌐 [JikanService] Fetching anime from API...');
          final startTime = DateTime.now();
          
          final apiResult = await _jikanApi.getAnime(id);
          
          final duration = DateTime.now().difference(startTime);
          debugPrint('✅ [JikanService] API call completed in ${duration.inMilliseconds}ms');
          
          // Convert to simple Map format
          final Map<String, dynamic> result = _animeToMap(apiResult);
          debugPrint('✅ [JikanService] Converted anime "${result['title']}" to Map format');
          
          // Store in Firestore if not already there
          await _storeAnimeInFirestore(id, result);
          
          return result;
        } catch (e, stackTrace) {
          debugPrint('❌ [JikanService] Failed to get anime:');
          debugPrint('   • Error: $e');
          debugPrint('   • Stack trace: $stackTrace');
          throw JikanServiceException('Failed to get anime: $e');
        }
      },
      expiration: _defaultCacheExpiry,
    );
  }

  /// Store anime data in Firestore if it doesn't exist
  Future<void> _storeAnimeInFirestore(int malId, Map<String, dynamic> animeData) async {
    try {
      debugPrint('🔥 [JikanService] Checking if anime $malId exists in Firestore...');
      
      final docRef = _firestore.collection('animes').doc(malId.toString());
      final docSnapshot = await docRef.get();
      
      if (!docSnapshot.exists) {
        debugPrint('📝 [JikanService] Anime $malId not found in Firestore, storing...');
        
        // Add metadata for Firestore document
        final firestoreData = {
          ...animeData,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'source': 'jikan_api',
        };
        
        await docRef.set(firestoreData);
        debugPrint('✅ [JikanService] Successfully stored anime "${animeData['title']}" in Firestore');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ [JikanService] Failed to store anime in Firestore:');
      debugPrint('   • Error: $e');
      debugPrint('   • Stack trace: $stackTrace');
      // Don't throw the error - we don't want Firestore issues to break the API response
      // Just log the error and continue
         }
   }
   
  /// Check if anime exists in Firestore
  Future<bool> animeExistsInFirestore(int malId) async {
    try {
      final docRef = _firestore.collection('animes').doc(malId.toString());
      final docSnapshot = await docRef.get();
      return docSnapshot.exists;
    } catch (e) {
      debugPrint('❌ [JikanService] Failed to check anime existence in Firestore: $e');
      return false;
    }
  }

  /// Get anime characters
  Future<List<Map<String, dynamic>>> getAnimeCharacters(int id) async {
    debugPrint('👥 [JikanService] Getting anime characters (id: $id)');
    
    return await _cache.getOrSet<List<Map<String, dynamic>>>(
      'anime_characters_$id',
      () async {
        try {
          debugPrint('🌐 [JikanService] Fetching anime characters from API...');
          final startTime = DateTime.now();
          
          final builtResult = await _jikanApi.getAnimeCharacters(id);
          
          final duration = DateTime.now().difference(startTime);
          debugPrint('✅ [JikanService] API call completed in ${duration.inMilliseconds}ms');
          
          final List<Map<String, dynamic>> result = builtResult.map((character) => {
            'malId': character.malId,
            'url': character.url,
            'imageUrl': character.imageUrl,
            'name': character.name,
            'role': character.role,
          }).toList();
          
          debugPrint('✅ [JikanService] Converted ${result.length} anime characters to Map format');
          return result;
        } catch (e, stackTrace) {
          debugPrint('❌ [JikanService] Failed to get anime characters:');
          debugPrint('   • Error: $e');
          debugPrint('   • Stack trace: $stackTrace');
          throw JikanServiceException('Failed to get anime characters: $e');
        }
      },
      expiration: _defaultCacheExpiry,
    );
  }

  /// Get anime staff
  Future<List<Map<String, dynamic>>> getAnimeStaff(int id) async {
    debugPrint('👨‍💼 [JikanService] Getting anime staff (id: $id)');
    
    return await _cache.getOrSet<List<Map<String, dynamic>>>(
      'anime_staff_$id',
      () async {
        try {
          debugPrint('🌐 [JikanService] Fetching anime staff from API...');
          final startTime = DateTime.now();
          
          final builtResult = await _jikanApi.getAnimeStaff(id);
          
          final duration = DateTime.now().difference(startTime);
          debugPrint('✅ [JikanService] API call completed in ${duration.inMilliseconds}ms');
          
          final List<Map<String, dynamic>> result = builtResult.map((staff) => {
            'malId': staff.malId,
            'url': staff.url,
            'imageUrl': staff.imageUrl,
            'name': staff.name,
            'positions': staff.positions,
          }).toList();
          
          debugPrint('✅ [JikanService] Converted ${result.length} anime staff to Map format');
          return result;
        } catch (e, stackTrace) {
          debugPrint('❌ [JikanService] Failed to get anime staff:');
          debugPrint('   • Error: $e');
          debugPrint('   • Stack trace: $stackTrace');
          throw JikanServiceException('Failed to get anime staff: $e');
        }
      },
      expiration: _defaultCacheExpiry,
    );
  }

  /// Get anime episodes
  Future<List<Map<String, dynamic>>> getAnimeEpisodes(int id, {int page = 1}) async {
    debugPrint('📺 [JikanService] Getting anime episodes (id: $id, page: $page)');
    
    return await _cache.getOrSet<List<Map<String, dynamic>>>(
      'anime_episodes_${id}_$page',
      () async {
        try {
          debugPrint('🌐 [JikanService] Fetching anime episodes from API...');
          final startTime = DateTime.now();
          
          final builtResult = await _jikanApi.getAnimeEpisodes(id, page: page);
          
          final duration = DateTime.now().difference(startTime);
          debugPrint('✅ [JikanService] API call completed in ${duration.inMilliseconds}ms');
          
          final List<Map<String, dynamic>> result = builtResult.map((episode) => {
            'malId': episode.malId,
            'url': episode.url,
            'title': episode.title,
            'titleJapanese': episode.titleJapanese,
            'titleRomanji': episode.titleRomanji,
            'aired': episode.aired,
            'score': episode.score,
            'filler': episode.filler,
            'recap': episode.recap,
            'forumUrl': episode.forumUrl,
          }).toList();
          
          debugPrint('✅ [JikanService] Converted ${result.length} anime episodes to Map format');
          return result;
        } catch (e, stackTrace) {
          debugPrint('❌ [JikanService] Failed to get anime episodes:');
          debugPrint('   • Error: $e');
          debugPrint('   • Stack trace: $stackTrace');
          throw JikanServiceException('Failed to get anime episodes: $e');
        }
      },
      expiration: _defaultCacheExpiry,
    );
  }

  /// Get anime news
  Future<BuiltList<Article>> getAnimeNews(int id, {int page = 1}) async {
    return await _cache.getOrSet<BuiltList<Article>>(
      'anime_news_${id}_$page',
      () async {
        try {
          return await _jikanApi.getAnimeNews(id, page: page);
        } catch (e) {
          throw JikanServiceException('Failed to get anime news: $e');
        }
      },
      expiration: _defaultCacheExpiry,
    );
  }

  /// Get anime forum discussions
  Future<BuiltList<Forum>> getAnimeForum(int id, {ForumType? type}) async {
    return await _cache.getOrSet<BuiltList<Forum>>(
      'anime_forum_${id}_${type?.name ?? 'all'}',
      () async {
        try {
          return await _jikanApi.getAnimeForum(id, type: type);
        } catch (e) {
          throw JikanServiceException('Failed to get anime forum: $e');
        }
      },
      expiration: _defaultCacheExpiry,
    );
  }

  /// Get anime videos/promos
  /// NOTE: This method is deprecated as Jikan API videos are broken
  /// Use getAnimeVideosAsMap() instead which uses YouTube Data API
  @Deprecated('Jikan API videos are broken. Use getAnimeVideosAsMap() instead.')
  Future<BuiltList<Promo>> getAnimeVideos(int id) async {
    debugPrint('⚠️ [JikanService] getAnimeVideos() is deprecated - Jikan API videos are broken');
    debugPrint('   Use getAnimeVideosAsMap() instead which uses YouTube Data API');
    throw UnsupportedError('Jikan API videos are broken. Use getAnimeVideosAsMap() instead.');
  }

  /// Get anime videos as Map format for easier UI consumption
  /// Uses YouTube Data API exclusively (Jikan API videos are broken)
  Future<List<Map<String, dynamic>>> getAnimeVideosAsMap(int id) async {
    debugPrint('🎬 [JikanService] Getting anime videos (id: $id)');
    
    return await _cache.getOrSet<List<Map<String, dynamic>>>(
      'anime_videos_map_$id',
      () async {
        try {
          debugPrint('🌐 [JikanService] Fetching anime videos from YouTube API...');
          final startTime = DateTime.now();
          
          // Get the anime data to extract the title for YouTube search
          Map<String, dynamic>? animeData;
          try {
            animeData = await getAnime(id);
          } catch (e) {
            debugPrint('⚠️ [JikanService] Could not fetch anime data for YouTube search: $e');
            return []; // Return empty list if we can't get anime data
          }
          
          final animeTitle = animeData?['title'] ?? 'Unknown Anime';
          
          // Try to get YouTube videos if API is configured
          try {
            final youtubeService = YouTubeService.instance;
            final isConfigured = await youtubeService.isConfigured();
            
            if (!isConfigured) {
              debugPrint('⚠️ [JikanService] YouTube API not configured, no videos available');
              return [];
            }
            
            debugPrint('🎬 [JikanService] YouTube API configured, fetching videos...');
            final youtubeVideos = await youtubeService.searchAnimeVideos(
              id,
              animeTitle,
              maxResults: 6,
            );
            
            final duration = DateTime.now().difference(startTime);
            
            if (youtubeVideos.isNotEmpty) {
              debugPrint('✅ [JikanService] Found ${youtubeVideos.length} YouTube videos in ${duration.inMilliseconds}ms');
              
              // Convert YouTube data to the expected format
              final result = youtubeVideos.map((video) => {
                'title': video['title'] ?? 'Untitled Video',
                'url': video['url'] ?? '',
                'embedUrl': video['embedUrl'] ?? '',
                'imageUrl': video['thumbnailUrl'] ?? '',
                'videoId': video['videoId'] ?? '',
                'description': video['description'] ?? '',
                'channelTitle': video['channelTitle'] ?? '',
                'duration': video['duration'] ?? '',
                'viewCount': video['viewCount'] ?? 0,
                'likeCount': video['likeCount'] ?? 0,
                'publishedAt': video['publishedAt'] ?? '',
                'source': 'youtube',
              }).toList();
              
              return result;
            } else {
              debugPrint('⚠️ [JikanService] No YouTube videos found for "$animeTitle" in ${duration.inMilliseconds}ms');
              return [];
            }
          } catch (e) {
            debugPrint('❌ [JikanService] YouTube API error: $e');
            return []; // Return empty list on error instead of throwing
          }
        } catch (e, stackTrace) {
          debugPrint('❌ [JikanService] Failed to get anime videos:');
          debugPrint('   • Error: $e');
          debugPrint('   • Stack trace: $stackTrace');
          return []; // Return empty list instead of throwing exception
        }
      },
      expiration: _defaultCacheExpiry,
    );
  }

  /// Get anime pictures
  Future<BuiltList<Picture>> getAnimePictures(int id) async {
    return await _cache.getOrSet<BuiltList<Picture>>(
      'anime_pictures_$id',
      () async {
        try {
          return await _jikanApi.getAnimePictures(id);
        } catch (e) {
          throw JikanServiceException('Failed to get anime pictures: $e');
        }
      },
      expiration: _defaultCacheExpiry,
    );
  }

  /// Get anime pictures as Map format for easier UI consumption
  Future<List<Map<String, dynamic>>> getAnimePicturesAsMap(int id) async {
    debugPrint('🖼️ [JikanService] Getting anime pictures (id: $id)');
    
    return await _cache.getOrSet<List<Map<String, dynamic>>>(
      'anime_pictures_map_$id',
      () async {
        try {
          debugPrint('🌐 [JikanService] Fetching anime pictures from API...');
          final startTime = DateTime.now();
          
          final builtResult = await _jikanApi.getAnimePictures(id);
          
          final duration = DateTime.now().difference(startTime);
          debugPrint('✅ [JikanService] API call completed in ${duration.inMilliseconds}ms');
          
          final List<Map<String, dynamic>> result = builtResult.map((picture) => {
            'imageUrl': picture.imageUrl ?? '',
            'largeImageUrl': picture.largeImageUrl ?? picture.imageUrl ?? '',
          }).toList();
          
          debugPrint('✅ [JikanService] Converted ${result.length} anime pictures to Map format');
          return result;
        } catch (e, stackTrace) {
          debugPrint('❌ [JikanService] Failed to get anime pictures:');
          debugPrint('   • Error: $e');
          debugPrint('   • Stack trace: $stackTrace');
          throw JikanServiceException('Failed to get anime pictures: $e');
        }
      },
      expiration: _defaultCacheExpiry,
    );
  }

  /// Get anime statistics
  Future<Stats> getAnimeStatistics(int id) async {
    return await _cache.getOrSet<Stats>(
      'anime_stats_$id',
      () async {
        try {
          return await _jikanApi.getAnimeStatistics(id);
        } catch (e) {
          throw JikanServiceException('Failed to get anime statistics: $e');
        }
      },
      expiration: _defaultCacheExpiry,
    );
  }

  /// Get anime more info
  Future<String> getAnimeMoreInfo(int id) async {
    return await _cache.getOrSet<String>(
      'anime_more_info_$id',
      () async {
        try {
          return await _jikanApi.getAnimeMoreInfo(id);
        } catch (e) {
          throw JikanServiceException('Failed to get anime more info: $e');
        }
      },
      expiration: _defaultCacheExpiry,
    );
  }

  /// Get anime recommendations
  Future<BuiltList<Recommendation>> getAnimeRecommendations(int id) async {
    return await _cache.getOrSet<BuiltList<Recommendation>>(
      'anime_recommendations_$id',
      () async {
        try {
          return await _jikanApi.getAnimeRecommendations(id);
        } catch (e) {
          throw JikanServiceException('Failed to get anime recommendations: $e');
        }
      },
      expiration: _defaultCacheExpiry,
    );
  }

  /// Get anime user updates
  Future<BuiltList<UserUpdate>> getAnimeUserUpdates(int id, {int page = 1}) async {
    return await _cache.getOrSet<BuiltList<UserUpdate>>(
      'anime_user_updates_${id}_$page',
      () async {
        try {
          return await _jikanApi.getAnimeUserUpdates(id, page: page);
        } catch (e) {
          throw JikanServiceException('Failed to get anime user updates: $e');
        }
      },
      expiration: _defaultCacheExpiry,
    );
  }

  /// Get anime reviews
  Future<List<Map<String, dynamic>>> getAnimeReviews(int id, {int page = 1}) async {
    debugPrint('📝 [JikanService] Getting anime reviews (id: $id, page: $page)');
    
    return await _cache.getOrSet<List<Map<String, dynamic>>>(
      'anime_reviews_${id}_$page',
      () async {
        try {
          debugPrint('🌐 [JikanService] Fetching anime reviews from API...');
          final startTime = DateTime.now();
          
          final builtResult = await _jikanApi.getAnimeReviews(id, page: page);
          
          final duration = DateTime.now().difference(startTime);
          debugPrint('✅ [JikanService] API call completed in ${duration.inMilliseconds}ms');
          
          final List<Map<String, dynamic>> result = builtResult.map((review) => {
            'malId': review.malId,
            'url': review.url,
            'type': review.type,
            'reactions': review.reactions,
            'date': review.date,
            'review': review.review,
            'score': review.score,
            'tags': review.tags,
            'isSpoiler': review.isSpoiler,
            'isPreliminary': review.isPreliminary,
            'user': review.user != null ? {
              'url': review.user!.url,
              'username': review.user!.username,
              'imageUrl': review.user!.imageUrl,
            } : null,
          }).toList();
          
          debugPrint('✅ [JikanService] Converted ${result.length} anime reviews to Map format');
          return result;
        } catch (e, stackTrace) {
          debugPrint('❌ [JikanService] Failed to get anime reviews:');
          debugPrint('   • Error: $e');
          debugPrint('   • Stack trace: $stackTrace');
          throw JikanServiceException('Failed to get anime reviews: $e');
        }
      },
      expiration: _defaultCacheExpiry,
    );
  }

  // =================
  // MANGA METHODS
  // =================

  /// Get manga by ID
  Future<Manga> getManga(int id) async {
    return await _cache.getOrSet<Manga>(
      'manga_$id',
      () async {
        try {
          return await _jikanApi.getManga(id);
        } catch (e) {
          throw JikanServiceException('Failed to get manga: $e');
        }
      },
      expiration: _defaultCacheExpiry,
    );
  }

  /// Get manga characters
  Future<BuiltList<CharacterMeta>> getMangaCharacters(int id) async {
    return await _cache.getOrSet<BuiltList<CharacterMeta>>(
      'manga_characters_$id',
      () async {
        try {
          return await _jikanApi.getMangaCharacters(id);
        } catch (e) {
          throw JikanServiceException('Failed to get manga characters: $e');
        }
      },
      expiration: _defaultCacheExpiry,
    );
  }

  /// Get manga news
  Future<BuiltList<Article>> getMangaNews(int id, {int page = 1}) async {
    return await _cache.getOrSet<BuiltList<Article>>(
      'manga_news_${id}_$page',
      () async {
        try {
          return await _jikanApi.getMangaNews(id, page: page);
        } catch (e) {
          throw JikanServiceException('Failed to get manga news: $e');
        }
      },
      expiration: _defaultCacheExpiry,
    );
  }

  /// Get manga forum discussions
  Future<BuiltList<Forum>> getMangaForum(int id, {ForumType? type}) async {
    return await _cache.getOrSet<BuiltList<Forum>>(
      'manga_forum_${id}_${type?.name ?? 'all'}',
      () async {
        try {
          return await _jikanApi.getMangaForum(id, type: type);
        } catch (e) {
          throw JikanServiceException('Failed to get manga forum: $e');
        }
      },
      expiration: _defaultCacheExpiry,
    );
  }

  /// Get manga pictures
  Future<BuiltList<Picture>> getMangaPictures(int id) async {
    return await _cache.getOrSet<BuiltList<Picture>>(
      'manga_pictures_$id',
      () async {
        try {
          return await _jikanApi.getMangaPictures(id);
        } catch (e) {
          throw JikanServiceException('Failed to get manga pictures: $e');
        }
      },
      expiration: _defaultCacheExpiry,
    );
  }

  /// Get manga statistics
  Future<Stats> getMangaStatistics(int id) async {
    return await _cache.getOrSet<Stats>(
      'manga_stats_$id',
      () async {
        try {
          return await _jikanApi.getMangaStatistics(id);
        } catch (e) {
          throw JikanServiceException('Failed to get manga statistics: $e');
        }
      },
      expiration: _defaultCacheExpiry,
    );
  }

  /// Get manga more info
  Future<String> getMangaMoreInfo(int id) async {
    return await _cache.getOrSet<String>(
      'manga_more_info_$id',
      () async {
        try {
          return await _jikanApi.getMangaMoreInfo(id);
        } catch (e) {
          throw JikanServiceException('Failed to get manga more info: $e');
        }
      },
      expiration: _defaultCacheExpiry,
    );
  }

  /// Get manga recommendations
  Future<BuiltList<Recommendation>> getMangaRecommendations(int id) async {
    return await _cache.getOrSet<BuiltList<Recommendation>>(
      'manga_recommendations_$id',
      () async {
        try {
          return await _jikanApi.getMangaRecommendations(id);
        } catch (e) {
          throw JikanServiceException('Failed to get manga recommendations: $e');
        }
      },
      expiration: _defaultCacheExpiry,
    );
  }

  /// Get manga user updates
  Future<BuiltList<UserUpdate>> getMangaUserUpdates(int id, {int page = 1}) async {
    return await _cache.getOrSet<BuiltList<UserUpdate>>(
      'manga_user_updates_${id}_$page',
      () async {
        try {
          return await _jikanApi.getMangaUserUpdates(id, page: page);
        } catch (e) {
          throw JikanServiceException('Failed to get manga user updates: $e');
        }
      },
      expiration: _defaultCacheExpiry,
    );
  }

  /// Get manga reviews
  Future<BuiltList<Review>> getMangaReviews(int id, {int page = 1}) async {
    return await _cache.getOrSet<BuiltList<Review>>(
      'manga_reviews_${id}_$page',
      () async {
        try {
          return await _jikanApi.getMangaReviews(id, page: page);
        } catch (e) {
          throw JikanServiceException('Failed to get manga reviews: $e');
        }
      },
      expiration: _defaultCacheExpiry,
    );
  }

  // =================
  // PEOPLE METHODS
  // =================

  /// Get person by ID
  Future<Person> getPerson(int id) async {
    return await _cache.getOrSet<Person>(
      'person_$id',
      () async {
        try {
          return await _jikanApi.getPerson(id);
        } catch (e) {
          throw JikanServiceException('Failed to get person: $e');
        }
      },
      expiration: _defaultCacheExpiry,
    );
  }

  /// Get person pictures
  Future<BuiltList<Picture>> getPersonPictures(int id) async {
    return await _cache.getOrSet<BuiltList<Picture>>(
      'person_pictures_$id',
      () async {
        try {
          return await _jikanApi.getPersonPictures(id);
        } catch (e) {
          throw JikanServiceException('Failed to get person pictures: $e');
        }
      },
      expiration: _defaultCacheExpiry,
    );
  }

  // =================
  // CHARACTER METHODS
  // =================

  /// Get character by ID
  Future<Character> getCharacter(int id) async {
    return await _cache.getOrSet<Character>(
      'character_$id',
      () async {
        try {
          return await _jikanApi.getCharacter(id);
        } catch (e) {
          throw JikanServiceException('Failed to get character: $e');
        }
      },
      expiration: _defaultCacheExpiry,
    );
  }

  /// Get character pictures
  Future<BuiltList<Picture>> getCharacterPictures(int id) async {
    return await _cache.getOrSet<BuiltList<Picture>>(
      'character_pictures_$id',
      () async {
        try {
          return await _jikanApi.getCharacterPictures(id);
        } catch (e) {
          throw JikanServiceException('Failed to get character pictures: $e');
        }
      },
      expiration: _defaultCacheExpiry,
    );
  }

  // =================
  // SEARCH METHODS
  // =================

  /// Search anime
  Future<List<Map<String, dynamic>>> searchAnime({
    String? query,
    AnimeType? type,
    List<int>? genres,
    List<int>? producers,
    String? orderBy,
    String? sort,
    int page = 1,
  }) async {
    debugPrint('🔍 [JikanService] Searching anime (query: ${query ?? 'none'}, page: $page)');
    
    final cacheKey = 'search_anime_${query ?? 'none'}_${type?.name ?? 'all'}_${genres?.join(',') ?? 'none'}_$page';
    
    return await _cache.getOrSet<List<Map<String, dynamic>>>(
      cacheKey,
      () async {
        try {
          debugPrint('🌐 [JikanService] Fetching search results from API...');
          final startTime = DateTime.now();
          
          final apiResult = await _jikanApi.searchAnime(
            query: query,
            type: type,
            genres: genres,
            producers: producers,
            orderBy: orderBy,
            sort: sort,
            page: page,
          );
          
          final duration = DateTime.now().difference(startTime);
          debugPrint('✅ [JikanService] API call completed in ${duration.inMilliseconds}ms');
          
          // Convert to simple Map format
          final List<Map<String, dynamic>> result = apiResult.map((anime) => _animeToMap(anime)).toList();
          debugPrint('✅ [JikanService] Converted ${result.length} search results to Map format');
          
          return result;
        } catch (e, stackTrace) {
          debugPrint('❌ [JikanService] Failed to search anime:');
          debugPrint('   • Error: $e');
          debugPrint('   • Stack trace: $stackTrace');
          throw JikanServiceException('Failed to search anime: $e');
        }
      },
      expiration: _defaultCacheExpiry,
    );
  }

  /// Search manga
  Future<List<Map<String, dynamic>>> searchManga({
    String? query,
    MangaType? type,
    List<int>? genres,
    List<int>? magazines,
    String? orderBy,
    String? sort,
    int page = 1,
  }) async {
    debugPrint('🔍 [JikanService] Searching manga (query: ${query ?? 'none'}, page: $page)');
    
    final cacheKey = 'search_manga_${query ?? 'none'}_${type?.name ?? 'all'}_${genres?.join(',') ?? 'none'}_$page';
    
    return await _cache.getOrSet<List<Map<String, dynamic>>>(
      cacheKey,
      () async {
        try {
          debugPrint('🌐 [JikanService] Fetching manga search results from API...');
          final startTime = DateTime.now();
          
          final builtResult = await _jikanApi.searchManga(
            query: query,
            type: type,
            genres: genres,
            magazines: magazines,
            orderBy: orderBy,
            sort: sort,
            page: page,
          );
          
          final duration = DateTime.now().difference(startTime);
          debugPrint('✅ [JikanService] API call completed in ${duration.inMilliseconds}ms');
          
          final List<Map<String, dynamic>> result = builtResult.map((manga) => _mangaToMap(manga)).toList();
          
          debugPrint('✅ [JikanService] Converted ${result.length} manga search results to Map format');
          return result;
        } catch (e, stackTrace) {
          debugPrint('❌ [JikanService] Failed to search manga:');
          debugPrint('   • Error: $e');
          debugPrint('   • Stack trace: $stackTrace');
          throw JikanServiceException('Failed to search manga: $e');
        }
      },
      expiration: _defaultCacheExpiry,
    );
  }

  /// Search people
  Future<BuiltList<Person>> searchPeople({
    String? query,
    String? orderBy,
    String? sort,
    int page = 1,
  }) async {
    try {
      return await _jikanApi.searchPeople(
        query: query,
        orderBy: orderBy,
        sort: sort,
        page: page,
      );
    } catch (e) {
      throw JikanServiceException('Failed to search people: $e');
    }
  }

  /// Search characters
  Future<BuiltList<Character>> searchCharacters({
    String? query,
    String? orderBy,
    String? sort,
    int page = 1,
  }) async {
    try {
      return await _jikanApi.searchCharacters(
        query: query,
        orderBy: orderBy,
        sort: sort,
        page: page,
      );
    } catch (e) {
      throw JikanServiceException('Failed to search characters: $e');
    }
  }

  // =================
  // SEASON METHODS
  // =================

  /// Get seasonal anime
  Future<List<Map<String, dynamic>>> getSeason({
    int? year,
    SeasonType? season,
    int page = 1,
  }) async {
    debugPrint('🌸 [JikanService] Getting seasonal anime (year: ${year ?? 'current'}, season: ${season?.name ?? 'all'}, page: $page)');
    
    return await _cache.getOrSet<List<Map<String, dynamic>>>(
      'season_${year ?? 'current'}_${season?.name ?? 'all'}_$page',
      () async {
        try {
          debugPrint('🌐 [JikanService] Fetching seasonal anime from API...');
          final startTime = DateTime.now();
          
          final builtResult = await _jikanApi.getSeason(
            year: year,
            season: season,
            page: page,
          );
          
          final duration = DateTime.now().difference(startTime);
          debugPrint('✅ [JikanService] API call completed in ${duration.inMilliseconds}ms');
          
          final List<Map<String, dynamic>> result = builtResult.map((anime) => _animeToMap(anime)).toList();
          
          debugPrint('✅ [JikanService] Converted ${result.length} seasonal anime to Map format');
          return result;
        } catch (e, stackTrace) {
          debugPrint('❌ [JikanService] Failed to get seasonal anime:');
          debugPrint('   • Error: $e');
          debugPrint('   • Stack trace: $stackTrace');
          throw JikanServiceException('Failed to get season: $e');
        }
      },
      expiration: _defaultCacheExpiry,
    );
  }

  /// Get upcoming seasonal anime
  Future<List<Map<String, dynamic>>> getSeasonUpcoming({int page = 1}) async {
    debugPrint('🔮 [JikanService] Getting upcoming season anime (page: $page)');
    
    final cacheKey = 'season_upcoming_page_$page';
    
    return await _cache.getOrSet<List<Map<String, dynamic>>>(
      cacheKey,
      () async {
        try {
          debugPrint('🌐 [JikanService] Fetching upcoming season anime from API...');
          final startTime = DateTime.now();
          
          // Get built_value result from API
          final builtResult = await _jikanApi.getSeasonUpcoming(page: page);
          
          final duration = DateTime.now().difference(startTime);
          debugPrint('✅ [JikanService] API call completed in ${duration.inMilliseconds}ms');
          
          // Convert to simple Map format
          final List<Map<String, dynamic>> result = builtResult.map((anime) => _animeToMap(anime)).toList();
          
          debugPrint('✅ [JikanService] Converted ${result.length} upcoming season anime to Map format');
          return result;
        } catch (e, stackTrace) {
          debugPrint('❌ [JikanService] Failed to get upcoming season anime:');
          debugPrint('   • Error: $e');
          debugPrint('   • Stack trace: $stackTrace');
          throw JikanServiceException('Failed to get upcoming season: $e');
        }
      },
      expiration: _defaultCacheExpiry,
    );
  }

  /// Get seasons list/archive
  Future<BuiltList<Archive>> getSeasonsList() async {
    return await _cache.getOrSet<BuiltList<Archive>>(
      'seasons_list',
      () async {
        try {
          return await _jikanApi.getSeasonsList();
        } catch (e) {
          throw JikanServiceException('Failed to get seasons list: $e');
        }
      },
      expiration: _defaultCacheExpiry,
    );
  }

  // =================
  // SCHEDULE METHODS
  // =================

  /// Get anime schedules
  Future<List<Map<String, dynamic>>> getSchedules({
    WeekDay? weekday,
    int page = 1,
  }) async {
    debugPrint('📅 [JikanService] Getting anime schedules (weekday: ${weekday?.name ?? 'all'}, page: $page)');
    
    final cacheKey = 'schedules_${weekday?.name ?? 'all'}_$page';
    
    return await _cache.getOrSet<List<Map<String, dynamic>>>(
      cacheKey,
      () async {
        try {
          debugPrint('🌐 [JikanService] Fetching anime schedules from API...');
          final startTime = DateTime.now();
          
          // Get built_value result from API
          final builtResult = await _jikanApi.getSchedules(
            weekday: weekday,
            page: page,
          );
          
          final duration = DateTime.now().difference(startTime);
          debugPrint('✅ [JikanService] API call completed in ${duration.inMilliseconds}ms');
          
          // Convert to simple Map format
          final List<Map<String, dynamic>> result = builtResult.map((anime) => _animeToMap(anime)).toList();
          
          debugPrint('✅ [JikanService] Converted ${result.length} anime schedules to Map format');
          return result;
        } catch (e, stackTrace) {
          debugPrint('❌ [JikanService] Failed to get anime schedules:');
          debugPrint('   • Error: $e');
          debugPrint('   • Stack trace: $stackTrace');
          throw JikanServiceException('Failed to get schedules: $e');
        }
      },
      expiration: _defaultCacheExpiry,
    );
  }

  // =================
  // TOP LISTS METHODS
  // =================

  /// Get top anime
  Future<List<Map<String, dynamic>>> getTopAnime({
    AnimeType? type,
    TopFilter? filter,
    int page = 1,
  }) async {
    final cacheKey = 'top_anime_${type?.name ?? 'all'}_${filter?.name ?? 'all'}_$page';
    
    debugPrint('🔍 [JikanService] Fetching top anime:');
    debugPrint('   • Type: ${type?.name ?? 'all'}');
    debugPrint('   • Filter: ${filter?.name ?? 'all'}');
    debugPrint('   • Page: $page');
    debugPrint('   • Cache Key: $cacheKey');
    
    try {
      final result = await _cache.getOrSet<List<Map<String, dynamic>>>(
        cacheKey,
        () async {
          debugPrint('🌐 [JikanService] Making API call to Jikan...');
          final startTime = DateTime.now();
          
          try {
            final apiResult = await _jikanApi.getTopAnime(
              type: type,
              filter: filter,
              page: page,
            );
            
            final endTime = DateTime.now();
            final duration = endTime.difference(startTime);
            
            debugPrint('✅ [JikanService] API call successful:');
            debugPrint('   • Duration: ${duration.inMilliseconds}ms');
            debugPrint('   • Results count: ${apiResult.length}');
            debugPrint('   • First anime: ${apiResult.isNotEmpty ? apiResult.first.title : 'N/A'}');
            
            // Convert to simple Map format
            final List<Map<String, dynamic>> convertedResult = apiResult.map((anime) => _animeToMap(anime)).toList();
            debugPrint('✅ [JikanService] Converted ${convertedResult.length} anime to Map format');
            
            return convertedResult;
          } catch (apiError, stackTrace) {
            final endTime = DateTime.now();
            final duration = endTime.difference(startTime);
            
            debugPrint('❌ [JikanService] API call failed:');
            debugPrint('   • Duration: ${duration.inMilliseconds}ms');
            debugPrint('   • Error Type: ${apiError.runtimeType}');
            debugPrint('   • Error Message: $apiError');
            debugPrint('   • Stack Trace: $stackTrace');
            
                         // Try to provide more specific error information
             if (apiError.toString().contains('SocketException')) {
               throw JikanServiceException.now(
                 'Network error: Unable to connect to Jikan API. Please check your internet connection.',
                 endpoint: 'getTopAnime',
                 originalError: apiError,
                 stackTrace: stackTrace,
               );
             } else if (apiError.toString().contains('TimeoutException')) {
               throw JikanServiceException.now(
                 'Request timeout: Jikan API is taking too long to respond.',
                 endpoint: 'getTopAnime',
                 originalError: apiError,
                 stackTrace: stackTrace,
               );
             } else if (apiError.toString().contains('HttpException') || apiError.toString().contains('404')) {
               throw JikanServiceException.now(
                 'API error: Jikan API returned an error. The endpoint might be unavailable.',
                 endpoint: 'getTopAnime',
                 originalError: apiError,
                 stackTrace: stackTrace,
               );
             } else if (apiError.toString().contains('FormatException')) {
               throw JikanServiceException.now(
                 'Data format error: Jikan API returned invalid data format.',
                 endpoint: 'getTopAnime',
                 originalError: apiError,
                 stackTrace: stackTrace,
               );
             } else {
               throw JikanServiceException.now(
                 'Failed to get top anime: $apiError',
                 endpoint: 'getTopAnime',
                 originalError: apiError,
                 stackTrace: stackTrace,
               );
             }
          }
        },
        expiration: _defaultCacheExpiry,
      );
      
      debugPrint('✅ [JikanService] Request completed successfully');
      debugPrint('   • Final result count: ${result.length}');
      
      return result;
    } catch (e, stackTrace) {
      debugPrint('❌ [JikanService] Top anime request failed:');
      debugPrint('   • Error: $e');
      debugPrint('   • Stack Trace: $stackTrace');
      rethrow;
    }
  }

  /// Get top manga
  Future<BuiltList<Manga>> getTopManga({
    MangaType? type,
    TopFilter? filter,
    int page = 1,
  }) async {
    return await _cache.getOrSet<BuiltList<Manga>>(
      'top_manga_${type?.name ?? 'all'}_${filter?.name ?? 'all'}_$page',
      () async {
        try {
          return await _jikanApi.getTopManga(
            type: type,
            filter: filter,
            page: page,
          );
        } catch (e) {
          throw JikanServiceException('Failed to get top manga: $e');
        }
      },
      expiration: _defaultCacheExpiry,
    );
  }

  /// Get top people
  Future<BuiltList<Person>> getTopPeople({int page = 1}) async {
    return await _cache.getOrSet<BuiltList<Person>>(
      'top_people_$page',
      () async {
        try {
          return await _jikanApi.getTopPeople(page: page);
        } catch (e) {
          throw JikanServiceException('Failed to get top people: $e');
        }
      },
      expiration: _defaultCacheExpiry,
    );
  }

  /// Get top characters
  Future<BuiltList<Character>> getTopCharacters({int page = 1}) async {
    return await _cache.getOrSet<BuiltList<Character>>(
      'top_characters_$page',
      () async {
        try {
          return await _jikanApi.getTopCharacters(page: page);
        } catch (e) {
          throw JikanServiceException('Failed to get top characters: $e');
        }
      },
      expiration: _defaultCacheExpiry,
    );
  }

  /// Get top reviews
  Future<BuiltList<UserReview>> getTopReviews({int page = 1}) async {
    return await _cache.getOrSet<BuiltList<UserReview>>(
      'top_reviews_$page',
      () async {
        try {
          return await _jikanApi.getTopReviews(page: page);
        } catch (e) {
          throw JikanServiceException('Failed to get top reviews: $e');
        }
      },
      expiration: _defaultCacheExpiry,
    );
  }

  // =================
  // GENRE METHODS
  // =================

  /// Get anime genres
  Future<BuiltList<Genre>> getAnimeGenres({GenreType? type}) async {
    return await _cache.getOrSet<BuiltList<Genre>>(
      'anime_genres_${type?.name ?? 'all'}',
      () async {
        try {
          return await _jikanApi.getAnimeGenres(type: type);
        } catch (e) {
          throw JikanServiceException('Failed to get anime genres: $e');
        }
      },
      expiration: _defaultCacheExpiry,
    );
  }

  /// Get manga genres
  Future<BuiltList<Genre>> getMangaGenres({GenreType? type}) async {
    return await _cache.getOrSet<BuiltList<Genre>>(
      'manga_genres_${type?.name ?? 'all'}',
      () async {
        try {
          return await _jikanApi.getMangaGenres(type: type);
        } catch (e) {
          throw JikanServiceException('Failed to get manga genres: $e');
        }
      },
      expiration: _defaultCacheExpiry,
    );
  }

  // =================
  // PRODUCER METHODS
  // =================

  /// Get producers
  Future<BuiltList<Producer>> getProducers({
    String? query,
    String? orderBy,
    String? sort,
    int page = 1,
  }) async {
    return await _cache.getOrSet<BuiltList<Producer>>(
      'producers_${query ?? ''}_${orderBy ?? ''}_${sort ?? ''}_$page',
      () async {
        try {
          return await _jikanApi.getProducers(
            query: query,
            orderBy: orderBy,
            sort: sort,
            page: page,
          );
        } catch (e) {
          throw JikanServiceException('Failed to get producers: $e');
        }
      },
      expiration: _defaultCacheExpiry,
    );
  }

  // =================
  // MAGAZINE METHODS
  // =================

  /// Get magazines
  Future<BuiltList<Magazine>> getMagazines({
    String? query,
    String? orderBy,
    String? sort,
    int page = 1,
  }) async {
    return await _cache.getOrSet<BuiltList<Magazine>>(
      'magazines_${query ?? ''}_${orderBy ?? ''}_${sort ?? ''}_$page',
      () async {
        try {
          return await _jikanApi.getMagazines(
            query: query,
            orderBy: orderBy,
            sort: sort,
            page: page,
          );
        } catch (e) {
          throw JikanServiceException('Failed to get magazines: $e');
        }
      },
      expiration: _defaultCacheExpiry,
    );
  }

  // =================
  // USER METHODS
  // =================

  /// Get user profile
  Future<UserProfile> getUserProfile(String username) async {
    return await _cache.getOrSet<UserProfile>(
      'user_profile_$username',
      () async {
        try {
          return await _jikanApi.getUserProfile(username);
        } catch (e) {
          throw JikanServiceException('Failed to get user profile: $e');
        }
      },
      expiration: _defaultCacheExpiry,
    );
  }

  /// Get user history
  Future<BuiltList<History>> getUserHistory(String username, {HistoryType? type}) async {
    return await _cache.getOrSet<BuiltList<History>>(
      'user_history_${username}_${type?.name ?? 'all'}',
      () async {
        try {
          return await _jikanApi.getUserHistory(username, type: type);
        } catch (e) {
          throw JikanServiceException('Failed to get user history: $e');
        }
      },
      expiration: _defaultCacheExpiry,
    );
  }

  /// Get user friends
  Future<BuiltList<Friend>> getUserFriends(String username, {int page = 1}) async {
    return await _cache.getOrSet<BuiltList<Friend>>(
      'user_friends_${username}_$page',
      () async {
        try {
          return await _jikanApi.getUserFriends(username, page: page);
        } catch (e) {
          throw JikanServiceException('Failed to get user friends: $e');
        }
      },
      expiration: _defaultCacheExpiry,
    );
  }

  /// Get user reviews
  Future<BuiltList<UserReview>> getUserReviews(String username, {int page = 1}) async {
    return await _cache.getOrSet<BuiltList<UserReview>>(
      'user_reviews_${username}_$page',
      () async {
        try {
          return await _jikanApi.getUserReviews(username, page: page);
        } catch (e) {
          throw JikanServiceException('Failed to get user reviews: $e');
        }
      },
      expiration: _defaultCacheExpiry,
    );
  }

  /// Get user recommendations
  Future<BuiltList<UserRecommendation>> getUserRecommendations(String username, {int page = 1}) async {
    return await _cache.getOrSet<BuiltList<UserRecommendation>>(
      'user_recommendations_${username}_$page',
      () async {
        try {
          return await _jikanApi.getUserRecommendations(username, page: page);
        } catch (e) {
          throw JikanServiceException('Failed to get user recommendations: $e');
        }
      },
      expiration: _defaultCacheExpiry,
    );
  }

  // =================
  // RECENT CONTENT METHODS
  // =================

  /// Get recent anime reviews
  Future<BuiltList<UserReview>> getRecentAnimeReviews({int page = 1}) async {
    return await _cache.getOrSet<BuiltList<UserReview>>(
      'recent_anime_reviews_$page',
      () async {
        try {
          return await _jikanApi.getRecentAnimeReviews(page: page);
        } catch (e) {
          throw JikanServiceException('Failed to get recent anime reviews: $e');
        }
      },
      expiration: _defaultCacheExpiry,
    );
  }

  /// Get recent manga reviews
  Future<BuiltList<UserReview>> getRecentMangaReviews({int page = 1}) async {
    return await _cache.getOrSet<BuiltList<UserReview>>(
      'recent_manga_reviews_$page',
      () async {
        try {
          return await _jikanApi.getRecentMangaReviews(page: page);
        } catch (e) {
          throw JikanServiceException('Failed to get recent manga reviews: $e');
        }
      },
      expiration: _defaultCacheExpiry,
    );
  }

  /// Get recent anime recommendations
  Future<BuiltList<UserRecommendation>> getRecentAnimeRecommendations({int page = 1}) async {
    return await _cache.getOrSet<BuiltList<UserRecommendation>>(
      'recent_anime_recommendations_$page',
      () async {
        try {
          return await _jikanApi.getRecentAnimeRecommendations(page: page);
        } catch (e) {
          throw JikanServiceException('Failed to get recent anime recommendations: $e');
        }
      },
      expiration: _defaultCacheExpiry,
    );
  }

  /// Get recent manga recommendations
  Future<BuiltList<UserRecommendation>> getRecentMangaRecommendations({int page = 1}) async {
    return await _cache.getOrSet<BuiltList<UserRecommendation>>(
      'recent_manga_recommendations_$page',
      () async {
        try {
          return await _jikanApi.getRecentMangaRecommendations(page: page);
        } catch (e) {
          throw JikanServiceException('Failed to get recent manga recommendations: $e');
        }
      },
      expiration: _defaultCacheExpiry,
    );
  }

  // =================
  // WATCH METHODS
  // =================

  /// Get watch episodes
  Future<BuiltList<WatchEpisode>> getWatchEpisodes({bool popular = false}) async {
    return await _cache.getOrSet<BuiltList<WatchEpisode>>(
      'watch_episodes_${popular ? 'popular' : 'recent'}',
      () async {
        try {
          return await _jikanApi.getWatchEpisodes(popular: popular);
        } catch (e) {
          throw JikanServiceException('Failed to get watch episodes: $e');
        }
      },
      expiration: _defaultCacheExpiry,
    );
  }

  /// Get watch promos
  Future<BuiltList<WatchPromo>> getWatchPromos({bool popular = false}) async {
    return await _cache.getOrSet<BuiltList<WatchPromo>>(
      'watch_promos_${popular ? 'popular' : 'recent'}',
      () async {
        try {
          return await _jikanApi.getWatchPromos(popular: popular);
        } catch (e) {
          throw JikanServiceException('Failed to get watch promos: $e');
        }
      },
      expiration: _defaultCacheExpiry,
    );
  }

  // =================
  // UTILITY METHODS
  // =================

  /// Get popular anime - Returns simple Map format for easy caching and UI usage
  Future<List<Map<String, dynamic>>> getPopularAnime({int page = 1}) async {
    debugPrint('🔥 [JikanService] Getting popular anime (page: $page)');
    
    final cacheKey = 'popular_anime_page_$page';
    
    return await _cache.getOrSet<List<Map<String, dynamic>>>(
      cacheKey,
      () async {
        try {
          debugPrint('🌐 [JikanService] Fetching popular anime from API...');
          final startTime = DateTime.now();
          
          // Get built_value result from API
          final builtResult = await _jikanApi.getTopAnime(
            filter: TopFilter.bypopularity,
            page: page,
          );
          
          final duration = DateTime.now().difference(startTime);
          debugPrint('✅ [JikanService] API call completed in ${duration.inMilliseconds}ms');
          
          // Convert to simple Map format
          final List<Map<String, dynamic>> result = builtResult.map((anime) => _animeToMap(anime)).toList();
          
          debugPrint('✅ [JikanService] Converted ${result.length} anime to Map format');
          return result;
        } catch (e, stackTrace) {
          debugPrint('❌ [JikanService] Failed to get popular anime:');
          debugPrint('   • Error: $e');
          debugPrint('   • Stack trace: $stackTrace');
          throw JikanServiceException('Failed to get popular anime: $e');
        }
      },
      expiration: _defaultCacheExpiry,
    );
  }

  /// Get airing anime (convenience method)
  Future<List<Map<String, dynamic>>> getAiringAnime({int page = 1}) async {
    return await getTopAnime(filter: TopFilter.airing, page: page);
  }

  /// Get favorite anime (convenience method)
  Future<List<Map<String, dynamic>>> getFavoriteAnime({int page = 1}) async {
    return await getTopAnime(filter: TopFilter.favorite, page: page);
  }

  /// Get current season anime (convenience method)
  Future<List<Map<String, dynamic>>> getCurrentSeasonAnime({int page = 1}) async {
    debugPrint('🌸 [JikanService] Getting current season anime (page: $page)');
    
    final cacheKey = 'current_season_anime_page_$page';
    
    return await _cache.getOrSet<List<Map<String, dynamic>>>(
      cacheKey,
      () async {
        try {
          debugPrint('🌐 [JikanService] Fetching current season anime from API...');
          final startTime = DateTime.now();
          
          // Get built_value result from API
          final builtResult = await _jikanApi.getSeason(page: page);
          
          final duration = DateTime.now().difference(startTime);
          debugPrint('✅ [JikanService] API call completed in ${duration.inMilliseconds}ms');
          
          // Convert to simple Map format
          final List<Map<String, dynamic>> result = builtResult.map((anime) => _animeToMap(anime)).toList();
          
          debugPrint('✅ [JikanService] Converted ${result.length} current season anime to Map format');
          return result;
        } catch (e, stackTrace) {
          debugPrint('❌ [JikanService] Failed to get current season anime:');
          debugPrint('   • Error: $e');
          debugPrint('   • Stack trace: $stackTrace');
          throw JikanServiceException('Failed to get current season anime: $e');
        }
      },
      expiration: _defaultCacheExpiry,
    );
  }

  /// Get anime by genre (convenience method)
  Future<List<Map<String, dynamic>>> getAnimeByGenre(int genreId, {int page = 1}) async {
    return await searchAnime(genres: [genreId], page: page);
  }

  /// Get manga by genre (convenience method)
  Future<List<Map<String, dynamic>>> getMangaByGenre(int genreId, {int page = 1}) async {
    debugPrint('📚 [JikanService] Getting manga by genre (genreId: $genreId, page: $page)');
    
    final cacheKey = 'manga_by_genre_${genreId}_page_$page';
    
    return await _cache.getOrSet<List<Map<String, dynamic>>>(
      cacheKey,
      () async {
        try {
          debugPrint('🌐 [JikanService] Fetching manga by genre from API...');
          final startTime = DateTime.now();
          
          // Get built_value result from API
          final builtResult = await _jikanApi.searchManga(genres: [genreId], page: page);
          
          final duration = DateTime.now().difference(startTime);
          debugPrint('✅ [JikanService] API call completed in ${duration.inMilliseconds}ms');
          
          // Convert to simple Map format
          final List<Map<String, dynamic>> result = builtResult.map((manga) => _mangaToMap(manga)).toList();
          
          debugPrint('✅ [JikanService] Converted ${result.length} manga to Map format');
          return result;
        } catch (e, stackTrace) {
          debugPrint('❌ [JikanService] Failed to get manga by genre:');
          debugPrint('   • Error: $e');
          debugPrint('   • Stack trace: $stackTrace');
          throw JikanServiceException('Failed to get manga by genre: $e');
        }
      },
      expiration: _defaultCacheExpiry,
    );
  }

  // =================
  // CONVERSION METHODS
  // =================

  /// Convert Anime built_value object to simple Map
  Map<String, dynamic> _animeToMap(Anime anime) {
    return {
      'malId': anime.malId,
      'url': anime.url,
      'imageUrl': anime.imageUrl,
      'title': anime.title,
      'titleEnglish': anime.titleEnglish,
      'titleJapanese': anime.titleJapanese,
      'episodes': anime.episodes,
      'status': anime.status,
      'aired': anime.aired,
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
      }).toList(),
      'studios': anime.studios?.map((studio) => {
        'malId': studio.malId,
        'name': studio.name,
      }).toList(),
    };
  }

  /// Convert Manga built_value object to simple Map
  Map<String, dynamic> _mangaToMap(Manga manga) {
    return {
      'malId': manga.malId,
      'url': manga.url,
      'imageUrl': manga.imageUrl,
      'title': manga.title,
      'titleEnglish': manga.titleEnglish,
      'titleJapanese': manga.titleJapanese,
      'chapters': manga.chapters,
      'volumes': manga.volumes,
      'status': manga.status,
      'published': manga.published,
      'score': manga.score,
      'scoredBy': manga.scoredBy,
      'rank': manga.rank,
      'popularity': manga.popularity,
      'members': manga.members,
      'favorites': manga.favorites,
      'synopsis': manga.synopsis,
      'background': manga.background,
      'genres': manga.genres?.map((genre) => {
        'malId': genre.malId,
        'name': genre.name,
      }).toList(),
      'authors': manga.authors?.map((author) => {
        'malId': author.malId,
        'name': author.name,
      }).toList(),
      'serializations': manga.serializations?.map((serialization) => {
        'malId': serialization.malId,
        'name': serialization.name,
      }).toList(),
    };
  }
}

/// Custom exception for Jikan Service errors
class JikanServiceException implements Exception {
  final String message;
  final String? endpoint;
  final Object? originalError;
  final StackTrace? stackTrace;
  final DateTime? timestamp;
  
  const JikanServiceException(
    this.message, {
    this.endpoint,
    this.originalError,
    this.stackTrace,
    this.timestamp,
  });
  
  JikanServiceException.now(
    this.message, {
    this.endpoint,
    this.originalError,
    this.stackTrace,
  }) : timestamp = DateTime.now();
  
  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.writeln('JikanServiceException: $message');
    if (endpoint != null) buffer.writeln('  Endpoint: $endpoint');
    if (originalError != null) buffer.writeln('  Original Error: $originalError');
    if (timestamp != null) buffer.writeln('  Timestamp: $timestamp');
    return buffer.toString();
  }
} 
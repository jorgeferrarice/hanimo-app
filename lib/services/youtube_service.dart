import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'app_config_service.dart';
import 'cache_service.dart';

/// Service for fetching YouTube video data using YouTube Data API v3
/// Integrates with Firebase Remote Config for API key management
class YouTubeService {
  static final YouTubeService _instance = YouTubeService._internal();
  factory YouTubeService() => _instance;
  YouTubeService._internal();

  static YouTubeService get instance => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CacheService _cache = CacheService.instance;
  
  /// Cache duration for YouTube video data (1 week)
  /// Extended duration due to YouTube Data API quotas
  static const Duration _cacheExpiry = Duration(days: 7);
  
  /// Base URL for YouTube Data API v3
  static const String _baseUrl = 'https://www.googleapis.com/youtube/v3';

  /// Search for YouTube videos related to an anime
  /// Priority: Firestore cache → Memory cache → YouTube API
  Future<List<Map<String, dynamic>>> searchAnimeVideos(
    int animeId,
    String animeTitle, {
    int maxResults = 5,
  }) async {
    debugPrint('🎬 [YouTubeService] Searching videos for anime: $animeTitle (ID: $animeId)');
    
    try {
      // 1. Check Firestore cache first
      final firestoreVideos = await _getVideosFromFirestore(animeId);
      if (firestoreVideos.isNotEmpty) {
        debugPrint('✅ [YouTubeService] Found ${firestoreVideos.length} videos in Firestore cache');
        return firestoreVideos;
      }
      
      // 2. Check memory cache
      final cacheKey = 'youtube_videos_$animeId';
      try {
        final cachedVideos = await _cache.get<List<Map<String, dynamic>>>(cacheKey);
        if (cachedVideos != null && cachedVideos.isNotEmpty) {
          debugPrint('✅ [YouTubeService] Found ${cachedVideos.length} videos in memory cache');
          return cachedVideos;
        }
      } catch (e) {
        debugPrint('⚠️ [YouTubeService] Memory cache error: $e');
      }
      
      // 3. Fetch from YouTube API
      final apiVideos = await _fetchFromYouTubeAPI(animeTitle, maxResults: maxResults);
      
      if (apiVideos.isNotEmpty) {
        // Cache in memory
        await _cache.set(cacheKey, apiVideos, expiration: _cacheExpiry);
        
        // Save to Firestore for persistence
        await _saveVideosToFirestore(animeId, apiVideos);
        
        debugPrint('✅ [YouTubeService] Fetched and cached ${apiVideos.length} videos from YouTube API');
      }
      
      return apiVideos;
    } catch (e, stackTrace) {
      debugPrint('❌ [YouTubeService] Error searching anime videos: $e');
      debugPrint('   • Stack trace: $stackTrace');
      return [];
    }
  }

  /// Fetch videos from YouTube Data API
  Future<List<Map<String, dynamic>>> _fetchFromYouTubeAPI(
    String query, {
    int maxResults = 5,
  }) async {
    debugPrint('🌐 [YouTubeService] Fetching from YouTube API...');
    
    // Get API key from Remote Config
    final appConfig = AppConfigService.instance;
    final apiKey = await appConfig.getYouTubeDataApiKey();
    
    if (apiKey.isEmpty) {
      debugPrint('❌ [YouTubeService] YouTube Data API key not configured');
      throw Exception('YouTube Data API key not configured in Remote Config');
    }
    
    // Build search query with anime-specific terms
    // If query already contains 'Anime Trailer', use it as-is, otherwise add keywords
    final searchQuery = query.toLowerCase().contains('anime trailer') 
        ? query 
        : '$query trailer PV promotional video anime';
    
    try {
      final startTime = DateTime.now();
      
      // Search for videos
      final searchUrl = Uri.parse('$_baseUrl/search').replace(queryParameters: {
        'part': 'snippet',
        'q': searchQuery,
        'type': 'video',
        'maxResults': maxResults.toString(),
        'order': 'relevance',
        'videoCategoryId': '24', // Entertainment category
        'key': apiKey,
      });
      
      debugPrint('🔍 [YouTubeService] Search query: "$searchQuery"');
      debugPrint('🌐 [YouTubeService] API URL: ${searchUrl.toString().replaceAll(apiKey, '***')}');
      
      final response = await http.get(searchUrl);
      final duration = DateTime.now().difference(startTime);
      
      debugPrint('📊 [YouTubeService] API response: ${response.statusCode} (${duration.inMilliseconds}ms)');
      
      if (response.statusCode != 200) {
        debugPrint('❌ [YouTubeService] API error: ${response.statusCode}');
        debugPrint('   • Response: ${response.body}');
        throw Exception('YouTube API error: ${response.statusCode}');
      }
      
      final data = json.decode(response.body);
      final items = data['items'] as List<dynamic>? ?? [];
      
      if (items.isEmpty) {
        debugPrint('⚠️ [YouTubeService] No videos found for query: "$searchQuery"');
        return [];
      }
      
      // Extract video IDs for additional details
      final videoIds = items
          .map((item) => item['id']['videoId'] as String)
          .toList();
      
      // Get additional video details
      final videoDetails = await _getVideoDetails(videoIds, apiKey);
      
      // Combine search results with details
      final videos = <Map<String, dynamic>>[];
      for (int i = 0; i < items.length; i++) {
        final item = items[i];
        final videoId = item['id']['videoId'] as String;
        final snippet = item['snippet'] as Map<String, dynamic>;
        final details = videoDetails[videoId];
        
        videos.add({
          'videoId': videoId,
          'title': snippet['title'] ?? 'Untitled Video',
          'description': snippet['description'] ?? '',
          'channelTitle': snippet['channelTitle'] ?? '',
          'publishedAt': snippet['publishedAt'] ?? '',
          'thumbnailUrl': snippet['thumbnails']?['high']?['url'] ?? 
                         snippet['thumbnails']?['medium']?['url'] ?? 
                         snippet['thumbnails']?['default']?['url'] ?? '',
          'url': 'https://www.youtube.com/watch?v=$videoId',
          'embedUrl': 'https://www.youtube.com/embed/$videoId',
          'duration': details?['duration'] ?? '',
          'viewCount': details?['viewCount'] ?? 0,
          'likeCount': details?['likeCount'] ?? 0,
          'tags': details?['tags'] ?? [],
          'fetchedAt': DateTime.now().toIso8601String(),
        });
      }
      
      debugPrint('✅ [YouTubeService] Successfully processed ${videos.length} videos');
      return videos;
      
    } catch (e, stackTrace) {
      debugPrint('❌ [YouTubeService] API fetch error: $e');
      debugPrint('   • Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Get detailed information about videos
  Future<Map<String, Map<String, dynamic>>> _getVideoDetails(
    List<String> videoIds,
    String apiKey,
  ) async {
    if (videoIds.isEmpty) return {};
    
    try {
      final videoUrl = Uri.parse('$_baseUrl/videos').replace(queryParameters: {
        'part': 'contentDetails,statistics,snippet',
        'id': videoIds.join(','),
        'key': apiKey,
      });
      
      final response = await http.get(videoUrl);
      
      if (response.statusCode != 200) {
        debugPrint('⚠️ [YouTubeService] Video details API error: ${response.statusCode}');
        return {};
      }
      
      final data = json.decode(response.body);
      final items = data['items'] as List<dynamic>? ?? [];
      
      final details = <String, Map<String, dynamic>>{};
      for (final item in items) {
        final videoId = item['id'] as String;
        final contentDetails = item['contentDetails'] as Map<String, dynamic>? ?? {};
        final statistics = item['statistics'] as Map<String, dynamic>? ?? {};
        final snippet = item['snippet'] as Map<String, dynamic>? ?? {};
        
        details[videoId] = {
          'duration': contentDetails['duration'] ?? '',
          'viewCount': int.tryParse(statistics['viewCount']?.toString() ?? '0') ?? 0,
          'likeCount': int.tryParse(statistics['likeCount']?.toString() ?? '0') ?? 0,
          'tags': snippet['tags'] ?? [],
        };
      }
      
      return details;
    } catch (e) {
      debugPrint('⚠️ [YouTubeService] Error getting video details: $e');
      return {};
    }
  }

  /// Get videos from Firestore cache
  Future<List<Map<String, dynamic>>> _getVideosFromFirestore(int animeId) async {
    try {
      final doc = await _firestore
          .collection('animes')
          .doc(animeId.toString())
          .collection('videos')
          .doc('youtube')
          .get();
      
      if (!doc.exists) {
        debugPrint('📝 [YouTubeService] No Firestore cache found for anime $animeId');
        return [];
      }
      
      final data = doc.data()!;
      final videos = List<Map<String, dynamic>>.from(data['videos'] ?? []);
      final cachedAt = (data['cachedAt'] as Timestamp?)?.toDate();
      
      // Check if cache is still valid (1 week)
      if (cachedAt != null && DateTime.now().difference(cachedAt) < _cacheExpiry) {
        debugPrint('✅ [YouTubeService] Found ${videos.length} valid videos in Firestore cache');
        return videos;
      } else {
        debugPrint('⏰ [YouTubeService] Firestore cache expired for anime $animeId');
        return [];
      }
    } catch (e) {
      debugPrint('❌ [YouTubeService] Error reading from Firestore: $e');
      return [];
    }
  }

  /// Save videos to Firestore for persistence
  Future<void> _saveVideosToFirestore(int animeId, List<Map<String, dynamic>> videos) async {
    try {
      await _firestore
          .collection('animes')
          .doc(animeId.toString())
          .collection('videos')
          .doc('youtube')
          .set({
        'videos': videos,
        'cachedAt': FieldValue.serverTimestamp(),
        'animeId': animeId,
        'totalVideos': videos.length,
      });
      
      debugPrint('💾 [YouTubeService] Saved ${videos.length} videos to Firestore for anime $animeId');
    } catch (e) {
      debugPrint('❌ [YouTubeService] Error saving to Firestore: $e');
      // Don't rethrow - this is a secondary operation
    }
  }

  /// Clear cache for a specific anime
  Future<void> clearAnimeCache(int animeId) async {
    try {
      // Clear memory cache
      await _cache.remove('youtube_videos_$animeId');
      
      // Clear Firestore cache
      await _firestore
          .collection('animes')
          .doc(animeId.toString())
          .collection('videos')
          .doc('youtube')
          .delete();
      
      debugPrint('🗑️ [YouTubeService] Cleared cache for anime $animeId');
    } catch (e) {
      debugPrint('❌ [YouTubeService] Error clearing cache: $e');
    }
  }

  /// Check if YouTube Data API is configured
  Future<bool> isConfigured() async {
    final appConfig = AppConfigService.instance;
    return await appConfig.isYouTubeDataApiKeyConfigured();
  }

  /// Test YouTube API connection
  Future<bool> testConnection() async {
    try {
      final appConfig = AppConfigService.instance;
      final apiKey = await appConfig.getYouTubeDataApiKey();
      
      if (apiKey.isEmpty) {
        debugPrint('❌ [YouTubeService] API key not configured');
        return false;
      }
      
      // Simple test query
      final testUrl = Uri.parse('$_baseUrl/search').replace(queryParameters: {
        'part': 'snippet',
        'q': 'test',
        'type': 'video',
        'maxResults': '1',
        'key': apiKey,
      });
      
      final response = await http.get(testUrl);
      final success = response.statusCode == 200;
      
      debugPrint('🔧 [YouTubeService] Connection test: ${success ? 'SUCCESS' : 'FAILED'} (${response.statusCode})');
      return success;
    } catch (e) {
      debugPrint('❌ [YouTubeService] Connection test failed: $e');
      return false;
    }
  }

  /// Get service statistics
  Future<Map<String, dynamic>> getStats() async {
    try {
      final isConfigured = await this.isConfigured();
      final canConnect = isConfigured ? await testConnection() : false;
      
      return {
        'configured': isConfigured,
        'connected': canConnect,
        'cacheExpiry': '${_cacheExpiry.inDays} days',
        'baseUrl': _baseUrl,
        'lastCheck': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'configured': false,
        'connected': false,
        'error': e.toString(),
        'lastCheck': DateTime.now().toIso8601String(),
      };
    }
  }
} 
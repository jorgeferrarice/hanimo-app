import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'analytics_service.dart';
import 'in_app_review_service.dart';

/// Enum for anime watch status
enum AnimeWatchStatus {
  planning('planning'),
  watching('watching'),
  completed('completed'),
  dropped('dropped');

  const AnimeWatchStatus(this.value);
  final String value;

  static AnimeWatchStatus fromString(String value) {
    return AnimeWatchStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => AnimeWatchStatus.planning,
    );
  }
}

/// Model class for user anime data
class UserAnime {
  final int malId;
  final String title;
  final String imageUrl;
  final String? titleEnglish;
  final String? titleJapanese;
  final int? totalEpisodes;
  final String? status; // anime status (airing, completed, etc.)
  final double? score;
  final String? synopsis;
  final List<Map<String, dynamic>>? genres;
  final List<Map<String, dynamic>>? studios;
  
  // User-specific fields
  final AnimeWatchStatus watchStatus;
  final int watchedEpisodesCount;
  final List<int> watchedEpisodes;
  final DateTime addedAt;
  final DateTime? updatedAt;
  final double? userRating; // User's personal rating
  final String? userNotes; // User's personal notes

  const UserAnime({
    required this.malId,
    required this.title,
    required this.imageUrl,
    this.titleEnglish,
    this.titleJapanese,
    this.totalEpisodes,
    this.status,
    this.score,
    this.synopsis,
    this.genres,
    this.studios,
    required this.watchStatus,
    required this.watchedEpisodesCount,
    required this.watchedEpisodes,
    required this.addedAt,
    this.updatedAt,
    this.userRating,
    this.userNotes,
  });

  /// Convert UserAnime to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'malId': malId,
      'title': title,
      'imageUrl': imageUrl,
      'titleEnglish': titleEnglish,
      'titleJapanese': titleJapanese,
      'totalEpisodes': totalEpisodes,
      'status': status,
      'score': score,
      'synopsis': synopsis,
      'genres': genres,
      'studios': studios,
      'watchStatus': watchStatus.value,
      'watchedEpisodesCount': watchedEpisodesCount,
      'watchedEpisodes': watchedEpisodes,
      'addedAt': Timestamp.fromDate(addedAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'userRating': userRating,
      'userNotes': userNotes,
    };
  }

  /// Create UserAnime from Firestore document
  factory UserAnime.fromMap(Map<String, dynamic> map) {
    return UserAnime(
      malId: map['malId'] ?? 0,
      title: map['title'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      titleEnglish: map['titleEnglish'],
      titleJapanese: map['titleJapanese'],
      totalEpisodes: map['totalEpisodes'],
      status: map['status'],
      score: map['score']?.toDouble(),
      synopsis: map['synopsis'],
      genres: map['genres'] != null ? List<Map<String, dynamic>>.from(map['genres']) : null,
      studios: map['studios'] != null ? List<Map<String, dynamic>>.from(map['studios']) : null,
      watchStatus: AnimeWatchStatus.fromString(map['watchStatus'] ?? 'planning'),
      watchedEpisodesCount: map['watchedEpisodesCount'] ?? 0,
      watchedEpisodes: List<int>.from(map['watchedEpisodes'] ?? []),
      addedAt: (map['addedAt'] as Timestamp).toDate(),
      updatedAt: map['updatedAt'] != null ? (map['updatedAt'] as Timestamp).toDate() : null,
      userRating: map['userRating']?.toDouble(),
      userNotes: map['userNotes'],
    );
  }

  /// Create a copy of UserAnime with updated fields
  UserAnime copyWith({
    int? malId,
    String? title,
    String? imageUrl,
    String? titleEnglish,
    String? titleJapanese,
    int? totalEpisodes,
    String? status,
    double? score,
    String? synopsis,
    List<Map<String, dynamic>>? genres,
    List<Map<String, dynamic>>? studios,
    AnimeWatchStatus? watchStatus,
    int? watchedEpisodesCount,
    List<int>? watchedEpisodes,
    DateTime? addedAt,
    DateTime? updatedAt,
    double? userRating,
    String? userNotes,
  }) {
    return UserAnime(
      malId: malId ?? this.malId,
      title: title ?? this.title,
      imageUrl: imageUrl ?? this.imageUrl,
      titleEnglish: titleEnglish ?? this.titleEnglish,
      titleJapanese: titleJapanese ?? this.titleJapanese,
      totalEpisodes: totalEpisodes ?? this.totalEpisodes,
      status: status ?? this.status,
      score: score ?? this.score,
      synopsis: synopsis ?? this.synopsis,
      genres: genres ?? this.genres,
      studios: studios ?? this.studios,
      watchStatus: watchStatus ?? this.watchStatus,
      watchedEpisodesCount: watchedEpisodesCount ?? this.watchedEpisodesCount,
      watchedEpisodes: watchedEpisodes ?? this.watchedEpisodes,
      addedAt: addedAt ?? this.addedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      userRating: userRating ?? this.userRating,
      userNotes: userNotes ?? this.userNotes,
    );
  }
}

/// Service for managing user anime collections
class UserAnimeService {
  static final UserAnimeService _instance = UserAnimeService._internal();
  factory UserAnimeService() => _instance;
  UserAnimeService._internal();

  static UserAnimeService get instance => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get current user ID
  String? get _currentUserId => _auth.currentUser?.uid;

  /// Get user's followed anime collection reference
  CollectionReference<Map<String, dynamic>>? get _userAnimeCollection {
    final userId = _currentUserId;
    if (userId == null) return null;
    return _firestore.collection('users').doc(userId).collection('following');
  }

  /// Check if user is authenticated
  bool get isAuthenticated => _currentUserId != null;

  // =================
  // CORE METHODS
  // =================

  /// Get user's followed anime IDs from Firestore
  Future<List<int>> getFollowedAnimeIds() async {
    debugPrint('📋 [UserAnimeService] Getting followed anime IDs...');
    
    if (!isAuthenticated) {
      debugPrint('❌ [UserAnimeService] User not authenticated');
      return [];
    }

    try {
      final userId = _currentUserId!;
      debugPrint('🌐 [UserAnimeService] Fetching followed anime IDs for user: $userId');
      
      final userDoc = await _firestore.collection('users').doc(userId).get();
      
      if (!userDoc.exists) {
        debugPrint('📝 [UserAnimeService] User document does not exist, returning empty list');
        return [];
      }
      
      final data = userDoc.data();
      final followedAnimes = data?['followedAnimes'] as List<dynamic>?;
      
      if (followedAnimes == null || followedAnimes.isEmpty) {
        debugPrint('📝 [UserAnimeService] No followed anime IDs found');
        return [];
      }
      
      // Convert to List<int> and filter out any non-integer values
      final animeIds = followedAnimes
          .where((id) => id is int)
          .cast<int>()
          .toList();
      
      debugPrint('✅ [UserAnimeService] Found ${animeIds.length} followed anime IDs: $animeIds');
      return animeIds;
    } catch (e, stackTrace) {
      debugPrint('❌ [UserAnimeService] Failed to get followed anime IDs: $e');
      debugPrint('   Stack trace: $stackTrace');
      return [];
    }
  }

  /// Get all followed anime for the current user from users/{userId}/following collection
  Future<List<UserAnime>> getFollowedAnime() async {
    debugPrint('📚 [UserAnimeService] Getting followed anime from following subcollection...');
    
    if (!isAuthenticated) {
      debugPrint('❌ [UserAnimeService] User not authenticated');
      throw Exception('User not authenticated');
    }

    try {
      debugPrint('🌐 [UserAnimeService] Fetching from users/{userId}/following...');
      final startTime = DateTime.now();
      
      final snapshot = await _userAnimeCollection!
          .orderBy('addedAt', descending: true)
          .get();
      
      final duration = DateTime.now().difference(startTime);
      debugPrint('✅ [UserAnimeService] Firestore query completed in ${duration.inMilliseconds}ms');
      
      final List<UserAnime> animeList = snapshot.docs
          .map((doc) => UserAnime.fromMap(doc.data()))
          .toList();
      
      debugPrint('✅ [UserAnimeService] Retrieved ${animeList.length} followed anime from following subcollection');
      return animeList;
    } catch (e, stackTrace) {
      debugPrint('❌ [UserAnimeService] Failed to get followed anime: $e');
      debugPrint('   Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Get all followed anime for display on home screen (optimized for UI)
  Future<List<UserAnime>> getAllFollowedAnimes() async {
    debugPrint('🏠 [UserAnimeService] Getting all followed animes for home screen...');
    
    if (!isAuthenticated) {
      debugPrint('❌ [UserAnimeService] User not authenticated');
      return [];
    }

    try {
      debugPrint('🌐 [UserAnimeService] Fetching from users/{userId}/following for home screen...');
      final startTime = DateTime.now();
      
      // Get all followed anime, ordered by most recently added
      final snapshot = await _userAnimeCollection!
          .orderBy('addedAt', descending: true)
          .limit(50) // Limit to 50 for home screen performance
          .get();
      
      final duration = DateTime.now().difference(startTime);
      debugPrint('✅ [UserAnimeService] Home screen query completed in ${duration.inMilliseconds}ms');
      
      final List<UserAnime> animeList = snapshot.docs
          .map((doc) => UserAnime.fromMap(doc.data()))
          .toList();
      
      debugPrint('✅ [UserAnimeService] Retrieved ${animeList.length} followed anime for home screen');
      return animeList;
    } catch (e, stackTrace) {
      debugPrint('❌ [UserAnimeService] Failed to get followed anime for home screen: $e');
      debugPrint('   Stack trace: $stackTrace');
      return []; // Return empty list instead of throwing for home screen
    }
  }

  /// Follow an anime (add to user's collection)
  Future<void> followAnime(Map<String, dynamic> animeData, {
    AnimeWatchStatus watchStatus = AnimeWatchStatus.planning,
    double? userRating,
    String? userNotes,
    int watchedEpisodesCount = 0,
  }) async {
    debugPrint('➕ [UserAnimeService] Following anime: ${animeData['title']}');
    
    if (!isAuthenticated) {
      debugPrint('❌ [UserAnimeService] User not authenticated');
      throw Exception('User not authenticated');
    }

    final malId = animeData['malId'] as int;
    final userId = _currentUserId!;
    
    try {
      // Check if anime is already followed
      final existing = await _userAnimeCollection!.doc(malId.toString()).get();
      if (existing.exists) {
        debugPrint('⚠️  [UserAnimeService] Anime already followed');
        throw Exception('Anime is already in your collection');
      }

      // Create UserAnime object
      final userAnime = UserAnime(
        malId: malId,
        title: animeData['title'] ?? '',
        imageUrl: animeData['imageUrl'] ?? '',
        titleEnglish: animeData['titleEnglish'],
        titleJapanese: animeData['titleJapanese'],
        totalEpisodes: animeData['episodes'],
        status: animeData['status'],
        score: animeData['score']?.toDouble(),
        synopsis: animeData['synopsis'],
        genres: animeData['genres'] != null 
            ? List<Map<String, dynamic>>.from(animeData['genres']) 
            : null,
        studios: animeData['studios'] != null 
            ? List<Map<String, dynamic>>.from(animeData['studios']) 
            : null,
        watchStatus: watchStatus,
        watchedEpisodesCount: watchedEpisodesCount,
        watchedEpisodes: [],
        addedAt: DateTime.now(),
        userRating: userRating,
        userNotes: userNotes,
      );

      // Use a batch write to ensure all operations succeed or fail together
      final batch = _firestore.batch();
      
      // Add to user's following collection
      final userAnimeRef = _userAnimeCollection!.doc(malId.toString());
      batch.set(userAnimeRef, userAnime.toMap());
      
      // Add user to anime's followers array
      final animeRef = _firestore.collection('animes').doc(malId.toString());
      batch.update(animeRef, {
        'followers': FieldValue.arrayUnion([userId])
      });
      
      // If anime document doesn't exist, create it with the followers array
      // We'll use set with merge to handle both cases
      batch.set(animeRef, {
        'followers': FieldValue.arrayUnion([userId])
      }, SetOptions(merge: true));
      
      // Add anime ID to user's followedAnimes array
      final userDocRef = _firestore.collection('users').doc(userId);
      batch.set(userDocRef, {
        'followedAnimes': FieldValue.arrayUnion([malId])
      }, SetOptions(merge: true));
      
      await batch.commit();
      
      // Log analytics event for following anime
      await _logFollowAnimeAnalytics(animeData);
      
      // Check if we should trigger in-app review
      await _checkAndTriggerReview();
      
      debugPrint('✅ [UserAnimeService] Successfully followed anime: ${animeData['title']}');
      debugPrint('✅ [UserAnimeService] Added user $userId to anime $malId followers');
    } catch (e, stackTrace) {
      debugPrint('❌ [UserAnimeService] Failed to follow anime: $e');
      debugPrint('   Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Unfollow an anime (remove from user's collection)
  Future<void> unfollowAnime(int malId) async {
    debugPrint('➖ [UserAnimeService] Unfollowing anime with MAL ID: $malId');
    
    if (!isAuthenticated) {
      debugPrint('❌ [UserAnimeService] User not authenticated');
      throw Exception('User not authenticated');
    }

    final userId = _currentUserId!;

    try {
      // Check if anime exists in collection
      final doc = await _userAnimeCollection!.doc(malId.toString()).get();
      if (!doc.exists) {
        debugPrint('⚠️  [UserAnimeService] Anime not found in collection');
        throw Exception('Anime not found in your collection');
      }

      // Use a batch write to ensure all operations succeed or fail together
      final batch = _firestore.batch();
      
      // Remove from user's following collection
      final userAnimeRef = _userAnimeCollection!.doc(malId.toString());
      batch.delete(userAnimeRef);
      
      // Remove user from anime's followers array
      final animeRef = _firestore.collection('animes').doc(malId.toString());
      batch.update(animeRef, {
        'followers': FieldValue.arrayRemove([userId])
      });
      
      // Remove anime ID from user's followedAnimes array
      final userDocRef = _firestore.collection('users').doc(userId);
      batch.update(userDocRef, {
        'followedAnimes': FieldValue.arrayRemove([malId])
      });
      
      await batch.commit();
      
      // Log analytics event for unfollowing anime
      await _logUnfollowAnimeAnalytics(malId, doc.data()!);
      
      debugPrint('✅ [UserAnimeService] Successfully unfollowed anime with MAL ID: $malId');
      debugPrint('✅ [UserAnimeService] Removed user $userId from anime $malId followers');
    } catch (e, stackTrace) {
      debugPrint('❌ [UserAnimeService] Failed to unfollow anime: $e');
      debugPrint('   Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<void> _logFollowAnimeAnalytics(Map<String, dynamic> animeData) async {
    try {
      await AnalyticsService.instance.logFollowAnime(
        animeId: (animeData['malId'] ?? 0).toString(),
        animeTitle: animeData['title'] ?? 'Unknown',
        genre: animeData['genres']?.isNotEmpty == true 
            ? animeData['genres'][0]['name'] 
            : null,
        status: animeData['status'],
        year: animeData['year'],
        score: animeData['score']?.toDouble(),
        totalEpisodes: animeData['episodes'],
        studio: animeData['studios']?.isNotEmpty == true 
            ? animeData['studios'][0]['name'] 
            : null,
      );
    } catch (e) {
      debugPrint('❌ [UserAnimeService] Failed to log follow anime analytics: $e');
    }
  }

  Future<void> _logUnfollowAnimeAnalytics(int malId, Map<String, dynamic> animeData) async {
    try {
      await AnalyticsService.instance.logUnfollowAnime(
        animeId: malId.toString(),
        animeTitle: animeData['title'] ?? 'Unknown',
      );
    } catch (e) {
      debugPrint('❌ [UserAnimeService] Failed to log unfollow anime analytics: $e');
    }
  }

  // =================
  // FAVORITES METHODS
  // =================

  /// Get user's favorite anime collection reference
  CollectionReference<Map<String, dynamic>>? get _userFavoritesCollection {
    final userId = _currentUserId;
    if (userId == null) return null;
    return _firestore.collection('users').doc(userId).collection('favorites');
  }

  /// Get user's favorite anime IDs from Firestore
  Future<List<int>> getFavoriteAnimeIds() async {
    debugPrint('⭐ [UserAnimeService] Getting favorite anime IDs...');
    
    if (!isAuthenticated) {
      debugPrint('❌ [UserAnimeService] User not authenticated');
      return [];
    }

    try {
      final userId = _currentUserId!;
      debugPrint('🌐 [UserAnimeService] Fetching favorite anime IDs for user: $userId');
      
      final userDoc = await _firestore.collection('users').doc(userId).get();
      
      if (!userDoc.exists) {
        debugPrint('📝 [UserAnimeService] User document does not exist, returning empty list');
        return [];
      }
      
      final data = userDoc.data();
      final favoriteAnimes = data?['favoriteAnimes'] as List<dynamic>?;
      
      if (favoriteAnimes == null || favoriteAnimes.isEmpty) {
        debugPrint('📝 [UserAnimeService] No favorite anime IDs found');
        return [];
      }
      
      // Convert to List<int> and filter out any non-integer values
      final animeIds = favoriteAnimes
          .where((id) => id is int)
          .cast<int>()
          .toList();
      
      debugPrint('✅ [UserAnimeService] Found ${animeIds.length} favorite anime IDs: $animeIds');
      return animeIds;
    } catch (e, stackTrace) {
      debugPrint('❌ [UserAnimeService] Failed to get favorite anime IDs: $e');
      debugPrint('   Stack trace: $stackTrace');
      return [];
    }
  }

  /// Get all favorite anime for display (optimized for UI)
  Future<List<UserAnime>> getAllFavoriteAnimes() async {
    debugPrint('⭐ [UserAnimeService] Getting all favorite animes...');
    
    if (!isAuthenticated) {
      debugPrint('❌ [UserAnimeService] User not authenticated');
      return [];
    }

    try {
      debugPrint('🌐 [UserAnimeService] Fetching from users/{userId}/favorites...');
      final startTime = DateTime.now();
      
      // Get all favorite anime, ordered by most recently added
      final snapshot = await _userFavoritesCollection!
          .orderBy('addedAt', descending: true)
          .limit(50) // Limit to 50 for performance
          .get();
      
      final duration = DateTime.now().difference(startTime);
      debugPrint('✅ [UserAnimeService] Favorites query completed in ${duration.inMilliseconds}ms');
      
      final List<UserAnime> animeList = snapshot.docs
          .map((doc) => UserAnime.fromMap(doc.data()))
          .toList();
      
      debugPrint('✅ [UserAnimeService] Retrieved ${animeList.length} favorite anime');
      return animeList;
    } catch (e, stackTrace) {
      debugPrint('❌ [UserAnimeService] Failed to get favorite anime: $e');
      debugPrint('   Stack trace: $stackTrace');
      return []; // Return empty list instead of throwing
    }
  }

  /// Add an anime to favorites
  Future<void> addFavorite(Map<String, dynamic> animeData) async {
    debugPrint('⭐ [UserAnimeService] Adding anime to favorites: ${animeData['title']}');
    
    if (!isAuthenticated) {
      debugPrint('❌ [UserAnimeService] User not authenticated');
      throw Exception('User not authenticated');
    }

    final malId = animeData['malId'] as int;
    final userId = _currentUserId!;
    
    try {
      // Check if anime is already in favorites
      final existing = await _userFavoritesCollection!.doc(malId.toString()).get();
      if (existing.exists) {
        debugPrint('⚠️  [UserAnimeService] Anime already in favorites');
        throw Exception('Anime is already in your favorites');
      }

      // Create UserAnime object for favorites (simplified, no watch tracking)
      final favoriteAnime = UserAnime(
        malId: malId,
        title: animeData['title'] ?? '',
        imageUrl: animeData['imageUrl'] ?? '',
        titleEnglish: animeData['titleEnglish'],
        titleJapanese: animeData['titleJapanese'],
        totalEpisodes: animeData['episodes'],
        status: animeData['status'],
        score: animeData['score']?.toDouble(),
        synopsis: animeData['synopsis'],
        genres: animeData['genres'] != null 
            ? List<Map<String, dynamic>>.from(animeData['genres']) 
            : null,
        studios: animeData['studios'] != null 
            ? List<Map<String, dynamic>>.from(animeData['studios']) 
            : null,
        watchStatus: AnimeWatchStatus.planning, // Default for favorites
        watchedEpisodesCount: 0,
        watchedEpisodes: [],
        addedAt: DateTime.now(),
      );

      // Use a batch write to ensure all operations succeed or fail together
      final batch = _firestore.batch();
      
      // Add to user's favorites collection
      final userFavoriteRef = _userFavoritesCollection!.doc(malId.toString());
      batch.set(userFavoriteRef, favoriteAnime.toMap());
      
      // Add anime ID to user's favoriteAnimes array
      final userDocRef = _firestore.collection('users').doc(userId);
      batch.set(userDocRef, {
        'favoriteAnimes': FieldValue.arrayUnion([malId])
      }, SetOptions(merge: true));
      
      await batch.commit();
      
      debugPrint('✅ [UserAnimeService] Successfully added anime to favorites: ${animeData['title']}');
    } catch (e, stackTrace) {
      debugPrint('❌ [UserAnimeService] Failed to add anime to favorites: $e');
      debugPrint('   Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Remove an anime from favorites
  Future<void> removeFavorite(int malId) async {
    debugPrint('💔 [UserAnimeService] Removing anime from favorites with MAL ID: $malId');
    
    if (!isAuthenticated) {
      debugPrint('❌ [UserAnimeService] User not authenticated');
      throw Exception('User not authenticated');
    }

    final userId = _currentUserId!;

    try {
      // Check if anime exists in favorites
      final doc = await _userFavoritesCollection!.doc(malId.toString()).get();
      if (!doc.exists) {
        debugPrint('⚠️  [UserAnimeService] Anime not found in favorites');
        throw Exception('Anime not found in your favorites');
      }

      // Use a batch write to ensure all operations succeed or fail together
      final batch = _firestore.batch();
      
      // Remove from user's favorites collection
      final userFavoriteRef = _userFavoritesCollection!.doc(malId.toString());
      batch.delete(userFavoriteRef);
      
      // Remove anime ID from user's favoriteAnimes array
      final userDocRef = _firestore.collection('users').doc(userId);
      batch.update(userDocRef, {
        'favoriteAnimes': FieldValue.arrayRemove([malId])
      });
      
      await batch.commit();
      
      debugPrint('✅ [UserAnimeService] Successfully removed anime from favorites with MAL ID: $malId');
    } catch (e, stackTrace) {
      debugPrint('❌ [UserAnimeService] Failed to remove anime from favorites: $e');
      debugPrint('   Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Check if an anime is in favorites
  Future<bool> isAnimeFavorited(int malId) async {
    if (!isAuthenticated) return false;
    
    try {
      final doc = await _userFavoritesCollection!.doc(malId.toString()).get();
      return doc.exists;
    } catch (e) {
      debugPrint('❌ [UserAnimeService] Failed to check if anime is favorited: $e');
      return false;
    }
  }

  /// Update anime in user's collection
  Future<void> updateAnime(int malId, {
    AnimeWatchStatus? watchStatus,
    int? watchedEpisodesCount,
    List<int>? watchedEpisodes,
    double? userRating,
    String? userNotes,
  }) async {
    debugPrint('🔄 [UserAnimeService] Updating anime with MAL ID: $malId');
    
    if (!isAuthenticated) {
      debugPrint('❌ [UserAnimeService] User not authenticated');
      throw Exception('User not authenticated');
    }

    try {
      // Get current anime data
      final doc = await _userAnimeCollection!.doc(malId.toString()).get();
      if (!doc.exists) {
        debugPrint('⚠️  [UserAnimeService] Anime not found in collection');
        throw Exception('Anime not found in your collection');
      }

      final currentAnime = UserAnime.fromMap(doc.data()!);
      
      // Create updated anime
      final updatedAnime = currentAnime.copyWith(
        watchStatus: watchStatus,
        watchedEpisodesCount: watchedEpisodesCount,
        watchedEpisodes: watchedEpisodes,
        userRating: userRating,
        userNotes: userNotes,
        updatedAt: DateTime.now(),
      );

      // Update in Firestore
      await _userAnimeCollection!.doc(malId.toString()).update(updatedAnime.toMap());
      
      debugPrint('✅ [UserAnimeService] Successfully updated anime with MAL ID: $malId');
    } catch (e, stackTrace) {
      debugPrint('❌ [UserAnimeService] Failed to update anime: $e');
      debugPrint('   Stack trace: $stackTrace');
      rethrow;
    }
  }

  // =================
  // EPISODE TRACKING METHODS
  // =================

  /// Mark an episode as watched
  Future<void> markEpisodeWatched(int malId, int episodeNumber) async {
    debugPrint('▶️  [UserAnimeService] Marking episode $episodeNumber as watched for MAL ID: $malId');
    
    try {
      final doc = await _userAnimeCollection!.doc(malId.toString()).get();
      if (!doc.exists) {
        throw Exception('Anime not found in your collection');
      }

      final currentAnime = UserAnime.fromMap(doc.data()!);
      
      // Add episode to watched list if not already there
      final watchedEpisodes = List<int>.from(currentAnime.watchedEpisodes);
      if (!watchedEpisodes.contains(episodeNumber)) {
        watchedEpisodes.add(episodeNumber);
        watchedEpisodes.sort(); // Keep episodes sorted
      }

      // Update watched episodes count and status
      AnimeWatchStatus newStatus = currentAnime.watchStatus;
      if (currentAnime.totalEpisodes != null && 
          watchedEpisodes.length >= currentAnime.totalEpisodes!) {
        newStatus = AnimeWatchStatus.completed;
      } else if (currentAnime.watchStatus == AnimeWatchStatus.planning) {
        newStatus = AnimeWatchStatus.watching;
      }

      await updateAnime(
        malId,
        watchedEpisodes: watchedEpisodes,
        watchedEpisodesCount: watchedEpisodes.length,
        watchStatus: newStatus,
      );
      
      debugPrint('✅ [UserAnimeService] Episode $episodeNumber marked as watched');
    } catch (e, stackTrace) {
      debugPrint('❌ [UserAnimeService] Failed to mark episode as watched: $e');
      debugPrint('   Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Mark an episode as unwatched
  Future<void> markEpisodeUnwatched(int malId, int episodeNumber) async {
    debugPrint('⏸️  [UserAnimeService] Marking episode $episodeNumber as unwatched for MAL ID: $malId');
    
    try {
      final doc = await _userAnimeCollection!.doc(malId.toString()).get();
      if (!doc.exists) {
        throw Exception('Anime not found in your collection');
      }

      final currentAnime = UserAnime.fromMap(doc.data()!);
      
      // Remove episode from watched list
      final watchedEpisodes = List<int>.from(currentAnime.watchedEpisodes);
      watchedEpisodes.remove(episodeNumber);

      // Update status if needed
      AnimeWatchStatus newStatus = currentAnime.watchStatus;
      if (currentAnime.watchStatus == AnimeWatchStatus.completed && 
          watchedEpisodes.length < (currentAnime.totalEpisodes ?? 0)) {
        newStatus = watchedEpisodes.isEmpty ? AnimeWatchStatus.planning : AnimeWatchStatus.watching;
      }

      await updateAnime(
        malId,
        watchedEpisodes: watchedEpisodes,
        watchedEpisodesCount: watchedEpisodes.length,
        watchStatus: newStatus,
      );
      
      debugPrint('✅ [UserAnimeService] Episode $episodeNumber marked as unwatched');
    } catch (e, stackTrace) {
      debugPrint('❌ [UserAnimeService] Failed to mark episode as unwatched: $e');
      debugPrint('   Stack trace: $stackTrace');
      rethrow;
    }
  }

  // =================
  // QUERY METHODS
  // =================

  /// Check if an anime is followed by the user
  Future<bool> isAnimeFollowed(int malId) async {
    if (!isAuthenticated) return false;
    
    try {
      final doc = await _userAnimeCollection!.doc(malId.toString()).get();
      return doc.exists;
    } catch (e) {
      debugPrint('❌ [UserAnimeService] Failed to check if anime is followed: $e');
      return false;
    }
  }

  /// Get a specific anime from user's collection
  Future<UserAnime?> getUserAnime(int malId) async {
    if (!isAuthenticated) return null;
    
    try {
      final doc = await _userAnimeCollection!.doc(malId.toString()).get();
      if (!doc.exists) return null;
      
      return UserAnime.fromMap(doc.data()!);
    } catch (e) {
      debugPrint('❌ [UserAnimeService] Failed to get user anime: $e');
      return null;
    }
  }

  /// Get anime by watch status
  Future<List<UserAnime>> getAnimeByStatus(AnimeWatchStatus status) async {
    if (!isAuthenticated) return [];
    
    try {
      final snapshot = await _userAnimeCollection!
          .where('watchStatus', isEqualTo: status.value)
          .orderBy('addedAt', descending: true)
          .get();
      
      return snapshot.docs
          .map((doc) => UserAnime.fromMap(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('❌ [UserAnimeService] Failed to get anime by status: $e');
      return [];
    }
  }

  /// Get user's anime statistics
  Future<Map<String, int>> getUserStats() async {
    if (!isAuthenticated) return {};
    
    try {
      final animeList = await getFollowedAnime();
      
      final stats = <String, int>{};
      stats['total'] = animeList.length;
      stats['planning'] = animeList.where((a) => a.watchStatus == AnimeWatchStatus.planning).length;
      stats['watching'] = animeList.where((a) => a.watchStatus == AnimeWatchStatus.watching).length;
      stats['completed'] = animeList.where((a) => a.watchStatus == AnimeWatchStatus.completed).length;
      stats['dropped'] = animeList.where((a) => a.watchStatus == AnimeWatchStatus.dropped).length;
      stats['totalEpisodesWatched'] = animeList.fold<int>(0, (sum, anime) => sum + anime.watchedEpisodesCount);
      
      return stats;
    } catch (e) {
      debugPrint('❌ [UserAnimeService] Failed to get user stats: $e');
      return {};
    }
  }

  // =================
  // UTILITY METHODS
  // =================

  /// Clear all user data (for testing/debugging)
  Future<void> clearUserData() async {
    if (!isAuthenticated) return;
    
    try {
      final snapshot = await _userAnimeCollection!.get();
      final batch = _firestore.batch();
      
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      
      debugPrint('🗑️  [UserAnimeService] All user data cleared');
    } catch (e) {
      debugPrint('❌ [UserAnimeService] Failed to clear user data: $e');
      rethrow;
    }
  }

  /// Get service health status
  Future<Map<String, dynamic>> getServiceHealth() async {
    try {
      final isAuth = isAuthenticated;
      final userId = _currentUserId;
      
      Map<String, dynamic> firestoreHealth = {};
      if (isAuth) {
        try {
          final testQuery = await _userAnimeCollection!.limit(1).get();
          firestoreHealth = {
            'status': 'healthy',
            'documentsAccessible': true,
            'queryTime': DateTime.now().toIso8601String(),
          };
        } catch (e) {
          firestoreHealth = {
            'status': 'error',
            'error': e.toString(),
          };
        }
      }
      
      return {
        'isAuthenticated': isAuth,
        'userId': userId,
        'firestore': firestoreHealth,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'status': 'error',
        'error': e.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  Future<void> _checkAndTriggerReview() async {
    try {
      // Get current followed anime count
      final followedAnimeIds = await getFollowedAnimeIds();
      final animeCount = followedAnimeIds.length;
      
      // Check if we should trigger review
      final shouldTrigger = await InAppReviewService.instance.shouldTriggerReview(animeCount);
      
      if (shouldTrigger) {
        debugPrint('⭐ [UserAnimeService] Triggering in-app review after following $animeCount anime(s)');
        await InAppReviewService.instance.requestReview();
      }
    } catch (e) {
      debugPrint('❌ [UserAnimeService] Error checking review trigger: $e');
      // Don't throw - review failure shouldn't break the follow operation
    }
  }
}

/// Exception class for UserAnimeService errors
class UserAnimeServiceException implements Exception {
  final String message;
  final String? code;
  final Object? originalError;
  
  const UserAnimeServiceException(
    this.message, {
    this.code,
    this.originalError,
  });
  
  @override
  String toString() => 'UserAnimeServiceException: $message';
} 
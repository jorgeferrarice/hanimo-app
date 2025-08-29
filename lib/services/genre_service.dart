import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:jikan_api/jikan_api.dart';
import 'dart:math';

import '../models/genre_model.dart';
import 'jikan_service.dart';

/// Service for managing genres with Firestore caching and image paths
class GenreService {
  static const String _collectionName = 'genres';
  
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final JikanService _jikanService = JikanService();
  
  /// Get genres with Firestore caching
  Future<List<EnhancedGenre>> getAnimeGenres() async {
    try {
      debugPrint('🎭 [GenreService] Getting anime genres with Firestore caching...');
      
      // Try to get from Firestore first
      final firestoreGenres = await _getGenresFromFirestore();
      if (firestoreGenres.isNotEmpty) {
        debugPrint('✅ [GenreService] Found ${firestoreGenres.length} genres in Firestore cache');
        return firestoreGenres;
      }
      
      debugPrint('📡 [GenreService] No cache found, fetching from API...');
      
      // Fallback to API
      final apiGenres = await _jikanService.getAnimeGenres();
      
      // Convert to EnhancedGenre and process images
      final enhancedGenres = <EnhancedGenre>[];
      
      for (final genre in apiGenres) {
        debugPrint('🖼️ [GenreService] Processing genre: ${genre.name}');
        
        // Try to get a random anime image for this genre
        String? imagePath;
        try {
          imagePath = await _getRandomAnimeImageForGenre(genre.malId);
        } catch (e) {
          debugPrint('⚠️ [GenreService] Failed to get image for ${genre.name}: $e');
        }
        
        final enhancedGenre = EnhancedGenre.fromJikanGenre(genre, imagePath: imagePath);
        enhancedGenres.add(enhancedGenre);
      }
      
      // Save to Firestore for future use
      await _saveGenresToFirestore(enhancedGenres);
      
      debugPrint('✅ [GenreService] Processed and cached ${enhancedGenres.length} genres');
      return enhancedGenres;
      
    } catch (e, stackTrace) {
      debugPrint('❌ [GenreService] Error getting genres: $e');
      debugPrint('   Stack trace: $stackTrace');
      rethrow;
    }
  }
  
  /// Get genres from Firestore cache
  Future<List<EnhancedGenre>> _getGenresFromFirestore() async {
    try {
      final snapshot = await _firestore.collection(_collectionName).get();
      
      if (snapshot.docs.isEmpty) {
        return [];
      }
      
      final genres = snapshot.docs
          .map((doc) => EnhancedGenre.fromMap(doc.data()))
          .toList();
      
      // Sort by malId for consistency
      genres.sort((a, b) => a.malId.compareTo(b.malId));
      
      return genres;
    } catch (e) {
      debugPrint('❌ [GenreService] Error getting genres from Firestore: $e');
      return [];
    }
  }
  
  /// Save genres to Firestore
  Future<void> _saveGenresToFirestore(List<EnhancedGenre> genres) async {
    try {
      final batch = _firestore.batch();
      
      for (final genre in genres) {
        final docRef = _firestore.collection(_collectionName).doc(genre.malId.toString());
        batch.set(docRef, genre.toMap());
      }
      
      await batch.commit();
      debugPrint('✅ [GenreService] Saved ${genres.length} genres to Firestore');
    } catch (e) {
      debugPrint('❌ [GenreService] Error saving genres to Firestore: $e');
    }
  }
  
  /// Get a random anime image for a genre
  Future<String?> _getRandomAnimeImageForGenre(int genreId) async {
    try {
      // Get first page of anime for this genre
      final animeList = await _jikanService.getAnimeByGenre(genreId, page: 1);
      
      if (animeList.isEmpty) {
        return null;
      }
      
      // Get a random anime from the list
      final random = Random();
      final randomAnime = animeList[random.nextInt(animeList.length)];
      
      // Return the image URL
      final imageUrl = randomAnime['imageUrl'] as String?;
      if (imageUrl != null && imageUrl.isNotEmpty) {
        debugPrint('🖼️ [GenreService] Found image for genre $genreId: ${randomAnime['title']}');
        return imageUrl;
      }
      
      return null;
    } catch (e) {
      debugPrint('❌ [GenreService] Error getting random anime image for genre $genreId: $e');
      return null;
    }
  }
  
  /// Update a genre's image path
  Future<void> updateGenreImage(int malId, String imagePath) async {
    try {
      await _firestore.collection(_collectionName).doc(malId.toString()).update({
        'imagePath': imagePath,
      });
      debugPrint('✅ [GenreService] Updated image for genre $malId');
    } catch (e) {
      debugPrint('❌ [GenreService] Error updating genre image: $e');
    }
  }
  
  /// Clear Firestore cache (for testing/debugging)
  Future<void> clearCache() async {
    try {
      final snapshot = await _firestore.collection(_collectionName).get();
      final batch = _firestore.batch();
      
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      debugPrint('✅ [GenreService] Cleared genres cache');
    } catch (e) {
      debugPrint('❌ [GenreService] Error clearing cache: $e');
    }
  }
} 
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import '../redux/app_state.dart';
import '../redux/actions.dart';
import 'user_anime_service.dart';

/// Service for accessing followed anime state from Redux
class FollowedAnimeService {
  /// Check if an anime is followed by ID
  static bool isAnimeFollowed(BuildContext context, int malId) {
    final store = StoreProvider.of<AppState>(context);
    return store.state.isAnimeFollowed(malId);
  }
  
  /// Get all followed anime IDs
  static List<int> getFollowedAnimeIds(BuildContext context) {
    final store = StoreProvider.of<AppState>(context);
    return store.state.followedAnimeIds;
  }
  
  /// Check if followed anime IDs are currently loading
  static bool isLoadingFollowedAnimes(BuildContext context) {
    final store = StoreProvider.of<AppState>(context);
    return store.state.isLoadingFollowedAnimes;
  }
  
  /// Get followed anime loading error if any
  static String? getFollowedAnimesError(BuildContext context) {
    final store = StoreProvider.of<AppState>(context);
    return store.state.followedAnimesError;
  }
  
  /// Follow an anime (dispatches Redux action)
  static Future<void> followAnime(
    BuildContext context,
    Map<String, dynamic> animeData, {
    required AnimeWatchStatus watchStatus,
    double? userRating,
    String? userNotes,
  }) async {
    final store = StoreProvider.of<AppState>(context);
    await store.dispatch(followAnimeAction(
      animeData,
      watchStatus: watchStatus,
      userRating: userRating,
      userNotes: userNotes,
    ));
  }
  
  /// Unfollow an anime (dispatches Redux action)
  static Future<void> unfollowAnime(BuildContext context, int malId) async {
    final store = StoreProvider.of<AppState>(context);
    await store.dispatch(unfollowAnimeAction(malId));
  }
  
  /// Refresh followed anime IDs from server
  static void refreshFollowedAnimes(BuildContext context) {
    final store = StoreProvider.of<AppState>(context);
    store.dispatch(loadFollowedAnimesAction());
  }
} 
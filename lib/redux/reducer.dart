import 'package:flutter/foundation.dart';
import 'app_state.dart';
import 'actions.dart';

/// Main app reducer that handles all state changes
AppState appReducer(AppState state, dynamic action) {
  switch (action.runtimeType) {
    case LoadFollowedAnimesStartAction:
      return _loadFollowedAnimesStart(state, action);
    case LoadFollowedAnimesSuccessAction:
      return _loadFollowedAnimesSuccess(state, action);
    case LoadFollowedAnimesFailureAction:
      return _loadFollowedAnimesFailure(state, action);
    case AddFollowedAnimeAction:
      return _addFollowedAnime(state, action);
    case RemoveFollowedAnimeAction:
      return _removeFollowedAnime(state, action);
    case ClearFollowedAnimesAction:
      return _clearFollowedAnimes(state, action);
    case LoadMyAnimesStartAction:
      return _loadMyAnimesStart(state, action);
    case LoadMyAnimesSuccessAction:
      return _loadMyAnimesSuccess(state, action);
    case LoadMyAnimesFailureAction:
      return _loadMyAnimesFailure(state, action);
    case ClearMyAnimesAction:
      return _clearMyAnimes(state, action);
    case LoadFavoriteAnimesStartAction:
      return _loadFavoriteAnimesStart(state, action);
    case LoadFavoriteAnimesSuccessAction:
      return _loadFavoriteAnimesSuccess(state, action);
    case LoadFavoriteAnimesFailureAction:
      return _loadFavoriteAnimesFailure(state, action);
    case AddFavoriteAnimeAction:
      return _addFavoriteAnime(state, action);
    case RemoveFavoriteAnimeAction:
      return _removeFavoriteAnime(state, action);
    case ClearFavoriteAnimesAction:
      return _clearFavoriteAnimes(state, action);
    case LoadMyFavoritesStartAction:
      return _loadMyFavoritesStart(state, action);
    case LoadMyFavoritesSuccessAction:
      return _loadMyFavoritesSuccess(state, action);
    case LoadMyFavoritesFailureAction:
      return _loadMyFavoritesFailure(state, action);
    case ClearMyFavoritesAction:
      return _clearMyFavorites(state, action);
    case SetCurrentUserIdAction:
      return _setCurrentUserId(state, action);
    case StartUserMigrationAction:
      return _startUserMigration(state, action);
    case UserMigrationSuccessAction:
      return _userMigrationSuccess(state, action);
    case UserMigrationFailureAction:
      return _userMigrationFailure(state, action);
    case MigrationRequiresChoiceAction:
      return _migrationRequiresChoice(state, action);
    case UserChooseKeepCloudDataAction:
      return _userChooseKeepCloudData(state, action);
    case UserChooseMigrateLocalDataAction:
      return _userChooseMigrateLocalData(state, action);
    default:
      return state;
  }
}

/// Handle start of loading followed anime IDs
AppState _loadFollowedAnimesStart(AppState state, LoadFollowedAnimesStartAction action) {
  debugPrint('🔄 [Reducer] Starting to load followed anime IDs');
  return state.copyWith(
    isLoadingFollowedAnimes: true,
    followedAnimesError: null,
  );
}

/// Handle successful load of followed anime IDs
AppState _loadFollowedAnimesSuccess(AppState state, LoadFollowedAnimesSuccessAction action) {
  debugPrint('✅ [Reducer] Successfully loaded ${action.followedAnimeIds.length} followed anime IDs');
  return state.copyWith(
    followedAnimeIds: action.followedAnimeIds,
    isLoadingFollowedAnimes: false,
    followedAnimesError: null,
  );
}

/// Handle failed load of followed anime IDs
AppState _loadFollowedAnimesFailure(AppState state, LoadFollowedAnimesFailureAction action) {
  debugPrint('❌ [Reducer] Failed to load followed anime IDs: ${action.error}');
  return state.copyWith(
    isLoadingFollowedAnimes: false,
    followedAnimesError: action.error,
  );
}

/// Handle adding an anime to the followed list
AppState _addFollowedAnime(AppState state, AddFollowedAnimeAction action) {
  debugPrint('➕ [Reducer] Adding anime ${action.malId} to followed list');
  
  // Check if anime is already in the list
  if (state.followedAnimeIds.contains(action.malId)) {
    debugPrint('⚠️  [Reducer] Anime ${action.malId} already in followed list');
    return state;
  }
  
  // Add anime to the list
  final updatedList = List<int>.from(state.followedAnimeIds)..add(action.malId);
  debugPrint('✅ [Reducer] Added anime ${action.malId} to followed list (total: ${updatedList.length})');
  
  return state.copyWith(
    followedAnimeIds: updatedList,
  );
}

/// Handle removing an anime from the followed list
AppState _removeFollowedAnime(AppState state, RemoveFollowedAnimeAction action) {
  debugPrint('➖ [Reducer] Removing anime ${action.malId} from followed list');
  
  // Check if anime is in the list
  if (!state.followedAnimeIds.contains(action.malId)) {
    debugPrint('⚠️  [Reducer] Anime ${action.malId} not in followed list');
    return state;
  }
  
  // Remove anime from the list
  final updatedList = List<int>.from(state.followedAnimeIds)..remove(action.malId);
  debugPrint('✅ [Reducer] Removed anime ${action.malId} from followed list (total: ${updatedList.length})');
  
  return state.copyWith(
    followedAnimeIds: updatedList,
  );
}

/// Handle clearing all followed anime IDs
AppState _clearFollowedAnimes(AppState state, ClearFollowedAnimesAction action) {
  debugPrint('🧹 [Reducer] Clearing all followed anime IDs');
  return state.copyWith(
    followedAnimeIds: [],
    isLoadingFollowedAnimes: false,
    followedAnimesError: null,
  );
}

/// Handle start of loading my animes
AppState _loadMyAnimesStart(AppState state, LoadMyAnimesStartAction action) {
  debugPrint('🔄 [Reducer] Starting to load my animes');
  return state.copyWith(
    isLoadingMyAnimes: true,
    myAnimesError: null,
  );
}

/// Handle successful load of my animes
AppState _loadMyAnimesSuccess(AppState state, LoadMyAnimesSuccessAction action) {
  debugPrint('✅ [Reducer] Successfully loaded ${action.myAnimes.length} my animes');
  return state.copyWith(
    myAnimes: action.myAnimes,
    isLoadingMyAnimes: false,
    myAnimesError: null,
  );
}

/// Handle failed load of my animes
AppState _loadMyAnimesFailure(AppState state, LoadMyAnimesFailureAction action) {
  debugPrint('❌ [Reducer] Failed to load my animes: ${action.error}');
  return state.copyWith(
    isLoadingMyAnimes: false,
    myAnimesError: action.error,
  );
}

/// Handle clearing all my animes
AppState _clearMyAnimes(AppState state, ClearMyAnimesAction action) {
  debugPrint('🧹 [Reducer] Clearing all my animes');
  return state.copyWith(
    myAnimes: [],
    isLoadingMyAnimes: false,
    myAnimesError: null,
  );
}

// =================
// FAVORITES REDUCERS
// =================

/// Handle start of loading favorite anime IDs
AppState _loadFavoriteAnimesStart(AppState state, LoadFavoriteAnimesStartAction action) {
  debugPrint('🔄 [Reducer] Starting to load favorite anime IDs');
  return state.copyWith(
    isLoadingFavoriteAnimes: true,
    favoriteAnimesError: null,
  );
}

/// Handle successful load of favorite anime IDs
AppState _loadFavoriteAnimesSuccess(AppState state, LoadFavoriteAnimesSuccessAction action) {
  debugPrint('✅ [Reducer] Successfully loaded ${action.favoriteAnimeIds.length} favorite anime IDs');
  return state.copyWith(
    favoriteAnimeIds: action.favoriteAnimeIds,
    isLoadingFavoriteAnimes: false,
    favoriteAnimesError: null,
  );
}

/// Handle failed load of favorite anime IDs
AppState _loadFavoriteAnimesFailure(AppState state, LoadFavoriteAnimesFailureAction action) {
  debugPrint('❌ [Reducer] Failed to load favorite anime IDs: ${action.error}');
  return state.copyWith(
    isLoadingFavoriteAnimes: false,
    favoriteAnimesError: action.error,
  );
}

/// Handle adding an anime to the favorites list
AppState _addFavoriteAnime(AppState state, AddFavoriteAnimeAction action) {
  debugPrint('⭐ [Reducer] Adding anime ${action.malId} to favorites list');
  
  // Check if anime is already in the list
  if (state.favoriteAnimeIds.contains(action.malId)) {
    debugPrint('⚠️  [Reducer] Anime ${action.malId} already in favorites list');
    return state;
  }
  
  // Add anime to the list
  final updatedList = List<int>.from(state.favoriteAnimeIds)..add(action.malId);
  debugPrint('✅ [Reducer] Added anime ${action.malId} to favorites list (total: ${updatedList.length})');
  
  return state.copyWith(
    favoriteAnimeIds: updatedList,
  );
}

/// Handle removing an anime from the favorites list
AppState _removeFavoriteAnime(AppState state, RemoveFavoriteAnimeAction action) {
  debugPrint('💔 [Reducer] Removing anime ${action.malId} from favorites list');
  
  // Check if anime is in the list
  if (!state.favoriteAnimeIds.contains(action.malId)) {
    debugPrint('⚠️  [Reducer] Anime ${action.malId} not in favorites list');
    return state;
  }
  
  // Remove anime from the list
  final updatedList = List<int>.from(state.favoriteAnimeIds)..remove(action.malId);
  debugPrint('✅ [Reducer] Removed anime ${action.malId} from favorites list (total: ${updatedList.length})');
  
  return state.copyWith(
    favoriteAnimeIds: updatedList,
  );
}

/// Handle clearing all favorite anime IDs
AppState _clearFavoriteAnimes(AppState state, ClearFavoriteAnimesAction action) {
  debugPrint('🧹 [Reducer] Clearing all favorite anime IDs');
  return state.copyWith(
    favoriteAnimeIds: [],
    isLoadingFavoriteAnimes: false,
    favoriteAnimesError: null,
  );
}

/// Handle start of loading my favorites
AppState _loadMyFavoritesStart(AppState state, LoadMyFavoritesStartAction action) {
  debugPrint('🔄 [Reducer] Starting to load my favorites');
  return state.copyWith(
    isLoadingMyFavorites: true,
    myFavoritesError: null,
  );
}

/// Handle successful load of my favorites
AppState _loadMyFavoritesSuccess(AppState state, LoadMyFavoritesSuccessAction action) {
  debugPrint('✅ [Reducer] Successfully loaded ${action.myFavorites.length} my favorites');
  return state.copyWith(
    myFavorites: action.myFavorites,
    isLoadingMyFavorites: false,
    myFavoritesError: null,
  );
}

/// Handle failed load of my favorites
AppState _loadMyFavoritesFailure(AppState state, LoadMyFavoritesFailureAction action) {
  debugPrint('❌ [Reducer] Failed to load my favorites: ${action.error}');
  return state.copyWith(
    isLoadingMyFavorites: false,
    myFavoritesError: action.error,
  );
}

/// Handle clearing all my favorites
AppState _clearMyFavorites(AppState state, ClearMyFavoritesAction action) {
  debugPrint('🧹 [Reducer] Clearing all my favorites');
  return state.copyWith(
    myFavorites: [],
    isLoadingMyFavorites: false,
    myFavoritesError: null,
  );
}

// =================
// USER REDUCERS
// =================

/// Handle setting the current user ID
AppState _setCurrentUserId(AppState state, SetCurrentUserIdAction action) {
  debugPrint('👤 [Reducer] Setting current user ID: ${action.userId}');
  return state.copyWith(
    currentUserId: action.userId,
  );
}

/// Handle start of user data migration
AppState _startUserMigration(AppState state, StartUserMigrationAction action) {
  debugPrint('🔄 [Reducer] Starting user data migration');
  return state.copyWith(
    isMigratingUserData: true,
    migrationError: null,
  );
}

/// Handle successful user data migration
AppState _userMigrationSuccess(AppState state, UserMigrationSuccessAction action) {
  debugPrint('✅ [Reducer] User data migration successful: ${action.fromUserId} -> ${action.toUserId}');
  return state.copyWith(
    isMigratingUserData: false,
    migrationError: null,
  );
}

/// Handle failed user data migration
AppState _userMigrationFailure(AppState state, UserMigrationFailureAction action) {
  debugPrint('❌ [Reducer] User data migration failed: ${action.error}');
  return state.copyWith(
    isMigratingUserData: false,
    migrationError: action.error,
  );
}

/// Handle migration requires choice
AppState _migrationRequiresChoice(AppState state, MigrationRequiresChoiceAction action) {
  debugPrint('🤔 [Reducer] Migration requires choice');
  return state.copyWith(
    isMigratingUserData: true,
    migrationError: null,
    migrationRequiresChoice: true,
    localDataSummary: action.localData,
    cloudDataSummary: action.cloudData,
    pendingMigrationFromUserId: action.fromUserId,
    pendingMigrationToUserId: action.toUserId,
  );
}

/// Handle user choosing to keep cloud data
AppState _userChooseKeepCloudData(AppState state, UserChooseKeepCloudDataAction action) {
  debugPrint('☁️ [Reducer] User chose to keep cloud data');
  return state.copyWith(
    isMigratingUserData: false,
    migrationError: null,
    migrationRequiresChoice: false,
    localDataSummary: null,
    cloudDataSummary: null,
    pendingMigrationFromUserId: null,
    pendingMigrationToUserId: null,
  );
}

/// Handle user choosing to migrate local data
AppState _userChooseMigrateLocalData(AppState state, UserChooseMigrateLocalDataAction action) {
  debugPrint('📱 [Reducer] User chose to migrate local data');
  return state.copyWith(
    isMigratingUserData: true,
    migrationError: null,
    migrationRequiresChoice: false,
    localDataSummary: null,
    cloudDataSummary: null,
    pendingMigrationFromUserId: null,
    pendingMigrationToUserId: null,
  );
} 
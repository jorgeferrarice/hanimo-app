import 'package:redux/redux.dart';
import 'package:flutter/foundation.dart';
import 'package:redux_thunk/redux_thunk.dart';
import '../services/user_anime_service.dart';
import '../services/user_migration_service.dart';
import '../services/onesignal_service.dart';
import '../services/auth_service.dart';
import '../widgets/migration_choice_dialog.dart';
import 'app_state.dart';

// =================
// SYNC ACTIONS
// =================

/// Action to start loading followed anime IDs
class LoadFollowedAnimesStartAction {}

/// Action to set followed anime IDs after successful load
class LoadFollowedAnimesSuccessAction {
  final List<int> followedAnimeIds;

  LoadFollowedAnimesSuccessAction(this.followedAnimeIds);
}

/// Action to handle failed load of followed anime IDs
class LoadFollowedAnimesFailureAction {
  final String error;

  LoadFollowedAnimesFailureAction(this.error);
}

/// Action to add an anime ID to the followed list
class AddFollowedAnimeAction {
  final int malId;

  AddFollowedAnimeAction(this.malId);
}

/// Action to remove an anime ID from the followed list
class RemoveFollowedAnimeAction {
  final int malId;

  RemoveFollowedAnimeAction(this.malId);
}

/// Action to clear all followed anime IDs (e.g., on logout)
class ClearFollowedAnimesAction {}

// =================
// MY ANIMES ACTIONS
// =================

/// Action to start loading my animes
class LoadMyAnimesStartAction {}

/// Action to set my animes after successful load
class LoadMyAnimesSuccessAction {
  final List<UserAnime> myAnimes;

  LoadMyAnimesSuccessAction(this.myAnimes);
}

/// Action to handle failed load of my animes
class LoadMyAnimesFailureAction {
  final String error;

  LoadMyAnimesFailureAction(this.error);
}

/// Action to clear all my animes (e.g., on logout)
class ClearMyAnimesAction {}

// =================
// FAVORITES ACTIONS
// =================

/// Action to start loading favorite anime IDs
class LoadFavoriteAnimesStartAction {}

/// Action to set favorite anime IDs after successful load
class LoadFavoriteAnimesSuccessAction {
  final List<int> favoriteAnimeIds;

  LoadFavoriteAnimesSuccessAction(this.favoriteAnimeIds);
}

/// Action to handle failed load of favorite anime IDs
class LoadFavoriteAnimesFailureAction {
  final String error;

  LoadFavoriteAnimesFailureAction(this.error);
}

/// Action to add an anime ID to the favorites list
class AddFavoriteAnimeAction {
  final int malId;

  AddFavoriteAnimeAction(this.malId);
}

/// Action to remove an anime ID from the favorites list
class RemoveFavoriteAnimeAction {
  final int malId;

  RemoveFavoriteAnimeAction(this.malId);
}

/// Action to clear all favorite anime IDs (e.g., on logout)
class ClearFavoriteAnimesAction {}

/// Action to start loading my favorites
class LoadMyFavoritesStartAction {}

/// Action to set my favorites after successful load
class LoadMyFavoritesSuccessAction {
  final List<UserAnime> myFavorites;

  LoadMyFavoritesSuccessAction(this.myFavorites);
}

/// Action to handle failed load of my favorites
class LoadMyFavoritesFailureAction {
  final String error;

  LoadMyFavoritesFailureAction(this.error);
}

/// Action to clear all my favorites (e.g., on logout)
class ClearMyFavoritesAction {}

// =================
// USER ACTIONS
// =================

/// Action to set the current user ID
class SetCurrentUserIdAction {
  final String? userId;

  SetCurrentUserIdAction(this.userId);
}

/// Action to start user data migration
class StartUserMigrationAction {}

/// Action for successful user data migration
class UserMigrationSuccessAction {
  final String fromUserId;
  final String toUserId;

  UserMigrationSuccessAction(this.fromUserId, this.toUserId);
}

/// Action for failed user data migration
class UserMigrationFailureAction {
  final String error;

  UserMigrationFailureAction(this.error);
}

/// Action when migration requires user choice (both accounts have data)
class MigrationRequiresChoiceAction {
  final String fromUserId;
  final String toUserId;
  final UserDataSummary localData;
  final UserDataSummary cloudData;

  MigrationRequiresChoiceAction({
    required this.fromUserId,
    required this.toUserId,
    required this.localData,
    required this.cloudData,
  });
}

/// Action when user chooses to keep cloud data
class UserChooseKeepCloudDataAction {
  final String fromUserId;
  final String toUserId;

  UserChooseKeepCloudDataAction({
    required this.fromUserId,
    required this.toUserId,
  });
}

/// Action when user chooses to migrate local data
class UserChooseMigrateLocalDataAction {
  final String fromUserId;
  final String toUserId;

  UserChooseMigrateLocalDataAction({
    required this.fromUserId,
    required this.toUserId,
  });
}

// =================
// ASYNC ACTIONS (THUNKS)
// =================

/// Thunk action to handle user authentication and migration
ThunkAction<AppState> handleUserAuthenticationAction(String newUserId) {
  return (Store<AppState> store) async {
    debugPrint('🔐 [Redux] Handling user authentication for: $newUserId');
    
    try {
      final String? oldUserId = store.state.currentUserId;
      
      debugPrint('🔍 [Redux] Authentication context:');
      debugPrint('   • Old User ID: $oldUserId');
      debugPrint('   • New User ID: $newUserId');
      debugPrint('   • Migration needed: ${oldUserId != null && oldUserId != newUserId}');
      
      // Check if we need to migrate data
      if (oldUserId != null && oldUserId != newUserId) {
        debugPrint('🔄 [Redux] Starting data migration from $oldUserId to $newUserId');
        
        // Start migration
        store.dispatch(StartUserMigrationAction());
        
        try {
          final migrationService = UserMigrationService();
          
          // Check if both users have data
          final oldUserHasData = await migrationService.hasUserData(oldUserId);
          final newUserHasData = await migrationService.hasUserData(newUserId);
          
          debugPrint('🔍 [Redux] Data check results:');
          debugPrint('   • Old user has data: $oldUserHasData');
          debugPrint('   • New user has data: $newUserHasData');
          
          if (oldUserHasData && newUserHasData) {
            // Both users have data - need user choice
            debugPrint('🤔 [Redux] Both users have data, requesting user choice...');
            
            final localDataSummary = await migrationService.getUserDataSummary(oldUserId);
            final cloudDataSummary = await migrationService.getUserDataSummary(newUserId);
            
            store.dispatch(MigrationRequiresChoiceAction(
              fromUserId: oldUserId,
              toUserId: newUserId,
              localData: localDataSummary,
              cloudData: cloudDataSummary,
            ));
            
            // Don't continue with automatic migration - wait for user choice
            debugPrint('⏸️ [Redux] Waiting for user migration choice...');
            return;
          } else if (oldUserHasData) {
            // Only old user has data - proceed with normal migration
            debugPrint('📦 [Redux] Only old user has data, proceeding with migration...');
            await migrationService.migrateUserData(oldUserId, newUserId);
            store.dispatch(UserMigrationSuccessAction(oldUserId, newUserId));
            
            // Add a small delay to ensure Firestore batch operations are fully processed
            debugPrint('⏳ [Redux] Waiting for Firestore operations to complete...');
            await Future.delayed(const Duration(milliseconds: 500));
            
            // Verify migration success
            final migrationSuccessful = await migrationService.verifyMigrationSuccess(oldUserId, newUserId);
            if (!migrationSuccessful) {
              debugPrint('⚠️ [Redux] Migration verification failed - data might not be properly migrated');
            }
          } else {
            // Old user has no data worth migrating
            debugPrint('ℹ️ [Redux] Old user has no data to migrate');
          }
        } catch (migrationError) {
          debugPrint('❌ [Redux] User data migration failed: $migrationError');
          store.dispatch(UserMigrationFailureAction(migrationError.toString()));
          // Continue with authentication even if migration fails
        }
      } else if (oldUserId == null) {
        debugPrint('ℹ️ [Redux] First-time user authentication (no previous user ID)');
      } else {
        debugPrint('ℹ️ [Redux] Same user re-authenticating (no migration needed)');
      }
      
      // Update the current user ID
      debugPrint('👤 [Redux] Setting current user ID to: $newUserId');
      store.dispatch(SetCurrentUserIdAction(newUserId));
      
      // Get the current Firebase user for OneSignal registration
      final authService = AuthService();
      final currentUser = authService.currentUser;
      
      if (currentUser != null) {
        // Register/resubscribe user with OneSignal and save OneSignal ID
        try {
          debugPrint('🔔 [Redux] Registering user with OneSignal: ${currentUser.uid}');
          await OneSignalService.instance.registerUser(currentUser);
          debugPrint('✅ [Redux] OneSignal registration completed for: ${currentUser.uid}');
        } catch (oneSignalError) {
          debugPrint('❌ [Redux] OneSignal registration failed: $oneSignalError');
          // Don't throw here - continue with other authentication steps
        }
      }
      
      // Load user data for the new user
      debugPrint('📊 [Redux] Loading user data for: $newUserId');
      store.dispatch(loadFollowedAnimesAction());
      store.dispatch(loadMyAnimesAction());
      store.dispatch(loadFavoriteAnimesAction());
      store.dispatch(loadMyFavoritesAction());
      
      debugPrint('✅ [Redux] User authentication handling completed for: $newUserId');
    } catch (e) {
      debugPrint('❌ [Redux] Error handling user authentication: $e');
      rethrow;
    }
  };
}

/// Thunk action to handle user sign out
ThunkAction<AppState> handleUserSignOutAction() {
  return (Store<AppState> store) async {
    debugPrint('🚪 [Redux] Handling user sign out...');
    
    try {
      // Unregister from OneSignal before clearing user data
      try {
        debugPrint('🔔 [Redux] Unregistering user from OneSignal');
        await OneSignalService.instance.unregisterUser();
        debugPrint('✅ [Redux] OneSignal unregistration completed');
      } catch (oneSignalError) {
        debugPrint('❌ [Redux] OneSignal unregistration failed: $oneSignalError');
        // Don't throw here - continue with sign out process
      }
      
      // Clear user ID
      store.dispatch(SetCurrentUserIdAction(null));
      
      // Clear all user data
      store.dispatch(ClearFollowedAnimesAction());
      store.dispatch(ClearMyAnimesAction());
      store.dispatch(ClearFavoriteAnimesAction());
      store.dispatch(ClearMyFavoritesAction());
      
      debugPrint('✅ [Redux] User sign out handling completed');
    } catch (e) {
      debugPrint('❌ [Redux] Error handling user sign out: $e');
      rethrow;
    }
  };
}

/// Thunk action to load followed anime IDs from UserAnimeService
ThunkAction<AppState> loadFollowedAnimesAction() {
  return (Store<AppState> store) async {
    debugPrint('🔄 [Redux] Loading followed anime IDs...');
    
    // Dispatch start action
    store.dispatch(LoadFollowedAnimesStartAction());
    
    try {
      final userAnimeService = UserAnimeService();
      final followedAnimeIds = await userAnimeService.getFollowedAnimeIds();
      
      debugPrint('✅ [Redux] Successfully loaded ${followedAnimeIds.length} followed anime IDs');
      store.dispatch(LoadFollowedAnimesSuccessAction(followedAnimeIds));
    } catch (e) {
      debugPrint('❌ [Redux] Failed to load followed anime IDs: $e');
      store.dispatch(LoadFollowedAnimesFailureAction(e.toString()));
    }
  };
}

/// Thunk action to follow an anime and update both Firestore and local state
ThunkAction<AppState> followAnimeAction(Map<String, dynamic> animeData, {
  required AnimeWatchStatus watchStatus,
  double? userRating,
  String? userNotes,
  int watchedEpisodesCount = 0,
  bool isUpdate = false,
}) {
  return (Store<AppState> store) async {
    final malId = animeData['malId'] as int;
    debugPrint('🔄 [Redux] ${isUpdate ? 'Updating' : 'Following'} anime: $malId');
    
    try {
      final userAnimeService = UserAnimeService();
      
      if (isUpdate) {
        // Update existing anime
        await userAnimeService.updateAnime(
          malId,
          watchStatus: watchStatus,
          userRating: userRating,
          userNotes: userNotes,
          watchedEpisodesCount: watchedEpisodesCount,
        );
      } else {
        // Add new anime
        await userAnimeService.followAnime(
          animeData,
          watchStatus: watchStatus,
          userRating: userRating,
          userNotes: userNotes,
          watchedEpisodesCount: watchedEpisodesCount,
        );
        
        // Update local state only for new follows
        store.dispatch(AddFollowedAnimeAction(malId));
      }
      
      // Refresh my animes in the background
      store.dispatch(loadMyAnimesAction());
      
      debugPrint('✅ [Redux] Successfully ${isUpdate ? 'updated' : 'followed'} anime: $malId');
    } catch (e) {
      debugPrint('❌ [Redux] Failed to ${isUpdate ? 'update' : 'follow'} anime: $e');
      rethrow; // Re-throw so UI can handle the error
    }
  };
}

/// Thunk action to unfollow an anime and update both Firestore and local state
ThunkAction<AppState> unfollowAnimeAction(int malId) {
  return (Store<AppState> store) async {
    debugPrint('🔄 [Redux] Unfollowing anime: $malId');
    
    try {
      final userAnimeService = UserAnimeService();
      
      // Update Firestore
      await userAnimeService.unfollowAnime(malId);
      
      // Update local state
      store.dispatch(RemoveFollowedAnimeAction(malId));
      
      // Refresh my animes in the background
      store.dispatch(loadMyAnimesAction());
      
      debugPrint('✅ [Redux] Successfully unfollowed anime: $malId');
    } catch (e) {
      debugPrint('❌ [Redux] Failed to unfollow anime: $e');
      rethrow; // Re-throw so UI can handle the error
    }
  };
}

/// Thunk action to load my animes from UserAnimeService
ThunkAction<AppState> loadMyAnimesAction() {
  return (Store<AppState> store) async {
    debugPrint('🔄 [Redux] Loading my animes...');
    
    // Dispatch start action
    store.dispatch(LoadMyAnimesStartAction());
    
    try {
      final userAnimeService = UserAnimeService();
      final myAnimes = await userAnimeService.getAllFollowedAnimes();
      
      debugPrint('✅ [Redux] Successfully loaded ${myAnimes.length} my animes');
      store.dispatch(LoadMyAnimesSuccessAction(myAnimes));
    } catch (e) {
      debugPrint('❌ [Redux] Failed to load my animes: $e');
      store.dispatch(LoadMyAnimesFailureAction(e.toString()));
    }
  };
}

/// Thunk action to load favorite anime IDs from UserAnimeService
ThunkAction<AppState> loadFavoriteAnimesAction() {
  return (Store<AppState> store) async {
    debugPrint('🔄 [Redux] Loading favorite anime IDs...');
    
    // Dispatch start action
    store.dispatch(LoadFavoriteAnimesStartAction());
    
    try {
      final userAnimeService = UserAnimeService();
      final favoriteAnimeIds = await userAnimeService.getFavoriteAnimeIds();
      
      debugPrint('✅ [Redux] Successfully loaded ${favoriteAnimeIds.length} favorite anime IDs');
      store.dispatch(LoadFavoriteAnimesSuccessAction(favoriteAnimeIds));
    } catch (e) {
      debugPrint('❌ [Redux] Failed to load favorite anime IDs: $e');
      store.dispatch(LoadFavoriteAnimesFailureAction(e.toString()));
    }
  };
}

/// Thunk action to load my favorites from UserAnimeService
ThunkAction<AppState> loadMyFavoritesAction() {
  return (Store<AppState> store) async {
    debugPrint('🔄 [Redux] Loading my favorites...');
    
    // Dispatch start action
    store.dispatch(LoadMyFavoritesStartAction());
    
    try {
      final userAnimeService = UserAnimeService();
      final myFavorites = await userAnimeService.getAllFavoriteAnimes();
      
      debugPrint('✅ [Redux] Successfully loaded ${myFavorites.length} my favorites');
      store.dispatch(LoadMyFavoritesSuccessAction(myFavorites));
    } catch (e) {
      debugPrint('❌ [Redux] Failed to load my favorites: $e');
      store.dispatch(LoadMyFavoritesFailureAction(e.toString()));
    }
  };
}

/// Thunk action to add an anime to favorites and update both Firestore and local state
ThunkAction<AppState> addFavoriteAction(Map<String, dynamic> animeData) {
  return (Store<AppState> store) async {
    final malId = animeData['malId'] as int;
    debugPrint('🔄 [Redux] Adding anime to favorites: $malId');
    
    try {
      final userAnimeService = UserAnimeService();
      
      // Update Firestore
      await userAnimeService.addFavorite(animeData);
      
      // Update local state
      store.dispatch(AddFavoriteAnimeAction(malId));
      
      // Refresh favorites in the background
      store.dispatch(loadMyFavoritesAction());
      
      debugPrint('✅ [Redux] Successfully added anime to favorites: $malId');
    } catch (e) {
      debugPrint('❌ [Redux] Failed to add anime to favorites: $e');
      rethrow; // Re-throw so UI can handle the error
    }
  };
}

/// Thunk action to remove an anime from favorites and update both Firestore and local state
ThunkAction<AppState> removeFavoriteAction(int malId) {
  return (Store<AppState> store) async {
    debugPrint('🔄 [Redux] Removing anime from favorites: $malId');
    
    try {
      final userAnimeService = UserAnimeService();
      
      // Update Firestore
      await userAnimeService.removeFavorite(malId);
      
      // Update local state
      store.dispatch(RemoveFavoriteAnimeAction(malId));
      
      // Refresh favorites in the background
      store.dispatch(loadMyFavoritesAction());
      
      debugPrint('✅ [Redux] Successfully removed anime from favorites: $malId');
    } catch (e) {
      debugPrint('❌ [Redux] Failed to remove anime from favorites: $e');
      rethrow; // Re-throw so UI can handle the error
    }
  };
}

/// Thunk action to handle when user chooses to keep cloud data
ThunkAction<AppState> handleKeepCloudDataAction(String fromUserId, String toUserId) {
  return (Store<AppState> store) async {
    debugPrint('☁️ [Redux] User chose to keep cloud data, cleaning up local data...');
    
    try {
      store.dispatch(UserChooseKeepCloudDataAction(
        fromUserId: fromUserId,
        toUserId: toUserId,
      ));
      
      // Clean up old anonymous user data since user wants to keep cloud data
      final migrationService = UserMigrationService();
      await migrationService.cleanupUserData(fromUserId);
      
      // Add a small delay to ensure Firestore operations are fully processed
      debugPrint('⏳ [Redux] Waiting for cleanup operations to complete...');
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Update current user ID
      store.dispatch(SetCurrentUserIdAction(toUserId));
      
      // Register with OneSignal
      final authService = AuthService();
      final currentUser = authService.currentUser;
      if (currentUser != null) {
        try {
          await OneSignalService.instance.registerUser(currentUser);
        } catch (e) {
          debugPrint('❌ [Redux] OneSignal registration failed: $e');
        }
      }
      
      // Load cloud data
      store.dispatch(loadFollowedAnimesAction());
      store.dispatch(loadMyAnimesAction());
      store.dispatch(loadFavoriteAnimesAction());
      store.dispatch(loadMyFavoritesAction());
      
      debugPrint('✅ [Redux] Successfully kept cloud data and cleaned up local data');
    } catch (e) {
      debugPrint('❌ [Redux] Error handling keep cloud data choice: $e');
      store.dispatch(UserMigrationFailureAction('Failed to keep cloud data: $e'));
    }
  };
}

/// Thunk action to handle when user chooses to migrate local data
ThunkAction<AppState> handleMigrateLocalDataAction(String fromUserId, String toUserId) {
  return (Store<AppState> store) async {
    debugPrint('📱 [Redux] User chose to migrate local data, overwriting cloud data...');
    
    try {
      store.dispatch(UserChooseMigrateLocalDataAction(
        fromUserId: fromUserId,
        toUserId: toUserId,
      ));
      
      // Force migrate data, overwriting existing cloud data
      final migrationService = UserMigrationService();
      await migrationService.migrateUserData(fromUserId, toUserId, overwriteExisting: true);
      
      // Migration successful
      store.dispatch(UserMigrationSuccessAction(fromUserId, toUserId));
      
      // Add a small delay to ensure Firestore operations are fully processed
      debugPrint('⏳ [Redux] Waiting for migration operations to complete...');
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Update current user ID
      store.dispatch(SetCurrentUserIdAction(toUserId));
      
      // Register with OneSignal
      final authService = AuthService();
      final currentUser = authService.currentUser;
      if (currentUser != null) {
        try {
          await OneSignalService.instance.resubscribeUser(currentUser);
        } catch (e) {
          debugPrint('❌ [Redux] OneSignal registration failed: $e');
        }
      }
      
      // Load migrated data
      store.dispatch(loadFollowedAnimesAction());
      store.dispatch(loadMyAnimesAction());
      store.dispatch(loadFavoriteAnimesAction());
      store.dispatch(loadMyFavoritesAction());
      
      debugPrint('✅ [Redux] Successfully migrated local data to cloud');
    } catch (e) {
      debugPrint('❌ [Redux] Error handling migrate local data choice: $e');
      store.dispatch(UserMigrationFailureAction('Failed to migrate local data: $e'));
    }
  };
} 
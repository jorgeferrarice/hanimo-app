import '../services/user_anime_service.dart';
import '../widgets/migration_choice_dialog.dart';

/// Main application state
class AppState {
  final List<int> followedAnimeIds;
  final bool isLoadingFollowedAnimes;
  final String? followedAnimesError;
  final List<UserAnime> myAnimes;
  final bool isLoadingMyAnimes;
  final String? myAnimesError;
  final List<int> favoriteAnimeIds;
  final bool isLoadingFavoriteAnimes;
  final String? favoriteAnimesError;
  final List<UserAnime> myFavorites;
  final bool isLoadingMyFavorites;
  final String? myFavoritesError;
  final String? currentUserId;
  final bool isMigratingUserData;
  final String? migrationError;
  final bool migrationRequiresChoice;
  final UserDataSummary? localDataSummary;
  final UserDataSummary? cloudDataSummary;
  final String? pendingMigrationFromUserId;
  final String? pendingMigrationToUserId;

  const AppState({
    this.followedAnimeIds = const [],
    this.isLoadingFollowedAnimes = false,
    this.followedAnimesError,
    this.myAnimes = const [],
    this.isLoadingMyAnimes = false,
    this.myAnimesError,
    this.favoriteAnimeIds = const [],
    this.isLoadingFavoriteAnimes = false,
    this.favoriteAnimesError,
    this.myFavorites = const [],
    this.isLoadingMyFavorites = false,
    this.myFavoritesError,
    this.currentUserId,
    this.isMigratingUserData = false,
    this.migrationError,
    this.migrationRequiresChoice = false,
    this.localDataSummary,
    this.cloudDataSummary,
    this.pendingMigrationFromUserId,
    this.pendingMigrationToUserId,
  });

  /// Create a copy of AppState with updated fields
  AppState copyWith({
    List<int>? followedAnimeIds,
    bool? isLoadingFollowedAnimes,
    String? followedAnimesError,
    List<UserAnime>? myAnimes,
    bool? isLoadingMyAnimes,
    String? myAnimesError,
    List<int>? favoriteAnimeIds,
    bool? isLoadingFavoriteAnimes,
    String? favoriteAnimesError,
    List<UserAnime>? myFavorites,
    bool? isLoadingMyFavorites,
    String? myFavoritesError,
    String? currentUserId,
    bool? isMigratingUserData,
    String? migrationError,
    bool? migrationRequiresChoice,
    UserDataSummary? localDataSummary,
    UserDataSummary? cloudDataSummary,
    String? pendingMigrationFromUserId,
    String? pendingMigrationToUserId,
  }) {
    return AppState(
      followedAnimeIds: followedAnimeIds ?? this.followedAnimeIds,
      isLoadingFollowedAnimes: isLoadingFollowedAnimes ?? this.isLoadingFollowedAnimes,
      followedAnimesError: followedAnimesError ?? this.followedAnimesError,
      myAnimes: myAnimes ?? this.myAnimes,
      isLoadingMyAnimes: isLoadingMyAnimes ?? this.isLoadingMyAnimes,
      myAnimesError: myAnimesError ?? this.myAnimesError,
      favoriteAnimeIds: favoriteAnimeIds ?? this.favoriteAnimeIds,
      isLoadingFavoriteAnimes: isLoadingFavoriteAnimes ?? this.isLoadingFavoriteAnimes,
      favoriteAnimesError: favoriteAnimesError ?? this.favoriteAnimesError,
      myFavorites: myFavorites ?? this.myFavorites,
      isLoadingMyFavorites: isLoadingMyFavorites ?? this.isLoadingMyFavorites,
      myFavoritesError: myFavoritesError ?? this.myFavoritesError,
      currentUserId: currentUserId ?? this.currentUserId,
      isMigratingUserData: isMigratingUserData ?? this.isMigratingUserData,
      migrationError: migrationError ?? this.migrationError,
      migrationRequiresChoice: migrationRequiresChoice ?? this.migrationRequiresChoice,
      localDataSummary: localDataSummary ?? this.localDataSummary,
      cloudDataSummary: cloudDataSummary ?? this.cloudDataSummary,
      pendingMigrationFromUserId: pendingMigrationFromUserId ?? this.pendingMigrationFromUserId,
      pendingMigrationToUserId: pendingMigrationToUserId ?? this.pendingMigrationToUserId,
    );
  }

  /// Check if an anime is followed by ID
  bool isAnimeFollowed(int malId) {
    return followedAnimeIds.contains(malId);
  }

  /// Check if an anime is favorited by ID
  bool isAnimeFavorited(int malId) {
    return favoriteAnimeIds.contains(malId);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppState &&
          runtimeType == other.runtimeType &&
          followedAnimeIds.length == other.followedAnimeIds.length &&
          followedAnimeIds.every((id) => other.followedAnimeIds.contains(id)) &&
          isLoadingFollowedAnimes == other.isLoadingFollowedAnimes &&
          followedAnimesError == other.followedAnimesError &&
          currentUserId == other.currentUserId;

  @override
  int get hashCode =>
      followedAnimeIds.hashCode ^
      isLoadingFollowedAnimes.hashCode ^
      followedAnimesError.hashCode ^
      currentUserId.hashCode;

  @override
  String toString() {
    return 'AppState{followedAnimeIds: $followedAnimeIds, isLoadingFollowedAnimes: $isLoadingFollowedAnimes, followedAnimesError: $followedAnimesError, currentUserId: $currentUserId}';
  }
} 
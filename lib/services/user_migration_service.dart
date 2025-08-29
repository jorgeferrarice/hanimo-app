import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/migration_choice_dialog.dart';
import 'onesignal_service.dart';

/// Service to handle user data migration when transitioning from anonymous to authenticated accounts
class UserMigrationService {
  static final UserMigrationService _instance = UserMigrationService._internal();
  factory UserMigrationService() => _instance;
  UserMigrationService._internal();

  static UserMigrationService get instance => _instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Migrate user data from old user ID to new user ID
  /// This is typically called when an anonymous user signs in with Google/Apple
  Future<void> migrateUserData(String oldUserId, String newUserId, {bool overwriteExisting = false}) async {
    if (oldUserId == newUserId) {
      debugPrint('🔀 [UserMigration] User IDs are the same, no migration needed');
      return;
    }

    debugPrint('🔀 [UserMigration] Starting migration from $oldUserId to $newUserId');
    debugPrint('   • Overwrite existing: $overwriteExisting');
    
    final startTime = DateTime.now();
    
    try {
      // Step 1: Check if old user has data worth migrating
      debugPrint('🔍 [UserMigration] Step 1: Checking if old user has data...');
      final hasData = await hasUserData(oldUserId);
      debugPrint('🔍 [UserMigration] Old user has data: $hasData');
      
      if (!hasData) {
        debugPrint('ℹ️ [UserMigration] No data found for old user $oldUserId, skipping migration');
        return;
      }
      
      // Step 2: Check if new user already has data (avoid overwriting unless forced)
      debugPrint('🔍 [UserMigration] Step 2: Checking if new user already has data...');
      final newUserHasData = await hasUserData(newUserId);
      debugPrint('🔍 [UserMigration] New user has data: $newUserHasData');
      
      if (newUserHasData && !overwriteExisting) {
        debugPrint('⚠️ [UserMigration] New user $newUserId already has data, skipping migration to avoid overwrite');
        debugPrint('   • Use overwriteExisting: true to force migration');
        return;
      }
      
      // Step 3: Perform the migration using a batch write for atomicity
      debugPrint('🔍 [UserMigration] Step 3: Performing migration...');
      final batch = _firestore.batch();
      bool hasDataToMigrate = false;

      // 1. Migrate user profile/settings document
      debugPrint('📄 [UserMigration] Migrating user document...');
      await _migrateDocument(
        batch, 
        'users', 
        oldUserId, 
        newUserId,
        merge: !overwriteExisting, // If overwriting, don't merge
      ).then((migrated) => hasDataToMigrate = hasDataToMigrate || migrated);

      // 2. Migrate followed animes collection
      debugPrint('📁 [UserMigration] Migrating followed animes...');
      await _migrateCollection(
        batch,
        'users/$oldUserId/followed_animes',
        'users/$newUserId/followed_animes',
        clearDestination: overwriteExisting,
      ).then((migrated) => hasDataToMigrate = hasDataToMigrate || migrated);

      // 3. Migrate favorite animes collection
      debugPrint('📁 [UserMigration] Migrating favorite animes...');
      await _migrateCollection(
        batch,
        'users/$oldUserId/favorite_animes',
        'users/$newUserId/favorite_animes',
        clearDestination: overwriteExisting,
      ).then((migrated) => hasDataToMigrate = hasDataToMigrate || migrated);

      // 4. Migrate watchlist collection
      debugPrint('📁 [UserMigration] Migrating watchlist...');
      await _migrateCollection(
        batch,
        'users/$oldUserId/watchlist',
        'users/$newUserId/watchlist',
        clearDestination: overwriteExisting,
      ).then((migrated) => hasDataToMigrate = hasDataToMigrate || migrated);

      // 5. Migrate user preferences collection
      debugPrint('📁 [UserMigration] Migrating preferences...');
      await _migrateCollection(
        batch,
        'users/$oldUserId/preferences',
        'users/$newUserId/preferences',
        clearDestination: overwriteExisting,
      ).then((migrated) => hasDataToMigrate = hasDataToMigrate || migrated);

      debugPrint('🔍 [UserMigration] Migration summary:');
      debugPrint('   • Has data to migrate: $hasDataToMigrate');

      if (hasDataToMigrate) {
        // Add migration metadata
        final migrationDoc = _firestore.collection('users').doc(newUserId);
        batch.set(migrationDoc, {
          'migration': {
            'migratedFrom': oldUserId,
            'migratedAt': FieldValue.serverTimestamp(),
            'operationsCount': 5,
            'version': '1.0',
            'overwriteExisting': overwriteExisting,
          },
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: !overwriteExisting));
        
        // Step 4: Commit the batch
        debugPrint('🔄 [UserMigration] Committing batch...');
        await batch.commit();
        
        // Step 5: Resubscribe user to OneSignal with new user ID
        try {
          final currentUser = _auth.currentUser;
          if (currentUser != null && currentUser.uid == newUserId) {
            debugPrint('🔔 [UserMigration] Resubscribing user to OneSignal after migration...');
            await OneSignalService.instance.resubscribeUser(currentUser);
            debugPrint('✅ [UserMigration] OneSignal resubscription completed');
          }
        } catch (oneSignalError) {
          debugPrint('❌ [UserMigration] OneSignal resubscription failed: $oneSignalError');
          // Don't fail the entire migration for OneSignal issues
        }
        
        // Step 6: Clean up old user data after successful migration
        debugPrint('🧹 [UserMigration] Cleaning up old user data...');
        await _cleanupOldUserData(oldUserId);
        
        final duration = DateTime.now().difference(startTime);
        debugPrint('✅ [UserMigration] Migration completed successfully in ${duration.inMilliseconds}ms');
        debugPrint('   • Operations: 5');
        debugPrint('   • From: $oldUserId');
        debugPrint('   • To: $newUserId');
      } else {
        debugPrint('ℹ️ [UserMigration] No data found to migrate from $oldUserId');
      }
    } catch (e, stackTrace) {
      final duration = DateTime.now().difference(startTime);
      debugPrint('❌ [UserMigration] Migration failed after ${duration.inMilliseconds}ms');
      debugPrint('   • Error: $e');
      debugPrint('   • Stack trace: $stackTrace');
      rethrow;
    }
  }

  /// Migrate a single document from old path to new path
  Future<bool> _migrateDocument(
    WriteBatch batch,
    String collectionPath,
    String oldDocId,
    String newDocId, {
    bool merge = false,
  }) async {
    try {
      final oldDocRef = _firestore.collection(collectionPath).doc(oldDocId);
      final newDocRef = _firestore.collection(collectionPath).doc(newDocId);
      
      final oldDoc = await oldDocRef.get();
      
      if (oldDoc.exists && oldDoc.data() != null) {
        final data = oldDoc.data()!;
        // Add migration metadata
        data['migratedFrom'] = oldDocId;
        data['migratedAt'] = FieldValue.serverTimestamp();
        
        batch.set(newDocRef, data, SetOptions(merge: merge));
        batch.delete(oldDocRef);
        
        debugPrint('📄 [UserMigration] Queued document migration: $collectionPath/$oldDocId -> $collectionPath/$newDocId');
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('❌ [UserMigration] Error migrating document $collectionPath/$oldDocId: $e');
      rethrow;
    }
  }

  /// Migrate an entire collection from old path to new path
  Future<bool> _migrateCollection(
    WriteBatch batch,
    String oldCollectionPath,
    String newCollectionPath, {
    bool clearDestination = false,
  }) async {
    try {
      final oldCollection = await _firestore.collection(oldCollectionPath).get();
      
      if (oldCollection.docs.isEmpty) {
        debugPrint('📁 [UserMigration] No documents found in: $oldCollectionPath');
        return false;
      }

      // Clear destination collection BEFORE migration if requested
      if (clearDestination) {
        debugPrint('🧹 [UserMigration] Clearing destination collection: $newCollectionPath');
        final newCollection = await _firestore.collection(newCollectionPath).get();
        for (final doc in newCollection.docs) {
          batch.delete(doc.reference);
        }
        debugPrint('🗑️ [UserMigration] Queued deletion of ${newCollection.docs.length} existing documents in destination');
      }

      // Migrate documents from old to new collection
      for (final doc in oldCollection.docs) {
        if (doc.exists && doc.data().isNotEmpty) {
          final data = Map<String, dynamic>.from(doc.data());
          
          // Add migration metadata
          data['migratedFrom'] = doc.id;
          data['migratedAt'] = FieldValue.serverTimestamp();
          
          final newDocRef = _firestore.collection(newCollectionPath).doc(doc.id);
          
          // Use merge: true to preserve any existing data in destination documents
          // unless clearDestination is true
          batch.set(newDocRef, data, SetOptions(merge: !clearDestination));
          batch.delete(doc.reference);
        }
      }
      
      debugPrint('📁 [UserMigration] Queued collection migration: $oldCollectionPath -> $newCollectionPath (${oldCollection.docs.length} documents, clearDestination: $clearDestination)');
      return true;
    } catch (e) {
      debugPrint('❌ [UserMigration] Error migrating collection $oldCollectionPath: $e');
      rethrow;
    }
  }

  /// Clean up any remaining old user data after successful migration
  Future<void> _cleanupOldUserData(String oldUserId) async {
    try {
      debugPrint('🧹 [UserMigration] Starting cleanup of old user data: $oldUserId');
      
      // Delete the main user document if it still exists
      final userDocRef = _firestore.collection('users').doc(oldUserId);
      final userDoc = await userDocRef.get();
      
      if (userDoc.exists) {
        await userDocRef.delete();
        debugPrint('🗑️ [UserMigration] Deleted old user document: users/$oldUserId');
      }
      
      // Note: Collections should already be cleaned up by the migration batch operations
      // This is just a safety check for the main user document
      
      debugPrint('✅ [UserMigration] Cleanup completed for old user: $oldUserId');
    } catch (e) {
      debugPrint('⚠️ [UserMigration] Error during cleanup (non-critical): $e');
      // Don't rethrow cleanup errors as the migration was already successful
    }
  }

  /// Debug method to check current migration state
  Future<void> debugMigrationState() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        debugPrint('🔍 [UserMigration] DEBUG: No current user found');
        return;
      }
      
      debugPrint('🔍 [UserMigration] DEBUG: Current migration state:');
      debugPrint('   • Current User ID: ${currentUser.uid}');
      debugPrint('   • User is anonymous: ${currentUser.isAnonymous}');
      debugPrint('   • User email: ${currentUser.email ?? 'N/A'}');
      debugPrint('   • User display name: ${currentUser.displayName ?? 'N/A'}');
      
      // Check if user has data
      final hasData = await hasUserData(currentUser.uid);
      debugPrint('   • User has data: $hasData');
      
      if (hasData) {
        debugPrint('🔍 [UserMigration] DEBUG: User data breakdown:');
        
        // Check main document
        final userDoc = await _firestore.collection('users').doc(currentUser.uid).get();
        if (userDoc.exists) {
          final data = userDoc.data();
          debugPrint('   • User document exists with ${data?.keys.length ?? 0} fields');
          debugPrint('   • User document data: ${data?.keys.join(', ') ?? 'none'}');
        }
        
        // Check collections
        final collections = [
          'users/${currentUser.uid}/followed_animes',
          'users/${currentUser.uid}/favorite_animes',
          'users/${currentUser.uid}/watchlist',
          'users/${currentUser.uid}/preferences',
        ];
        
        for (final collectionPath in collections) {
          final snapshot = await _firestore.collection(collectionPath).get();
          debugPrint('   • $collectionPath: ${snapshot.docs.length} documents');
        }
      }
    } catch (e) {
      debugPrint('❌ [UserMigration] DEBUG: Error checking migration state: $e');
    }
  }

  /// Check if a user has any data that needs migration
  Future<bool> hasUserData(String userId) async {
    try {
      debugPrint('🔍 [UserMigration] Checking user data for: $userId');
      
      // Check main user document
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists && userDoc.data()?.isNotEmpty == true) {
        debugPrint('✅ [UserMigration] Found user document for $userId');
        return true;
      } else {
        debugPrint('ℹ️ [UserMigration] No user document found for $userId');
      }

      // Check sub-collections
      final collections = [
        'users/$userId/followed_animes',
        'users/$userId/favorite_animes',
        'users/$userId/watchlist',
        'users/$userId/preferences',
      ];

      for (final collectionPath in collections) {
        debugPrint('🔍 [UserMigration] Checking collection: $collectionPath');
        final snapshot = await _firestore.collection(collectionPath).limit(1).get();
        if (snapshot.docs.isNotEmpty) {
          debugPrint('✅ [UserMigration] Found data in collection: $collectionPath (${snapshot.docs.length} documents)');
          return true;
        } else {
          debugPrint('ℹ️ [UserMigration] No data in collection: $collectionPath');
        }
      }

      debugPrint('ℹ️ [UserMigration] No data found for user: $userId');
      return false;
    } catch (e) {
      debugPrint('❌ [UserMigration] Error checking user data for $userId: $e');
      return false; // Assume no data on error to avoid unnecessary migration attempts
    }
  }

  /// Clean up user data for a specific user ID (public method)
  Future<void> cleanupUserData(String userId) async {
    await _cleanupOldUserData(userId);
  }

  /// Get user data summary for comparison in migration dialog
  Future<UserDataSummary> getUserDataSummary(String userId) async {
    try {
      debugPrint('📊 [UserMigration] Getting data summary for: $userId');
      
      int followedAnimes = 0;
      int favoriteAnimes = 0;
      int watchlistItems = 0;
      DateTime? lastUpdated;
      
      // Check main user document for last updated timestamp
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final data = userDoc.data();
        if (data?['lastUpdated'] != null) {
          lastUpdated = (data!['lastUpdated'] as Timestamp).toDate();
        }
      }
      
      // Count followed animes
      final followedSnapshot = await _firestore
          .collection('users/$userId/followed_animes')
          .get();
      followedAnimes = followedSnapshot.docs.length;
      
      // Count favorite animes  
      final favoritesSnapshot = await _firestore
          .collection('users/$userId/favorite_animes')
          .get();
      favoriteAnimes = favoritesSnapshot.docs.length;
      
      // Count watchlist items
      final watchlistSnapshot = await _firestore
          .collection('users/$userId/watchlist')
          .get();
      watchlistItems = watchlistSnapshot.docs.length;
      
      // Determine if user is anonymous by checking current auth state
      final currentUser = _auth.currentUser;
      bool isAnonymous = false;
      if (currentUser?.uid == userId) {
        isAnonymous = currentUser?.isAnonymous ?? false;
      }
      
      debugPrint('📊 [UserMigration] Data summary for $userId:');
      debugPrint('   • Followed: $followedAnimes');
      debugPrint('   • Favorites: $favoriteAnimes');
      debugPrint('   • Watchlist: $watchlistItems');
      debugPrint('   • Last updated: $lastUpdated');
      debugPrint('   • Is anonymous: $isAnonymous');
      
      return UserDataSummary(
        userId: userId,
        followedAnimes: followedAnimes,
        favoriteAnimes: favoriteAnimes,
        watchlistItems: watchlistItems,
        lastUpdated: lastUpdated,
        isAnonymous: isAnonymous,
      );
    } catch (e) {
      debugPrint('❌ [UserMigration] Error getting user data summary for $userId: $e');
      rethrow;
    }
  }
  
  /// Verify that migration was successful by comparing data counts
  Future<bool> verifyMigrationSuccess(String fromUserId, String toUserId) async {
    try {
      debugPrint('🔍 [UserMigration] Verifying migration success from $fromUserId to $toUserId');
      
      // Check that old user data is gone
      final oldUserHasData = await hasUserData(fromUserId);
      if (oldUserHasData) {
        debugPrint('⚠️ [UserMigration] WARNING: Old user $fromUserId still has data after migration');
        return false;
      }
      
      // Check that new user has data
      final newUserHasData = await hasUserData(toUserId);
      if (!newUserHasData) {
        debugPrint('⚠️ [UserMigration] WARNING: New user $toUserId has no data after migration');
        return false;
      }
      
      // Get detailed summary for verification
      final newUserSummary = await getUserDataSummary(toUserId);
      debugPrint('✅ [UserMigration] Migration verification successful:');
      debugPrint('   • Old user data cleared: ${!oldUserHasData}');
      debugPrint('   • New user has data: $newUserHasData');
             debugPrint('   • New user followed animes: ${newUserSummary.followedAnimes}');
       debugPrint('   • New user favorites: ${newUserSummary.favoriteAnimes}');
       debugPrint('   • New user watchlist: ${newUserSummary.watchlistItems}');
      
      return true;
    } catch (e) {
      debugPrint('❌ [UserMigration] Error verifying migration: $e');
      return false;
    }
  }
} 
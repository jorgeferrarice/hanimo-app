import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:redux/redux.dart';
import '../redux/app_state.dart';
import '../redux/actions.dart';
import 'migration_choice_dialog.dart';

/// A widget that shows migration progress when user data is being migrated
class MigrationProgressWidget extends StatelessWidget {
  const MigrationProgressWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, _MigrationState>(
      converter: (store) => _MigrationState(
        isMigrating: store.state.isMigratingUserData,
        error: store.state.migrationError,
        requiresChoice: store.state.migrationRequiresChoice,
        localData: store.state.localDataSummary,
        cloudData: store.state.cloudDataSummary,
        fromUserId: store.state.pendingMigrationFromUserId,
        toUserId: store.state.pendingMigrationToUserId,
        store: store,
      ),
      builder: (context, migrationState) {
        // Show choice dialog if migration requires user choice
        if (migrationState.requiresChoice && 
            migrationState.localData != null && 
            migrationState.cloudData != null &&
            migrationState.fromUserId != null &&
            migrationState.toUserId != null) {
          
          WidgetsBinding.instance.addPostFrameCallback((_) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => MigrationChoiceDialog(
                localData: migrationState.localData!,
                cloudData: migrationState.cloudData!,
                onKeepCloudData: () {
                  Navigator.of(context).pop();
                  migrationState.store.dispatch(
                    handleKeepCloudDataAction(
                      migrationState.fromUserId!,
                      migrationState.toUserId!,
                    ),
                  );
                },
                onMigrateLocalData: () {
                  Navigator.of(context).pop();
                  migrationState.store.dispatch(
                    handleMigrateLocalDataAction(
                      migrationState.fromUserId!,
                      migrationState.toUserId!,
                    ),
                  );
                },
              ),
            );
          });
        }
        
        if (!migrationState.isMigrating && migrationState.error == null && !migrationState.requiresChoice) {
          return const SizedBox.shrink(); // Hide when not migrating
        }

        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: migrationState.error != null 
                ? Theme.of(context).colorScheme.errorContainer
                : Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: migrationState.error != null
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.primary,
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Migration in progress
              if (migrationState.isMigrating && migrationState.error == null) ...[
                Row(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Migrating Data',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Moving your anime data to your authenticated account...',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.8),
                  ),
                ),
              ],
              
              // Migration error
              if (migrationState.error != null) ...[
                Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Theme.of(context).colorScheme.error,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Migration Error',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onErrorContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Failed to migrate your data: ${migrationState.error}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onErrorContainer.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        // You could add retry logic here if needed
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please try logging in again or contact support if the issue persists.'),
                          ),
                        );
                      },
                      child: const Text('Dismiss'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _MigrationState {
  final bool isMigrating;
  final String? error;
  final bool requiresChoice;
  final UserDataSummary? localData;
  final UserDataSummary? cloudData;
  final String? fromUserId;
  final String? toUserId;
  final Store<AppState> store;

  _MigrationState({
    required this.isMigrating,
    required this.error,
    required this.requiresChoice,
    required this.localData,
    required this.cloudData,
    required this.fromUserId,
    required this.toUserId,
    required this.store,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _MigrationState &&
          runtimeType == other.runtimeType &&
          isMigrating == other.isMigrating &&
          error == other.error &&
          requiresChoice == other.requiresChoice &&
          localData == other.localData &&
          cloudData == other.cloudData &&
          fromUserId == other.fromUserId &&
          toUserId == other.toUserId &&
          store == other.store;

  @override
  int get hashCode =>
      isMigrating.hashCode ^
      error.hashCode ^
      requiresChoice.hashCode ^
      localData.hashCode ^
      cloudData.hashCode ^
      fromUserId.hashCode ^
      toUserId.hashCode ^
      store.hashCode;
} 
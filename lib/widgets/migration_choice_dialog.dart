import 'package:flutter/material.dart';

/// Data summary for comparison in migration dialog
class UserDataSummary {
  final int followedAnimes;
  final int favoriteAnimes;
  final int watchlistItems;
  final DateTime? lastUpdated;
  final String userId;
  final bool isAnonymous;

  const UserDataSummary({
    required this.followedAnimes,
    required this.favoriteAnimes,
    required this.watchlistItems,
    required this.lastUpdated,
    required this.userId,
    required this.isAnonymous,
  });
}

/// Dialog that appears when both anonymous and authenticated users have data
/// Allows user to choose which data to keep
class MigrationChoiceDialog extends StatelessWidget {
  final UserDataSummary localData;  // Anonymous user data
  final UserDataSummary cloudData;  // Authenticated user data
  final VoidCallback onKeepCloudData;
  final VoidCallback onMigrateLocalData;
  final VoidCallback? onCancel;

  const MigrationChoiceDialog({
    super.key,
    required this.localData,
    required this.cloudData,
    required this.onKeepCloudData,
    required this.onMigrateLocalData,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.merge_type,
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Data Conflict',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Both accounts have anime data',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Explanation
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.colorScheme.outline.withOpacity(0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'We found anime data in both accounts. Choose which data you want to keep:',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Data comparison
            Row(
              children: [
                // Local data (anonymous)
                Expanded(
                  child: _buildDataCard(
                    context,
                    title: 'Current Session',
                    subtitle: 'Anonymous account',
                    data: localData,
                    color: theme.colorScheme.secondary,
                    icon: Icons.phone_android,
                  ),
                ),
                
                const SizedBox(width: 16),
                
                // Cloud data (authenticated)
                Expanded(
                  child: _buildDataCard(
                    context,
                    title: 'Cloud Data',
                    subtitle: 'Your account',
                    data: cloudData,
                    color: theme.colorScheme.primary,
                    icon: Icons.cloud,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 32),
            
            // Action buttons
            Column(
              children: [
                // Keep cloud data button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onKeepCloudData,
                    icon: const Icon(Icons.cloud_download),
                    label: const Text('Keep Cloud Data'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Migrate local data button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onMigrateLocalData,
                    icon: const Icon(Icons.upload),
                    label: const Text('Use Current Session Data'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                
                // Cancel button (if provided)
                if (onCancel != null) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: onCancel,
                    child: const Text('Cancel'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required UserDataSummary data,
    required Color color,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                icon,
                color: color,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Stats
          Column(
            children: [
              _buildStatRow(
                context,
                icon: Icons.bookmark,
                label: 'Following',
                value: data.followedAnimes.toString(),
              ),
              const SizedBox(height: 8),
              _buildStatRow(
                context,
                icon: Icons.favorite,
                label: 'Favorites',
                value: data.favoriteAnimes.toString(),
              ),
              const SizedBox(height: 8),
              _buildStatRow(
                context,
                icon: Icons.list,
                label: 'Watchlist',
                value: data.watchlistItems.toString(),
              ),
              if (data.lastUpdated != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Last updated: ${_formatDate(data.lastUpdated!)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                    fontSize: 10,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    
    return Row(
      children: [
        Icon(
          icon,
          size: 14,
          color: theme.colorScheme.onSurface.withOpacity(0.6),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.8),
            ),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
} 
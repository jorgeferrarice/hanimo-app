import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/theme_service.dart';
import '../services/onesignal_service.dart';
import '../services/in_app_review_service.dart';
import 'login_screen.dart';
import 'privacy_policy_screen.dart';
import 'terms_of_service_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _authService = AuthService();
  final OneSignalService _oneSignalService = OneSignalService.instance;
  final InAppReviewService _inAppReviewService = InAppReviewService();
  bool _notificationsEnabled = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Wait a bit for OneSignal to initialize before checking preferences
    Future.delayed(const Duration(milliseconds: 500), () {
      _loadNotificationPreference();
    });
  }

  /// Load notification preference from SharedPreferences and OneSignal
  Future<void> _loadNotificationPreference() async {
    try {
      // Ensure OneSignal is initialized
      await _oneSignalService.initialize();
      
      final prefs = await SharedPreferences.getInstance();
      final savedPreference = prefs.getBool('notifications_enabled');
      
      // Check OneSignal subscription status and permission
      final isOneSignalSubscribed = _oneSignalService.isSubscribed;
      final hasPermission = await _oneSignalService.hasNotificationPermission;
      
      // Determine the final enabled state
      bool finalEnabled;
      if (savedPreference == null) {
        // First time - use OneSignal status and permission as default
        finalEnabled = isOneSignalSubscribed && hasPermission;
        // Save this initial state
        await prefs.setBool('notifications_enabled', finalEnabled);
      } else {
        // Use saved preference, but verify against actual OneSignal status
        // If user had it enabled but OneSignal shows disabled, respect OneSignal
        if (savedPreference && !isOneSignalSubscribed) {
          finalEnabled = false;
          // Update saved preference to match reality
          await prefs.setBool('notifications_enabled', false);
        } else {
          finalEnabled = savedPreference;
        }
      }
      
      setState(() {
        _notificationsEnabled = finalEnabled;
      });
      
      debugPrint('🔔 Loaded notification preference: $_notificationsEnabled (Saved: $savedPreference, OneSignal: $isOneSignalSubscribed, Permission: $hasPermission, Final: $finalEnabled)');
    } catch (e) {
      debugPrint('❌ Error loading notification preference: $e');
      // Default to false if there's an error
      setState(() {
        _notificationsEnabled = false;
      });
    }
  }

  /// Save notification preference and update OneSignal
  Future<void> _updateNotificationPreference(bool enabled) async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (enabled) {
        // First check if we have permission
        final hasPermission = await _oneSignalService.hasNotificationPermission;
        debugPrint('🔔 Has notification permission: $hasPermission');
        
        if (!hasPermission) {
          // Show dialog explaining permission is needed
          final shouldRequestPermission = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Notification Permission'),
              content: const Text(
                'To receive notifications about new anime episodes, please allow notifications when prompted.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Allow'),
                ),
              ],
            ),
          );
          
          if (shouldRequestPermission != true) {
            setState(() {
              _isLoading = false;
            });
            return;
          }
        }
        
        // Enable notifications
        await _oneSignalService.enableNotifications();
      } else {
        // Disable notifications
        await _oneSignalService.disableNotifications();
      }
      
      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('notifications_enabled', enabled);
      
      // Wait a moment for OneSignal to update, then refresh and check the actual status
      await Future.delayed(const Duration(milliseconds: 1000));
      final actualStatus = await _oneSignalService.refreshSubscriptionStatus();
      final hasPermission = await _oneSignalService.hasNotificationPermission;
      
      setState(() {
        // If we tried to enable but OneSignal says it's not subscribed, 
        // there might be a permission issue
        if (enabled && !actualStatus) {
          _notificationsEnabled = false;
        } else {
          _notificationsEnabled = enabled;
        }
        _isLoading = false;
      });
      
      if (enabled && !actualStatus) {
        debugPrint('⚠️ Notification preference mismatch: requested $enabled but OneSignal status is $actualStatus (Permission: $hasPermission)');
        
        // Show specific error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                hasPermission 
                    ? 'Notifications enabled but subscription failed. Please try again.'
                    : 'Notification permission was denied. Please enable in device settings.',
              ),
              backgroundColor: Theme.of(context).colorScheme.error,
              duration: const Duration(seconds: 4),
              action: !hasPermission ? SnackBarAction(
                label: 'Settings',
                onPressed: () {
                  // TODO: Open device settings
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enable notifications in your device settings'),
                    ),
                  );
                },
              ) : null,
            ),
          );
        }
      } else {
        debugPrint('✅ Notification preference updated: $enabled (Actual OneSignal status: $actualStatus, Permission: $hasPermission)');
        
        // Show success feedback
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                enabled 
                    ? 'Notifications enabled successfully!' 
                    : 'Notifications disabled',
              ),
              backgroundColor: enabled ? Colors.green : null,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error updating notification preference: $e');
      
      setState(() {
        _isLoading = false;
      });
      
      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update notifications: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Handle review request
  Future<void> _handleReviewRequest() async {
    try {
      final isAvailable = await _inAppReviewService.isAvailable();
      if (!isAvailable) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Review is not available on this device'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      await _inAppReviewService.requestReview();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you for your feedback!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error requesting review: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open review: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Handle account deletion
  Future<void> _handleDeleteAccount() async {
    // Show confirmation dialog
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'Are you sure you want to delete your account? This action is irreversible and will permanently delete all your data including:\n\n'
          '• All followed anime\n'
          '• Your watch history\n'
          '• Personal ratings and notes\n'
          '• Account settings\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Soft delete user data from Firestore first
      await _softDeleteUserData();
      
      // Sign out the user (soft delete approach)
      await _authService.deleteAccount();
      
      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account deleted successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        
        // Navigate to login screen
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => const LoginScreen(),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('❌ Error soft deleting account: $e');
      
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete account: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  /// Soft delete user data from Firestore
  Future<void> _softDeleteUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final firestore = FirebaseFirestore.instance;
      final userId = user.uid;
      
      // Get the current user data before deletion
      final userDoc = await firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        debugPrint('⚠️ [SettingsScreen] User document not found, nothing to soft delete');
        return;
      }
      
      // Delete the original user document
      await firestore.collection('users').doc(userId).delete();
      
      // Create a new document with deletion metadata
      await firestore.collection('users').doc(userId).set({
        'deleted': true,
        'deletedAt': FieldValue.serverTimestamp(),
        'originalEmail': user.email,
        'originalDisplayName': user.displayName,
        'originalProviderId': user.providerData.isNotEmpty ? user.providerData.first.providerId : 'unknown',
        'deletedBy': 'user_request',
      });
      
      debugPrint('✅ [SettingsScreen] User data soft deleted from Firestore');
    } catch (e) {
      debugPrint('❌ [SettingsScreen] Error soft deleting user data: $e');
      // Don't throw here - we still want to try to sign out
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = FirebaseAuth.instance.currentUser;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: theme.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Account Section (only show for anonymous users)
          if (user != null && user.isAnonymous) ...[
            _buildSectionHeader('Account', theme),
            const SizedBox(height: 12),
            _buildSettingsTile(
              icon: Icons.login,
              title: 'Login',
              subtitle: 'Sign in to sync your anime across devices',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LoginScreen(showStayAnonymous: true),
                  ),
                );
              },
              theme: theme,
            ),
          ],
          
          // Add spacing only if Account section was shown
          if (user != null && user.isAnonymous) const SizedBox(height: 24),
          
          // Preferences Section
          _buildSectionHeader('Preferences', theme),
          const SizedBox(height: 12),
          _buildSwitchTile(
            icon: Icons.notifications,
            title: 'Notifications',
            subtitle: 'Get notified about new episodes',
            value: _notificationsEnabled,
            onChanged: _isLoading ? null : (value) => _updateNotificationPreference(value),
            theme: theme,
            isLoading: _isLoading,
          ),
          Consumer<ThemeService>(
            builder: (context, themeService, child) {
              return _buildThemeTile(
                icon: Icons.palette,
                title: 'Theme',
                currentTheme: themeService.themeMode,
                onChanged: (ThemeMode mode) {
                  themeService.setThemeMode(mode);
                },
                theme: theme,
              );
            },
          ),

          
          const SizedBox(height: 24),
          
          // About Section
          _buildSectionHeader('About', theme),
          const SizedBox(height: 12),
          _buildSettingsTile(
            icon: Icons.info,
            title: 'About Hanimo',
            subtitle: 'Version 1.0.0',
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'Hanimo',
                applicationVersion: '1.0.0',
                applicationIcon: Icon(
                  Icons.movie,
                  color: theme.colorScheme.primary,
                  size: 48,
                ),
                children: [
                  const Text(
                    'Hanimo was born from a deep love for anime. Like many fans, I often found myself struggling to keep up with release dates and remember which episodes I had already watched. That\'s why I decided to build this app — a simple, clean, and reliable way to track your anime journey.\n\n'
                    'Whether you\'re a casual viewer or a dedicated otaku, Hanimo is here to help you stay on top of your favorite shows, never miss a new episode, and keep your watchlist organized. Built by a fan, for fans — enjoy the ride :)',
                    style: TextStyle(height: 1.5),
                  ),
                ],
              );
            },
            theme: theme,
          ),
          _buildSettingsTile(
            icon: Icons.star,
            title: 'Rate Hanimo',
            subtitle: 'Share your feedback with us',
            onTap: _handleReviewRequest,
            theme: theme,
          ),
          _buildSettingsTile(
            icon: Icons.privacy_tip,
            title: 'Privacy Policy',
            subtitle: 'Read our privacy policy',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PrivacyPolicyScreen(),
                ),
              );
            },
            theme: theme,
          ),
          _buildSettingsTile(
            icon: Icons.description,
            title: 'Terms of Service',
            subtitle: 'Read our terms of service',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TermsOfServiceScreen(),
                ),
              );
            },
            theme: theme,
          ),
          
          const SizedBox(height: 32),
          
          // Sign Out Button (only show for authenticated users)
          if (user != null && !user.isAnonymous)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 32),
              child: ElevatedButton.icon(
                onPressed: () async {
                  // Show confirmation dialog
                  final shouldSignOut = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Sign Out'),
                      content: const Text('Are you sure you want to sign out?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('Sign Out'),
                        ),
                      ],
                    ),
                  );
                  
                  if (shouldSignOut == true) {
                    await _authService.signOut();
                    if (mounted) {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginScreen(),
                        ),
                        (route) => false,
                      );
                    }
                  }
                },
                icon: const Icon(Icons.logout),
                label: const Text('Sign Out'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          
          // Delete Account Button (only show for authenticated users)
          if (user != null && !user.isAnonymous) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 32),
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _handleDeleteAccount,
                icon: _isLoading 
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.delete_forever),
                label: Text(_isLoading ? 'Deleting...' : 'Delete Account'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  disabledBackgroundColor: Colors.red.shade300,
                ),
              ),
            ),
          ],
          
          const SizedBox(height: 80), // Bottom padding
        ],
      ),
    );
  }
  
  Widget _buildSectionHeader(String title, ThemeData theme) {
    return Text(
      title,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: theme.colorScheme.primary,
      ),
    );
  }
  
  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: theme.colorScheme.primary,
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: theme.colorScheme.onSurface.withOpacity(0.4),
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
  
  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
    required ThemeData theme,
    bool isLoading = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: SwitchListTile(
        secondary: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: isLoading 
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                  ),
                )
              : Icon(
                  icon,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
        ),
        title: Text(
          title,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: isLoading ? theme.colorScheme.onSurface.withOpacity(0.5) : null,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(isLoading ? 0.3 : 0.7),
          ),
        ),
        value: value,
        onChanged: onChanged,
        activeColor: theme.colorScheme.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  Widget _buildThemeTile({
    required IconData icon,
    required String title,
    required ThemeMode currentTheme,
    required ValueChanged<ThemeMode> onChanged,
    required ThemeData theme,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withOpacity(0.2),
        ),
      ),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: theme.colorScheme.primary,
            size: 20,
          ),
        ),
        title: Text(
          title,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          _getThemeModeDisplayName(currentTheme),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        children: [
          RadioListTile<ThemeMode>(
            title: const Text('Light'),
            value: ThemeMode.light,
            groupValue: currentTheme,
            onChanged: (ThemeMode? value) {
              if (value != null) onChanged(value);
            },
          ),
          RadioListTile<ThemeMode>(
            title: const Text('Dark'),
            value: ThemeMode.dark,
            groupValue: currentTheme,
            onChanged: (ThemeMode? value) {
              if (value != null) onChanged(value);
            },
          ),
          RadioListTile<ThemeMode>(
            title: const Text('System'),
            value: ThemeMode.system,
            groupValue: currentTheme,
            onChanged: (ThemeMode? value) {
              if (value != null) onChanged(value);
            },
          ),
        ],
      ),
    );
  }

  String _getThemeModeDisplayName(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
    }
  }
} 
import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        backgroundColor: theme.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.colorScheme.primary.withOpacity(0.1),
                    theme.colorScheme.secondary.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.colorScheme.outline.withOpacity(0.2),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.privacy_tip,
                    size: 48,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your Privacy Matters',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Last updated: ${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Introduction
            _buildSection(
              'Introduction',
              'Welcome to Hanimo! We respect your privacy and are committed to protecting your personal data. This privacy policy explains how we collect, use, and safeguard your information when you use our anime tracking application.',
              theme,
            ),
            
            // Information We Collect
            _buildSection(
              'Information We Collect',
              '''We collect the following types of information:

• Account Information: When you create an account, we collect your email address, display name, and authentication provider information (Google, Apple, or email).

• Anime Data: Your anime watchlist, ratings, watch status, episode progress, and personal notes.

• Usage Data: Information about how you use the app, including features accessed, time spent, and interaction patterns.

• Device Information: Device type, operating system, app version, and unique device identifiers for analytics and crash reporting.

• Optional Data: Profile pictures and additional profile information you choose to provide.''',
              theme,
            ),
            
            // How We Use Your Information
            _buildSection(
              'How We Use Your Information',
              '''We use your information to:

• Provide and maintain the Hanimo service
• Sync your anime data across devices
• Send notifications about new episodes and updates
• Improve app performance and user experience
• Provide customer support
• Analyze usage patterns to enhance features
• Ensure app security and prevent abuse

We do not sell, rent, or trade your personal information to third parties for marketing purposes.''',
              theme,
            ),
            
            // Data Storage and Security
            _buildSection(
              'Data Storage and Security',
              '''Your data is stored securely using:

• Firebase/Firestore: Google's secure cloud database platform
• Industry-standard encryption for data transmission
• Regular security audits and updates
• Access controls and authentication mechanisms

We implement appropriate technical and organizational measures to protect your personal data against unauthorized access, alteration, disclosure, or destruction.''',
              theme,
            ),
            
            // Third-Party Services
            _buildSection(
              'Third-Party Services',
              '''Hanimo integrates with the following third-party services:

• Jikan API: For anime information and metadata (no personal data shared)
• Firebase: For authentication, database, and analytics
• OneSignal: For push notifications (with your consent)
• Google AdMob: For advertising (anonymized data only)
• Google/Apple Sign-In: For authentication services

Each service has its own privacy policy, and we encourage you to review them.''',
              theme,
            ),
            
            // Your Rights
            _buildSection(
              'Your Rights',
              '''You have the right to:

• Access your personal data
• Correct inaccurate information
• Delete your account and associated data
• Export your anime data
• Opt-out of notifications
• Withdraw consent for data processing

To exercise these rights, please contact us through the app's settings or support channels.''',
              theme,
            ),
            
            // Data Retention
            _buildSection(
              'Data Retention',
              '''We retain your data for as long as your account is active or as needed to provide services. When you delete your account:

• Personal information is deleted within 30 days
• Anonymized usage data may be retained for analytics
• Backup data is purged within 90 days
• Some data may be retained longer if required by law''',
              theme,
            ),
            
            // Children's Privacy
            _buildSection(
              'Children\'s Privacy',
              'Hanimo is not intended for children under 13. We do not knowingly collect personal information from children under 13. If you believe we have collected information from a child under 13, please contact us immediately.',
              theme,
            ),
            
            // Changes to Privacy Policy
            _buildSection(
              'Changes to This Privacy Policy',
              'We may update this privacy policy from time to time. We will notify you of any changes by posting the new privacy policy in the app and updating the "Last updated" date. Continued use of the app after changes constitutes acceptance of the updated policy.',
              theme,
            ),
            
            // Contact Information
            _buildSection(
              'Contact Us',
              '''If you have questions about this privacy policy or our data practices, please contact us:

• Through the app's feedback feature
• Via the support section in app settings
• By reviewing our community guidelines

We're committed to addressing your privacy concerns promptly and transparently.''',
              theme,
            ),
            
            const SizedBox(height: 40),
            
            // Footer
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Thank you for trusting Hanimo with your anime journey! 🎌',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.onSurface.withOpacity(0.8),
                ),
                textAlign: TextAlign.center,
              ),
            ),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSection(String title, String content, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.outline.withOpacity(0.2),
            ),
          ),
          child: Text(
            content,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.6,
              color: theme.colorScheme.onSurface.withOpacity(0.8),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
} 
import 'package:flutter/material.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms of Service'),
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
                    theme.colorScheme.secondary.withOpacity(0.1),
                    theme.colorScheme.tertiary.withOpacity(0.1),
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
                    Icons.description,
                    size: 48,
                    color: theme.colorScheme.secondary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Terms of Service',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.secondary,
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
            
            // Agreement
            _buildSection(
              'Agreement to Terms',
              'By downloading, installing, or using the Hanimo anime tracking application, you agree to be bound by these Terms of Service. If you do not agree to these terms, please do not use our service.',
              theme,
            ),
            
            // Description of Service
            _buildSection(
              'Description of Service',
              '''Hanimo is a free anime tracking application that allows users to:

• Track their anime watching progress
• Discover new anime series and movies
• Rate and review anime content
• Receive notifications about new episodes
• Sync data across multiple devices
• Connect with the anime community

Our service relies on publicly available anime databases and user-generated content to provide these features.''',
              theme,
            ),
            
            // User Accounts
            _buildSection(
              'User Accounts',
              '''To access certain features, you may need to create an account. You agree to:

• Provide accurate and complete information
• Maintain the security of your account credentials
• Notify us immediately of any unauthorized access
• Take responsibility for all activities under your account
• Use only one account per person

We reserve the right to suspend or terminate accounts that violate these terms.''',
              theme,
            ),
            
            // Acceptable Use
            _buildSection(
              'Acceptable Use Policy',
              '''You agree to use Hanimo responsibly and not to:

• Share illegal, harmful, or inappropriate content
• Harass, abuse, or harm other users
• Spam or send unsolicited messages
• Attempt to hack, reverse engineer, or exploit the app
• Create fake accounts or impersonate others
• Violate any applicable laws or regulations
• Use automated systems to access the service

We reserve the right to remove content and suspend users who violate these guidelines.''',
              theme,
            ),
            
            // Content and Intellectual Property
            _buildSection(
              'Content and Intellectual Property',
              '''Regarding content and intellectual property:

• Anime data is sourced from public databases (primarily Jikan API/MyAnimeList)
• User-generated content (reviews, ratings, lists) remains owned by users
• Users grant Hanimo a license to use their content within the service
• We respect intellectual property rights and respond to valid DMCA requests
• The Hanimo app design, code, and branding are our intellectual property

Users are responsible for ensuring their content doesn't infringe on others' rights.''',
              theme,
            ),
            
            // Privacy and Data
            _buildSection(
              'Privacy and Data',
              '''Your privacy is important to us:

• We collect and use data as described in our Privacy Policy
• You can access, modify, or delete your data at any time
• We implement security measures to protect your information
• We don't sell your personal data to third parties
• Anonymous usage analytics help us improve the app

Please review our Privacy Policy for detailed information about data handling.''',
              theme,
            ),
            
            // Third-Party Services
            _buildSection(
              'Third-Party Services',
              '''Hanimo integrates with third-party services:

• Jikan API for anime data (subject to their terms)
• Firebase for backend services (Google's terms apply)
• OneSignal for notifications (their privacy policy applies)
• Authentication providers (Google, Apple terms apply)
• AdMob for advertising (Google's advertising terms apply)

We're not responsible for third-party service availability or terms changes.''',
              theme,
            ),
            
            // Disclaimers
            _buildSection(
              'Disclaimers and Limitations',
              '''Important disclaimers:

• Hanimo is provided "as is" without warranties of any kind
• We don't guarantee uninterrupted or error-free service
• Anime data accuracy depends on third-party sources
• We're not liable for any damages from app use
• Our liability is limited to the maximum extent permitted by law
• Service availability may vary by region

Use Hanimo at your own discretion and risk.''',
              theme,
            ),
            
            // Modifications
            _buildSection(
              'Service Modifications',
              '''We reserve the right to:

• Modify or discontinue features at any time
• Update these terms with reasonable notice
• Change pricing for premium features (if introduced)
• Implement new policies and guidelines
• Suspend service for maintenance or improvements

Continued use after changes constitutes acceptance of updated terms.''',
              theme,
            ),
            
            // Termination
            _buildSection(
              'Termination',
              '''Either party may terminate this agreement:

• You can delete your account and stop using the service anytime
• We may suspend or terminate accounts for terms violations
• We may discontinue the service with reasonable notice
• Upon termination, your right to use the service ends immediately
• Data deletion follows our Privacy Policy guidelines

Provisions regarding intellectual property and limitations survive termination.''',
              theme,
            ),
            
            // Governing Law
            _buildSection(
              'Governing Law',
              'These terms are governed by applicable laws in your jurisdiction. Any disputes will be resolved through appropriate legal channels. We encourage users to contact us first to resolve issues amicably.',
              theme,
            ),
            
            // Contact Information
            _buildSection(
              'Contact Us',
              '''For questions about these terms or to report violations:

• Use the feedback feature in the app
• Contact us through the settings support section
• Report content violations through appropriate channels

We're committed to maintaining a positive community experience for all anime fans.''',
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
              child: Column(
                children: [
                  Text(
                    'Thank you for being part of the Hanimo community!',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface.withOpacity(0.8),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Let\'s explore the world of anime together! 🌟',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
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
            color: theme.colorScheme.secondary,
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
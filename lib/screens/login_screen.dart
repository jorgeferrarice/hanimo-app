import 'dart:io';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../services/auth_service.dart';

enum LoadingState { none, anonymous, google, apple }

class LoginScreen extends StatefulWidget {
  final bool showStayAnonymous;
  
  const LoginScreen({super.key, this.showStayAnonymous = false});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  LoadingState _loadingState = LoadingState.none;
  bool _isAppleSignInAvailable = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _checkAppleSignInAvailability();
    _setupAnimations();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkAppleSignInAvailability() async {
    final isAvailable = await AuthService.isAppleSignInAvailable();
    setState(() {
      _isAppleSignInAvailable = isAvailable;
    });
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _loadingState = LoadingState.google;
    });

    try {
      final result = await _authService.signInWithGoogle();
      if (result != null && mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to sign in with Google: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingState = LoadingState.none;
        });
      }
    }
  }

  Future<void> _signInWithApple() async {
    setState(() {
      _loadingState = LoadingState.apple;
    });

    try {
      final result = await _authService.signInWithApple();
      if (result != null && mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to sign in with Apple: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingState = LoadingState.none;
        });
      }
    }
  }

  Future<void> _signInAnonymously() async {
    setState(() {
      _loadingState = LoadingState.anonymous;
    });

    try {
      final result = await _authService.signInAnonymously();
      if (result != null && mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to continue anonymously: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingState = LoadingState.none;
        });
      }
    }
  }

  void _stayAnonymous() {
    // User is already anonymous, just navigate back to home
    Navigator.of(context).pushReplacementNamed('/home');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primary.withOpacity(0.1),
              colorScheme.secondary.withOpacity(0.1),
              colorScheme.tertiary.withOpacity(0.1),
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // App Icon and Title
                    _buildHeader(theme),
                    
                    const SizedBox(height: 48),
                    
                    // Welcome Text
                    _buildWelcomeText(theme),
                    
                    const SizedBox(height: 48),
                    
                    // Login Buttons
                    _buildLoginButtons(theme, colorScheme),
                    
                    const SizedBox(height: 32),
                    
                    // Terms and Privacy
                    _buildTermsText(theme),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Column(
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary,
                theme.colorScheme.secondary,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withOpacity(0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Icon(
            Icons.play_circle_fill,
            size: 60,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Hanimo',
          style: theme.textTheme.displayMedium?.copyWith(
            fontWeight: FontWeight.bold,
            foreground: Paint()
              ..shader = LinearGradient(
                colors: [
                  theme.colorScheme.primary,
                  theme.colorScheme.secondary,
                ],
              ).createShader(const Rect.fromLTWH(0.0, 0.0, 200.0, 70.0)),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Your Anime Journey Starts Here',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onBackground.withOpacity(0.7),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildWelcomeText(ThemeData theme) {
    return Column(
      children: [
        Text(
          'Welcome Back!',
          style: theme.textTheme.headlineLarge?.copyWith(
            color: theme.colorScheme.onBackground,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Sign in to continue tracking your favorite anime episodes',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onBackground.withOpacity(0.7),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildLoginButtons(ThemeData theme, ColorScheme colorScheme) {
    final bool isAnyLoading = _loadingState != LoadingState.none;
    
    return Column(
      children: [
        // Get Started Button (Anonymous)
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: isAnyLoading ? null : (widget.showStayAnonymous ? _stayAnonymous : _signInAnonymously),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 2,
            ),
            icon: _loadingState == LoadingState.anonymous
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(
                    Icons.rocket_launch,
                    size: 22,
                  ),
            label: Text(
              _loadingState == LoadingState.anonymous 
                  ? 'Getting Started...' 
                  : (widget.showStayAnonymous ? 'Stay Anonymous' : 'Get Started'),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 24),
        
        // Divider with "OR"
        Row(
          children: [
            Expanded(
              child: Container(
                height: 1,
                color: colorScheme.onBackground.withOpacity(0.2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'OR',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onBackground.withOpacity(0.6),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              child: Container(
                height: 1,
                color: colorScheme.onBackground.withOpacity(0.2),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 24),
        
        // Google Sign In Button
        _buildSocialButton(
          onPressed: isAnyLoading ? null : _signInWithGoogle,
          icon: FontAwesomeIcons.google,
          label: _loadingState == LoadingState.google ? 'Signing in...' : 'Continue with Google',
          backgroundColor: Colors.white,
          textColor: Colors.black87,
          borderColor: Colors.grey.shade300,
          isLoading: _loadingState == LoadingState.google,
        ),
        
        if (_isAppleSignInAvailable) ...[
          const SizedBox(height: 16),
          // Apple Sign In Button
          _buildSocialButton(
            onPressed: isAnyLoading ? null : _signInWithApple,
            icon: FontAwesomeIcons.apple,
            label: _loadingState == LoadingState.apple ? 'Signing in...' : 'Continue with Apple',
            backgroundColor: Colors.black,
            textColor: Colors.white,
            borderColor: Colors.black,
            isLoading: _loadingState == LoadingState.apple,
          ),
        ],
      ],
    );
  }

  Widget _buildSocialButton({
    required VoidCallback? onPressed,
    required IconData icon,
    required String label,
    required Color backgroundColor,
    required Color textColor,
    required Color borderColor,
    required bool isLoading,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          side: BorderSide(color: borderColor, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        icon: isLoading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(textColor),
                ),
              )
            : FaIcon(
                icon,
                size: 20,
                color: textColor,
              ),
        label: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ),
    );
  }

  Widget _buildTermsText(ThemeData theme) {
    return Text(
      'By continuing, you agree to our Terms of Service and Privacy Policy',
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onBackground.withOpacity(0.6),
      ),
      textAlign: TextAlign.center,
    );
  }
} 
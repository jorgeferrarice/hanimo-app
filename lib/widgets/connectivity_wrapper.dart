import 'package:flutter/material.dart';
import '../services/connectivity_service.dart';
import 'no_internet_screen.dart';

class ConnectivityWrapper extends StatefulWidget {
  final Widget child;
  
  const ConnectivityWrapper({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  State<ConnectivityWrapper> createState() => _ConnectivityWrapperState();
}

class _ConnectivityWrapperState extends State<ConnectivityWrapper>
    with TickerProviderStateMixin {
  final ConnectivityService _connectivityService = ConnectivityService();
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  bool _isConnected = true;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    
    // Initialize slide animation
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeInOut,
    ));
    
    _initializeConnectivity();
  }

  Future<void> _initializeConnectivity() async {
    try {
      await _connectivityService.initialize();
      
      // Listen to connectivity changes
      _connectivityService.connectivityStream.listen((bool isConnected) {
        if (mounted) {
          setState(() {
            _isConnected = isConnected;
            _isInitialized = true;
          });
          
          if (isConnected) {
            // Hide no internet screen
            _slideController.reverse();
          } else {
            // Show no internet screen
            _slideController.forward();
          }
        }
      });
      
      // Set initial state
      if (mounted) {
        setState(() {
          _isConnected = _connectivityService.isConnected;
          _isInitialized = true;
        });
        
        if (!_isConnected) {
          _slideController.forward();
        }
      }
    } catch (e) {
      // If initialization fails, assume no connection
      if (mounted) {
        setState(() {
          _isConnected = false;
          _isInitialized = true;
        });
        _slideController.forward();
      }
    }
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      // Show loading indicator while checking connectivity
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 20),
              Text(
                'Checking connection...',
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        // Main app content
        widget.child,
        
        // No internet screen overlay
        AnimatedBuilder(
          animation: _slideAnimation,
          builder: (context, child) {
            return SlideTransition(
              position: _slideAnimation,
              child: Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.transparent,
                child: const NoInternetScreen(),
              ),
            );
          },
        ),
      ],
    );
  }
} 
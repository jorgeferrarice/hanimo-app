import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamController<bool> _connectivityController = StreamController<bool>.broadcast();
  
  Stream<bool> get connectivityStream => _connectivityController.stream;
  bool _isConnected = true;
  
  bool get isConnected => _isConnected;

  Future<void> initialize() async {
    // Check initial connectivity
    _isConnected = await _checkInternetConnection();
    _connectivityController.add(_isConnected);
    
    // Listen to connectivity changes
    _connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) async {
      // Check if any connection is available
      bool hasConnection = results.any((result) => 
        result != ConnectivityResult.none
      );
      
      if (hasConnection) {
        // Even if we have a connection type, we need to verify actual internet access
        bool actualConnection = await _checkInternetConnection();
        if (actualConnection != _isConnected) {
          _isConnected = actualConnection;
          _connectivityController.add(_isConnected);
        }
      } else {
        // No connection at all
        if (_isConnected) {
          _isConnected = false;
          _connectivityController.add(_isConnected);
        }
      }
    });
  }

  Future<bool> _checkInternetConnection() async {
    try {
      // Try to reach a reliable endpoint
      final response = await http.get(
        Uri.parse('https://www.google.com'),
        headers: {'Connection': 'close'},
      ).timeout(const Duration(seconds: 5));
      
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<bool> checkConnectivity() async {
    _isConnected = await _checkInternetConnection();
    _connectivityController.add(_isConnected);
    return _isConnected;
  }

  void dispose() {
    _connectivityController.close();
  }
} 
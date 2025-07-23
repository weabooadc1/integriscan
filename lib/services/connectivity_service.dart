import 'dart:async';
import 'package:integriscan/services/firestore_sync_service.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  bool _isConnected = false;
  bool get isConnected => _isConnected;
  
  final _connectivityController = StreamController<bool>.broadcast();
  Stream<bool> get connectivityStream => _connectivityController.stream;
  
  Timer? _connectivityTimer;

  // Callback for when connectivity is restored
  Function()? _onConnectivityRestored;
  
  void setConnectivityRestoredCallback(Function() callback) {
    _onConnectivityRestored = callback;
  }

  Future<void> initialize() async {
    print('Initializing ConnectivityService (Firebase-based)...');
    
    // Check initial connectivity
    await _updateConnectivityStatus();
    print('Initial connectivity status: $_isConnected');
    
    // Start periodic connectivity checking (every 30 seconds)
    _startPeriodicConnectivityCheck();
  }

  void _startPeriodicConnectivityCheck() {
    _connectivityTimer?.cancel();
    _connectivityTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      // Run connectivity check without blocking
      _updateConnectivityStatus().catchError((error) {
        print('Periodic connectivity check error: $error');
        _isConnected = false;
        _connectivityController.add(false);
      });
    });
  }

  Future<void> _updateConnectivityStatus() async {
    try {
      print('Testing Firebase connectivity...');
      
      final wasConnected = _isConnected;
      
      // Test actual Firebase connectivity with timeout
      _isConnected = await FirestoreSyncService.testConnection()
          .timeout(const Duration(seconds: 5), onTimeout: () {
        print('Connectivity test timed out - assuming offline');
        return false;
      });
      
      print('Connectivity status updated: $_isConnected (was: $wasConnected)');
      
      // Notify listeners of connectivity changes
      _connectivityController.add(_isConnected);
      
      // If we just got connected, trigger background sync
      if (!wasConnected && _isConnected && _onConnectivityRestored != null) {
        print('Connection restored - triggering background sync');
        Future.delayed(const Duration(seconds: 2), () {
          _onConnectivityRestored!();
        });
      }
    } catch (e) {
      print('Error checking connectivity: $e');
      _isConnected = false;
      _connectivityController.add(false);
    }
  }

  /// Manual connectivity check
  Future<bool> checkConnectivity() async {
    print('Manual connectivity check requested...');
    try {
      await _updateConnectivityStatus()
          .timeout(const Duration(seconds: 3), onTimeout: () {
        print('Manual connectivity check timed out');
        _isConnected = false;
        _connectivityController.add(false);
      });
    } catch (e) {
      print('Manual connectivity check error: $e');
      _isConnected = false;
      _connectivityController.add(false);
    }
    return _isConnected;
  }

  /// Force refresh connectivity status
  Future<void> refreshConnectivityStatus() async {
    print('Forcing connectivity status refresh...');
    try {
      await _updateConnectivityStatus()
          .timeout(const Duration(seconds: 3), onTimeout: () {
        print('Refresh connectivity check timed out');
        _isConnected = false;
        _connectivityController.add(false);
      });
    } catch (e) {
      print('Refresh connectivity check error: $e');
      _isConnected = false;
      _connectivityController.add(false);
    }
  }

  /// Test actual Firebase connectivity
  Future<bool> testInternetConnectivity() async {
    try {
      print('Testing Firebase connectivity...');
      
      final result = await FirestoreSyncService.testConnection()
          .timeout(const Duration(seconds: 5), onTimeout: () {
        print('Internet connectivity test timed out');
        return false;
      });
      
      print('Firebase connectivity test result: $result');
      return result;
    } catch (e) {
      print('Firebase connectivity test failed: $e');
      return false;
    }
  }

  /// Force connectivity check manually (useful for debugging)
  Future<void> forceConnectivityCheck() async {
    print('Forcing connectivity check...');
    await _updateConnectivityStatus();
  }

  void dispose() {
    _connectivityTimer?.cancel();
    _connectivityController.close();
  }
}

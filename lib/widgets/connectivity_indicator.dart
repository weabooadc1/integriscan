import 'dart:async';
import 'package:flutter/material.dart';
import 'package:integriscan/services/connectivity_service.dart';

class ConnectivityIndicator extends StatefulWidget {
  final Widget child;
  final bool showOnlineIndicator;
  
  const ConnectivityIndicator({
    super.key,
    required this.child,
    this.showOnlineIndicator = true,
  });

  @override
  State<ConnectivityIndicator> createState() => _ConnectivityIndicatorState();
}

class _ConnectivityIndicatorState extends State<ConnectivityIndicator> {
  final ConnectivityService _connectivityService = ConnectivityService();
  bool _isConnected = false;
  late StreamSubscription<bool> _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _initializeConnectivity();
  }

  Future<void> _initializeConnectivity() async {
    // Get initial connectivity status with timeout
    try {
      await _connectivityService.refreshConnectivityStatus()
          .timeout(const Duration(seconds: 2), onTimeout: () {
        print('Initial connectivity check timed out');
      });
    } catch (e) {
      print('Error initializing connectivity: $e');
    }
    
    if (mounted) {
      setState(() {
        _isConnected = _connectivityService.isConnected;
      });
    }
    
    // Listen to connectivity changes
    _connectivitySubscription = _connectivityService.connectivityStream.listen((isConnected) {
      if (mounted) {
        setState(() {
          _isConnected = isConnected;
        });
      }
    });
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Add padding to the child content when offline indicator is showing
        Padding(
          padding: EdgeInsets.only(top: !_isConnected ? 40.0 : 0.0),
          child: widget.child,
        ),
        if (!_isConnected)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: Colors.orange.withOpacity(0.9),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.wifi_off,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Offline Mode - Reports will sync when connection is restored',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (_isConnected && widget.showOnlineIndicator)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
              color: Colors.green.withOpacity(0.9),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.wifi,
                    color: Colors.white,
                    size: 14,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Online - Real-time sync enabled',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class ConnectivityStatusChip extends StatefulWidget {
  const ConnectivityStatusChip({super.key});

  @override
  State<ConnectivityStatusChip> createState() => _ConnectivityStatusChipState();
}

class _ConnectivityStatusChipState extends State<ConnectivityStatusChip> {
  final ConnectivityService _connectivityService = ConnectivityService();
  bool _isConnected = false;
  late StreamSubscription<bool> _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _initializeConnectivity();
  }

  Future<void> _initializeConnectivity() async {
    // Get initial connectivity status with timeout
    try {
      await _connectivityService.refreshConnectivityStatus()
          .timeout(const Duration(seconds: 2), onTimeout: () {
        print('Initial connectivity check timed out for status chip');
      });
    } catch (e) {
      print('Error initializing connectivity for status chip: $e');
    }
    
    if (mounted) {
      setState(() {
        _isConnected = _connectivityService.isConnected;
      });
    }
    
    // Listen to connectivity changes
    _connectivitySubscription = _connectivityService.connectivityStream.listen((isConnected) {
      if (mounted) {
        setState(() {
          _isConnected = isConnected;
        });
      }
    });
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        // Enhanced debug tap to test connectivity with timeout protection
        print('=== Connectivity Debug Tap ===');
        print('Current _isConnected: $_isConnected');
        print('Service isConnected: ${_connectivityService.isConnected}');
        
        try {
          // Force refresh connectivity with timeout
          await _connectivityService.refreshConnectivityStatus()
              .timeout(const Duration(seconds: 3), onTimeout: () {
            print('Debug refresh timed out');
          });
          print('After refresh - Service isConnected: ${_connectivityService.isConnected}');
          
          // Test actual internet connectivity with timeout
          final internetConnected = await _connectivityService.testInternetConnectivity()
              .timeout(const Duration(seconds: 3), onTimeout: () {
            print('Debug internet test timed out');
            return false;
          });
          print('Internet connectivity test: $internetConnected');
          
          // Update state
          if (mounted) {
            setState(() {
              _isConnected = _connectivityService.isConnected;
            });
          }
          
          // Show debug dialog
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Debug: Network=${_connectivityService.isConnected}, Internet=$internetConnected'
                ),
                duration: const Duration(seconds: 3),
              ),
            );
          }
        } catch (e) {
          print('Debug tap error: $e');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Debug error: $e'),
                duration: const Duration(seconds: 3),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: _isConnected ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isConnected ? Colors.green.withOpacity(0.3) : Colors.orange.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isConnected ? Icons.wifi : Icons.wifi_off,
              size: 14,
              color: _isConnected ? Colors.green[700] : Colors.orange[700],
            ),
            const SizedBox(width: 4),
            Text(
              _isConnected ? 'Online' : 'Offline',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: _isConnected ? Colors.green[700] : Colors.orange[700],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

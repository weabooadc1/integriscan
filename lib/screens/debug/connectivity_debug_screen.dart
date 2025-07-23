import 'package:flutter/material.dart';
import 'package:integriscan/services/connectivity_service.dart';

class ConnectivityDebugScreen extends StatefulWidget {
  const ConnectivityDebugScreen({super.key});

  @override
  State<ConnectivityDebugScreen> createState() => _ConnectivityDebugScreenState();
}

class _ConnectivityDebugScreenState extends State<ConnectivityDebugScreen> {
  final ConnectivityService _connectivityService = ConnectivityService();
  bool _isConnected = false;
  String _debugInfo = '';

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
    
    // Listen to connectivity changes
    _connectivityService.connectivityStream.listen((isConnected) {
      if (mounted) {
        setState(() {
          _isConnected = isConnected;
          _debugInfo += '\nConnectivity changed: $isConnected at ${DateTime.now()}';
        });
      }
    });
  }

  Future<void> _checkConnectivity() async {
    setState(() {
      _debugInfo = 'Checking connectivity...\n';
    });

    try {
      await _connectivityService.refreshConnectivityStatus();
      setState(() {
        _isConnected = _connectivityService.isConnected;
        _debugInfo += 'Initial check: $_isConnected at ${DateTime.now()}\n';
      });
    } catch (e) {
      setState(() {
        _debugInfo += 'Error: $e\n';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connectivity Debug'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _checkConnectivity,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _isConnected ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isConnected ? Colors.green : Colors.orange,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _isConnected ? Icons.wifi : Icons.wifi_off,
                        color: _isConnected ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isConnected ? 'CONNECTED' : 'DISCONNECTED',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _isConnected ? Colors.green : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Status: ${_isConnected ? "Online" : "Offline"}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Debug Information:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _debugInfo.isEmpty ? 'No debug information yet...' : _debugInfo,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _checkConnectivity,
                child: const Text('Refresh Connectivity'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

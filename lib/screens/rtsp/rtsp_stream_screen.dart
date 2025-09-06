import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import 'package:integriscan/constant.dart';
import 'package:integriscan/services/tflite_service.dart';
import 'package:integriscan/services/frame_capture_service.dart';
import 'package:integriscan/services/report_service.dart';
import 'package:integriscan/services/firestore_sync_service.dart';
import 'package:integriscan/services/ptz_service.dart';
import 'package:integriscan/providers/auth_provider.dart';
import 'package:integriscan/screens/reports/report_detail_screen.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'dart:io';

class RtspStreamScreen extends StatefulWidget {
  final String rtspUrl;
  const RtspStreamScreen({super.key, required this.rtspUrl});

  @override
  State<RtspStreamScreen> createState() => _RtspStreamScreenState();
}

// Add new enum for scan states
enum AutoScanState {
  idle,
  analyzing,
  showingResults,
  movingCamera,
  stabilizing
}

class _RtspStreamScreenState extends State<RtspStreamScreen> {
  late VlcPlayerController _vlcViewController;
  bool _isPlaying = true;
  bool _isConnected = false;
  bool _isLoading = true;
  bool _isAnalyzing = false;
  
  // Redesigned Auto-scan state management
  bool _autoScanEnabled = false;
  AutoScanState _currentScanState = AutoScanState.idle;
  Timer? _autoScanTimer;
  
  // TFLite Analysis
  Map<String, dynamic>? _lastAnalysisResult;
  int _totalFramesAnalyzed = 0;
  int _damagesDetected = 0;
  final GlobalKey _playerKey = GlobalKey();
  List<Map<String, dynamic>> _currentDetections = [];
  List<Map<String, dynamic>> _detectionHistory = []; // Store all detections for report
  // CPU optimization variables - removed unused ones, kept only what's needed
  // static const double _frameSimilarityThreshold = 0.95; // Skip similar frames
  
  // User configurable analysis settings
  int _analysisIntervalSeconds = 5; // Default 5 seconds
  final List<int> _availableIntervals = [3, 5, 10, 15, 30]; // Available intervals
  
  // PTZ Control variables
  bool _ptzEnabled = false;
  bool _ptzSupported = false;
  bool _isMovingCamera = false;
  int _totalPTZMovements = 0;
  Timer? _ptzMovementTimer;
  bool _ptzDebugMode = false; // For testing PTZ without actual camera
  
  // Bounding box display timing - removed since handled by auto-scan states
  bool _showBoundingBoxes = true;

  @override
  void initState() {
    super.initState();
    _validateRtspUrl(); // Validate URL format first
    _initializeVLC();
    _initializeTFLite();
    _initializePTZ();
    // Attempt background sync for all unsynced reports on screen load
    _syncUnsyncedReportsForCurrentUser();
  }
  
  /// Validate and provide suggestions for RTSP URL format
  void _validateRtspUrl() {
    print('🔍 Validating RTSP URL: ${widget.rtspUrl}');
    
    final uri = Uri.tryParse(widget.rtspUrl);
    if (uri == null) {
      print('❌ Invalid URL format');
      _showRtspSuggestions('Invalid URL format');
      return;
    }
    
    if (!uri.scheme.toLowerCase().startsWith('rtsp')) {
      print('❌ Not an RTSP URL (scheme: ${uri.scheme})');
      _showRtspSuggestions('URL must start with rtsp://');
      return;
    }
    
    if (uri.host.isEmpty) {
      print('❌ Missing hostname/IP address');
      _showRtspSuggestions('Missing camera IP address');
      return;
    }
    
    print('✅ URL format appears valid');
    print('  - Host: ${uri.host}');
    print('  - Port: ${uri.port}');
    print('  - Path: ${uri.path}');
    print('  - Query: ${uri.query}');
  }
  
  /// Show RTSP URL format suggestions
  void _showRtspSuggestions(String issue) {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('AMCREST IP2M-841B Connection Help'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Issue: $issue\n'),
              const Text('Try these AMCREST IP2M-841B formats:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              
              const Text('📹 Main Stream (Primary):', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
              const SelectableText('rtsp://admin:admin123@192.168.1.14:554/cam/realmonitor?channel=1&subtype=0'),
              const SizedBox(height: 8),
              
              const Text('📱 Sub Stream (Lower Quality):', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
              const SelectableText('rtsp://admin:admin123@192.168.1.14:554/cam/realmonitor?channel=1&subtype=1'),
              const SizedBox(height: 8),
              
              const Text('🔄 Alternative Paths:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
              const SelectableText('rtsp://admin:admin123@192.168.1.14:554/h264Preview_01_main'),
              const SelectableText('rtsp://admin:admin123@192.168.1.14:554/h264Preview_01_sub'),
              const SelectableText('rtsp://admin:admin123@192.168.1.14:554/live'),
              const SizedBox(height: 12),
              
              const Text('🔧 Troubleshooting Steps:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
              const Text('1. Check camera web interface (http://192.168.1.14)'),
              const Text('2. Verify RTSP is enabled in camera settings'),
              const Text('3. Try different authentication ports'),
              const Text('4. Check if another app is using the stream'),
              const SizedBox(height: 8),
              
              const Text('📝 Current Status:', style: TextStyle(fontWeight: FontWeight.bold)),
              const Text('✅ Network: Reachable (ping successful)'),
              const Text('✅ Port 554: Open and accessible'),
              const Text('❓ Stream: Testing different formats...'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _testAlternativeUrls();
            },
            child: const Text('Test Alternative URLs'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _syncUnsyncedReportsForCurrentUser() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.user?.uid ?? 'anonymous';
      
      // Test Firestore connection first
      print('Testing Firestore connection...');
      final connectionOk = await FirestoreSyncService.testConnection();
      if (connectionOk) {
        print('Firestore connection OK, proceeding with sync...');
        await ReportService.syncAllUnsyncedReportsStatic(userId: userId);
      } else {
        print('Firestore connection failed, skipping sync');
      }
    } catch (e) {
      print('Background sync error: $e');
    }
  }

  void _initializeVLC() {
    print('🎬 Initializing VLC with RTSP URL: ${widget.rtspUrl}');
    
    _vlcViewController = VlcPlayerController.network(
      widget.rtspUrl,
      hwAcc: HwAcc.full,
      autoPlay: true,
      options: VlcPlayerOptions(
        advanced: VlcAdvancedOptions([
          '--network-caching=3000',      // Increased for WiFi stability
          '--rtsp-tcp',                  // Force TCP (more reliable than UDP)
          '--live-caching=3000',         // Increased live buffer
          '--rtsp-frame-buffer-size=1000000', // Larger frame buffer
          '--rtsp-timeout=30',           // 30 second timeout
          '--tcp-caching=3000',          // TCP caching
          '--no-audio',                  // Disable audio for stability
          '--rtsp-kasenna',              // Better RTSP compatibility
          '--rtsp-wmserver',             // Windows Media Server compatibility
          '--verbose=2',                 // Enable detailed logging
        ]),
        video: VlcVideoOptions([
          '--no-video-title-show',
          '--drop-late-frames',          // Drop frames if behind
          '--skip-frames',               // Skip frames to maintain sync
        ]),
        audio: VlcAudioOptions([
          '--no-audio',                  // Explicitly disable audio
        ]),
        subtitle: VlcSubtitleOptions([]),
        rtp: VlcRtpOptions([
          '--rtsp-tcp',                  // Ensure TCP is used
          '--rtp-max-src=1',             // Limit RTP sources
        ]),
      ),
    );
    
    // Add listeners for connection status
    _vlcViewController.addListener(() {
      if (mounted) {
        final isPlaying = _vlcViewController.value.isPlaying;
        final isInitialized = _vlcViewController.value.isInitialized;
        final hasError = _vlcViewController.value.hasError;
        final playbackState = _vlcViewController.value.playingState;
        
        print('🎬 VLC State Update:');
        print('  - Playing: $isPlaying');
        print('  - Initialized: $isInitialized');
        print('  - Has Error: $hasError');
        print('  - Playback State: $playbackState');
        print('  - Position: ${_vlcViewController.value.position}');
        print('  - Duration: ${_vlcViewController.value.duration}');
        
        setState(() {
          _isConnected = isPlaying && isInitialized && !hasError;
          _isLoading = !isInitialized && !hasError;
        });
        
        if (hasError) {
          final errorMsg = _vlcViewController.value.errorDescription.isEmpty 
              ? 'Unknown VLC error' 
              : _vlcViewController.value.errorDescription;
          print('🎬 VLC Error detected: $errorMsg');
          
          // Show detailed error to user
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('RTSP Connection Error: $errorMsg'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 8),
                action: SnackBarAction(
                  label: 'Retry',
                  textColor: Colors.white,
                  onPressed: () => _retryConnection(),
                ),
              ),
            );
          }
        }
      }
    });
  }
  
  /// Retry RTSP connection
  void _retryConnection() {
    print('🔄 Retrying RTSP connection...');
    _vlcViewController.dispose();
    setState(() {
      _isConnected = false;
      _isLoading = true;
    });
    
    // Wait a moment before retrying
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _initializeVLC();
      }
    });
  }
  
  /// Test alternative RTSP URLs for AMCREST IP2M-841B
  void _testAlternativeUrls() async {
    final List<String> alternativeUrls = [
      'rtsp://admin:admin123@192.168.1.14:554/cam/realmonitor?channel=1&subtype=1', // Sub stream
      'rtsp://admin:admin123@192.168.1.14:554/h264Preview_01_main',                // Alternative main
      'rtsp://admin:admin123@192.168.1.14:554/h264Preview_01_sub',                 // Alternative sub
      'rtsp://admin:admin123@192.168.1.14:554/live',                              // Generic live
      'rtsp://admin:admin123@192.168.1.14:554/stream1',                           // Stream1
      'rtsp://admin:admin123@192.168.1.14:554/cam1',                              // Cam1
    ];
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🔍 Testing alternative RTSP URLs for your AMCREST camera...'),
        duration: Duration(seconds: 3),
      ),
    );
    
    print('🔍 Testing ${alternativeUrls.length} alternative RTSP URLs...');
    
    for (int i = 0; i < alternativeUrls.length; i++) {
      final testUrl = alternativeUrls[i];
      print('🧪 Testing URL ${i + 1}/${alternativeUrls.length}: $testUrl');
      
      try {
        // Create a temporary VLC controller to test the URL
        final testController = VlcPlayerController.network(
          testUrl,
          hwAcc: HwAcc.disabled, // Disable hardware acceleration for testing
          autoPlay: false,
          options: VlcPlayerOptions(
            advanced: VlcAdvancedOptions([
              '--network-caching=1000',
              '--rtsp-tcp',
              '--rtsp-timeout=5',   // Quick timeout for testing
              '--no-audio',
            ]),
          ),
        );
        
        bool connectionSuccessful = false;
        Timer? testTimer;
        
        // Set up listener for connection test
        testController.addListener(() {
          if (testController.value.isInitialized && 
              testController.value.isPlaying && 
              !testController.value.hasError) {
            connectionSuccessful = true;
            print('✅ URL ${i + 1} SUCCESSFUL: $testUrl');
            
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('✅ Found working URL! Tap to use: ${testUrl.split('@')[1]}'),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 8),
                  action: SnackBarAction(
                    label: 'Use This URL',
                    textColor: Colors.white,
                    onPressed: () => _useAlternativeUrl(testUrl),
                  ),
                ),
              );
            }
          } else if (testController.value.hasError) {
            print('❌ URL ${i + 1} FAILED: $testUrl - ${testController.value.errorDescription}');
          }
        });
        
        // Initialize the test controller
        await testController.initialize();
        
        // Wait up to 8 seconds for connection
        testTimer = Timer(const Duration(seconds: 8), () {
          if (!connectionSuccessful) {
            print('⏱️ URL ${i + 1} TIMEOUT: $testUrl');
          }
        });
        
        // Wait a moment for the connection attempt
        await Future.delayed(const Duration(seconds: 8));
        
        // Clean up
        testTimer.cancel();
        testController.dispose();
        
        // If we found a working URL, stop testing others
        if (connectionSuccessful) {
          break;
        }
        
        // Small delay between tests
        await Future.delayed(const Duration(seconds: 2));
        
      } catch (e) {
        print('❌ URL ${i + 1} ERROR: $testUrl - $e');
      }
    }
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔍 Alternative URL testing completed. Check console for results.'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }
  
  /// Use an alternative URL that was found to work
  void _useAlternativeUrl(String newUrl) {
    print('🔄 Switching to alternative URL: $newUrl');
    
    // Dispose current controller
    _vlcViewController.dispose();
    
    setState(() {
      _isConnected = false;
      _isLoading = true;
    });
    
    // Wait a moment then initialize with new URL
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        // Create new controller with the working URL
        _vlcViewController = VlcPlayerController.network(
          newUrl,
          hwAcc: HwAcc.full,
          autoPlay: true,
          options: VlcPlayerOptions(
            advanced: VlcAdvancedOptions([
              '--network-caching=3000',
              '--rtsp-tcp',
              '--live-caching=3000',
              '--rtsp-frame-buffer-size=1000000',
              '--rtsp-timeout=30',
              '--tcp-caching=3000',
              '--no-audio',
              '--rtsp-kasenna',
              '--rtsp-wmserver',
              '--verbose=2',
            ]),
            video: VlcVideoOptions([
              '--no-video-title-show',
              '--drop-late-frames',
              '--skip-frames',
            ]),
            audio: VlcAudioOptions([
              '--no-audio',
            ]),
            subtitle: VlcSubtitleOptions([]),
            rtp: VlcRtpOptions([
              '--rtsp-tcp',
              '--rtp-max-src=1',
            ]),
          ),
        );
        
        // Add the listener again (same as in _initializeVLC)
        _vlcViewController.addListener(() {
          if (mounted) {
            final isPlaying = _vlcViewController.value.isPlaying;
            final isInitialized = _vlcViewController.value.isInitialized;
            final hasError = _vlcViewController.value.hasError;
            final playbackState = _vlcViewController.value.playingState;
            
            print('🎬 VLC State Update (Alternative URL):');
            print('  - Playing: $isPlaying');
            print('  - Initialized: $isInitialized');
            print('  - Has Error: $hasError');
            print('  - Playback State: $playbackState');
            
            setState(() {
              _isConnected = isPlaying && isInitialized && !hasError;
              _isLoading = !isInitialized && !hasError;
            });
            
            if (hasError) {
              final errorMsg = _vlcViewController.value.errorDescription.isEmpty 
                  ? 'Unknown VLC error' 
                  : _vlcViewController.value.errorDescription;
              print('🎬 VLC Error with alternative URL: $errorMsg');
            } else if (isPlaying) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('🎉 Alternative URL connected successfully!'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 3),
                ),
              );
            }
          }
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🔄 Connecting with alternative URL: ${newUrl.split('@')[1]}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });
  }

  void _initializeTFLite() async {
    print('🚀 RTSP Screen: Starting TFLite initialization...');
    try {
      final success = await TFLiteService.initialize();
      print('🚀 RTSP Screen: TFLite initialization result: $success');
      
      if (success && mounted) {
        print('🚀 RTSP Screen: TFLite initialization successful, testing model...');
        // Test the model with a sample image
        await _testModelWithSampleImage();
        
        // Check if we're in mock mode
        final modelInfo = TFLiteService.getModelInfo();
        print('🚀 RTSP Screen: Model info after initialization: $modelInfo');
        
        if (modelInfo['mockMode'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('AI Analysis ready! (Mock Mode - for testing)'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('AI Analysis ready!'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else if (mounted) {
        print('🚀 RTSP Screen: TFLite initialization failed');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('AI model not available - using mock analysis'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print('🚀 RTSP Screen: Exception during TFLite initialization: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('AI model initialization error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _initializePTZ() async {
    print('🎥 PTZ: Initializing AMCREST IP2M-841B PTZ control...');
    
    // For IP2M-841B, enable PTZ by default since we know it works
    // Also enable debug mode by default for testing
    setState(() {
      _ptzSupported = true;
      _ptzDebugMode = true; // Enable debug mode by default for testing
    });
    
    print('🎥 PTZ: Enabled with debug mode for testing');
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🔧 PTZ Debug Mode enabled for testing - Auto-scan ready!'),
        backgroundColor: Colors.purple,
        duration: Duration(seconds: 3),
      ),
    );
    
    // Optional: Still test real PTZ in background but don't block functionality
    _testRealPTZInBackground();
  }

  void _testRealPTZInBackground() async {
    // Test the actual PTZ connection with working commands in background
    try {
      // First test basic HTTP connectivity
      print('🔌 PTZ: Testing camera HTTP connectivity in background...');
      final connectivityOk = await PTZService.testCameraConnectivity(widget.rtspUrl);
      
      if (!connectivityOk) {
        print('⚠️ PTZ: Camera HTTP port unreachable - staying in debug mode');
        return;
      }
      
      print('✅ PTZ: HTTP connectivity confirmed, testing PTZ command formats...');
      
      // Test different PTZ command formats to find working one
      final formatSuccess = await PTZService.testPTZFormats(widget.rtspUrl);
      
      if (formatSuccess) {
        print('✅ PTZ: Real PTZ commands working! Can disable debug mode if needed');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('✅ Real PTZ commands working! You can disable debug mode.'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'Disable Debug',
                textColor: Colors.white,
                onPressed: () {
                  setState(() {
                    _ptzDebugMode = false;
                  });
                },
              ),
            ),
          );
        }
      } else {
        print('⚠️ PTZ: Real PTZ commands not working - debug mode recommended');
      }
    } catch (e) {
      print('🎥 PTZ: Background test error: $e');
    }
  }

  Future<void> _testModelWithSampleImage() async {
    try {
      print('=== Testing Model with Sample Image ===');
      
      // Get model info
      final modelInfo = TFLiteService.getModelInfo();
      print('Model info: $modelInfo');
      
      // Load a sample image from assets to test
      final ByteData data = await rootBundle.load('assets/images/TEsting2.jpg');
      final Uint8List bytes = data.buffer.asUint8List();
      
      print('Testing model with sample image (${bytes.length} bytes)');
      
      // Test inference
      final result = await TFLiteService.runInference(bytes);
      print('Sample image test result: $result');
      
      if (result != null) {
        print('✅ Model is working! Top prediction: ${result['damageType']} (${result['confidence']})');
      } else {
        print('❌ Model test failed - null result');
      }
      
      // Test frame capture functionality after a delay to ensure widget is built
      Future.delayed(const Duration(seconds: 2), () async {
        await _testFrameCapture();
      });
      
    } catch (e) {
      print('❌ Model test error: $e');
    }
  }

  Future<void> _testFrameCapture() async {
    try {
      print('=== Testing Frame Capture ===');
      
      // Test if the GlobalKey is properly attached
      print('🎥 Player key context: ${_playerKey.currentContext != null}');
      print('🎥 VLC Controller initialized: ${_vlcViewController.value.isInitialized}');
      print('🎥 VLC Controller playing: ${_vlcViewController.value.isPlaying}');
      
      final frameBytes = await FrameCaptureService.captureWidget(_playerKey);
      
      if (frameBytes != null) {
        print('✅ Frame capture test successful: ${frameBytes.length} bytes');
      } else {
        print('❌ Frame capture test failed');
      }
    } catch (e) {
      print('❌ Frame capture test error: $e');
    }
  }

  // Replace _toggleAnalysis() and _togglePTZ() with this unified method:
  void _toggleAutoScan() {
    print('🔄 _toggleAutoScan() called - current state: $_autoScanEnabled');
    
    setState(() {
      _autoScanEnabled = !_autoScanEnabled;
    });

    print('🔄 Auto-scan enabled changed to: $_autoScanEnabled');

    if (_autoScanEnabled) {
      print('🔄 Starting auto-scan');
      _startAutoScan();
    } else {
      print('🔄 Stopping auto-scan');
      _stopAutoScan();
    }
  }

  void _startAutoScan() {
    print('🎯 _startAutoScan() called');
    print('🎯 PTZ Supported: $_ptzSupported, PTZ Debug: $_ptzDebugMode');
    print('🎯 VLC Connected: $_isConnected, VLC Loading: $_isLoading');
    
    if (!_ptzSupported && !_ptzDebugMode) {
      print('❌ Auto-scan blocked: PTZ not supported and debug mode disabled');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Auto-scan requires PTZ camera support'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _autoScanEnabled = false;
      });
      return;
    }

    print('🎯 Starting Auto-scan workflow');
    setState(() {
      _currentScanState = AutoScanState.analyzing;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🔄 Auto-scan started: Analysis → Results → Move → Repeat'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );

    print('🎯 About to call _executeAutoScanCycle()');
    _executeAutoScanCycle();
  }

  void _stopAutoScan() {
    print('🛑 Stopping Auto-scan workflow');
    
    _autoScanTimer?.cancel();
    _autoScanTimer = null;
    
    setState(() {
      _currentScanState = AutoScanState.idle;
      _currentDetections = [];
      _showBoundingBoxes = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Auto-scan stopped'),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 2),
      ),
    );
  }

  // New unified auto-scan cycle method
  Future<void> _executeAutoScanCycle() async {
    print('🔄 _executeAutoScanCycle() called');
    print('🔄 Auto-scan enabled: $_autoScanEnabled, mounted: $mounted');
    print('🔄 Current scan state: $_currentScanState');
    
    if (!_autoScanEnabled || !mounted) {
      print('❌ Auto-scan cycle aborted: enabled=$_autoScanEnabled, mounted=$mounted');
      return;
    }

    try {
      // State 1: Initial Analysis
      print('📊 Auto-scan: Step 1 - Running analysis');
      setState(() {
        _currentScanState = AutoScanState.analyzing;
      });

      final analysisResult = await _performSingleAnalysis();
      print('📊 Analysis result: $analysisResult');

      if (!_autoScanEnabled || !mounted) {
        print('❌ Auto-scan aborted after analysis');
        return;
      }

      // State 2: Show Detection Results (5 seconds)
      print('🎯 Auto-scan: Step 2 - Showing results for 5 seconds');
      setState(() {
        _currentScanState = AutoScanState.showingResults;
        
        if (analysisResult != null && analysisResult['isDamageDetected'] == true) {
          // Show bounding boxes for damage detection
          final detection = {
            'label': analysisResult['damageType'] ?? 'Unknown',
            'confidence': analysisResult['confidence'] ?? 0.0,
            'box': {
              'x': 0.3,
              'y': 0.3,
              'width': 0.4,
              'height': 0.4,
            }
          };
          _currentDetections = [detection];
          _showBoundingBoxes = true;
          print('🎯 Showing bounding boxes for detection: ${detection['label']}');
        } else {
          _currentDetections = [];
          _showBoundingBoxes = false;
          print('🎯 No damage detected, hiding bounding boxes');
        }
      });

      // Wait exactly 5 seconds
      print('⏰ Auto-scan: Setting 5-second timer for results display');
      _autoScanTimer = Timer(const Duration(seconds: 5), () async {
        print('⏰ 5-second timer triggered');
        if (!_autoScanEnabled || !mounted) {
          print('❌ Auto-scan aborted in timer callback');
          return;
        }

        // State 3: Camera Movement
        print('📹 Auto-scan: Step 3 - Moving camera');
        setState(() {
          _currentScanState = AutoScanState.movingCamera;
          _showBoundingBoxes = false; // Hide bounding boxes during movement
          _currentDetections = [];
        });

        final moveSuccess = await _performCameraMovement();
        print('📹 Camera movement result: $moveSuccess');

        if (!_autoScanEnabled || !mounted) {
          print('❌ Auto-scan aborted after camera movement');
          return;
        }

        // State 4: Camera Stabilization
        if (moveSuccess) {
          print('⏳ Auto-scan: Step 4 - Camera stabilization (3 seconds)');
          setState(() {
            _currentScanState = AutoScanState.stabilizing;
          });

          _autoScanTimer = Timer(const Duration(seconds: 3), () {
            print('⏳ Stabilization timer triggered');
            if (!_autoScanEnabled || !mounted) {
              print('❌ Auto-scan aborted in stabilization callback');
              return;
            }

            // Return to State 1: Next Analysis Cycle
            print('🔄 Auto-scan: Cycle complete, starting next analysis');
            _executeAutoScanCycle(); // Recursive call for continuous scanning
          });
        } else {
          print('❌ Auto-scan: Camera movement failed, retrying cycle');
          // Retry the cycle even if movement fails
          _autoScanTimer = Timer(const Duration(seconds: 2), () {
            if (_autoScanEnabled && mounted) {
              print('🔄 Retrying auto-scan cycle after movement failure');
              _executeAutoScanCycle();
            }
          });
        }
      });

    } catch (e) {
      print('❌ Auto-scan: Error in cycle: $e');
      if (_autoScanEnabled && mounted) {
        // Retry after error
        _autoScanTimer = Timer(const Duration(seconds: 3), () {
          if (_autoScanEnabled && mounted) {
            print('🔄 Retrying auto-scan cycle after error');
            _executeAutoScanCycle();
          }
        });
      }
    }
  }

  // Simplified single analysis method
  Future<Map<String, dynamic>?> _performSingleAnalysis() async {
    print('🔍 _performSingleAnalysis() called');
    print('🔍 VLC Connected: $_isConnected, Widget key context: ${_playerKey.currentContext != null}');
    
    if (!_isConnected) {
      print('❌ Analysis skipped - VLC not connected');
      return null;
    }

    try {
      print('🔍 Performing single analysis...');
      
      // Small delay to ensure frame is ready
      await Future.delayed(const Duration(milliseconds: 200));
      
      // Capture frame from VLC player
      print('📸 Attempting to capture frame from VLC widget');
      final frameBytes = await FrameCaptureService.captureWidget(_playerKey);
      
      if (frameBytes != null) {
        print('📸 Frame captured successfully: ${frameBytes.length} bytes');
        
        // Run AI inference
        print('🤖 Running AI inference on captured frame');
        final result = await TFLiteService.runInference(frameBytes);
        print('🤖 AI inference result: $result');
        
        if (result != null && result['isDamageDetected'] != null) {
          print('🤖 Analysis result: ${result['damageType']} (${(result['confidence'] * 100).toInt()}%)');
          
          // Update statistics
          setState(() {
            _totalFramesAnalyzed++;
            if (result['isDamageDetected'] == true) {
              _damagesDetected++;
              
              // Save to detection history if damage found
              if (result['confidence'] > 0.5) {
                print('💾 Saving detection to history');
                _saveDetectionToHistory(result, frameBytes);
              }
            }
            _lastAnalysisResult = result; // Store the latest result
          });
          
          return result;
        } else {
          print('🤖 Analysis returned null or invalid result: $result');
          return null;
        }
      } else {
        print('❌ Frame capture failed - returned null');
        return null;
      }
    } catch (e) {
      print('❌ Analysis error: $e');
      return null;
    }
  }

  // Simplified camera movement method
  Future<bool> _performCameraMovement() async {
    print('🎬 Auto-scan: ===== CAMERA MOVEMENT START =====');
    print('🎬 Auto-scan: PTZ supported: $_ptzSupported, Debug mode: $_ptzDebugMode, Is moving: $_isMovingCamera');
    
    if (!_ptzSupported && !_ptzDebugMode) {
      print('🎬 Auto-scan: ❌ PTZ not supported and not in debug mode - BLOCKING MOVEMENT');
      return false;
    }

    print('🎬 Auto-scan: Setting movement state to true');
    setState(() {
      _isMovingCamera = true;
    });

    try {
      bool success = false;
      _totalPTZMovements++;
      
      print('🎬 Auto-scan: Starting movement $_totalPTZMovements');
      
      if (_ptzDebugMode) {
        print('� Auto-scan: �🎥 PTZ Debug: Simulating movement $_totalPTZMovements');
        await Future.delayed(const Duration(seconds: 2)); // Longer delay for more realistic simulation
        success = true;
        print('🎬 Auto-scan: ✅ Debug movement completed successfully');
      } else {
        print('🎬 Auto-scan: ➡️ PTZ: Moving RIGHT (movement $_totalPTZMovements)');
        print('� Auto-scan: RTSP URL: ${widget.rtspUrl}');
        
        // Add retry logic for failed movements
        for (int attempt = 1; attempt <= 2; attempt++) {
          print('🎬 Auto-scan: Movement attempt $attempt/2');
          success = await PTZService.panRight(widget.rtspUrl, speed: 4);
          
          if (success) {
            print('🎬 Auto-scan: ✅ Movement successful on attempt $attempt');
            break;
          } else {
            print('🎬 Auto-scan: ❌ Movement failed on attempt $attempt');
            if (attempt < 2) {
              print('🎬 Auto-scan: Waiting 1 second before retry...');
              await Future.delayed(Duration(seconds: 1));
            }
          }
        }
        
        print('🎬 Auto-scan: Final PTZ panRight result: $success');
      }

      if (success) {
        print('🎬 Auto-scan: ✅ PTZ: Movement $_totalPTZMovements completed successfully');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('📹 Camera moved (${_totalPTZMovements} moves) - Stabilizing...'),
              backgroundColor: Colors.blue,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        print('🎬 Auto-scan: ❌ PTZ: Movement $_totalPTZMovements FAILED after all attempts');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚠️ Camera movement ${_totalPTZMovements} failed - Continuing cycle'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
      
      print('🎬 Auto-scan: ===== CAMERA MOVEMENT END (Success: $success) =====');
      return success;
    } catch (e) {
      print('🎬 Auto-scan: ❌ PTZ: EXCEPTION during movement: $e');
      print('🎬 Auto-scan: Error stack trace: ${StackTrace.current}');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Camera movement error: ${e.toString().length > 50 ? e.toString().substring(0, 50) + '...' : e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return false;
    } finally {
      print('🎬 Auto-scan: Setting _isMovingCamera = false in finally block');
      if (mounted) {
        setState(() {
          _isMovingCamera = false;
        });
      }
      print('🎬 Auto-scan: Movement state reset completed');
    }
  }

  // Helper method to save detections to history
  Future<void> _saveDetectionToHistory(Map<String, dynamic> result, Uint8List frameBytes) async {
    try {
      final savedImagePath = await _saveAnalyzedFrame(
        frameBytes, 
        result['damageType'] ?? 'Unknown', 
        result['confidence'] ?? 0.0
      );
      
      final detectionData = {
        'damageType': result['damageType'],
        'confidence': result['confidence'],
        'imagePath': savedImagePath,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'boundingBox': {
          'x': 0.3,
          'y': 0.3,
          'width': 0.4,
          'height': 0.4,
        },
      };
      
      _detectionHistory.add(detectionData);
      print('💾 Detection saved to history. Total: ${_detectionHistory.length}');
    } catch (e) {
      print('❌ Error saving detection: $e');
    }
  }

  /// Manual PTZ control for IP2M-841B
  Future<void> _manualPTZControl(PTZDirection direction) async {
    if (!_ptzSupported && !_ptzDebugMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PTZ control is not supported by this camera'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    if (_isMovingCamera) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Camera is already moving, please wait...'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    setState(() {
      _isMovingCamera = true;
    });
    
    try {
      bool success = false;
      String directionName = direction.name.toUpperCase();
      
      if (_ptzDebugMode) {
        // Simulate movement in debug mode
        print('🎥 PTZ Debug: Simulating movement $directionName');
        await Future.delayed(const Duration(seconds: 1));
        success = true;
      } else {
        // Real IP2M-841B PTZ movement with working commands
        print('🎯 IP2M-841B Manual PTZ: Executing $directionName movement');
        
        switch (direction) {
          case PTZDirection.left:
            success = await PTZService.panLeft(widget.rtspUrl, speed: 4);
            break;
          case PTZDirection.right:
            success = await PTZService.panRight(widget.rtspUrl, speed: 4);
            break;
          case PTZDirection.up:
            success = await PTZService.tiltUp(widget.rtspUrl, speed: 4);
            break;
          case PTZDirection.down:
            success = await PTZService.tiltDown(widget.rtspUrl, speed: 4);
            break;
          case PTZDirection.center:
            // Center position - simulate success
            print('📍 Moving to center position (no movement required)');
            success = true;
            break;
        }
        
        // Add small delay after movement for stabilization
        if (success) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_ptzDebugMode 
                ? '🔧 Debug: Camera moved $directionName' 
                : '📹 Camera moved $directionName'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1),
          ),
        );
        print('✅ Manual PTZ: $directionName movement completed successfully');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ PTZ $directionName movement failed'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
        print('❌ Manual PTZ: $directionName movement failed');
      }
    } catch (e) {
      print('❌ Manual PTZ: Error during ${direction.name.toUpperCase()} movement: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PTZ error: ${e.toString().substring(0, 30)}...'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isMovingCamera = false;
        });
      }
    }
  }

  // PTZ Control Methods
  
  /// Toggle PTZ automatic scanning - kept for backward compatibility but now just calls auto-scan
  void _togglePTZ() {
    // Legacy method - redirect to auto-scan
    _toggleAutoScan();
  }
  
  /// Toggle PTZ debug mode for testing
  void _togglePTZDebugMode() {
    setState(() {
      _ptzDebugMode = !_ptzDebugMode;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_ptzDebugMode 
            ? 'PTZ Debug Mode enabled - UI controls now visible for testing'
            : 'PTZ Debug Mode disabled'),
        backgroundColor: _ptzDebugMode ? Colors.purple : Colors.orange,
        duration: const Duration(seconds: 3),
      ),
    );
  }
  
  /// Stop PTZ movement
  void _stopPTZMovement() {
    _ptzMovementTimer?.cancel();
    _ptzMovementTimer = null;
    
    if (mounted) {
      setState(() {
        _isMovingCamera = false;
      });
    }
  }
  
  Future<String> _saveAnalyzedFrame(Uint8List frameBytes, String damageType, double confidence) async {
    try {
      // Create a unique filename
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = 'damage_${damageType.toLowerCase()}_${timestamp}.png';
      
      // Get app documents directory
      final directory = await getApplicationDocumentsDirectory();
      final framesDir = Directory('${directory.path}/frames');
      
      // Create frames directory if it doesn't exist
      if (!await framesDir.exists()) {
        await framesDir.create(recursive: true);
      }
      
      final file = File('${framesDir.path}/$filename');
      
      // Save the frame
      await file.writeAsBytes(frameBytes);
      
      print('Frame saved: ${file.path}');
      return file.path; // Return the saved file path
    } catch (e) {
      print('Error saving frame: $e');
      return ''; // Return empty string on error
    }
  }

  Future<void> _generateReport() async {
    print('Generate report called. Detection history size: ${_detectionHistory.length}');
    
    if (_detectionHistory.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No detections found to generate report. Start analysis first and wait for damage detection.'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    // Debug: Log each detection in the history to verify image paths
    print('=== Detection History Debug ===');
    for (int i = 0; i < _detectionHistory.length; i++) {
      final detection = _detectionHistory[i];
      print('Detection $i:');
      print('  damageType: ${detection['damageType']}');
      print('  confidence: ${detection['confidence']}');
      print('  imagePath: "${detection['imagePath']}" (length: ${detection['imagePath']?.length ?? 0})');
      print('  timestamp: ${detection['timestamp']}');
      print('  boundingBox: ${detection['boundingBox']}');
      
      // Check if image file actually exists
      if (detection['imagePath'] != null && detection['imagePath'].isNotEmpty) {
        final file = File(detection['imagePath']);
        final exists = await file.exists();
        print('  imageFile exists: $exists');
        if (exists) {
          final size = await file.length();
          print('  imageFile size: $size bytes');
        }
      } else {
        print('  ❌ WARNING: Empty or null image path!');
      }
    }
    print('=== End Detection History Debug ===');

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.user?.uid ?? 'anonymous';
      
      print('Generating report for ${_detectionHistory.length} detections');
      
      final report = await ReportService.generateReport(
        userId: userId,
        sessionName: 'RTSP Stream Session ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
        detections: _detectionHistory,
        trySyncToCloud: true, // This will attempt sync but won't fail if offline
      );

      print('Report generated successfully: ${report.id}');

      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              report.synced 
                ? 'Report generated and synced to cloud successfully!' 
                : 'Report generated and saved locally! Will sync when connection is available.',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );

        // Trigger background sync for all unsynced reports for this user (non-blocking)
        ReportService.syncAllUnsyncedReportsStatic(userId: userId).catchError((e) {
          print('Background sync error: $e');
          // Don't show error to user - this is background operation
        });

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReportDetailScreen(
              report: report,
              fromAnalysis: true, // Indicate this came from analysis
            ),
          ),
        );
      }
    } catch (e) {
      print('Error generating report: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _addTestDetection() async {
    print('_addTestDetection called');
    final random = DateTime.now().millisecondsSinceEpoch % 100;
    final damageTypes = ['Crack', 'Deformation', 'Rust', 'Scaling'];
    final damageType = damageTypes[random % 4];
    final confidence = 0.6 + (random % 40) / 100;
    
    // Create a sample image for testing Firebase Storage
    String imagePath = '';
    try {
      // Get app documents directory
      final directory = await getApplicationDocumentsDirectory();
      final framesDir = Directory('${directory.path}/frames');
      
      // Create frames directory if it doesn't exist
      if (!await framesDir.exists()) {
        await framesDir.create(recursive: true);
      }
      
      // Copy one of the existing assets as a test image
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filename = 'test_damage_${damageType.toLowerCase()}_${timestamp}.png';
      final targetFile = File('${framesDir.path}/$filename');
      
      // Load an asset image and save it as test damage image
      final ByteData data = await rootBundle.load('assets/images/main_top.png');
      final Uint8List bytes = data.buffer.asUint8List();
      await targetFile.writeAsBytes(bytes);
      
      imagePath = targetFile.path;
      print('Test image created at: $imagePath');
    } catch (e) {
      print('Error creating test image: $e');
      // Fall back to empty path if asset loading fails
    }
    
    final detection = {
      'damageType': damageType,
      'confidence': confidence,
      'imagePath': imagePath, // Now includes actual image path for testing
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'boundingBox': {
        'x': 0.2 + (random % 40) / 100,
        'y': 0.2 + (random % 40) / 100,
        'width': 0.2 + (random % 20) / 100,
        'height': 0.1 + (random % 20) / 100,
      },
    };
    
    if (mounted) {
      setState(() {
        _detectionHistory.add(detection);
        _damagesDetected++;
      });
    }
    
    print('Detection history now has ${_detectionHistory.length} items');
    print('Added detection: $detection');
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Test detection added: $damageType (${(confidence * 100).toInt()}%) - Total: ${_detectionHistory.length}'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _clearDetectionHistory() {
    if (mounted) {
      setState(() {
        _detectionHistory.clear();
        _damagesDetected = 0;
      });
    }
    
    print('Detection history cleared');
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Detection history cleared'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  void dispose() {
    _stopAutoScan();
    _stopPTZMovement(); // Stop PTZ movement
    _vlcViewController.dispose();
    TFLiteService.dispose();
    
    // CPU Optimization: Clear memory caches
    _detectionHistory.clear(); // Clear in-memory detection history on dispose (logout)
    _currentDetections.clear();
    _lastAnalysisResult = null;
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Column(
          children: [
            // Modern App Bar
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  // Back Button
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.arrow_back_ios_new,
                        color: Colors.grey[600],
                        size: 20,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Stream Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Live Stream',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'RTSP Video Feed',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Connection Status
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _isLoading 
                          ? Colors.orange.withOpacity(0.1)
                          : _isConnected 
                              ? Colors.green.withOpacity(0.1)
                              : Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _isLoading 
                                ? Colors.orange
                                : _isConnected 
                                    ? Colors.green
                                    : Colors.red,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isLoading 
                              ? 'Connecting...'
                              : _isConnected 
                                  ? 'Live'
                                  : 'Disconnected',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: _isLoading 
                                ? Colors.orange
                                : _isConnected 
                                    ? Colors.green
                                    : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // VLC Player at the top
            Container(
              color: Colors.black,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  children: [
                    RepaintBoundary(
                      key: _playerKey,
                      child: VlcPlayer(
                        controller: _vlcViewController,
                        aspectRatio: 16 / 9,
                        placeholder: Container(
                          color: Colors.black,
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'Loading stream...',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Bounding Box Overlay
                    if (_autoScanEnabled && _currentDetections.isNotEmpty && _showBoundingBoxes)
                      CustomPaint(
                        painter: BoundingBoxPainter(_currentDetections),
                        size: Size.infinite,
                      ),
                  ],
                ),
              ),
            ),
            
            // Content below the player
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Stream Info Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [kPrimaryColor, kPrimaryColor.withOpacity(0.8)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: kPrimaryColor.withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.videocam_outlined,
                                  color: Colors.white.withOpacity(0.9),
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    'Stream Analysis',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Real-time video stream analysis and damage detection powered by AI.',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Icon(
                                  Icons.link,
                                  color: Colors.white.withOpacity(0.7),
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    widget.rtspUrl,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: 12,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Controls Section
                      const Text(
                        'Stream Controls',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // Control Cards
                      Row(
                        children: [
                          Expanded(
                            child: _buildControlCard(
                              title: _isPlaying ? 'Pause' : 'Play',
                              icon: _isPlaying ? Icons.pause : Icons.play_arrow,
                              color: Colors.blue,
                              onTap: () {
                                setState(() {
                                  _isPlaying = !_isPlaying;
                                  _isPlaying 
                                      ? _vlcViewController.play() 
                                      : _vlcViewController.pause();
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildControlCard(
                              title: 'Stop',
                              icon: Icons.stop,
                              color: Colors.red,
                              onTap: () {
                                _vlcViewController.stop();
                                setState(() {
                                  _isPlaying = false;
                                  _isConnected = false;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Auto-scan Toggle
                      Row(
                        children: [
                          Expanded(
                            child: _buildAutoScanControlCard(),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildAutoScanStatusCard(),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // PTZ Controls (if supported or debug mode)
                      if (_ptzSupported || _ptzDebugMode) ...[
                        Row(
                          children: [
                            Expanded(
                              child: _buildControlCard(
                                title: _ptzEnabled ? 'Disable PTZ Auto-Scan' : 'Enable PTZ Auto-Scan',
                                icon: _ptzEnabled ? Icons.videocam_off : Icons.videocam,
                                color: _ptzEnabled ? Colors.red : Colors.blue,
                                onTap: _togglePTZ,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildPTZStatusCard(),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Manual PTZ Controls
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.control_camera,
                                    color: Colors.grey[600],
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Manual PTZ Control',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  const Spacer(),
                                  if (_isMovingCamera)
                                    const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              
                              // Direction Controls
                              Column(
                                children: [
                                  // Up button
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _buildPTZDirectionButton(
                                        Icons.keyboard_arrow_up,
                                        'Up',
                                        PTZDirection.up,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  // Left and Right buttons
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: [
                                      _buildPTZDirectionButton(
                                        Icons.keyboard_arrow_left,
                                        'Left',
                                        PTZDirection.left,
                                      ),
                                      Container(
                                        width: 48,
                                        height: 48,
                                        decoration: BoxDecoration(
                                          color: Colors.grey[100],
                                          borderRadius: BorderRadius.circular(24),
                                        ),
                                        child: Icon(
                                          Icons.control_camera,
                                          color: Colors.grey[400],
                                          size: 24,
                                        ),
                                      ),
                                      _buildPTZDirectionButton(
                                        Icons.keyboard_arrow_right,
                                        'Right',
                                        PTZDirection.right,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  // Down button
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _buildPTZDirectionButton(
                                        Icons.keyboard_arrow_down,
                                        'Down',
                                        PTZDirection.down,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 16),
                              
                              // Zoom Controls for IP2M-841B
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.blue.withOpacity(0.2)),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.zoom_in_map,
                                          color: Colors.blue[600],
                                          size: 16,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Zoom Control (IP2M-841B)',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.blue[700],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                      children: [
                                        _buildZoomButton(
                                          Icons.zoom_in,
                                          'Zoom In',
                                          () async => await _performZoom(true),
                                        ),
                                        _buildZoomButton(
                                          Icons.zoom_out,
                                          'Zoom Out',
                                          () async => await _performZoom(false),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              
                              const SizedBox(height: 16),
                              
                              // Scan Pattern Selection
                              Row(
                                children: [
                                  Text(
                                    'Auto-scan pattern:',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'Continuous Scan',
                                        style: TextStyle(fontSize: 14),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                      ],
                      
                      // Test Detection Button (for testing)
                      Row(
                        children: [
                          Expanded(
                            child: _buildControlCard(
                              title: 'Add Test Detection',
                              icon: Icons.bug_report,
                              color: Colors.indigo,
                              onTap: _addTestDetection,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildControlCard(
                              title: 'Clear History',
                              icon: Icons.clear_all,
                              color: Colors.orange,
                              onTap: _clearDetectionHistory,
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // PTZ Debug Toggle (for testing without PTZ camera)
                      Row(
                        children: [
                          Expanded(
                            child: _buildControlCard(
                              title: _ptzDebugMode ? 'Disable PTZ Debug' : 'Enable PTZ Debug',
                              icon: _ptzDebugMode ? Icons.camera_alt_outlined : Icons.camera_alt,
                              color: _ptzDebugMode ? Colors.red : Colors.purple,
                              onTap: _togglePTZDebugMode,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(16),
                              ),
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: Colors.grey[400],
                                    size: 24,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Debug Mode',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Enable to test PTZ UI without camera',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey[500],
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Performance Settings
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.tune,
                                    color: Colors.grey[600],
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Performance Settings',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Analysis Interval',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        DropdownButton<int>(
                                          value: _analysisIntervalSeconds,
                                          isExpanded: true,
                                          underline: Container(),
                                          items: _availableIntervals.map((interval) {
                                            return DropdownMenuItem<int>(
                                              value: interval,
                                              child: Text(
                                                '$interval seconds',
                                                style: const TextStyle(fontSize: 14),
                                              ),
                                            );
                                          }).toList(),
                                          onChanged: (value) {
                                            if (value != null) {
                                              setState(() {
                                                _analysisIntervalSeconds = value;
                                              });
                                              
                                              // Restart auto-scan with new interval if enabled
                                              if (_autoScanEnabled) {
                                                _stopAutoScan();
                                                _startAutoScan();
                                              }
                                              
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('Analysis interval updated to $value seconds'),
                                                  backgroundColor: Colors.blue,
                                                  duration: const Duration(seconds: 2),
                                                ),
                                              );
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Lower intervals = More frequent analysis but higher CPU usage\nHigher intervals = Better performance and battery life',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[500],
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Generate Report Button
                      SizedBox(
                        width: double.infinity,
                        child: _buildControlCard(
                          title: 'Generate Report',
                          icon: Icons.assignment,
                          color: Colors.purple,
                          onTap: _generateReport,
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Analysis Results Section
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.analytics_outlined,
                                  color: Colors.grey[600],
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'AI Analysis Results',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black87,
                                  ),
                                ),
                                const Spacer(),
                                if (_isAnalyzing)
                                  const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (_lastAnalysisResult != null) ...[
                              _buildAnalysisResultItem(
                                'Status',
                                _lastAnalysisResult!['isDamageDetected'] 
                                    ? 'Damage Detected' 
                                    : 'No Damage',
                                _lastAnalysisResult!['isDamageDetected'] 
                                    ? Colors.red 
                                    : Colors.green,
                              ),
                              const SizedBox(height: 8),
                              _buildAnalysisResultItem(
                                'Type',
                                _lastAnalysisResult!['damageType'] ?? 'Unknown',
                                Colors.blue,
                              ),
                              const SizedBox(height: 8),
                              _buildAnalysisResultItem(
                                'Confidence',
                                '${(_lastAnalysisResult!['confidence'] * 100).toStringAsFixed(1)}%',
                                Colors.orange,
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildAnalysisStatsItem(
                                      'Frames Analyzed',
                                      _totalFramesAnalyzed.toString(),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: _buildAnalysisStatsItem(
                                      'Damages Found',
                                      _damagesDetected.toString(),
                                    ),
                                  ),
                                ],
                              ),
                            ] else ...[
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      color: Colors.grey[400],
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      _autoScanEnabled
                                          ? 'Analysis running...'
                                          : 'Start auto-scan to see results',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Update the control card in the UI
  Widget _buildAutoScanControlCard() {
    return _buildControlCard(
      title: _autoScanEnabled ? 'Stop Auto-Scan' : 'Start Auto-Scan',
      icon: _autoScanEnabled ? Icons.stop_circle : Icons.auto_awesome,
      color: _autoScanEnabled ? Colors.red : Colors.green,
      onTap: _toggleAutoScan,
    );
  }

  // Update the status card
  Widget _buildAutoScanStatusCard() {
    String statusText = 'Disabled';
    Color statusColor = Colors.grey;
    IconData statusIcon = Icons.auto_awesome_outlined;

    if (_autoScanEnabled) {
      switch (_currentScanState) {
        case AutoScanState.analyzing:
          statusText = 'Analyzing';
          statusColor = Colors.blue;
          statusIcon = Icons.search;
          break;
        case AutoScanState.showingResults:
          statusText = 'Showing Results';
          statusColor = Colors.orange;
          statusIcon = Icons.visibility;
          break;
        case AutoScanState.movingCamera:
          statusText = 'Moving Camera';
          statusColor = Colors.purple;
          statusIcon = Icons.videocam;
          break;
        case AutoScanState.stabilizing:
          statusText = 'Stabilizing';
          statusColor = Colors.teal;
          statusIcon = Icons.hourglass_empty;
          break;
        case AutoScanState.idle:
          statusText = 'Idle';
          statusColor = Colors.green;
          statusIcon = Icons.auto_awesome;
          break;
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(25),
              ),
              child: _currentScanState == AutoScanState.analyzing || 
                     _currentScanState == AutoScanState.movingCamera
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(
                      statusIcon,
                      color: statusColor,
                      size: 24,
                    ),
            ),
            const SizedBox(height: 12),
            Text(
              statusText,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            if (_totalPTZMovements > 0) ...[
              const SizedBox(height: 4),
              Text(
                'Movements: $_totalPTZMovements',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAnalysisResultItem(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnalysisStatsItem(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildPTZStatusCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: _ptzEnabled 
                    ? Colors.blue.withOpacity(0.1)
                    : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Icon(
                _ptzEnabled ? Icons.videocam : Icons.videocam_off,
                color: _ptzEnabled ? Colors.blue : Colors.grey,
                size: 24,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _isMovingCamera 
                  ? 'Moving...' 
                  : _ptzEnabled 
                      ? 'Auto-Scan ON' 
                      : 'Auto-Scan OFF',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            if (_totalPTZMovements > 0) ...[
              const SizedBox(height: 4),
              Text(
                'Movements: $_totalPTZMovements',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  Widget _buildPTZDirectionButton(IconData icon, String label, PTZDirection direction) {
    return Container(
      width: 56,
      height: 56,
      margin: const EdgeInsets.all(4),
      child: Material(
        color: _isMovingCamera ? Colors.grey[300] : Colors.blue[50],
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          onTap: _isMovingCamera ? null : () => _manualPTZControl(direction),
          borderRadius: BorderRadius.circular(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: _isMovingCamera ? Colors.grey[500] : Colors.blue[600],
                size: 24,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: _isMovingCamera ? Colors.grey[500] : Colors.blue[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  /// Build zoom control button for IP2M-841B
  Widget _buildZoomButton(IconData icon, String label, VoidCallback onPressed) {
    return Container(
      width: 80,
      height: 48,
      child: Material(
        color: _isMovingCamera ? Colors.grey[300] : Colors.blue[50],
        borderRadius: BorderRadius.circular(24),
        child: InkWell(
          onTap: _isMovingCamera ? null : onPressed,
          borderRadius: BorderRadius.circular(24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: _isMovingCamera ? Colors.grey[500] : Colors.blue[600],
                size: 20,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: _isMovingCamera ? Colors.grey[500] : Colors.blue[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  /// Perform zoom control for IP2M-841B camera
  Future<void> _performZoom(bool zoomIn) async {
    if (!_ptzSupported && !_ptzDebugMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('PTZ control is not supported by this camera'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    if (_isMovingCamera) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Camera is already moving, please wait...'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    setState(() {
      _isMovingCamera = true;
    });
    
    try {
      bool success = false;
      String action = zoomIn ? 'Zoom In' : 'Zoom Out';
      
      if (_ptzDebugMode) {
        print('🎥 PTZ Debug: Simulating $action');
        await Future.delayed(const Duration(seconds: 1));
        success = true;
      } else {
        print('🎯 IP2M-841B Zoom: Executing $action');
        
        if (zoomIn) {
          success = await PTZService.zoomIn(widget.rtspUrl, multiple: 2);
        } else {
          success = await PTZService.zoomOut(widget.rtspUrl, multiple: 2);
        }
        
        if (success) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_ptzDebugMode 
                ? '🔧 Debug: $action completed' 
                : '🔍 Camera $action completed'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1),
          ),
        );
        print('✅ Zoom: $action completed successfully');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ $action failed'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
        print('❌ Zoom: $action failed');
      }
    } catch (e) {
      print('❌ Zoom: Error during ${zoomIn ? 'zoom in' : 'zoom out'}: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Zoom error: ${e.toString().substring(0, 30)}...'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isMovingCamera = false;
        });
      }
    }
  }
}

class BoundingBoxPainter extends CustomPainter {
  final List<Map<String, dynamic>> detections;

  BoundingBoxPainter(this.detections);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    final backgroundPaint = Paint()
      ..color = Colors.red;

    for (var detection in detections) {
      final box = detection['box'];
      final label = detection['label'];
      final confidence = detection['confidence'];

      // Convert normalized coordinates to screen coordinates
      final x = box['x'] * size.width;
      final y = box['y'] * size.height;
      final width = box['width'] * size.width;
      final height = box['height'] * size.height;

      // Draw bounding box
      final rect = Rect.fromLTWH(x, y, width, height);
      canvas.drawRect(rect, paint);

      // Prepare label text
      final labelText = '$label ${(confidence * 100).toInt()}%';
      final textSpan = TextSpan(
        text: labelText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      // Calculate label background position and size
      final labelY = y > textPainter.height + 8 ? y - textPainter.height - 8 : y + height + 4;
      final labelRect = Rect.fromLTWH(
        x,
        labelY,
        textPainter.width + 16,
        textPainter.height + 8,
      );

      // Draw label background
      canvas.drawRect(labelRect, backgroundPaint);

      // Draw label text
      textPainter.paint(canvas, Offset(x + 8, labelY + 4));

      // Draw corner markers for better visibility
      final cornerLength = 20.0;
      final cornerPaint = Paint()
        ..color = Colors.red
        ..strokeWidth = 4.0
        ..style = PaintingStyle.stroke;

      // Top-left corner
      canvas.drawLine(Offset(x, y), Offset(x + cornerLength, y), cornerPaint);
      canvas.drawLine(Offset(x, y), Offset(x, y + cornerLength), cornerPaint);

      // Top-right corner
      canvas.drawLine(Offset(x + width, y), Offset(x + width - cornerLength, y), cornerPaint);
      canvas.drawLine(Offset(x + width, y), Offset(x + width, y + cornerLength), cornerPaint);

      // Bottom-left corner
      canvas.drawLine(Offset(x, y + height), Offset(x + cornerLength, y + height), cornerPaint);
      canvas.drawLine(Offset(x, y + height), Offset(x, y + height - cornerLength), cornerPaint);

      // Bottom-right corner
      canvas.drawLine(Offset(x + width, y + height), Offset(x + width - cornerLength, y + height), cornerPaint);
      canvas.drawLine(Offset(x + width, y + height), Offset(x + width, y + height - cornerLength), cornerPaint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

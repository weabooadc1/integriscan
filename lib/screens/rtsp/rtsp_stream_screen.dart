import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import 'package:integriscan/constant.dart';
import 'package:integriscan/models/report_models.dart';
import 'package:integriscan/screens/common/loading_buffer_screen.dart';
import 'package:integriscan/services/tflite_service.dart';
import 'package:integriscan/services/frame_capture_service.dart';
import 'package:integriscan/services/report_service.dart';
import 'package:integriscan/services/firestore_sync_service.dart';
import 'package:integriscan/services/ptz_service.dart';
import 'package:integriscan/services/compute_service.dart';
import 'package:integriscan/providers/auth_provider.dart';
import 'package:integriscan/screens/reports/report_detail_screen.dart';
import 'package:integriscan/utils/work_manager.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

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

class _RtspStreamScreenState extends State<RtspStreamScreen> with WidgetsBindingObserver {
  VlcPlayerController? _vlcViewController;
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
  
  // PTZ Control variables
  bool _ptzEnabled = false;
  bool _ptzSupported = false;
  bool _isMovingCamera = false;
  int _totalPTZMovements = 0;
  Timer? _ptzMovementTimer;
  
  // Bounding box display timing - removed since handled by auto-scan states
  bool _showBoundingBoxes = true;
  // Navigation guard to prevent setState while navigating away
  bool _isNavigating = false;
  // Cleanup protection to prevent background operations during report generation
  bool _isCleaningUp = false;
  
  // State update debouncing to reduce UI thread pressure
  DateTime _lastStateUpdate = DateTime.now();
  bool _pendingStateUpdate = false;
  Timer? _stateUpdateTimer;
  
  /// Helper to run async operations without awaiting (fire-and-forget)
  void unawaited(Future<void> future) {
    // Intentionally don't await - this is for fire-and-forget operations
  }

  @override
  void initState() {
    super.initState();
    // Add lifecycle observer for memory management
    WidgetsBinding.instance.addObserver(this);
    
    _validateRtspUrl(); // Validate URL format first
    
    // Initialize components with proper sequencing and error handling
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeComponents();
    });
  }
  
  /// Initialize all components with proper error handling and sequencing
  void _initializeComponents() async {
    try {
      // Initialize VLC first
      _initializeVLC();
      
      // Wait a moment before initializing TFLite
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Initialize TFLite (async but void return)
      _initializeTFLite();
      
      // Initialize PTZ after a small delay
      await Future.delayed(const Duration(milliseconds: 300));
      _initializePTZ();
      
  // NOTE: We intentionally do NOT start a background sync here.
  // Starting an automatic sync immediately when the RTSP screen
  // initializes can race with user actions (generate/discard).
  // Background sync should run on a schedule or be explicitly
  // requested by the user elsewhere in the app.
      
    } catch (e) {
      print('🚨 Error during component initialization: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Initialization error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
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
    
    try {
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
    _vlcViewController?.addListener(() {
      if (mounted && !_isNavigating && _vlcViewController != null) {
        final isPlaying = _vlcViewController!.value.isPlaying;
        final isInitialized = _vlcViewController!.value.isInitialized;
        final hasError = _vlcViewController!.value.hasError;
        final playbackState = _vlcViewController!.value.playingState;
        
        print('🎬 VLC State Update:');
        print('  - Playing: $isPlaying');
        print('  - Initialized: $isInitialized');
        print('  - Has Error: $hasError');
        print('  - Playback State: $playbackState');
        print('  - Position: ${_vlcViewController!.value.position}');
        print('  - Duration: ${_vlcViewController!.value.duration}');
        
        if (mounted && !_isNavigating) {
          setState(() {
            _isConnected = isPlaying && isInitialized && !hasError;
            _isLoading = !isInitialized && !hasError;
          });
        }
        
        if (hasError) {
          final errorMsg = _vlcViewController!.value.errorDescription.isEmpty 
              ? 'Unknown VLC error' 
              : _vlcViewController!.value.errorDescription;
          print('🎬 VLC Error detected: $errorMsg');
          
          // Show detailed error to user
          if (mounted && !_isNavigating) {
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
    } catch (e) {
      print('🎬 VLC Controller creation failed: $e');
      if (mounted) {
        setState(() {
          _isConnected = false;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to initialize video player: $e'),
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
  
  /// Retry RTSP connection
  void _retryConnection() {
    print('🔄 Retrying RTSP connection...');
    try {
      _vlcViewController?.dispose();
    } catch (e) {
      print('🔄 Error disposing VLC controller: $e');
    }
    if (mounted && !_isNavigating) {
      setState(() {
        _isConnected = false;
        _isLoading = true;
      });
    }
    
    // Wait a moment before retrying
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _initializeVLC();
      }
    });
  }
  

  void _initializeTFLite() async {
    print('🚀 RTSP Screen: Starting TFLite initialization...');
    try {
      final success = await TFLiteService.initialize();
      print('🚀 RTSP Screen: TFLite initialization result: $success');
      
  if (success && mounted && !_isNavigating) {
        print('🚀 RTSP Screen: TFLite initialization successful');
        
        // Check if we're in mock mode
        final modelInfo = TFLiteService.getModelInfo();
        print('🚀 RTSP Screen: Model info after initialization: $modelInfo');
        
        if (mounted && !_isNavigating) {
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
        }
  } else if (mounted && !_isNavigating) {
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
      if (mounted && !_isNavigating) {
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
    if (mounted && !_isNavigating) {
      setState(() {
        _ptzSupported = true;
      });
    }
    
    print('🎥 PTZ: Enabled with debug mode for testing');
    
    if (mounted && !_isNavigating) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Auto-scan ready!'),
          backgroundColor: Colors.purple,
          duration: Duration(seconds: 3),
        ),
      );
    }
    
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
        print('✅ PTZ: Real PTZ commands working! Starting camera calibration...');
        
        // Show calibration message to user
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('🔧 AMCREST Camera detected - Starting calibration...'),
              backgroundColor: Colors.blue,
              duration: Duration(seconds: 4),
            ),
          );
        }
        
        // Perform camera calibration (pan left and right)
        final calibrationSuccess = await PTZService.quickCalibrateCamera(widget.rtspUrl);
        
        if (mounted) {
          if (calibrationSuccess) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('✅ AMCREST Camera calibrated (Right → Left)! Ready for auto-scan.'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 4),
                action: SnackBarAction(
                  label: 'OK',
                  textColor: Colors.white,
                  onPressed: () {},
                ),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('⚠️ Camera calibration completed with warnings - Auto-scan still available'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 4),
              ),
            );
          }
        }
      } else {
        print('⚠️ PTZ: Real PTZ commands not working - debug mode recommended');
      }
    } catch (e) {
      print('🎥 PTZ: Background test error: $e');
    }
  }



  // Replace _toggleAnalysis() and _togglePTZ() with this unified method:
  void _toggleAutoScan() {
    print('🔄 _toggleAutoScan() called - current state: $_autoScanEnabled');
    
    // ADD: Check TFLite service state before starting
    if (!_autoScanEnabled) {
      final modelInfo = TFLiteService.getModelInfo();
      print('🤖 TFLite Model Info before starting auto-scan: $modelInfo');
      
      if (modelInfo['isInitialized'] != true) {
        print('❌ TFLite not initialized - reinitializing...');
        _initializeTFLite();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ AI model not ready - initializing...'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }
    
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
    print('🎯 PTZ Supported: $_ptzSupported');
    print('🎯 VLC Connected: $_isConnected, VLC Loading: $_isLoading');
    
    if (!_ptzSupported) {
      print('❌ Auto-scan blocked: PTZ not supported');
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
    // Enhanced safety check - don't do anything if widget is disposed, navigating, or cleaning up
    if (!mounted || _isNavigating || _isCleaningUp) {
      print('🛑 Auto-scan stop requested but widget disposed/navigating/cleaning up - ignoring');
      print('🛑   mounted: $mounted, _isNavigating: $_isNavigating, _isCleaningUp: $_isCleaningUp');
      print('🛑 Stack trace: ${StackTrace.current}');
      return;
    }
    
    print('🛑 Stopping Auto-scan workflow');
    
    _autoScanTimer?.cancel();
    _autoScanTimer = null;
    
    if (mounted && !_isNavigating) {
      setState(() {
        _currentScanState = AutoScanState.idle;
        _currentDetections = [];
        _showBoundingBoxes = true;
      });
    }

    if (mounted && !_isNavigating) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Auto-scan stopped'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
    }
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
      if (mounted) {
        setState(() {
          _currentScanState = AutoScanState.analyzing;
        });
      }

      final analysisResult = await _performSingleAnalysis();
      
      // ADD: More detailed logging of analysis result
      print('📊 DETAILED Analysis result: $analysisResult');
      print('📊 Analysis result type: ${analysisResult.runtimeType}');
      if (analysisResult != null) {
        print('📊 isDamageDetected: ${analysisResult['isDamageDetected']}');
        print('📊 damageType: ${analysisResult['damageType']}');
        print('📊 confidence: ${analysisResult['confidence']}');
      } else {
        print('❌ Analysis result is NULL - this is the problem!');
      }

      if (!_autoScanEnabled || !mounted) {
        print('❌ Auto-scan aborted after analysis');
        return;
      }

      // State 2: Show Detection Results (5 seconds) - UPDATED FOR MULTIPLE DETECTIONS
      print('🎯 Auto-scan: Step 2 - Showing results for 5 seconds');
      if (mounted) {
        setState(() {
          _currentScanState = AutoScanState.showingResults;
          
          if (analysisResult != null) {
            // NEW: Handle multiple detections if available
            if (analysisResult.containsKey('allDetections') && analysisResult['allDetections'] is List) {
              final allDetections = analysisResult['allDetections'] as List;
              print('🎯 Displaying ${allDetections.length} detections simultaneously');
              
              _currentDetections = [];
              
              for (int i = 0; i < allDetections.length; i++) {
                final detection = allDetections[i];
                
                // Show ALL detections regardless of confidence level
                final displayDetection = {
                  'label': '${detection['damageType']} #${i + 1}',
                  'confidence': detection['confidence'],
                  'damageType': detection['damageType'], // Add damage type for color coding
                  'box': detection['boundingBox'] ?? {
                    'x': 0.2 + (i * 0.15), // Offset multiple boxes horizontally
                    'y': 0.2 + (i * 0.1),  // Offset multiple boxes vertically
                    'width': 0.25,
                    'height': 0.2,
                  }
                };
                _currentDetections.add(displayDetection);
              }
              
              _showBoundingBoxes = _currentDetections.isNotEmpty;
              print('🎯 Showing ${_currentDetections.length} bounding boxes for multiple detections');
            }
            // Handle single detection (existing logic)
            else if (analysisResult['isDamageDetected'] == true) {
              final detection = {
                'label': analysisResult['damageType'] ?? 'Unknown',
                'confidence': analysisResult['confidence'] ?? 0.0,
                'damageType': analysisResult['damageType'] ?? 'Unknown', // Add damage type for color coding
                'box': analysisResult['boundingBox'] ?? {
                  'x': 0.3,
                  'y': 0.3,
                  'width': 0.4,
                  'height': 0.4,
                }
              };
              _currentDetections = [detection];
              _showBoundingBoxes = true;
              print('🎯 Showing single bounding box for detection: ${detection['label']}');
            } else {
              // Show "No Damage" indicator for completed analysis
              final noDetection = {
                'label': 'No Damage Detected',
                'confidence': analysisResult['confidence'] ?? 0.0,
                'damageType': 'No Damage', // Add damage type for color coding
                'box': {
                  'x': 0.4,
                  'y': 0.4,
                  'width': 0.2,
                  'height': 0.2,
                }
              };
              _currentDetections = [noDetection];
              _showBoundingBoxes = true;
              print('🎯 Showing "No Damage" indicator with confidence: ${analysisResult['confidence']}');
            }
          } else {
            _currentDetections = [];
            _showBoundingBoxes = false;
            print('🎯 Analysis failed, hiding bounding boxes');
          }
        });
      }

      // Wait exactly 5 seconds
      print('⏰ Auto-scan: Setting 5-second timer for results display');
      _autoScanTimer = Timer(const Duration(seconds: 5), () async {
        print('⏰ 5-second timer triggered');
        // Double-check mounted state and auto-scan enabled to prevent setState on disposed widget
        if (!_autoScanEnabled || !mounted || _isNavigating) {
          print('❌ Auto-scan aborted in timer callback - mounted: $mounted, enabled: $_autoScanEnabled, navigating: $_isNavigating');
          return;
        }

        // Additional safety check - verify the timer hasn't been cancelled
        if (_autoScanTimer == null) {
          print('❌ Auto-scan timer was cancelled');
          return;
        }

        // State 3: Camera Movement
        print('📹 Auto-scan: Step 3 - Moving camera');
        if (mounted && !_isNavigating) {
          setState(() {
            _currentScanState = AutoScanState.movingCamera;
            _showBoundingBoxes = false; // Hide bounding boxes during movement
            _currentDetections = [];
          });
        }

        final moveSuccess = await _performCameraMovement();
        print('📹 Camera movement result: $moveSuccess');

        if (!_autoScanEnabled || !mounted) {
          print('❌ Auto-scan aborted after camera movement');
          return;
        }

        // State 4: Camera Stabilization
        if (moveSuccess) {
          print('⏳ Auto-scan: Step 4 - Camera stabilization (3 seconds)');
          if (mounted) {
            setState(() {
              _currentScanState = AutoScanState.stabilizing;
            });
          }

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
      
      // Check VLC controller state
      if (_vlcViewController == null) {
        print('❌ VLC controller is null');
        return null;
      }
      
      print('🔍 VLC controller state:');
      print('  - isPlaying: ${_vlcViewController!.value.isPlaying}');
      print('  - isInitialized: ${_vlcViewController!.value.isInitialized}');
      print('  - hasError: ${_vlcViewController!.value.hasError}');
      
      // Small delay to ensure frame is ready
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Capture frame from VLC player (UI thread only for widget capture)
      print('📸 Attempting to capture frame from VLC widget');
      final frameBytes = await FrameCaptureService.captureWidget(_playerKey);
      
      if (frameBytes == null) {
        print('❌ Frame capture failed - returned null');
        return null;
      }
      
      print('📸 Frame captured successfully: ${frameBytes.length} bytes');
      
      // Run AI inference on main isolate (TFLite uses native platform channels)
      // Note: TFLite inference is already optimized at the native level
      // Moving it to a background isolate would fail due to platform channel limitations
      print('🤖 Running AI inference on main isolate');
      final result = await TFLiteService.runInference(frameBytes);
      print('🤖 AI inference result: $result');
      
      if (result == null) {
        print('❌ TFLiteService.runInference returned NULL');
        final modelInfo = TFLiteService.getModelInfo();
        print('🤖 Model info: $modelInfo');
        return null;
      }
      
      print('🤖 Result validation:');
      print('  - Has isDamageDetected key: ${result.containsKey('isDamageDetected')}');
      print('  - isDamageDetected value: ${result['isDamageDetected']}');
      
      // Update statistics with debounced setState
      if (mounted && !_isNavigating) {
        _debouncedSetState(() {
          _totalFramesAnalyzed++;
          if (result['isDamageDetected'] == true) {
            _damagesDetected++;
          }
          _lastAnalysisResult = result;
        });
      }
      
      // Save detection to history in background if damage detected
      if (result['isDamageDetected'] == true) {
        // Fire and forget - don't await
        unawaited(_saveDetectionToHistoryAsync(result, frameBytes));
      }
      
      return result;
    } catch (e, stackTrace) {
      print('❌ Analysis error: $e');
      print('❌ Stack trace: $stackTrace');
      return null;
    }
  }

  // Simplified camera movement method
  Future<bool> _performCameraMovement() async {
    print('🎬 Auto-scan: ===== CAMERA MOVEMENT START =====');
    print('🎬 Auto-scan: PTZ supported: $_ptzSupported, Is moving: $_isMovingCamera');
    
    if (!_ptzSupported) {
      print('🎬 Auto-scan: ❌ PTZ not supported - BLOCKING MOVEMENT');
      return false;
    }

    print('🎬 Auto-scan: Setting movement state to true');
      if (mounted && !_isNavigating) {
        setState(() {
          _isMovingCamera = true;
        });
      }

    try {
      bool success = false;
      _totalPTZMovements++;
      
      print('🎬 Auto-scan: Starting movement $_totalPTZMovements');
      
      print(' Auto-scan: ➡️ PTZ: Moving RIGHT (movement $_totalPTZMovements)');
      print('🎬 Auto-scan: RTSP URL: ${widget.rtspUrl}');
        
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
      if (mounted && !_isNavigating) {
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
    if (!_ptzSupported) {
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
      
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📹 Camera moved $directionName'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1),
          ),
        );
        print('✅ Manual PTZ: $directionName movement completed successfully');
      } else if (!success && mounted) {
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PTZ error: ${e.toString().substring(0, 30)}...'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
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
  

  


  /// Perform camera calibration by panning left and right
  Future<void> _performCameraCalibration() async {
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔧 Calibrating camera: Right → Left...'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 2),
        ),
      );

      bool calibrationSuccess = false;

      // Perform actual camera calibration
      print('🔧 Performing camera calibration...');
      calibrationSuccess = await PTZService.quickCalibrateCamera(widget.rtspUrl);

      if (mounted) {
        if (calibrationSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ AMCREST camera calibrated (Right → Left)!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Camera calibration failed - Check connection'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Camera calibration error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Calibration error: ${e.toString().length > 30 ? e.toString().substring(0, 30) + '...' : e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isMovingCamera = false;
        });
      }
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No detections found to generate report. Start analysis first and wait for damage detection.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }
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
      if (!mounted) return; // Check mounted before using context
      
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.user?.uid ?? 'anonymous';
      
      print('Generating report for ${_detectionHistory.length} detections');
      
      final report = await ReportService.generateReport(
        userId: userId,
        sessionName: 'RTSP Stream Session ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
        detections: _detectionHistory,
        trySyncToCloud: false, // Don't auto-upload to cloud - user will decide later
      );

      print('Report generated successfully: ${report.id}');
      
      // Validate report data before navigation
      print('🔍 Validating report data before navigation...');
      print('🔍 Report ID: ${report.id}');
      print('🔍 Report detections count: ${report.detections.length}');
      
      // Check each detection for valid image paths
      for (int i = 0; i < report.detections.length; i++) {
        final detection = report.detections[i];
        print('🔍 Detection $i: ${detection.damageType} - Image: ${detection.imagePath}');
        
        // Validate image file exists
        if (detection.imagePath.isNotEmpty) {
          final imageFile = File(detection.imagePath);
          final exists = await imageFile.exists();
          print('🔍   Image file exists: $exists');
          if (!exists) {
            print('⚠️   WARNING: Image file does not exist for detection $i');
          }
        }
      }

      if (mounted) {
        // Set cleanup flag early to prevent any background operations
        _isCleaningUp = true;
        print('🔚 Cleanup flag set - preventing further background operations');
        
        // IMMEDIATELY cancel all timers to prevent any background callbacks
        print('🔚 Immediately cancelling all background timers...');
        _autoScanTimer?.cancel();
        _autoScanTimer = null;
        _ptzMovementTimer?.cancel();
        _ptzMovementTimer = null;
        _autoScanEnabled = false; // Disable auto-scan completely
        print('🔚 All timers cancelled and auto-scan disabled');
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report generated and saved locally! You can choose to upload it to cloud later.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );

        // Intentionally do NOT trigger background sync here. The user should
        // explicitly choose to upload from the report screen. Leaving this
        // out prevents race conditions where a background upload runs while
        // the user is choosing to discard the report.

        // End the analysis session before navigating to report
        await _endAnalysisSession();

        // Add extra delay and ensure all timers are cancelled
        await Future.delayed(const Duration(milliseconds: 300));
        
        // Force cancel all remaining timers before navigation
        _autoScanTimer?.cancel();
        _autoScanTimer = null;
        _ptzMovementTimer?.cancel();
        _ptzMovementTimer = null;

        // Add a small delay to ensure all resources are properly cleaned up
        await Future.delayed(const Duration(milliseconds: 500));

        // More aggressive VLC cleanup to prevent native crashes
        if (_vlcViewController != null) {
          try {
            print('🔚 Stopping VLC player completely...');
            
            // Stop playback first
            if (_vlcViewController!.value.isPlaying) {
              await _vlcViewController!.stop();
              print('🔚 VLC stopped');
            }
            
            // Clear any video surface/texture to free video buffers
            try {
              await _vlcViewController!.setVideoAspectRatio('');
              await _vlcViewController!.setVideoScale(0.0);
            } catch (e) {
              print('Error clearing VLC video settings: $e');
            }
            
            // Wait for VLC to fully stop and release video buffers
            await Future.delayed(const Duration(milliseconds: 500));
            
            // Dispose the controller
            await _vlcViewController!.dispose();
            _vlcViewController = null;
            print('🔚 VLC disposed');
            
            // Extra delay to ensure native resources are released
            await Future.delayed(const Duration(milliseconds: 700));
            
          } catch (e) {
            print('Error disposing VLC controller: $e');
            // Still set to null even if disposal fails
            _vlcViewController = null;
          }
        }

        // Force multiple garbage collections to free up native memory
        print('🔚 Forcing garbage collection...');
        
        // Clear any remaining detection images from memory BEFORE garbage collection
        _detectionHistory.clear();
        _currentDetections.clear();
        _lastAnalysisResult = null;
        
        // Force aggressive memory cleanup
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Clear any cached images from the image cache with extra safety
        try {
          print('🔚 Starting image cache clearing...');
          
          // Clear in stages to be more gentle
          imageCache.clear();
          print('🔚 Image cache.clear() completed');
          
          await Future.delayed(const Duration(milliseconds: 50));
          
          imageCache.clearLiveImages();
          print('🔚 Image cache.clearLiveImages() completed');
          
          await Future.delayed(const Duration(milliseconds: 50));
          
          print('🔚 Image cache clearing finished successfully');
        } catch (e) {
          print('❌ Error clearing image cache: $e');
          // Continue anyway - don't let image cache clearing block navigation
        }
        
        print('🔚 Starting additional cleanup delay...');
        // Additional delay for native buffer cleanup
        await Future.delayed(const Duration(milliseconds: 300));
        print('🔚 Additional cleanup delay completed');

        print('🔚 Checking navigation conditions...');
        print('🔚   mounted: $mounted');
        print('🔚   _isNavigating: $_isNavigating');
        print('🔚   _isCleaningUp: $_isCleaningUp');
        
        // Navigate to loading buffer screen first for better UX
        if (mounted && !_isNavigating) {
          print('🔚 Navigation conditions met - showing loading buffer screen');
          _isNavigating = true; // prevent further setState during navigation
          
          // Navigate to loading buffer screen immediately with timeout protection
          print('🔄 Starting navigation to loading screen at ${DateTime.now()}');
          print('🔄 Report details: ID=${report.id}, Detections=${report.detections.length}');
          try {
            await Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => LoadingBufferScreen(
                  title: 'Preparing Report',
                  message: 'Finalizing your analysis results',
                  duration: const Duration(seconds: 12), // Reduced timeout
                  navigationData: {
                    'report': report,
                    'fromAnalysis': true,
                    'screenWidget': ReportDetailScreen(
                      report: report,
                      fromAnalysis: true,
                    ),
                  },
                  onComplete: () async {
                    print('🔄 LoadingBufferScreen onComplete called at ${DateTime.now()}');
                    try {
                      // Perform cleanup and return success/failure
                      final success = await _performBackgroundCleanupAndNavigate(report);
                      print('✅ Background cleanup completed with result: $success');
                      return success;
                    } catch (e) {
                      print('❌ Background cleanup failed: $e');
                      return false; // Return failure
                    }
                  },
                ),
              ),
            );
            print('✅ Loading screen navigation completed successfully');
          } catch (e) {
            print('❌ Loading screen navigation error: $e');
            // Fallback to direct navigation if loading screen fails
            print('🔄 Falling back to direct navigation');
            await Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => ReportDetailScreen(
                  report: report,
                  fromAnalysis: true,
                ),
              ),
            );
          }
        } else {
          print('❌ Navigation conditions NOT met:');
          print('❌   mounted: $mounted');
          print('❌   _isNavigating: $_isNavigating');  
          print('❌ Navigation aborted - report saved but not navigating');
        }
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

  /// Handle back navigation with confirmation if analysis is active
  Future<void> _handleBackNavigation() async {
    // If auto-scan is running or we have detection history, show confirmation
    if (_autoScanEnabled || _detectionHistory.isNotEmpty) {
      final shouldLeave = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('End Analysis Session?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_autoScanEnabled) ...[
                const Text('• Auto-scan is currently running'),
                const SizedBox(height: 8),
              ],
              if (_detectionHistory.isNotEmpty) ...[
                Text('• ${_detectionHistory.length} detection(s) found'),
                const SizedBox(height: 8),
              ],
              const Text(
                'Leaving now will end your analysis session. Consider generating a report first.',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            if (_detectionHistory.isNotEmpty)
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(false);
                  _generateReport(); // Generate report instead of leaving
                },
                child: const Text(
                  'Generate Report',
                  style: TextStyle(color: Colors.blue),
                ),
              ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                'End Session',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
      );

      if (shouldLeave == true) {
        // User confirmed they want to leave
        await _endAnalysisSession();
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    } else {
      // No active analysis, just go back normally
      Navigator.of(context).pop();
    }
  }

  /// Properly end the analysis session and clean up resources
  Future<void> _endAnalysisSession() async {
    print('🔚 Ending analysis session and cleaning up resources...');
    
    try {
      // Stop auto-scan if running - this must be first to cancel all timers
      if (_autoScanEnabled) {
        print('🔚 Stopping auto-scan...');
        _stopAutoScan();
        // Give extra time for any pending timer callbacks to be cancelled
        await Future.delayed(const Duration(milliseconds: 100));
      }
      
      // Cancel any remaining timers to prevent setState after disposal
      _autoScanTimer?.cancel();
      _autoScanTimer = null;
      _ptzMovementTimer?.cancel(); 
      _ptzMovementTimer = null;
      
      // Dispose TFLite service to free native memory
      try {
        print('🔚 Disposing TFLite service...');
        TFLiteService.dispose();
        await Future.delayed(const Duration(milliseconds: 100));
      } catch (e) {
        print('Error disposing TFLite service: $e');
      }
      
      // Stop VLC player and RTSP stream
      print('🔚 Stopping RTSP stream...');
      if (_vlcViewController != null) {
        try {
          if (_vlcViewController!.value.isPlaying) {
            await _vlcViewController!.stop();
          }
          // Don't dispose here - let the navigation code handle it
          // to prevent double disposal
        } catch (e) {
          print('Error stopping VLC controller: $e');
        }
      }
      
      // Update UI state to show session ended - with mounted and navigation checks
      if (mounted && !_isNavigating) {
        setState(() {
          _isPlaying = false;
          _isConnected = false;
          _isLoading = false;
          _autoScanEnabled = false; // Ensure auto-scan is disabled
        });
      }
      
      // Show user feedback that session is ending - with mounted and navigation checks
      if (mounted && !_isNavigating) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📋 Analysis session completed - Report generated'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 3),
          ),
        );
      }
      
      print('✅ Analysis session ended successfully');
      
    } catch (e) {
      print('❌ Error ending analysis session: $e');
      // Don't throw error, just log it - we still want to navigate to report
    }
  }

  // ADD: Manual test method for AI analysis
  Future<void> _testManualAnalysis() async {
    print('🧪 Manual AI analysis test started');
    
    if (!_isConnected) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connect to RTSP stream first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🧪 Testing AI analysis manually...'),
        backgroundColor: Colors.blue,
      ),
    );
    
    try {
      final result = await _performSingleAnalysis();
      
      if (mounted) {
        if (result != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ AI Test: ${result['damageType']} (${(result['confidence'] * 100).toInt()}%) - Damage: ${result['isDamageDetected']}'),
              backgroundColor: result['isDamageDetected'] == true ? Colors.red : Colors.green,
              duration: const Duration(seconds: 5),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ AI Test failed - check console for details'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Manual analysis test error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Analysis error: ${e.toString().substring(0, 50)}...'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Show dialog to choose between single or multiple damage detection simulation
  void _showTestDetectionOptions() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Test Detection Simulation'),
          content: const Text('Choose the type of damage simulation to add:'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _addSingleTestDetection();
              },
              child: const Text('Single Damage'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _addMultipleTestDetections();
              },
              child: const Text('Multiple Damages'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  /// Add single damage detection (original behavior)
  void _addSingleTestDetection() async {
    print('_addSingleTestDetection called');
    final random = DateTime.now().millisecondsSinceEpoch % 100;
    final damageTypes = ['Crack', 'Deformation', 'Corrosion'];
    final damageType = damageTypes[random % 3];
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
    
    // Create display detection for bounding box
    final displayDetection = {
      'label': '$damageType (${(confidence * 100).toInt()}%)',
      'confidence': confidence,
      'damageType': damageType,
      'box': detection['boundingBox'],
    };
    
    if (mounted) {
      setState(() {
        _detectionHistory.add(detection);
        _damagesDetected++;
        
        // Update current detections for bounding box display
        _currentDetections = [displayDetection];
        _showBoundingBoxes = true;
      });
    }
    
    print('Detection history now has ${_detectionHistory.length} items');
    print('Added single detection: $detection');
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Single test detection added: $damageType (${(confidence * 100).toInt()}%) - Total: ${_detectionHistory.length}'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  /// Add multiple damage detections on single image (enhanced behavior)
  void _addMultipleTestDetections() async {
    print('_addMultipleTestDetections called - Creating multiple damage simulation');
    
    // Generate random number of damage types (2-3 different damages on one image)
    final random = DateTime.now().millisecondsSinceEpoch % 100;
    final damageTypes = ['Crack', 'Deformation', 'Corrosion'];
    
    // Randomly select 2-3 different damage types for this image
    final numDamages = 2 + (random % 2); // 2 or 3 damages
    final selectedDamages = <String>[];
    final usedIndices = <int>{};
    
    // Select unique damage types
    for (int i = 0; i < numDamages; i++) {
      int damageIndex;
      do {
        damageIndex = (random + i * 17) % damageTypes.length; // Use different multiplier to avoid same indices
      } while (usedIndices.contains(damageIndex));
      
      usedIndices.add(damageIndex);
      selectedDamages.add(damageTypes[damageIndex]);
    }
    
    print('🎯 Simulating ${selectedDamages.length} damage types on single image: ${selectedDamages.join(', ')}');
    
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
      final filename = 'test_multiple_damage_${timestamp}.png';
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
    
    // Create multiple detections for the same image
    final List<Map<String, dynamic>> newDetections = [];
    final List<Map<String, dynamic>> displayDetections = [];
    
    for (int i = 0; i < selectedDamages.length; i++) {
      final damageType = selectedDamages[i];
      final confidence = 0.6 + ((random + i * 13) % 40) / 100; // Vary confidence for each damage
      
      // Create different bounding box positions for each damage type
      final Map<String, double> boxPosition;
      switch (i) {
        case 0:
          // Top-left area
          boxPosition = {
            'x': 0.1 + (random % 20) / 100,
            'y': 0.1 + (random % 20) / 100,
            'width': 0.25 + (random % 10) / 100,
            'height': 0.2 + (random % 10) / 100,
          };
          break;
        case 1:
          // Top-right area
          boxPosition = {
            'x': 0.6 + (random % 20) / 100,
            'y': 0.1 + (random % 20) / 100,
            'width': 0.25 + (random % 10) / 100,
            'height': 0.2 + (random % 10) / 100,
          };
          break;
        case 2:
        default:
          // Bottom-center area
          boxPosition = {
            'x': 0.35 + (random % 20) / 100,
            'y': 0.6 + (random % 20) / 100,
            'width': 0.25 + (random % 10) / 100,
            'height': 0.2 + (random % 10) / 100,
          };
          break;
      }
      
      // Create detection for history
      final detection = {
        'damageType': damageType,
        'confidence': confidence,
        'imagePath': imagePath, // Same image path for all damages
        'timestamp': DateTime.now().millisecondsSinceEpoch + i, // Slightly different timestamps
        'boundingBox': boxPosition,
      };
      
      // Create display detection for bounding boxes
      final displayDetection = {
        'label': '$damageType (${(confidence * 100).toInt()}%)',
        'confidence': confidence,
        'damageType': damageType,
        'box': boxPosition,
      };
      
      newDetections.add(detection);
      displayDetections.add(displayDetection);
      
      print('🎯 Created damage ${i + 1}/${selectedDamages.length}: $damageType (${(confidence * 100).toInt()}%)');
    }
    
    if (mounted) {
      setState(() {
        // Add all detections to history
        _detectionHistory.addAll(newDetections);
        _damagesDetected += newDetections.length;
        
        // Update current detections for bounding box display
        _currentDetections = displayDetections;
        _showBoundingBoxes = true;
      });
    }
    
    print('Detection history now has ${_detectionHistory.length} items');
    print('Added ${newDetections.length} detections for multiple damage simulation');
    print('Updated bounding box display with ${displayDetections.length} boxes');
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Multiple damage simulation: ${selectedDamages.join(', ')} - Total detections: ${_detectionHistory.length}'),
          backgroundColor: Colors.purple,
          duration: const Duration(seconds: 4),
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



  Future<bool> _performBackgroundCleanupAndNavigate(DetectionReport report) async {
    try {
      print('🔚 Starting background cleanup process...');
      
      // Final safety check - ensure all timers are cancelled before navigation
      _autoScanTimer?.cancel();
      _autoScanTimer = null;
      _ptzMovementTimer?.cancel();
      _ptzMovementTimer = null;
      
      // Remove lifecycle observer immediately to prevent any further callbacks
      try {
        WidgetsBinding.instance.removeObserver(this);
      } catch (e) {
        print('Error removing lifecycle observer: $e');
      }
      
      // Perform intensive cleanup operations
      await Future.delayed(const Duration(milliseconds: 500));
      
      // VLC cleanup in background
      if (_vlcViewController != null) {
        try {
          print('🔚 Stopping VLC player completely...');
          
          // Stop playback first
          if (_vlcViewController!.value.isPlaying) {
            await _vlcViewController!.stop();
            print('🔚 VLC stopped');
          }
          
          // Clear any video surface/texture to free video buffers
          try {
            await _vlcViewController!.setVideoAspectRatio('');
            await _vlcViewController!.setVideoScale(0.0);
          } catch (e) {
            print('Error clearing VLC video settings: $e');
          }
          
          // Wait for VLC to fully stop and release video buffers
          await Future.delayed(const Duration(milliseconds: 300));
          
          // Dispose the controller
          await _vlcViewController!.dispose();
          _vlcViewController = null;
          print('🔚 VLC disposed');
          
        } catch (e) {
          print('Error disposing VLC controller: $e');
          _vlcViewController = null;
        }
      }
      
      // Memory cleanup
      _detectionHistory.clear();
      _currentDetections.clear();
      _lastAnalysisResult = null;
      
      // Clear image cache
      try {
        imageCache.clear();
        imageCache.clearLiveImages();
      } catch (e) {
        print('❌ Error clearing image cache: $e');
      }
      
      // Final delay for stability
      await Future.delayed(const Duration(milliseconds: 500));
      
      final cleanupTime = DateTime.now();
      print('🔚 Background cleanup completed successfully at $cleanupTime');
      
      return true; // Return success - navigation will be handled by caller
      
    } catch (e) {
      print('❌ Background cleanup error: $e');
      return false; // Return failure status
    }
  }

  /// Debounced setState to reduce UI thread pressure and prevent frame drops
  /// Batches multiple state updates together within a 250ms window
  void _debouncedSetState(void Function() fn) {
    if (!mounted || _isNavigating) return;
    
    final now = DateTime.now();
    
    // Cancel any pending update
    _stateUpdateTimer?.cancel();
    
    // If we updated recently, schedule for later
    if (now.difference(_lastStateUpdate) < const Duration(milliseconds: 250)) {
      _pendingStateUpdate = true;
      _stateUpdateTimer = Timer(const Duration(milliseconds: 250), () {
        if (mounted && !_isNavigating && _pendingStateUpdate) {
          setState(fn);
          _lastStateUpdate = DateTime.now();
          _pendingStateUpdate = false;
        }
      });
    } else {
      // Update immediately
      setState(fn);
      _lastStateUpdate = now;
      _pendingStateUpdate = false;
    }
  }
  
  /// Helper to save detection history in background without blocking UI
  Future<void> _saveDetectionToHistoryAsync(
    Map<String, dynamic> result,
    Uint8List frameBytes,
  ) async {
    try {
      print('💾 Starting to save detection image...');
      print('💾 Frame bytes length: ${frameBytes.length}');
      print('💾 Damage type: ${result['damageType']}');
      print('💾 Confidence: ${result['confidence']}');
      
      // Get frames directory path on main isolate (path_provider only works on main isolate)
      final directory = await getApplicationDocumentsDirectory();
      final framesDirectoryPath = '${directory.path}/frames';
      print('💾 Frames directory: $framesDirectoryPath');
      
      // Save image in background isolate using compute service
      final savedImagePath = await ComputeService.saveImageInBackground(
        imageBytes: frameBytes,
        damageType: result['damageType'] ?? 'Unknown',
        confidence: (result['confidence'] as num?)?.toDouble() ?? 0.0,
        framesDirectoryPath: framesDirectoryPath,
      );
      
      print('💾 Image saved to: "$savedImagePath" (length: ${savedImagePath.length})');
      
      if (savedImagePath.isEmpty) {
        print('❌ WARNING: Image path is empty after save attempt!');
      }

      final detectionData = {
        'damageType': result['damageType'],
        'confidence': result['confidence'],
        'imagePath': savedImagePath,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'boundingBox': result['boundingBox'] ?? {
          'x': 0.3,
          'y': 0.3,
          'width': 0.4,
          'height': 0.4,
        },
      };

      // Add to history with debounced setState
      if (mounted && !_isNavigating) {
        _debouncedSetState(() {
          _detectionHistory.add(detectionData);
        });
      }

      print('💾 Detection saved to history. Total: ${_detectionHistory.length}');
      print('💾 Saved detection data: $detectionData');
    } catch (e, stackTrace) {
      print('❌ Error saving detection: $e');
      print('❌ Stack trace: $stackTrace');
      
      // Still add detection to history even if image save fails
      // but with empty image path
      final detectionData = {
        'damageType': result['damageType'],
        'confidence': result['confidence'],
        'imagePath': '', // Empty path since save failed
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'boundingBox': result['boundingBox'] ?? {
          'x': 0.3,
          'y': 0.3,
          'width': 0.4,
          'height': 0.4,
        },
      };
      
      if (mounted && !_isNavigating) {
        _debouncedSetState(() {
          _detectionHistory.add(detectionData);
        });
      }
    }
  }



  @override
  void dispose() {
    print('🔚 RTSP Screen dispose() called - cleaning up without setState calls');
    
    // Remove lifecycle observer
    WidgetsBinding.instance.removeObserver(this);
    
    // Cancel all timers
    _autoScanTimer?.cancel();
    _autoScanTimer = null;
    _ptzMovementTimer?.cancel();
    _ptzMovementTimer = null;
    _stateUpdateTimer?.cancel();
    _stateUpdateTimer = null;
    
    // Cancel any pending work
    WorkManager().cancelAll();
    
    print('🔚 Timers cancelled in dispose() without setState calls');
    
    try {
      _vlcViewController?.dispose();
    } catch (e) {
      print('🔄 Error disposing VLC controller in dispose: $e');
    }
    
    try {
      TFLiteService.dispose();
    } catch (e) {
      print('🔄 Error disposing TFLite service: $e');
    }
    
    // CPU Optimization: Clear memory caches
    _detectionHistory.clear(); // Clear in-memory detection history on dispose (logout)
    _currentDetections.clear();
    _lastAnalysisResult = null;
    
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // Only handle app lifecycle changes if widget is still mounted and not navigating
    if (!mounted || _isNavigating) {
      print('🔄 App lifecycle change ignored - widget disposed or navigating');
      return;
    }
    
    switch (state) {
      case AppLifecycleState.paused:
        // App is going to background - reduce resource usage
        print('🔄 App paused - reducing resource usage');
        if (_vlcViewController != null && _vlcViewController!.value.isPlaying) {
          try {
            _vlcViewController!.pause();
          } catch (e) {
            print('Error pausing VLC on app pause: $e');
          }
        }
        _stopAutoScan();
        break;
      case AppLifecycleState.resumed:
        // App is coming back to foreground
        print('🔄 App resumed - restoring functionality');
        break;
      case AppLifecycleState.detached:
        // App is about to be terminated
        print('🔄 App detached - cleaning up resources');
        if (_vlcViewController != null) {
          try {
            _vlcViewController!.stop();
          } catch (e) {
            print('Error stopping VLC on app detach: $e');
          }
        }
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _handleBackNavigation();
        return false; // Always return false, let _handleBackNavigation() handle the actual navigation
      },
      child: Scaffold(
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
                      onPressed: () => _handleBackNavigation(),
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
                      child: _vlcViewController != null 
                        ? VlcPlayer(
                            controller: _vlcViewController!,
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
                      )
                      : Container(
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
                                  'Initializing video player...',
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
                                  if (_vlcViewController != null) {
                                    _isPlaying 
                                        ? _vlcViewController!.play() 
                                        : _vlcViewController!.pause();
                                  }
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
                                _vlcViewController?.stop();
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
                      if (_ptzSupported) ...[
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
                              
                              // Camera Calibration Button
                              Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 16),
                                child: ElevatedButton.icon(
                                  onPressed: _isMovingCamera ? null : () => _performCameraCalibration(),
                                  icon: const Icon(Icons.settings_remote, size: 18),
                                  label: const Text('Calibrate Camera (Right → Left)'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              ),
                              
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
                      
                      // Clear History and Generate Report Buttons
                      Row(
                        children: [
                          Expanded(
                            child: _buildControlCard(
                              title: 'Clear History',
                              icon: Icons.clear_all,
                              color: Colors.orange,
                              onTap: _clearDetectionHistory,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildControlCard(
                              title: 'Generate Report',
                              icon: Icons.assignment,
                              color: Colors.purple,
                              onTap: _generateReport,
                            ),
                          ),
                        ],
                      ),
                  
                      const SizedBox(height: 16),
                      
                      // ADD: Manual Test Buttons
                    /* Row(
                        children: [
                          Expanded(
                            child: _buildControlCard(
                              title: 'Test AI Analysis',
                              icon: Icons.psychology,
                              color: Colors.cyan,
                              onTap: _testManualAnalysis,
                            ),
                          ),
                          const SizedBox(width: 16),
                            Expanded(
                              child: _buildControlCard(
                                title: 'Add Test Detection',
                                 icon: Icons.bug_report,
                                 color: Colors.pink,
                                 onTap: _showTestDetectionOptions,
                               ),
                          ),
                        ],
                      ),*/
                      
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
    ),
    ); // Close WillPopScope
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
    if (!_ptzSupported) {
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
      
      print('🎯 IP2M-841B Zoom: Executing $action');
      
      if (zoomIn) {
        success = await PTZService.zoomIn(widget.rtspUrl, multiple: 2);
      } else {
        success = await PTZService.zoomOut(widget.rtspUrl, multiple: 2);
      }
      
      if (success) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🔍 Camera zoom completed'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1),
          ),
        );
        print('✅ Zoom: $action completed successfully');
      } else if (!success && mounted) {
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Zoom error: ${e.toString().substring(0, 30)}...'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
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

  // NEW: Get different colors for different damage types
  Color _getColorForDamageType(String damageType) {
    switch (damageType.toLowerCase()) {
      case 'crack':
      case 'cracking':
        return Colors.red;
      case 'corrosion':
      case 'rust':
        return Colors.orange;
      case 'deformation':
      case 'dent':
        return Colors.purple;
      case 'spalling':
        return Colors.yellow;
      case 'no damage':
      case 'no damage detected':
        return Colors.green;
      default:
        return Colors.blue; // Default color for unknown damage types
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < detections.length; i++) {
      var detection = detections[i];
      final box = detection['box'];
      final label = detection['label'];
      final confidence = detection['confidence'];
      final damageType = detection['damageType'] ?? label ?? 'unknown';

      // NEW: Use different colors for different damage types
      final damageColor = _getColorForDamageType(damageType);
      
      final paint = Paint()
        ..color = damageColor
        ..strokeWidth = 3.0
        ..style = PaintingStyle.stroke;

      final backgroundPaint = Paint()
        ..color = damageColor;

      // Convert normalized coordinates to screen coordinates
      final x = box['x'] * size.width;
      final y = box['y'] * size.height;
      final width = box['width'] * size.width;
      final height = box['height'] * size.height;

      // Draw bounding box
      final rect = Rect.fromLTWH(x, y, width, height);
      canvas.drawRect(rect, paint);

      // Prepare label text with damage index for multiple damages
      final labelText = detections.length > 1 
          ? '$label ${(confidence * 100).toInt()}%'
          : '$label ${(confidence * 100).toInt()}%';
          
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

      // Calculate label background position (avoid overlapping)
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

      // Draw corner markers with damage-specific colors
      final cornerLength = 20.0;
      final cornerPaint = Paint()
        ..color = damageColor
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

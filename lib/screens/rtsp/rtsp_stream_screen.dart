import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import 'package:integriscan/constant.dart';
import 'package:integriscan/services/tflite_service.dart';
import 'package:integriscan/services/frame_capture_service.dart';
import 'package:integriscan/services/report_service.dart';
import 'package:integriscan/services/firestore_sync_service.dart';
import 'package:integriscan/providers/auth_provider.dart';
import 'package:integriscan/screens/reports/report_detail_screen.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'dart:typed_data';
import 'dart:io';

class RtspStreamScreen extends StatefulWidget {
  final String rtspUrl;
  const RtspStreamScreen({super.key, required this.rtspUrl});

  @override
  State<RtspStreamScreen> createState() => _RtspStreamScreenState();
}

class _RtspStreamScreenState extends State<RtspStreamScreen> {
  late VlcPlayerController _vlcViewController;
  bool _isPlaying = true;
  bool _isConnected = false;
  bool _isLoading = true;
  bool _isAnalyzing = false;
  bool _analysisEnabled = false;
  // TFLite Analysis
  Map<String, dynamic>? _lastAnalysisResult;
  int _totalFramesAnalyzed = 0;
  int _damagesDetected = 0;
  Timer? _analysisTimer;
  final GlobalKey _playerKey = GlobalKey();
  List<Map<String, dynamic>> _currentDetections = [];
  List<Map<String, dynamic>> _detectionHistory = []; // Store all detections for report
  
  // CPU optimization variables
  int _frameSkipCounter = 0;
  static const int _frameSkipThreshold = 2; // Process every 3rd frame
  DateTime? _lastFrameProcessed;
  Uint8List? _lastFrameBytes; // Cache last frame for comparison
  static const double _frameSimilarityThreshold = 0.95; // Skip similar frames
  
  // User configurable analysis settings
  int _analysisIntervalSeconds = 5; // Default 5 seconds
  final List<int> _availableIntervals = [3, 5, 10, 15, 30]; // Available intervals

  @override
  void initState() {
    super.initState();
    _initializeVLC();
    _initializeTFLite();
    // Attempt background sync for all unsynced reports on screen load
    _syncUnsyncedReportsForCurrentUser();
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
    _vlcViewController = VlcPlayerController.network(
      widget.rtspUrl,
      hwAcc: HwAcc.full,
      autoPlay: true,
      options: VlcPlayerOptions(),
    );
    
    // Add listeners for connection status
    _vlcViewController.addListener(() {
      if (mounted) {
        final isPlaying = _vlcViewController.value.isPlaying;
        final isInitialized = _vlcViewController.value.isInitialized;
        final hasError = _vlcViewController.value.hasError;
        
        print('🎬 VLC State: playing=$isPlaying, initialized=$isInitialized, hasError=$hasError');
        
        setState(() {
          _isConnected = isPlaying && isInitialized && !hasError;
          _isLoading = !isInitialized && !hasError;
        });
        
        if (hasError) {
          print('🎬 VLC Error detected: ${_vlcViewController.value.errorDescription}');
        }
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

  void _toggleAnalysis() {
    setState(() {
      _analysisEnabled = !_analysisEnabled;
    });

    if (_analysisEnabled) {
      _startAnalysis();
    } else {
      _stopAnalysis();
    }
  }

  void _startAnalysis() {
    // Use configurable interval to reduce CPU load
    _analysisTimer = Timer.periodic(Duration(seconds: _analysisIntervalSeconds), (timer) async {
      if (!_analysisEnabled || !_isConnected || !mounted) return;

      // Skip analysis if previous one is still running
      if (_isAnalyzing) {
        print('⏭️ Skipping analysis - previous analysis still running');
        return;
      }

      if (mounted) {
        setState(() {
          _isAnalyzing = true;
        });
      }

      await _runRealTimeAnalysis();

      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
      }
    });
  }

  void _stopAnalysis() {
    _analysisTimer?.cancel();
    _analysisTimer = null;
  }

  Future<void> _runRealTimeAnalysis() async {
    if (!_analysisEnabled || !_isConnected) {
      print('=== Analysis Skipped ===');
      print('Analysis enabled: $_analysisEnabled, Connected: $_isConnected');
      return;
    }

    try {
      print('=== Starting Real-Time Analysis ===');
      
      // CPU Optimization 1: Rate limiting
      final now = DateTime.now();
      if (_lastFrameProcessed != null && 
          now.difference(_lastFrameProcessed!).inMilliseconds < 3000) {
        print('⏭️ Skipping analysis - rate limit (min 3 seconds between analyses)');
        return;
      }
      
      print('Analysis enabled: $_analysisEnabled, Connected: $_isConnected');
      print('VLC Controller state: playing=${_vlcViewController.value.isPlaying}, initialized=${_vlcViewController.value.isInitialized}');
      
      // Additional checks for VLC player state
      if (!_vlcViewController.value.isInitialized) {
        print('VLC controller not initialized yet, skipping frame capture');
        return;
      }
      
      if (!_vlcViewController.value.isPlaying) {
        print('VLC controller not playing, skipping frame capture');
        return;
      }
      
      // CPU Optimization 2: Frame skipping
      _frameSkipCounter++;
      if (_frameSkipCounter <= _frameSkipThreshold) {
        print('⏭️ Skipping frame ${_frameSkipCounter}/${_frameSkipThreshold + 1} for CPU optimization');
        return;
      }
      _frameSkipCounter = 0; // Reset counter
      
      // Small delay to ensure frame is ready
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Capture frame from VLC player
      final frameBytes = await FrameCaptureService.captureWidget(_playerKey);
      
      if (frameBytes != null) {
        print('Frame captured successfully: ${frameBytes.length} bytes');
        
        // CPU Optimization 3: Frame similarity check
        if (_lastFrameBytes != null && _isFrameSimilar(frameBytes, _lastFrameBytes!)) {
          print('⏭️ Skipping analysis - frame too similar to previous frame');
          return;
        }
        
        _lastFrameBytes = frameBytes;
        _lastFrameProcessed = now;
        
        // CPU Optimization 4: Run inference in background isolate would be ideal,
        // but for now we'll use the existing method with reduced frequency
        final result = await TFLiteService.runInference(frameBytes);
        
        if (result != null && result['isDamageDetected'] != null) {
          print('TFLite analysis result: $result');
          await _processAnalysisResult(result, frameBytes);
        } else {
          print('TFLite returned null or invalid result.');
        }
      } else {
        print('Frame capture failed - no frame data returned.');
      }
    } catch (e) {
      print('Real-time analysis error: $e');
    }
  }

  // CPU Optimization helper: Simple frame similarity check
  bool _isFrameSimilar(Uint8List frame1, Uint8List frame2) {
    if (frame1.length != frame2.length) return false;
    
    // Simple similarity check: compare file sizes and sample bytes
    if ((frame1.length - frame2.length).abs() > frame1.length * 0.05) {
      return false; // More than 5% size difference
    }
    
    // Sample comparison - check every 100th byte for performance
    int differences = 0;
    final sampleSize = (frame1.length / 100).round();
    
    for (int i = 0; i < frame1.length; i += sampleSize) {
      if (frame1[i] != frame2[i]) {
        differences++;
        if (differences > 10) return false; // Too many differences
      }
    }
    
    final similarity = 1.0 - (differences / (frame1.length / sampleSize));
    print('🔍 Frame similarity: ${(similarity * 100).toStringAsFixed(1)}%');
    
    return similarity >= _frameSimilarityThreshold;
  }

  Future<void> _processAnalysisResult(Map<String, dynamic> result, Uint8List frameBytes) async {
    final isDamage = result['isDamageDetected'] == true;
    final confidence = result['confidence'] ?? 0.0;
    final damageType = result['damageType'] ?? 'Unknown';
    
    // Process image saving outside setState if damage detected
    String? savedImagePath;
    Map<String, dynamic>? detectionData;
    
    if (isDamage && confidence > 0.5) {
      // Save frame if damage detected and get the saved path
      print('🖼️ Saving analyzed frame for damage: $damageType (confidence: $confidence)');
      savedImagePath = await _saveAnalyzedFrame(frameBytes, damageType, confidence);
      print('🖼️ Frame saved successfully at: $savedImagePath');
      
      detectionData = {
        'damageType': damageType,
        'confidence': confidence,
        'imagePath': savedImagePath, // Use the actual saved path
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'boundingBox': {
          'x': 0.3, // Center the bounding box for now
          'y': 0.3,
          'width': 0.4,
          'height': 0.4,
        },
      };
    }
    
    if (mounted) {
      setState(() {
        _totalFramesAnalyzed++;
        if (isDamage) _damagesDetected++;
        
        // Update current detections
        if (isDamage && confidence > 0.5) {
          final detection = {
            'label': damageType,
            'confidence': confidence,
            'box': {
              'x': 0.3, // Center the bounding box for now
              'y': 0.3,
              'width': 0.4,
              'height': 0.4,
            }
          };
          
          _currentDetections = [detection];
          
          // Add to detection history
          if (detectionData != null) {
            _detectionHistory.add(detectionData);
            print('📊 Added detection to history. Total detections: ${_detectionHistory.length}');
            print('📊 Detection data: $detectionData');
          }
        } else {
          _currentDetections = [];
        }
        
        _lastAnalysisResult = {
          'isDamageDetected': isDamage,
          'confidence': confidence,
          'damageType': damageType,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        };
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
    _stopAnalysis();
    _vlcViewController.dispose();
    TFLiteService.dispose();
    
    // CPU Optimization: Clear memory caches
    _detectionHistory.clear(); // Clear in-memory detection history on dispose (logout)
    _currentDetections.clear();
    _lastFrameBytes = null; // Free cached frame data
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
                    if (_analysisEnabled && _currentDetections.isNotEmpty)
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
                      
                      // AI Analysis Toggle
                      Row(
                        children: [
                          Expanded(
                            child: _buildControlCard(
                              title: _analysisEnabled ? 'Stop Analysis' : 'Start Analysis',
                              icon: _analysisEnabled ? Icons.stop_circle : Icons.smart_toy,
                              color: _analysisEnabled ? Colors.orange : Colors.green,
                              onTap: _toggleAnalysis,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildAnalysisStatusCard(),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
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
                                              
                                              // Restart analysis with new interval
                                              if (_analysisEnabled) {
                                                _stopAnalysis();
                                                _startAnalysis();
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
                                      _analysisEnabled 
                                          ? 'Analysis running...'
                                          : 'Start analysis to see results',
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

  Widget _buildAnalysisStatusCard() {
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
                color: _analysisEnabled 
                    ? Colors.green.withOpacity(0.1)
                    : Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(25),
              ),
              child: Icon(
                _analysisEnabled ? Icons.visibility : Icons.visibility_off,
                color: _analysisEnabled ? Colors.green : Colors.grey,
                size: 24,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _analysisEnabled ? 'Analyzing' : 'Disabled',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
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

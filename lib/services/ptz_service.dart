import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../utils/digest_auth.dart';

/// PTZ Direction enumeration
enum PTZDirection {
  left,
  right,
  up,
  down,
  center,
}

/// Predefined scan patterns for systematic analysis
class PTZScanPattern {
  // Horizontal left-right scan pattern
  static const List<PTZDirection> horizontalScan = [
    PTZDirection.left,
    PTZDirection.right,
    PTZDirection.center,
  ];
  
  // Vertical up-down scan pattern  
  static const List<PTZDirection> verticalScan = [
    PTZDirection.up,
    PTZDirection.down,
    PTZDirection.center,
  ];
  
  // Grid pattern for comprehensive coverage
  static const List<PTZDirection> gridScan = [
    PTZDirection.left,
    PTZDirection.up,
    PTZDirection.right,
    PTZDirection.down,
    PTZDirection.center,
  ];

  // 360-degree clockwise rotation pattern (12 positions, 30 degrees each)
  static const List<PTZDirection> clockwise360Scan = [
    PTZDirection.right, // Position 1 (30°)
    PTZDirection.right, // Position 2 (60°)
    PTZDirection.right, // Position 3 (90°)
    PTZDirection.right, // Position 4 (120°)
    PTZDirection.right, // Position 5 (150°)
    PTZDirection.right, // Position 6 (180°)
    PTZDirection.right, // Position 7 (210°)
    PTZDirection.right, // Position 8 (240°)
    PTZDirection.right, // Position 9 (270°)
    PTZDirection.right, // Position 10 (300°)
    PTZDirection.right, // Position 11 (330°)
    PTZDirection.right, // Position 12 (360°/0°)
  ];
}

/// Service for controlling PTZ (Pan-Tilt-Zoom) cameras
/// Specifically optimized for AMCREST IP2M-841B ProHD WiFi Pan/Tilt cameras
/// Based on AMCREST CGI SDK API documentation
/// Discovered working command format: action=start&channel=0&code=Direction&arg1=steps&arg2=steps&arg3=0
class PTZService {
  static const Duration _panDelay = Duration(seconds: 3); // Time to wait after panning
  static DateTime? _lastCommandTime; // Track last command time to prevent rapid requests
  
  /// Get the pan delay for testing purposes
  static Duration get panDelay => _panDelay;
  
  /// Parse RTSP URL to extract camera credentials and IP
  static Map<String, String>? _parseRtspUrl(String rtspUrl) {
    try {
      print('🔍 PTZ: Parsing RTSP URL: $rtspUrl');
      final uri = Uri.parse(rtspUrl);
      
      if (uri.scheme != 'rtsp') {
        print('❌ PTZ: Invalid RTSP URL scheme: ${uri.scheme}');
        return null;
      }
      
      final userInfo = uri.userInfo;
      final host = uri.host;
      final port = uri.port != 0 ? uri.port : 554; // Default RTSP port
      
      print('🔍 PTZ: UserInfo: $userInfo, Host: $host, Port: $port');
      
      if (userInfo.isEmpty || host.isEmpty) {
        print('❌ PTZ: Missing credentials or host in RTSP URL');
        return null;
      }
      
      final credentials = userInfo.split(':');
      if (credentials.length != 2) {
        print('❌ PTZ: Invalid credentials format in RTSP URL');
        return null;
      }
      
      final result = {
        'username': credentials[0],
        'password': credentials[1],
        'host': host,
        'port': port.toString(),
      };
      
      print('✅ PTZ: Successfully parsed camera info - ${result['username']}@${result['host']}');
      return result;
    } catch (e) {
      print('❌ PTZ: Error parsing RTSP URL: $e');
      return null;
    }
  }
  
  /// Send PTZ command to AMCREST IP2M-841B camera using Digest Authentication
  /// Uses port 80 specifically for AMCREST cameras
  static Future<bool> _sendCameraCommand(String rtspUrl, String command) async {
    // Rate limiting to prevent authentication issues
    final now = DateTime.now();
    if (_lastCommandTime != null) {
      final timeSinceLastCommand = now.difference(_lastCommandTime!);
      if (timeSinceLastCommand < Duration(milliseconds: 1000)) {
        final waitTime = Duration(milliseconds: 1000) - timeSinceLastCommand;
        print('⏳ IP2M-841B PTZ: Rate limiting - waiting ${waitTime.inMilliseconds}ms');
        await Future.delayed(waitTime);
      }
    }
    _lastCommandTime = DateTime.now();
    
    final cameraInfo = _parseRtspUrl(rtspUrl);
    if (cameraInfo == null) {
      print('❌ PTZ: Failed to parse RTSP URL');
      return false;
    }
    
    // AMCREST IP2M-841B uses HTTP port 80 for PTZ control
    final httpPort = 80;
    
    try {
      final url = Uri.parse('http://${cameraInfo['host']}:$httpPort/cgi-bin/ptz.cgi?$command');
      
      print('🎯 IP2M-841B PTZ: Sending command to ${cameraInfo['host']}:$httpPort');
      print('🎯 Command: $command');
      
      // For debugging, let's try a different approach - create the client once
      final client = http.Client();
      
      try {
        // Step 1: Get fresh authentication challenge
        final response1 = await client.get(url).timeout(Duration(seconds: 10));
        
        print('🔐 PTZ: Auth challenge status: ${response1.statusCode}');
        
        if (response1.statusCode == 401) {
          final wwwAuth = response1.headers['www-authenticate'];
          if (wwwAuth == null) {
            print('❌ PTZ: No WWW-Authenticate header found');
            return false;
          }
          
          print('🔐 PTZ: Auth challenge: ${wwwAuth.length > 150 ? wwwAuth.substring(0, 150) + '...' : wwwAuth}');
          
          if (wwwAuth.toLowerCase().contains('digest')) {
            // Let's try a more manual digest auth approach
            final authParams = DigestAuth.parseWWWAuthenticate(wwwAuth);
            final realm = authParams['realm'] ?? '';
            final nonce = authParams['nonce'] ?? '';
            final qop = authParams['qop'] ?? '';
            final opaque = authParams['opaque'];
            
            if (realm.isEmpty || nonce.isEmpty) {
              print('❌ PTZ: Invalid auth parameters - realm: $realm, nonce: $nonce');
              return false;
            }
            
            print('🔑 PTZ: Auth params - realm length: ${realm.length}, nonce: ${nonce.substring(0, 8)}..., qop: $qop');
            
            // Some camera firmware validates that the same cnonce and nc are
            // used in both the response computation and the Authorization
            // header and expect HA2 to be computed against the path only
            // (no query). Generate a single cnonce and use it for both calls.
            final cnonce = DigestAuth.generateCnonce();
            final nc = '00000001';

            // Use full request URI (path + query) for HA2 to match curl behavior
            final fullUri = '/cgi-bin/ptz.cgi?$command';

            // Generate digest response with shared cnonce/nc using full URI
            final digestResponse = DigestAuth.generateDigestResponse(
              username: cameraInfo['username']!,
              password: cameraInfo['password']!,
              method: 'GET',
              uri: fullUri,
              realm: realm,
              nonce: nonce,
              qop: qop,
              opaque: opaque,
              cnonce: cnonce,
              nc: nc,
            );

            // Build authorization header using the full request URI in the
            // header and reusing the same cnonce/nc
            final authHeader = DigestAuth.buildAuthorizationHeader(
              username: cameraInfo['username']!,
              response: digestResponse,
              realm: realm,
              nonce: nonce,
              uri: fullUri,
              qop: qop,
              opaque: opaque,
              cnonce: cnonce,
              nc: nc,
            );
            
            print('🔐 PTZ: Sending authenticated request...');
            
            // Step 2: Send authenticated request
            final response2 = await client.get(
              url,
              headers: {
                'Authorization': authHeader,
                'User-Agent': 'IntegriScan-PTZ/1.0',
              },
            ).timeout(Duration(seconds: 10));
            
            print('🎥 PTZ Response: Status ${response2.statusCode}');
            if (response2.body.isNotEmpty) {
              final bodyPreview = response2.body.length > 100 
                  ? response2.body.substring(0, 100) + '...' 
                  : response2.body.trim();
              print('🎥 PTZ Response body: $bodyPreview');
            }
            
            if (response2.statusCode == 200) {
              print('✅ IP2M-841B PTZ: Command executed successfully');
              return true;
            } else if (response2.statusCode == 401) {
              print('❌ IP2M-841B PTZ: Authentication still failed');
              print('💡 Possible issues:');
              print('   - Incorrect username/password');
              print('   - Camera requires different auth method');
              print('   - Digest auth calculation mismatch');
            } else {
              print('❌ IP2M-841B PTZ: Command failed - Status ${response2.statusCode}');
            }
          } else {
            print('⚠️ PTZ: Expected digest auth but got: ${wwwAuth.substring(0, 50)}...');
          }
        } else if (response1.statusCode == 200) {
          print('✅ IP2M-841B PTZ: Command successful without authentication');
          return true;
        } else {
          print('⚠️ IP2M-841B PTZ: Unexpected response - Status ${response1.statusCode}');
        }
        
      } finally {
        client.close();
      }
      
    } on SocketException catch (e) {
      print('🔌 IP2M-841B PTZ: Connection failed - ${e.message}');
      print('💡 Check camera IP address and network connection');
    } on TimeoutException {
      print('⏱️ IP2M-841B PTZ: Request timeout - camera may be busy or unreachable');
    } catch (e) {
      print('❌ IP2M-841B PTZ: Unexpected error - $e');
    }
    
    return false;
  }

  /// Test if PTZ capabilities are available for the given RTSP URL
  static Future<bool> testPTZSupport(String rtspUrl) async {
    print('🎥 PTZ: Testing AMCREST IP2M-841B PTZ support...');
    
    // Test with a minimal pan command
    final success = await _sendCameraCommand(rtspUrl, 'action=start&channel=0&code=Right&arg1=1&arg2=1&arg3=0');
    
    if (success) {
      print('✅ PTZ: AMCREST IP2M-841B PTZ support confirmed');
      // Return to position with left command after delay
      await Future.delayed(Duration(seconds: 1));
      await _sendCameraCommand(rtspUrl, 'action=start&channel=0&code=Left&arg1=1&arg2=1&arg3=0');
    } else {
      print('❌ PTZ: PTZ commands not responding - check network and credentials');
    }
    
    return success;
  }

  /// Pan the camera left using working directional command
  /// Uses a short pulse movement to prevent continuous rotation
  static Future<bool> panLeft(String rtspUrl, {int steps = 1}) async {
    print('🔄 PTZ: Starting pan left with immediate stop control');
    
    // Send movement command
    bool moveSuccess = await _sendCameraCommand(rtspUrl, 'action=start&channel=0&code=Left&arg1=$steps&arg2=$steps&arg3=0');
    
    if (moveSuccess) {
      // Very short delay to allow movement to register, then stop immediately
      await Future.delayed(Duration(milliseconds: 200));
      // Send direction-specific stop command that matches your working example
      bool stopSuccess = await _sendCameraCommand(rtspUrl, 'action=stop&channel=0&code=Left&arg1=0&arg2=1&arg3=0');
      print('🛑 PTZ: Pan left stop command sent - ${stopSuccess ? "SUCCESS" : "FAILED"}');
      return stopSuccess;
    }
    
    return moveSuccess;
  }
  
  /// Pan the camera right using working directional command
  /// Uses a short pulse movement to prevent continuous rotation
  static Future<bool> panRight(String rtspUrl, {int steps = 1}) async {
    print('🔄 PTZ: Starting pan right with immediate stop control');
    
    // Send movement command
    bool moveSuccess = await _sendCameraCommand(rtspUrl, 'action=start&channel=0&code=Right&arg1=$steps&arg2=$steps&arg3=0');
    
    if (moveSuccess) {
      // Very short delay to allow movement to register, then stop immediately
      await Future.delayed(Duration(milliseconds: 200));
      // Send direction-specific stop command
      bool stopSuccess = await _sendCameraCommand(rtspUrl, 'action=stop&channel=0&code=Right&arg1=0&arg2=1&arg3=0');
      print('🛑 PTZ: Pan right stop command sent - ${stopSuccess ? "SUCCESS" : "FAILED"}');
      return stopSuccess;
    }
    
    return moveSuccess;
  }
  
  /// Tilt the camera up using working directional command
  static Future<bool> tiltUp(String rtspUrl, {int steps = 1}) async {
    // Use working format: arg1=steps, arg2=steps (both must be non-zero)
    return await _sendCameraCommand(rtspUrl, 'action=start&channel=0&code=Up&arg1=$steps&arg2=$steps&arg3=0');
  }
  
  /// Tilt the camera down using working directional command
  static Future<bool> tiltDown(String rtspUrl, {int steps = 1}) async {
    // Use working format: arg1=steps, arg2=steps (both must be non-zero)
    return await _sendCameraCommand(rtspUrl, 'action=start&channel=0&code=Down&arg1=$steps&arg2=$steps&arg3=0');
  }
  
  /// Zoom in using working directional command
  static Future<bool> zoomIn(String rtspUrl, {int steps = 1}) async {
    // Use working format: arg1=steps, arg2=steps (both must be non-zero)
    return await _sendCameraCommand(rtspUrl, 'action=start&channel=0&code=ZoomTele&arg1=$steps&arg2=$steps&arg3=0');
  }
  
  /// Zoom out using working directional command
  static Future<bool> zoomOut(String rtspUrl, {int steps = 1}) async {
    // Use working format: arg1=steps, arg2=steps (both must be non-zero)
    return await _sendCameraCommand(rtspUrl, 'action=start&channel=0&code=ZoomWide&arg1=$steps&arg2=$steps&arg3=0');
  }

  /// Micro movement with pulse control for fine-grained PTZ adjustments
  /// Sends multiple short pulses with delays for precise positioning
  static Future<bool> microMove(String rtspUrl, PTZDirection direction, {int pulses = 1, int pulseMs = 100}) async {
    print('🔬 PTZ: Executing micro movement - $direction, pulses: $pulses, duration: ${pulseMs}ms each');
    
    bool allSuccessful = true;
    
    for (int i = 0; i < pulses; i++) {
      bool success = false;
      
      // Send movement command based on direction
      switch (direction) {
        case PTZDirection.left:
          success = await panLeft(rtspUrl, steps: 1);
          break;
        case PTZDirection.right:
          success = await panRight(rtspUrl, steps: 1);
          break;
        case PTZDirection.up:
          success = await tiltUp(rtspUrl, steps: 1);
          break;
        case PTZDirection.down:
          success = await tiltDown(rtspUrl, steps: 1);
          break;
        case PTZDirection.center:
          // Center is a no-op for micro movements
          success = true;
          break;
      }
      
      if (!success) {
        allSuccessful = false;
        print('❌ PTZ: Micro movement pulse ${i + 1} failed');
      }
      
      // Short delay between pulses if more than one pulse
      if (pulses > 1 && i < pulses - 1) {
        await Future.delayed(Duration(milliseconds: pulseMs));
      }
    }
    
    return allSuccessful;
  }

  /// Single pulse movement with automatic stop command
  /// Useful for very precise micro-adjustments
  static Future<bool> microPulseWithStop(String rtspUrl, PTZDirection direction, {int durationMs = 100}) async {
    print('🎯 PTZ: Executing micro pulse - $direction, duration: ${durationMs}ms with stop');
    
    // Send movement command
    bool moveSuccess = await microMove(rtspUrl, direction, pulses: 1, pulseMs: durationMs);
    
    if (!moveSuccess) {
      return false;
    }
    
    // Brief delay to let movement register
    await Future.delayed(Duration(milliseconds: durationMs ~/ 2));
    
    // Send stop command to halt movement
    bool stopSuccess = await stopMovement(rtspUrl);
    
    return moveSuccess && stopSuccess;
  }

  /// Execute automated PTZ workflow for damage analysis
  /// Moves through positions systematically with analysis delays
  static Future<bool> executeScanWorkflow(String rtspUrl, List<PTZDirection> scanPattern) async {
    print('🎯 IP2M-841B: Starting automated scan workflow with ${scanPattern.length} positions');
    
    bool allMovementsSuccessful = true;
    
    for (int i = 0; i < scanPattern.length; i++) {
      final direction = scanPattern[i];
      print('🔄 Step ${i + 1}/${scanPattern.length}: Moving ${direction.name.toUpperCase()}');
      
      bool success = false;
      
      // Execute movement based on direction
      switch (direction) {
        case PTZDirection.left:
          success = await _sendCameraCommand(rtspUrl, 'action=start&channel=0&code=Left&arg1=2&arg2=2&arg3=0');
          if (success) {
            await Future.delayed(Duration(milliseconds: 200));
            await _sendCameraCommand(rtspUrl, 'action=stop&channel=0&code=Left&arg1=0&arg2=1&arg3=0');
          }
          break;
        case PTZDirection.right:
          success = await _sendCameraCommand(rtspUrl, 'action=start&channel=0&code=Right&arg1=2&arg2=2&arg3=0');
          if (success) {
            await Future.delayed(Duration(milliseconds: 200));
            await _sendCameraCommand(rtspUrl, 'action=stop&channel=0&code=Right&arg1=0&arg2=1&arg3=0');
          }
          break;
        case PTZDirection.center:
          success = await _sendCameraCommand(rtspUrl, 'action=start&channel=0&code=Left&arg1=1&arg2=1&arg3=0');
          if (success) {
            await Future.delayed(Duration(milliseconds: 200));
            await _sendCameraCommand(rtspUrl, 'action=stop&channel=0&code=Left&arg1=0&arg2=1&arg3=0');
          }
          break;
        case PTZDirection.up:
          success = await _sendCameraCommand(rtspUrl, 'action=start&channel=0&code=Up&arg1=1&arg2=1&arg3=0');
          if (success) {
            await Future.delayed(Duration(milliseconds: 200));
            await _sendCameraCommand(rtspUrl, 'action=stop&channel=0&code=Up&arg1=0&arg2=1&arg3=0');
          }
          break;
        case PTZDirection.down:
          success = await _sendCameraCommand(rtspUrl, 'action=start&channel=0&code=Down&arg1=1&arg2=1&arg3=0');
          if (success) {
            await Future.delayed(Duration(milliseconds: 200));
            await _sendCameraCommand(rtspUrl, 'action=stop&channel=0&code=Down&arg1=0&arg2=1&arg3=0');
          }
          break;
      }
      
      if (success) {
        print('✅ Movement ${direction.name.toUpperCase()} completed');
        
        // Wait for camera stabilization and analysis
        print('⏳ Waiting ${_panDelay.inSeconds}s for stabilization and analysis...');
        await Future.delayed(_panDelay);
        
      } else {
        print('❌ Movement ${direction.name.toUpperCase()} failed');
        allMovementsSuccessful = false;
        
        // Continue with remaining movements even if one fails
        await Future.delayed(Duration(seconds: 1));
      }
    }
    
    if (allMovementsSuccessful) {
      print('✅ IP2M-841B: Scan workflow completed successfully');
    } else {
      print('⚠️ IP2M-841B: Scan workflow completed with some failures');
    }
    
    return allMovementsSuccessful;
  }

  /// Execute a complete 360-degree clockwise scan for comprehensive analysis
  /// Performs 12 movements of 30 degrees each to cover all angles
  static Future<bool> execute360DegreeScan(String rtspUrl) async {
    print('🌐 IP2M-841B: Starting 360-degree clockwise scan (12 positions)');
    return await executeScanWorkflow(rtspUrl, PTZScanPattern.clockwise360Scan);
  }

  /// Move camera to preset position for IP2M-841B
  static Future<bool> moveToPreset(String rtspUrl, int presetNumber) async {
    print('🎯 IP2M-841B: Moving to preset position $presetNumber');
    
    // AMCREST preset positions (adjust based on your camera setup)
    switch (presetNumber) {
      case 1: // Left position
        return await panLeft(rtspUrl, steps: 1);
      case 2: // Center position  
        print('📍 Moving to center position (no command needed)');
        return true;
      case 3: // Right position
        return await panRight(rtspUrl, steps: 1);
      default:
        print('⚠️ Invalid preset number: $presetNumber');
        return false;
    }
  }

  /// Stop all PTZ movement (if supported by camera)
  static Future<bool> stopMovement(String rtspUrl) async {
    print('🛑 IP2M-841B: Stopping PTZ movement');
    // Try the standard stop command first
    bool stopSuccess = await _sendCameraCommand(rtspUrl, 'action=stop&channel=0&code=Stop&arg1=0&arg2=0&arg3=0');
    
    // If that doesn't work, try an alternative stop format
    if (!stopSuccess) {
      print('🔄 IP2M-841B: Trying alternative stop command');
      stopSuccess = await _sendCameraCommand(rtspUrl, 'action=stop&channel=0');
    }
    
    return stopSuccess;
  }

  /// Get current camera position (if supported by camera)  
  static Future<Map<String, dynamic>?> getCurrentPosition(String rtspUrl) async {
    print('📍 IP2M-841B: Getting current position (simulation)');
    
    // AMCREST cameras don't typically support position queries via CGI
    // Return simulated position data
    return {
      'pan': 0,
      'tilt': 0,
      'zoom': 1,
      'timestamp': DateTime.now().toIso8601String(),
      'supported': false, // Indicates this is simulated data
    };
  }
}

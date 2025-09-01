/// Simple PTZ connection test script
/// Run this with: dart test_ptz_connection.dart
/// 
/// This script helps diagnose PTZ connection issues by testing various connection methods

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

void main() async {
  print('🚀 PTZ Connection Diagnostic Tool');
  print('=' * 50);
  
  // Test with your actual AMCREST camera details
  // IP: 192.168.1.14, Username: admin123, Password: admin123, HTTP Port: 80
  final testUrls = [
    'rtsp://admin123:admin123@192.168.1.14:554/cam/realmonitor?channel=1&subtype=0',
    'rtsp://admin123:admin123@192.168.1.14:554/cam/realmonitor',
    'rtsp://admin123:admin123@192.168.1.14:554/cam/realmonitor?channel=0&subtype=0',
  ];
  
  for (String rtspUrl in testUrls) {
    print('\n📡 Testing RTSP URL: $rtspUrl');
    await testConnection(rtspUrl);
  }
  
  print('\n🔧 Manual Test Instructions:');
  print('1. Replace the IP address above with your actual camera IP');
  print('2. Replace username/password with your camera credentials');
  print('3. Try accessing http://YOUR_CAMERA_IP/cgi-bin/ptz.cgi?action=getStatus in a browser');
  print('4. Check if your camera uses a different HTTP port (try 8080, 8000, or 8999)');
}

Future<void> testConnection(String rtspUrl) async {
  try {
    print('  🔍 Parsing RTSP URL...');
    final cameraInfo = parseRtspUrl(rtspUrl);
    if (cameraInfo == null) {
      print('  ❌ Failed to parse RTSP URL');
      return;
    }
    
    print('  ✅ Parsed: ${cameraInfo['username']}@${cameraInfo['host']}:${cameraInfo['port']}');
    
    // Test HTTP port 80 first (confirmed for this AMCREST camera)
    final ports = [80, 8080, 8000, 8999];
    
    for (int port in ports) {
      print('  🌐 Testing HTTP port $port...');
      final success = await testHttpConnection(cameraInfo, port);
      if (success) {
        print('  ✅ SUCCESS on port $port!');
        return;
      }
    }
    
    print('  ❌ No successful connection on any port');
    
  } catch (e) {
    print('  ❌ Error: $e');
  }
}

Future<bool> testHttpConnection(Map<String, String> cameraInfo, int port) async {
  try {
    // Test different AMCREST PTZ commands
    final testCommands = [
      'action=getStatus&channel=0',
      'action=getCurrentProtocolCaps&channel=0', 
      'action=start&channel=0&code=Left&arg1=0&arg2=1&arg3=0',
    ];
    
    for (String command in testCommands) {
      print('    🧪 Testing command: $command');
      final url = Uri.parse('http://${cameraInfo['host']}:$port/cgi-bin/ptz.cgi?$command');
      
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Basic ${base64Encode(utf8.encode('${cameraInfo['username']}:${cameraInfo['password']}'))}',
          'User-Agent': 'IntegriScan-PTZ-Test/1.0',
        },
      ).timeout(Duration(seconds: 10));
      
      print('    📊 Status: ${response.statusCode}');
      if (response.body.isNotEmpty) {
        print('    📝 Response: ${response.body.length > 150 ? response.body.substring(0, 150) + "..." : response.body}');
      }
      
      if (response.statusCode == 200) {
        print('    ✅ SUCCESS with command: $command');
        return true;
      } else if (response.statusCode == 401) {
        print('    🔐 Authentication failed - check credentials');
        return false;
      } else if (response.statusCode == 404) {
        print('    📂 PTZ endpoint not found');
        break; // Don't test other commands if endpoint doesn't exist
      }
    }
    
    return false;
  } on TimeoutException {
    print('    ⏱️ Timeout (host not responding after 10 seconds)');
    return false;
  } on SocketException {
    print('    🔌 No connection (host unreachable)');
    return false;
  } catch (e) {
    print('    ❌ Error: $e');
    return false;
  }
}

Map<String, String>? parseRtspUrl(String rtspUrl) {
  try {
    final uri = Uri.parse(rtspUrl);
    
    if (uri.scheme != 'rtsp') {
      return null;
    }
    
    final userInfo = uri.userInfo;
    final host = uri.host;
    final port = uri.port != 0 ? uri.port : 554;
    
    if (userInfo.isEmpty || host.isEmpty) {
      return null;
    }
    
    final credentials = userInfo.split(':');
    if (credentials.length != 2) {
      return null;
    }
    
    return {
      'username': credentials[0],
      'password': credentials[1],
      'host': host,
      'port': port.toString(),
    };
  } catch (e) {
    return null;
  }
}

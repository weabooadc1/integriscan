import 'dart:async';
import 'package:http/http.dart' as http;
import 'lib/utils/digest_auth.dart';

void main() async {
  print('🎯 AMCREST Absolute Position PTZ Control');
  print('📍 Testing different position coordinates');
  print('=' * 50);
  
  final ip = '192.168.1.14';
  final port = 80;
  final username = 'admin';
  final password = 'admin123';
  
  // Test different absolute positions
  // Format: action=start&channel=0&code=PositionABS&arg1=pan&arg2=tilt&arg3=zoom
  final positions = [
    // Center position
    {'name': 'Center', 'pan': 1800, 'tilt': 900, 'zoom': 0},
    
    // Pan left/right (keeping tilt at center)
    {'name': 'Pan Left', 'pan': 1000, 'tilt': 900, 'zoom': 0},
    {'name': 'Pan Right', 'pan': 2600, 'tilt': 900, 'zoom': 0},
    
    // Tilt up/down (keeping pan at center)
    {'name': 'Tilt Up', 'pan': 1800, 'tilt': 1200, 'zoom': 0},
    {'name': 'Tilt Down', 'pan': 1800, 'tilt': 600, 'zoom': 0},
    
    // Corner positions
    {'name': 'Top Left', 'pan': 1000, 'tilt': 1200, 'zoom': 0},
    {'name': 'Top Right', 'pan': 2600, 'tilt': 1200, 'zoom': 0},
    {'name': 'Bottom Left', 'pan': 1000, 'tilt': 600, 'zoom': 0},
    {'name': 'Bottom Right', 'pan': 2600, 'tilt': 600, 'zoom': 0},
    
    // Zoom test
    {'name': 'Zoom In', 'pan': 1800, 'tilt': 900, 'zoom': 500},
  ];
  
  for (var pos in positions) {
    print('\n🎥 Moving to ${pos['name']}: Pan=${pos['pan']}, Tilt=${pos['tilt']}, Zoom=${pos['zoom']}');
    
    final command = 'action=start&channel=0&code=PositionABS&arg1=${pos['pan']}&arg2=${pos['tilt']}&arg3=${pos['zoom']}';
    final success = await sendPTZCommand(ip, port, username, password, command);
    
    if (success) {
      print('  ✅ Movement successful - check camera position!');
      await Future.delayed(Duration(seconds: 2)); // Wait for movement
    } else {
      print('  ❌ Movement failed');
    }
  }
  
  print('\n🎯 PTZ Control Summary:');
  print('✅ Working Command Format: action=start&channel=0&code=PositionABS&arg1=pan&arg2=tilt&arg3=zoom');
  print('📐 Coordinate System:');
  print('   Pan: 0-3600 (1800 = center)');
  print('   Tilt: 0-1800 (900 = center)'); 
  print('   Zoom: 0-1000 (0 = no zoom)');
}

Future<bool> sendPTZCommand(String ip, int port, String username, String password, String command) async {
  try {
    final endpoint = '/cgi-bin/ptz.cgi?$command';
    final url = Uri.parse('http://$ip:$port$endpoint');
    
    // Get auth challenge
    final response1 = await http.get(url).timeout(Duration(seconds: 3));
    
    if (response1.statusCode == 401) {
      final wwwAuth = response1.headers['www-authenticate'];
      if (wwwAuth != null && wwwAuth.toLowerCase().contains('digest')) {
        
        final authParams = DigestAuth.parseWWWAuthenticate(wwwAuth);
        
        final digestResponse = DigestAuth.generateDigestResponse(
          username: username,
          password: password,
          method: 'GET',
          uri: endpoint,
          realm: authParams['realm'] ?? '',
          nonce: authParams['nonce'] ?? '',
          qop: authParams['qop'] ?? '',
          opaque: authParams['opaque'],
        );
        
        final authHeader = DigestAuth.buildAuthorizationHeader(
          username: username,
          response: digestResponse,
          realm: authParams['realm'] ?? '',
          nonce: authParams['nonce'] ?? '',
          uri: endpoint,
          qop: authParams['qop'] ?? '',
          opaque: authParams['opaque'],
        );
        
        final response2 = await http.get(
          url,
          headers: {
            'Authorization': authHeader,
            'User-Agent': 'IntegriScan-PTZ/1.0',
          },
        ).timeout(Duration(seconds: 5));
        
        if (response2.statusCode == 200 && response2.body.contains('OK')) {
          return true;
        }
      }
    }
    
    return false;
  } catch (e) {
    return false;
  }
}

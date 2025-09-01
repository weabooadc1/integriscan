import 'dart:async';
import 'package:http/http.dart' as http;
import 'lib/utils/digest_auth.dart';

void main() async {
  print('🎥 AMCREST PTZ Movement Test');
  print('📍 Using working endpoint pattern');
  print('=' * 50);
  
  final ip = '192.168.1.14';
  final port = 80;
  final username = 'admin';
  final password = 'admin123';
  
  // Test different PTZ movement commands
  final ptzCommands = [
    'action=start&channel=0&code=Left&arg1=0&arg2=1&arg3=0',
    'action=start&channel=1&code=Left&arg1=0&arg2=1&arg3=0',
    'action=move&channel=0&code=Left&arg1=0&arg2=1&arg3=0',
    'action=control&channel=0&code=Left&arg1=0&arg2=1&arg3=0',
    'action=directControl&channel=0&code=Left&arg1=0&arg2=1&arg3=0',
    'action=doPTZAction&channel=0&code=Left&arg1=0&arg2=1&arg3=0',
  ];
  
  for (String command in ptzCommands) {
    print('\n🧪 Testing PTZ command: $command');
    final success = await testPTZCommand(ip, port, username, password, command);
    if (success) {
      print('🎉 WORKING PTZ COMMAND FOUND!');
      
      // Test other directions with the working command format
      final directions = ['Right', 'Up', 'Down'];
      
      for (String direction in directions) {
        final testCmd = command.replaceAll('Left', direction);
        print('\n🎯 Testing $direction: $testCmd');
        await testPTZCommand(ip, port, username, password, testCmd);
      }
      break;
    }
  }
}

Future<bool> testPTZCommand(String ip, int port, String username, String password, String command) async {
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
            'User-Agent': 'IntegriScan-PTZ-Move/1.0',
          },
        ).timeout(Duration(seconds: 8));
        
        print('  📊 Status: ${response2.statusCode}');
        print('  📝 Response: ${response2.body.isEmpty ? "Empty" : response2.body}');
        
        if (response2.statusCode == 200) {
          print('  ✅ PTZ COMMAND SUCCESS!');
          print('  🎥 Camera should be moving now - check the camera!');
          return true;
        } else {
          print('  ❌ Command failed');
          return false;
        }
      }
    }
    
    return false;
  } catch (e) {
    print('  ❌ Error: $e');
    return false;
  }
}

import 'dart:async';
import 'package:http/http.dart' as http;
import 'lib/utils/digest_auth.dart';

void main() async {
  print('🔍 AMCREST PTZ Command Format Discovery');
  print('📍 Testing different parameter combinations');
  print('=' * 50);
  
  final ip = '192.168.1.14';
  final port = 80;
  final username = 'admin';
  final password = 'admin123';
  
  // Try different parameter combinations based on AMCREST documentation
  final commandVariations = [
    // Standard format
    'action=start&channel=0&code=Left&arg1=0&arg2=1&arg3=0',
    
    // Without arg parameters
    'action=start&channel=0&code=Left',
    'action=start&channel=0&code=PositionABS&arg1=0&arg2=1800&arg3=0',
    
    // Different action types
    'action=moveStart&channel=0&code=Left&arg1=0&arg2=1&arg3=0',
    'action=ptzControl&channel=0&code=Left&arg1=0&arg2=1&arg3=0',
    
    // Different code formats
    'action=start&channel=0&code=LEFT&arg1=0&arg2=1&arg3=0',
    'action=start&channel=0&code=PanLeft&arg1=0&arg2=1&arg3=0',
    'action=start&channel=0&code=DirectionLeft&arg1=0&arg2=1&arg3=0',
    
    // Different channel
    'action=start&channel=1&code=Left&arg1=0&arg2=1&arg3=0',
    
    // Speed variations
    'action=start&channel=0&code=Left&arg1=0&arg2=5&arg3=0',
    'action=start&channel=0&code=Left&arg1=5&arg2=5&arg3=0',
    
    // Continuous movement
    'action=start&channel=0&code=ContinuousMove&arg1=1&arg2=0&arg3=0',
    
    // Stop command
    'action=stop&channel=0&code=Left&arg1=0&arg2=1&arg3=0',
    'action=stop&channel=0',
    
    // Alternative formats from other AMCREST models
    'action=ptz&channel=0&ptz=left',
    'action=ptz&channel=0&move=left&speed=1',
  ];
  
  for (String command in commandVariations) {
    print('\n🧪 Testing: $command');
    
    final success = await testCommand(ip, port, username, password, command);
    if (success) {
      print('🎉 WORKING COMMAND FOUND: $command');
      print('🔄 Testing stop command...');
      await testCommand(ip, port, username, password, 'action=stop&channel=0');
      break;
    }
    
    // Small delay between commands
    await Future.delayed(Duration(milliseconds: 500));
  }
  
  print('\n💡 If no commands work, the issue might be:');
  print('1. Camera firmware doesn\'t support CGI PTZ control');
  print('2. PTZ control requires a different protocol (ONVIF, RTSP commands)');
  print('3. Camera needs specific user agent or headers');
  print('4. PTZ control is locked to specific IP addresses');
}

Future<bool> testCommand(String ip, int port, String username, String password, String command) async {
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
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          },
        ).timeout(Duration(seconds: 8));
        
        print('  📊 Status: ${response2.statusCode}');
        print('  📝 Response: ${response2.body.isEmpty ? "Empty" : response2.body}');
        
        if (response2.statusCode == 200) {
          print('  ✅ SUCCESS!');
          return true;
        } else if (response2.statusCode != 401) {
          print('  🤔 Unexpected status (not 401)');
        }
      }
    } else if (response1.statusCode == 200) {
      print('  ✅ SUCCESS without auth!');
      return true;
    }
    
    return false;
  } catch (e) {
    print('  ❌ Error: $e');
    return false;
  }
}

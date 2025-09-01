import 'dart:async';
import 'package:http/http.dart' as http;
import 'lib/utils/digest_auth.dart';

void main() async {
  print('🎯 AMCREST PTZ Endpoint Discovery');
  print('📍 IP: 192.168.1.14');
  print('=' * 50);
  
  final ip = '192.168.1.14';
  final port = 80;
  final username = 'admin';
  final password = 'admin123';
  
  // Try different PTZ endpoints that AMCREST cameras might use
  final endpoints = [
    '/cgi-bin/ptz.cgi?action=getStatus',
    '/cgi-bin/ptz.cgi?action=getStatus&channel=0',
    '/cgi-bin/ptz.cgi?action=getCurrentProtocolCaps&channel=0',
    '/cgi-bin/configManager.cgi?action=getConfig&name=PTZ',
    '/cgi-bin/devVideoInput.cgi?action=getCaps&channel=0',
    '/cgi-bin/magicBox.cgi?action=getSystemInfo',
    '/doc/page/login.asp',
    '/cgi-bin/snapshot.cgi?channel=1',
  ];
  
  for (String endpoint in endpoints) {
    print('\n🧪 Testing endpoint: $endpoint');
    await testEndpoint(ip, port, username, password, endpoint);
  }
  
  print('\n💡 Additional checks:');
  print('1. Try accessing http://192.168.1.14 in browser');
  print('2. Check if PTZ is enabled in camera web settings');
  print('3. Verify user has PTZ permissions in camera settings');
  print('4. Check if camera uses different port for PTZ (8080, 8000, etc.)');
}

Future<void> testEndpoint(String ip, int port, String username, String password, String endpoint) async {
  try {
    final url = Uri.parse('http://$ip:$port$endpoint');
    
    // Test 1: Without authentication
    try {
      final response0 = await http.get(url).timeout(Duration(seconds: 3));
      print('  📊 No Auth Status: ${response0.statusCode}');
      
      if (response0.statusCode == 200) {
        print('  ✅ Endpoint accessible without auth!');
        print('  📝 Body: ${response0.body.length > 100 ? response0.body.substring(0, 100) + "..." : response0.body}');
        return;
      }
    } catch (e) {
      // Continue to auth test
    }
    
    // Test 2: With digest authentication
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
            'User-Agent': 'IntegriScan-Discovery/1.0',
          },
        ).timeout(Duration(seconds: 5));
        
        print('  📊 Auth Status: ${response2.statusCode}');
        if (response2.statusCode == 200) {
          print('  ✅ SUCCESS! Endpoint works with auth');
          print('  📝 Body: ${response2.body.length > 150 ? response2.body.substring(0, 150) + "..." : response2.body}');
        } else {
          print('  📝 Body: ${response2.body.isEmpty ? "Empty" : response2.body}');
        }
      }
    } else {
      print('  📊 Direct Status: ${response1.statusCode}');
      if (response1.body.isNotEmpty) {
        print('  📝 Body: ${response1.body.length > 100 ? response1.body.substring(0, 100) + "..." : response1.body}');
      }
    }
    
  } catch (e) {
    print('  ❌ Error: $e');
  }
}

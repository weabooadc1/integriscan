import 'dart:async';
import 'package:http/http.dart' as http;
import 'lib/utils/digest_auth.dart';

void main() async {
  print('🎯 AMCREST Credential Discovery');
  print('📍 IP: 192.168.1.14');
  print('=' * 50);
  
  final ip = '192.168.1.14';
  final port = 80;
  
  // Test with your confirmed working credentials
  final credentialPairs = [
    {'username': 'admin', 'password': 'admin123'},
    {'username': 'admin123', 'password': 'admin123'},
    // Backup options
    {'username': 'admin', 'password': 'admin'},
    {'username': 'admin', 'password': ''},
  ];
  
  for (var creds in credentialPairs) {
    final username = creds['username']!;
    final password = creds['password']!;
    
    print('\n🔑 Testing credentials: $username:$password');
    
    final success = await testCredentials(ip, port, username, password);
    if (success) {
      print('🎉 WORKING CREDENTIALS FOUND: $username:$password');
      break;
    }
  }
}

Future<bool> testCredentials(String ip, int port, String username, String password) async {
  try {
    final url = Uri.parse('http://$ip:$port/cgi-bin/ptz.cgi?action=getStatus&channel=0');
    
    // Get auth challenge
    final response1 = await http.get(url).timeout(Duration(seconds: 5));
    
    if (response1.statusCode == 401) {
      final wwwAuth = response1.headers['www-authenticate'];
      if (wwwAuth != null && wwwAuth.toLowerCase().contains('digest')) {
        
        final authParams = DigestAuth.parseWWWAuthenticate(wwwAuth);
        
        final digestResponse = DigestAuth.generateDigestResponse(
          username: username,
          password: password,
          method: 'GET',
          uri: '/cgi-bin/ptz.cgi?action=getStatus&channel=0',
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
          uri: '/cgi-bin/ptz.cgi?action=getStatus&channel=0',
          qop: authParams['qop'] ?? '',
          opaque: authParams['opaque'],
        );
        
        final response2 = await http.get(
          url,
          headers: {
            'Authorization': authHeader,
            'User-Agent': 'IntegriScan-Cred-Test/1.0',
          },
        ).timeout(Duration(seconds: 5));
        
        print('  📊 Status: ${response2.statusCode}');
        print('  📝 Body: ${response2.body.isEmpty ? "Empty" : response2.body}');
        
        if (response2.statusCode == 200) {
          print('  ✅ SUCCESS!');
          return true;
        } else {
          print('  ❌ Failed');
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

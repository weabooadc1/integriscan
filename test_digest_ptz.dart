import 'package:http/http.dart' as http;
import 'lib/utils/digest_auth.dart';

void main() async {
  print('🎯 AMCREST Digest Auth PTZ Test');
  print('📍 IP: 192.168.1.14');
  print('👤 Credentials: admin123:admin123');
  print('=' * 50);
  
  final ip = '192.168.1.14';
  final username = 'admin123';
  final password = 'admin123';
  final port = 80;
  
  await testDigestPTZ(ip, port, username, password);
}

Future<void> testDigestPTZ(String ip, int port, String username, String password) async {
  try {
    final url = Uri.parse('http://$ip:$port/cgi-bin/ptz.cgi?action=getStatus&channel=0');
    
    print('🧪 Step 1: Getting authentication challenge...');
    final response1 = await http.get(url);
    
    print('📊 Initial Status: ${response1.statusCode}');
    
    if (response1.statusCode == 401) {
      final wwwAuth = response1.headers['www-authenticate'];
      print('🔐 Auth Challenge: $wwwAuth');
      
      if (wwwAuth != null && wwwAuth.toLowerCase().contains('digest')) {
        print('✅ Using Digest Authentication');
        
        // Parse digest challenge
        final authParams = DigestAuth.parseWWWAuthenticate(wwwAuth);
        final realm = authParams['realm'] ?? '';
        final nonce = authParams['nonce'] ?? '';
        final qop = authParams['qop'] ?? '';
        final opaque = authParams['opaque'];
        
        print('  🏰 Realm: $realm');
        print('  🎲 Nonce: $nonce');
        print('  🔒 QOP: $qop');
        
        // Generate digest response
        final digestResponse = DigestAuth.generateDigestResponse(
          username: username,
          password: password,
          method: 'GET',
          uri: '/cgi-bin/ptz.cgi?action=getStatus&channel=0',
          realm: realm,
          nonce: nonce,
          qop: qop,
          opaque: opaque,
        );
        
        // Build authorization header
        final authHeader = DigestAuth.buildAuthorizationHeader(
          username: username,
          response: digestResponse,
          realm: realm,
          nonce: nonce,
          uri: '/cgi-bin/ptz.cgi?action=getStatus&channel=0',
          qop: qop,
          opaque: opaque,
        );
        
        print('🔑 Auth Header: ${authHeader.substring(0, authHeader.length > 100 ? 100 : authHeader.length)}...');
        
        print('🧪 Step 2: Sending authenticated request...');
        final response2 = await http.get(
          url,
          headers: {
            'Authorization': authHeader,
            'User-Agent': 'IntegriScan-Digest-Test/1.0',
          },
        );
        
        print('📊 Authenticated Status: ${response2.statusCode}');
        print('📝 Response Body: ${response2.body.isEmpty ? "Empty" : response2.body}');
        
        if (response2.statusCode == 200) {
          print('🎉 SUCCESS! PTZ endpoint accessible with digest auth');
          
          // Test a simple PTZ command
          print('\n🎥 Testing PTZ command: Pan Left');
          await testPTZCommand(ip, port, username, password);
        } else {
          print('❌ Digest authentication failed: ${response2.statusCode}');
        }
      }
    }
  } catch (e) {
    print('❌ Error: $e');
  }
}

Future<void> testPTZCommand(String ip, int port, String username, String password) async {
  try {
    final url = Uri.parse('http://$ip:$port/cgi-bin/ptz.cgi?action=start&channel=0&code=Left&arg1=0&arg2=1&arg3=0');
    
    // Get auth challenge
    final response1 = await http.get(url);
    
    if (response1.statusCode == 401) {
      final wwwAuth = response1.headers['www-authenticate'];
      if (wwwAuth != null) {
        final authParams = DigestAuth.parseWWWAuthenticate(wwwAuth);
        
        final digestResponse = DigestAuth.generateDigestResponse(
          username: username,
          password: password,
          method: 'GET',
          uri: '/cgi-bin/ptz.cgi?action=start&channel=0&code=Left&arg1=0&arg2=1&arg3=0',
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
          uri: '/cgi-bin/ptz.cgi?action=start&channel=0&code=Left&arg1=0&arg2=1&arg3=0',
          qop: authParams['qop'] ?? '',
          opaque: authParams['opaque'],
        );
        
        final response2 = await http.get(
          url,
          headers: {
            'Authorization': authHeader,
            'User-Agent': 'IntegriScan-PTZ-Command/1.0',
          },
        );
        
        print('🎥 PTZ Command Status: ${response2.statusCode}');
        print('📝 PTZ Response: ${response2.body.isEmpty ? "Empty" : response2.body}');
        
        if (response2.statusCode == 200) {
          print('🎉 PTZ COMMAND SUCCESS! Camera should have moved left');
        }
      }
    }
  } catch (e) {
    print('❌ PTZ Command Error: $e');
  }
}

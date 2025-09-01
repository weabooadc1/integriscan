import 'dart:async';
import 'package:http/http.dart' as http;

void main() async {
  print('🔐 AMCREST Digest Authentication Test');
  print('📍 IP: 192.168.1.14');
  print('=' * 50);
  
  final ip = '192.168.1.14';
  final username = 'admin';
  final password = 'admin123';
  
  await testDigestAuth(ip, username, password);
}

Future<void> testDigestAuth(String ip, String username, String password) async {
  try {
    final url = Uri.parse('http://$ip/cgi-bin/ptz.cgi?action=getStatus&channel=0');
    
    print('🧪 Step 1: Getting authentication challenge...');
    final response1 = await http.get(url).timeout(Duration(seconds: 5));
    
    print('📊 Status: ${response1.statusCode}');
    print('📝 Headers: ${response1.headers}');
    
    if (response1.statusCode == 401) {
      final wwwAuth = response1.headers['www-authenticate'];
      print('🔑 Auth Challenge: $wwwAuth');
      
      if (wwwAuth != null && wwwAuth.toLowerCase().contains('digest')) {
        print('✅ Camera uses Digest Authentication!');
        print('💡 Your camera requires Digest Auth, not Basic Auth');
        print('🛠️  Need to implement digest authentication for PTZ control');
        
        // Parse digest challenge
        final realm = _extractValue(wwwAuth, 'realm');
        final nonce = _extractValue(wwwAuth, 'nonce');
        final qop = _extractValue(wwwAuth, 'qop');
        
        print('  🏰 Realm: $realm');
        print('  🎲 Nonce: $nonce');
        print('  🔒 QOP: $qop');
        
      } else if (wwwAuth != null && wwwAuth.toLowerCase().contains('basic')) {
        print('📋 Camera uses Basic Authentication (as expected)');
        print('❌ But credentials are still failing');
      } else {
        print('❓ Unknown authentication method');
      }
    } else {
      print('🤔 Unexpected response - camera might not require auth');
    }
    
  } catch (e) {
    print('❌ Error: $e');
  }
}

String? _extractValue(String header, String key) {
  final regex = RegExp('$key="([^"]*)"', caseSensitive: false);
  final match = regex.firstMatch(header);
  return match?.group(1);
}

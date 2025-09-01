import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  print('🔐 AMCREST Camera Authentication Test');
  print('📍 IP: 192.168.1.14');
  print('=' * 50);
  
  final ip = '192.168.1.14';
  final port = 80;
  
  // Test different common username/password combinations for AMCREST
  final credentialTests = [
    {'user': 'admin123', 'pass': 'admin123'},
    {'user': 'admin', 'pass': 'admin123'},
    {'user': 'admin123', 'pass': 'admin'},
    {'user': 'admin', 'pass': 'admin'},
    {'user': 'root', 'pass': 'admin123'},
  ];
  
  for (var cred in credentialTests) {
    print('\n🔑 Testing credentials: ${cred['user']}:${cred['pass']}');
    await testCredentials(ip, port, cred['user']!, cred['pass']!);
  }
  
  print('\n💡 Additional troubleshooting:');
  print('1. Try accessing http://192.168.1.14 in your browser');
  print('2. Check if camera requires different authentication method');
  print('3. Verify PTZ feature is enabled in camera settings');
  print('4. Check if camera uses digest authentication instead of basic');
}

Future<void> testCredentials(String ip, int port, String username, String password) async {
  try {
    final auth = base64Encode(utf8.encode('$username:$password'));
    
    // Test different endpoints that might reveal auth success
    final endpoints = [
      '/cgi-bin/ptz.cgi?action=getStatus&channel=0',
      '/cgi-bin/configManager.cgi?action=getConfig&name=PTZ',
      '/cgi-bin/devVideoInput.cgi?action=getCaps&channel=0',
    ];
    
    for (String endpoint in endpoints) {
      final url = Uri.parse('http://$ip:$port$endpoint');
      
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Basic $auth',
          'User-Agent': 'IntegriScan-Auth-Test/1.0',
        },
      ).timeout(Duration(seconds: 5));
      
      print('  📡 $endpoint -> Status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        print('  ✅ SUCCESS! Valid credentials found');
        if (response.body.isNotEmpty) {
          print('  📝 Response: ${response.body.length > 100 ? response.body.substring(0, 100) + "..." : response.body}');
        }
        return; // Found working credentials
      } else if (response.statusCode == 401) {
        print('  🔐 Unauthorized');
      } else if (response.statusCode == 404) {
        print('  📂 Endpoint not found');
      } else {
        print('  ❓ Unexpected status: ${response.statusCode}');
      }
    }
    
  } catch (e) {
    print('  ❌ Error testing credentials: $e');
  }
}

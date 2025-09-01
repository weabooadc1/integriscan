import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  print('🎯 Quick PTZ Test for AMCREST Camera');
  print('📍 IP: 192.168.1.14');
  print('👤 Credentials: admin123:admin123');
  print('🌐 HTTP Port: 80');
  print('=' * 50);
  
  final username = 'admin123';
  final password = 'admin123';
  final ip = '192.168.1.14';
  final port = 80;
  
  // Test 1: Basic connectivity
  print('\n🧪 Test 1: Basic HTTP connectivity');
  await testBasicHttp(ip, port, username, password);
  
  // Test 2: PTZ endpoint
  print('\n🧪 Test 2: PTZ endpoint test');
  await testPTZEndpoint(ip, port, username, password);
  
  // Test 3: Simple PTZ command
  print('\n🧪 Test 3: Simple PTZ command');
  await testPTZCommand(ip, port, username, password);
}

Future<void> testBasicHttp(String ip, int port, String username, String password) async {
  try {
    final url = Uri.parse('http://$ip:$port/');
    print('🌐 Testing: $url');
    
    final response = await http.get(url).timeout(Duration(seconds: 5));
    print('✅ HTTP Status: ${response.statusCode}');
    print('📝 Server: ${response.headers['server'] ?? 'Unknown'}');
    
  } catch (e) {
    print('❌ Basic HTTP test failed: $e');
  }
}

Future<void> testPTZEndpoint(String ip, int port, String username, String password) async {
  try {
    final auth = base64Encode(utf8.encode('$username:$password'));
    final url = Uri.parse('http://$ip:$port/cgi-bin/ptz.cgi?action=getStatus&channel=0');
    
    print('🎯 Testing: $url');
    print('🔑 Auth: Basic $auth');
    
    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Basic $auth',
        'User-Agent': 'IntegriScan-Test/1.0',
      },
    ).timeout(Duration(seconds: 10));
    
    print('✅ PTZ Status: ${response.statusCode}');
    print('📝 Response: ${response.body.isEmpty ? "Empty body" : response.body}');
    
    if (response.statusCode == 401) {
      print('🔐 Authentication failed - check username/password');
    } else if (response.statusCode == 404) {
      print('📂 PTZ endpoint not found - camera may not support PTZ');
    } else if (response.statusCode == 200) {
      print('🎉 PTZ endpoint is accessible!');
    }
    
  } catch (e) {
    print('❌ PTZ endpoint test failed: $e');
  }
}

Future<void> testPTZCommand(String ip, int port, String username, String password) async {
  try {
    final auth = base64Encode(utf8.encode('$username:$password'));
    
    // Test a simple pan left command
    final url = Uri.parse('http://$ip:$port/cgi-bin/ptz.cgi?action=start&channel=0&code=Left&arg1=0&arg2=1&arg3=0');
    
    print('🎯 Testing PTZ command: Pan Left');
    print('🌐 URL: $url');
    
    final response = await http.get(
      url,
      headers: {
        'Authorization': 'Basic $auth',
        'User-Agent': 'IntegriScan-Test/1.0',
      },
    ).timeout(Duration(seconds: 10));
    
    print('✅ Command Status: ${response.statusCode}');
    print('📝 Response: ${response.body.isEmpty ? "Empty body" : response.body}');
    
    if (response.statusCode == 200) {
      print('🎉 PTZ command executed successfully!');
      print('💡 Try observing if the camera actually moved');
    } else {
      print('⚠️ PTZ command may have failed');
    }
    
  } catch (e) {
    print('❌ PTZ command test failed: $e');
  }
}

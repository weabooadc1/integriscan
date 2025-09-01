import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

void main() async {
  print('🔧 AMCREST Authentication Debug Test');
  print('=====================================');
  
  final host = '192.168.1.14';
  final port = 80;
  final username = 'admin';
  final password = 'admin123';
  final command = 'action=start&channel=0&code=Right&arg1=1&arg2=1&arg3=0';
  final url = Uri.parse('http://$host:$port/cgi-bin/ptz.cgi?$command');
  
  print('🎯 Testing AMCREST IP2M-841B authentication methods...');
  print('URL: $url');
  
  // Test 1: Try Basic Authentication (some AMCREST cameras use this)
  print('\n🔄 Test 1: Basic Authentication');
  try {
    final client = http.Client();
    final basicAuth = base64Encode(utf8.encode('$username:$password'));
    
    final response = await client.get(
      url,
      headers: {
        'Authorization': 'Basic $basicAuth',
        'User-Agent': 'IntegriScan-PTZ/1.0',
        'Connection': 'close',
      }
    ).timeout(Duration(seconds: 10));
    
    print('✅ Basic Auth Response: ${response.statusCode}');
    if (response.body.isNotEmpty && response.body.length < 200) {
      print('Response body: ${response.body.trim()}');
    }
    
    if (response.statusCode == 200) {
      print('🎉 SUCCESS! Basic Authentication works');
      client.close();
      return;
    }
    client.close();
  } catch (e) {
    print('❌ Basic Auth Error: $e');
  }
  
  // Test 2: Check what authentication method the camera actually wants
  print('\n🔄 Test 2: Checking Authentication Challenge');
  try {
    final client = http.Client();
    
    final response = await client.get(
      url,
      headers: {
        'User-Agent': 'IntegriScan-PTZ/1.0',
        'Connection': 'close',
      }
    ).timeout(Duration(seconds: 10));
    
    print('Challenge Response: ${response.statusCode}');
    print('Headers:');
    response.headers.forEach((key, value) {
      print('  $key: $value');
    });
    
    if (response.body.isNotEmpty && response.body.length < 300) {
      print('Body: ${response.body.trim()}');
    }
    
    client.close();
  } catch (e) {
    print('❌ Challenge Error: $e');
  }
  
  // Test 3: Try a simple GET to see if the camera responds at all
  print('\n🔄 Test 3: Basic Connection Test');
  try {
    final client = http.Client();
    final testUrl = Uri.parse('http://$host:$port/');
    
    final response = await client.get(
      testUrl,
      headers: {
        'User-Agent': 'IntegriScan-PTZ/1.0',
        'Connection': 'close',
      }
    ).timeout(Duration(seconds: 10));
    
    print('Connection Test: ${response.statusCode}');
    if (response.statusCode == 200) {
      print('✅ Camera is accessible on port 80');
    } else if (response.statusCode == 401) {
      print('✅ Camera requires authentication (expected)');
    }
    
    client.close();
  } catch (e) {
    print('❌ Connection Error: $e');
  }
  
  print('\n📋 Summary:');
  print('If Basic Auth worked, we need to update the PTZ service');
  print('If connection failed, check camera IP and network');
  print('If authentication challenge shows different method, we need to adjust');
}

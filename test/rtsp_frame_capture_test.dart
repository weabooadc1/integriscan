import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'dart:convert';
import 'dart:typed_data';

void main() {
  group('RTSP Frame Capture Authentication Tests', () {
    test('Test Basic Auth header generation', () {
      final username = 'admin';
      final password = 'admin123';
      final credentials = '$username:$password';
      final encodedCredentials = base64Encode(utf8.encode(credentials));
      final expectedHeader = 'Basic $encodedCredentials';
      
      print('Testing Basic Auth:');
      print('  Username: $username');
      print('  Password: $password');
      print('  Credentials: $credentials');
      print('  Base64: $encodedCredentials');
      print('  Header: $expectedHeader');
      
      // Verify the header format
      expect(expectedHeader, startsWith('Basic '));
      expect(expectedHeader, contains(encodedCredentials));
      
      // Decode and verify
      final decoded = utf8.decode(base64Decode(encodedCredentials));
      expect(decoded, equals('admin:admin123'));
    });

    test('Test RTSP URL parsing', () {
      final testUrls = [
        'rtsp://admin:admin123@192.168.1.7:554/cam/realmonitor?channel=1&subtype=0',
        'rtsp://admin:admin123@192.168.1.7/cam/realmonitor?channel=1&subtype=0',
        'rtsp://user:pass@10.0.0.1:554/stream',
      ];
      
      for (final rtspUrl in testUrls) {
        final uri = Uri.parse(rtspUrl);
        print('\nTesting URL: $rtspUrl');
        print('  Host: ${uri.host}');
        print('  Port: ${uri.port}');
        print('  UserInfo: ${uri.userInfo}');
        print('  Path: ${uri.path}');
        
        // Parse credentials
        if (uri.userInfo.isNotEmpty) {
          final parts = uri.userInfo.split(':');
          final username = parts[0];
          final password = parts.length >= 2 ? parts.sublist(1).join(':') : '';
          
          print('  Username: $username');
          print('  Password: $password');
          
          expect(username, isNotEmpty);
          expect(password, isNotEmpty);
        }
      }
    });

    test('Test different snapshot URL formats', () {
      final host = '192.168.1.7';
      final possibleUrls = [
        'http://$host/cgi-bin/snapshot.cgi?channel=1',
        'http://$host/cgi-bin/snapshot.cgi',
        'http://$host/snapshot.cgi?channel=1',
        'http://$host/cgi-bin/api/snapshot?channel=1',
        'http://$host/ISAPI/Streaming/channels/101/picture',
      ];
      
      print('\nPossible snapshot URLs for IP camera at $host:');
      for (final url in possibleUrls) {
        print('  - $url');
      }
      
      expect(possibleUrls, isNotEmpty);
    });

    test('Test HTTP request with Basic Auth', () async {
      final username = 'admin';
      final password = 'admin123';
      final basicAuth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
      
      // Mock successful response
      final mockClient = MockClient((request) async {
        print('\nMock HTTP Request:');
        print('  URL: ${request.url}');
        print('  Method: ${request.method}');
        print('  Headers: ${request.headers}');
        
        // Verify Authorization header
        expect(request.headers['Authorization'], equals(basicAuth));
        expect(request.headers['User-Agent'], equals('IntegriScan/1.0'));
        
        // Return mock image data
        return http.Response.bytes(
          Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]), // JPEG header
          200,
          headers: {'content-type': 'image/jpeg'},
        );
      });
      
      final response = await mockClient.get(
        Uri.parse('http://192.168.1.7/cgi-bin/snapshot.cgi?channel=1'),
        headers: {
          'Authorization': basicAuth,
          'User-Agent': 'IntegriScan/1.0',
        },
      );
      
      expect(response.statusCode, equals(200));
      expect(response.bodyBytes, isNotEmpty);
      print('  Response Status: ${response.statusCode}');
      print('  Response Bytes: ${response.bodyBytes.length}');
    });

    test('Test different Amcrest camera endpoints', () {
      final testCases = [
        {
          'name': 'Standard Amcrest',
          'url': 'http://192.168.1.7/cgi-bin/snapshot.cgi?channel=1',
        },
        {
          'name': 'Amcrest without channel',
          'url': 'http://192.168.1.7/cgi-bin/snapshot.cgi',
        },
        {
          'name': 'Amcrest with subtype',
          'url': 'http://192.168.1.7/cgi-bin/snapshot.cgi?channel=1&subtype=0',
        },
        {
          'name': 'Alternative path',
          'url': 'http://192.168.1.7/snapshot.cgi?channel=1',
        },
      ];
      
      print('\nAmcrest IP2M-841B possible snapshot endpoints:');
      for (final testCase in testCases) {
        print('  ${testCase['name']}: ${testCase['url']}');
      }
      
      print('\nRecommended: Try each URL manually in browser with credentials');
      print('Browser URL: http://admin:admin123@192.168.1.7/cgi-bin/snapshot.cgi?channel=1');
    });

    test('Diagnose 401 error - possible causes', () {
      print('\n401 Unauthorized Error - Possible Causes:');
      print('1. ❌ Incorrect username or password');
      print('2. ❌ HTTP API disabled in camera settings');
      print('3. ❌ Different authentication method required (Digest Auth)');
      print('4. ❌ Wrong snapshot URL endpoint');
      print('5. ❌ IP address whitelisting enabled');
      print('6. ❌ Camera firmware requires different auth format');
      print('\nSolutions to try:');
      print('1. ✅ Access camera web interface at http://192.168.1.7');
      print('2. ✅ Verify credentials work in web interface');
      print('3. ✅ Check camera settings: Network > HTTP > Enable');
      print('4. ✅ Try snapshot URL in browser first');
      print('5. ✅ Check camera documentation for correct API endpoint');
      print('6. ✅ Consider using Digest Auth instead of Basic Auth');
    });
  });

  group('Integration Test - Manual Camera Test', () {
    test('Instructions for manual testing', () {
      print('\n════════════════════════════════════════');
      print('MANUAL TESTING INSTRUCTIONS');
      print('════════════════════════════════════════');
      print('\n1. Open browser and navigate to:');
      print('   http://192.168.1.7');
      print('\n2. Login with credentials:');
      print('   Username: admin');
      print('   Password: admin123');
      print('\n3. Once logged in, try these snapshot URLs:');
      print('   • http://192.168.1.7/cgi-bin/snapshot.cgi?channel=1');
      print('   • http://192.168.1.7/cgi-bin/snapshot.cgi');
      print('   • http://192.168.1.7/snapshot.cgi');
      print('\n4. If any URL returns an image, that\'s the correct endpoint!');
      print('\n5. Check camera settings:');
      print('   • Setup > Network > HTTP');
      print('   • Ensure HTTP is enabled');
      print('   • Check if authentication is required');
      print('\n6. Alternative: Try curl command:');
      print('   curl -u admin:admin123 http://192.168.1.7/cgi-bin/snapshot.cgi?channel=1 -o test.jpg');
      print('\n7. If curl works but app doesn\'t, the issue is in the app code');
      print('   If curl fails too, it\'s a camera configuration issue');
      print('════════════════════════════════════════\n');
    });
  });
}

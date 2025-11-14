import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:crypto/crypto.dart';

class RtspFrameCaptureService {
  /// Capture a frame directly from RTSP stream (bypassing VLC widget rendering)
  /// This preserves the original camera resolution
  static Future<Uint8List?> captureFrameFromStream(String rtspUrl) async {
    try {
      // Parse RTSP URL to get camera HTTP snapshot endpoint
      final uri = Uri.parse(rtspUrl);
      
      print('📸 Parsed RTSP URL:');
      print('  - Host: ${uri.host}');
      print('  - Port: ${uri.port}');
      print('  - UserInfo: ${uri.userInfo}');
      
      // Extract username and password from userInfo (format: "username:password")
      String? username;
      String? password;
      
      if (uri.userInfo.isNotEmpty) {
        final parts = uri.userInfo.split(':');
        if (parts.length >= 2) {
          username = parts[0];
          password = parts.sublist(1).join(':'); // Handle passwords with colons
        }
      }
      
      if (username == null || password == null) {
        print('❌ No credentials found in RTSP URL');
        return null;
      }
      
      // Try multiple snapshot URL formats for Amcrest cameras
      final snapshotUrls = [
        'http://${uri.host}/cgi-bin/snapshot.cgi?channel=1&subtype=0',
        'http://${uri.host}/cgi-bin/snapshot.cgi?channel=1',
        'http://${uri.host}/cgi-bin/snapshot.cgi',
        'http://${uri.host}/snapshot.cgi?channel=1',
      ];
      
      for (final snapshotUrl in snapshotUrls) {
        print('📸 Trying snapshot URL: $snapshotUrl');
        
        try {
          // Step 1: Try Basic Auth first
          print('🔐 Attempting Basic Authentication...');
          final basicAuth = 'Basic ${base64Encode(utf8.encode('$username:$password'))}';
          
          var response = await http.get(
            Uri.parse(snapshotUrl),
            headers: {
              'Authorization': basicAuth,
              'User-Agent': 'IntegriScan/1.0',
            },
          ).timeout(const Duration(seconds: 3));
          
          if (response.statusCode == 200) {
            print('✅ Basic Auth successful!');
            print('✅ Frame captured: ${response.bodyBytes.length} bytes');
            print('✅ Working URL: $snapshotUrl');
            return response.bodyBytes;
          }
          
          // Step 2: If Basic Auth fails with 401, try Digest Auth
          if (response.statusCode == 401) {
            print('⚠️ Basic Auth failed (401), trying Digest Authentication...');
            
            // Parse WWW-Authenticate header for Digest challenge
            final wwwAuth = response.headers['www-authenticate'] ?? '';
            print('🔐 WWW-Authenticate header: $wwwAuth');
            
            if (wwwAuth.toLowerCase().contains('digest')) {
              final digestResponse = await _digestAuth(
                snapshotUrl,
                username,
                password,
                wwwAuth,
              );
              
              if (digestResponse != null && digestResponse.statusCode == 200) {
                print('✅ Digest Auth successful!');
                print('✅ Frame captured: ${digestResponse.bodyBytes.length} bytes');
                print('✅ Working URL: $snapshotUrl');
                return digestResponse.bodyBytes;
              } else {
                print('❌ Digest Auth failed: ${digestResponse?.statusCode}');
              }
            } else {
              print('⚠️ Server does not support Digest Auth');
            }
          } else {
            print('⚠️ Failed with status ${response.statusCode} for: $snapshotUrl');
          }
        } catch (e) {
          print('⚠️ Error trying $snapshotUrl: $e');
          continue;
        }
      }
      
      // All URLs and auth methods failed
      print('❌ All snapshot URLs and authentication methods failed');
      print('❌ Possible causes:');
      print('   1. Incorrect credentials');
      print('   2. HTTP API disabled in camera settings');
      print('   3. Camera uses different snapshot endpoint');
      print('   4. IP/network restrictions');
      print('📝 Manual test: http://$username:$password@${uri.host}/cgi-bin/snapshot.cgi?channel=1');
      
      return null;
    } catch (e) {
      print('❌ Frame capture error: $e');
      return null;
    }
  }
  
  /// Perform Digest Authentication
  static Future<http.Response?> _digestAuth(
    String url,
    String username,
    String password,
    String wwwAuthHeader,
  ) async {
    try {
      // Parse Digest challenge parameters
      final params = _parseDigestParams(wwwAuthHeader);
      
      final realm = params['realm'] ?? '';
      final nonce = params['nonce'] ?? '';
      final qop = params['qop'] ?? '';
      final opaque = params['opaque'] ?? '';
      final algorithm = params['algorithm'] ?? 'MD5';
      
      print('🔐 Digest parameters:');
      print('   realm: $realm');
      print('   nonce: $nonce');
      print('   qop: $qop');
      print('   algorithm: $algorithm');
      
      if (realm.isEmpty || nonce.isEmpty) {
        print('❌ Invalid Digest challenge - missing realm or nonce');
        return null;
      }
      
      // Generate Digest response
      final uri = Uri.parse(url);
      final nc = '00000001'; // Request counter
      final cnonce = _generateCnonce();
      final method = 'GET';
      
      // Calculate HA1 = MD5(username:realm:password)
      final ha1 = md5.convert(utf8.encode('$username:$realm:$password')).toString();
      
      // Calculate HA2 = MD5(method:uri)
      final ha2 = md5.convert(utf8.encode('$method:${uri.path}${uri.query.isNotEmpty ? '?' + uri.query : ''}')).toString();
      
      // Calculate response
      String responseHash;
      if (qop.isNotEmpty) {
        // response = MD5(HA1:nonce:nc:cnonce:qop:HA2)
        responseHash = md5.convert(utf8.encode('$ha1:$nonce:$nc:$cnonce:$qop:$ha2')).toString();
      } else {
        // response = MD5(HA1:nonce:HA2)
        responseHash = md5.convert(utf8.encode('$ha1:$nonce:$ha2')).toString();
      }
      
      // Build Authorization header
      String authHeader = 'Digest username="$username", realm="$realm", nonce="$nonce", uri="${uri.path}${uri.query.isNotEmpty ? '?' + uri.query : ''}", response="$responseHash"';
      
      if (qop.isNotEmpty) {
        authHeader += ', qop=$qop, nc=$nc, cnonce="$cnonce"';
      }
      
      if (opaque.isNotEmpty) {
        authHeader += ', opaque="$opaque"';
      }
      
      authHeader += ', algorithm=$algorithm';
      
      print('🔐 Digest Authorization header generated');
      
      // Make authenticated request
      final response = await http.get(
        uri,
        headers: {
          'Authorization': authHeader,
          'User-Agent': 'IntegriScan/1.0',
        },
      ).timeout(const Duration(seconds: 5));
      
      return response;
    } catch (e) {
      print('❌ Digest auth error: $e');
      return null;
    }
  }
  
  /// Parse Digest authentication parameters from WWW-Authenticate header
  static Map<String, String> _parseDigestParams(String header) {
    final params = <String, String>{};
    
    // Remove "Digest " prefix
    String paramString = header;
    if (paramString.toLowerCase().startsWith('digest ')) {
      paramString = paramString.substring(7);
    }
    
    // Parse key="value" pairs
    final regex = RegExp(r'(\w+)=("[^"]*"|[^,]*)');
    final matches = regex.allMatches(paramString);
    
    for (final match in matches) {
      final key = match.group(1) ?? '';
      var value = match.group(2) ?? '';
      
      // Remove quotes
      if (value.startsWith('"') && value.endsWith('"')) {
        value = value.substring(1, value.length - 1);
      }
      
      params[key] = value.trim();
    }
    
    return params;
  }
  
  /// Generate client nonce for Digest auth
  static String _generateCnonce() {
    final random = DateTime.now().millisecondsSinceEpoch.toString();
    return md5.convert(utf8.encode(random)).toString().substring(0, 16);
  }
}
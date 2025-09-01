import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Helper class for HTTP Digest Authentication
class DigestAuth {
  static String generateDigestResponse({
    required String username,
    required String password,
    required String method,
    required String uri,
    required String realm,
    required String nonce,
    required String qop,
    String? opaque,
    String? cnonce,
    String? nc,
  }) {
    // Generate cnonce if not provided
    cnonce ??= _generateCnonce();
    nc ??= '00000001';
    
    print('🔐 Generating digest with:');
    print('  👤 Username: $username');
    print('  🏰 Realm: $realm');
    print('  🎲 Nonce: $nonce');
    print('  🌐 URI: $uri');
    print('  🔒 QOP: $qop');
    
    // Calculate HA1 = MD5(username:realm:password)
    final ha1 = _md5Hash('$username:$realm:$password');
    print('  🔑 HA1: $ha1');
    
    // Calculate HA2 = MD5(method:uri)
    final ha2 = _md5Hash('$method:$uri');
    print('  🔑 HA2: $ha2');
    
    // Calculate response based on qop
    String response;
    if (qop.toLowerCase() == 'auth' || qop == '"auth"') {
      final responseInput = '$ha1:$nonce:$nc:$cnonce:auth:$ha2';
      response = _md5Hash(responseInput);
      print('  🔑 Response input: $responseInput');
    } else {
      final responseInput = '$ha1:$nonce:$ha2';
      response = _md5Hash(responseInput);
      print('  🔑 Response input (no qop): $responseInput');
    }
    
    print('  ✅ Final response: $response');
    return response;
  }
  
  static String buildAuthorizationHeader({
    required String username,
    required String response,
    required String realm,
    required String nonce,
    required String uri,
    required String qop,
    String? opaque,
    String? cnonce,
    String? nc,
  }) {
    cnonce ??= _generateCnonce();
    nc ??= '00000001';
    
    // Build header in the same order curl uses (some devices expect this)
    // Order: username, realm, nonce, uri, cnonce, nc, response, qop, opaque
    var header = 'Digest username="$username"';
    header += ', realm="$realm"';
    header += ', nonce="$nonce"';
    header += ', uri="$uri"';

    // Only include cnonce/nc/qop when qop is present
  final cleanQop = qop.replaceAll('"', '');
  if (cleanQop.isNotEmpty && cleanQop.toLowerCase() == 'auth') {
      header += ', cnonce="$cnonce"';
      header += ', nc=$nc';
    }

    // Place response after nc/cnonce to match curl ordering
    header += ', response="$response"';

  if (cleanQop.isNotEmpty && cleanQop.toLowerCase() == 'auth') {
      // Use quoted qop to match server expectations
      header += ', qop="auth"';
    }

    if (opaque != null && opaque.isNotEmpty) {
      header += ', opaque="$opaque"';
    }
    
    print('🎯 Authorization header: $header');
    return header;
  }

  /// Generate a client nonce (cnonce) for Digest auth. Public wrapper so callers
  /// can reuse the same cnonce when computing the response and building the
  /// Authorization header (some devices validate that they match).
  static String generateCnonce() => _generateCnonce();
  
  static Map<String, String> parseWWWAuthenticate(String wwwAuth) {
    final result = <String, String>{};
    
    // Remove "Digest " prefix
    final authParams = wwwAuth.replaceFirst(RegExp(r'^Digest\s+', caseSensitive: false), '');
    
    // Parse key="value" pairs and key=value pairs
    final regex = RegExp(r'(\w+)=(?:"([^"]*)"|([^,\s]+))');
    final matches = regex.allMatches(authParams);
    
    for (final match in matches) {
      final key = match.group(1)!;
      final quotedValue = match.group(2);
      final unquotedValue = match.group(3);
      final value = quotedValue ?? unquotedValue ?? '';
      result[key] = value;
    }
    
    print('🔍 Parsed auth params: $result');
    return result;
  }
  
  static String _md5Hash(String input) {
    final bytes = utf8.encode(input);
    final digest = md5.convert(bytes);
    return digest.toString();
  }
  
  static String _generateCnonce() {
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    return _md5Hash(timestamp).substring(0, 16);
  }
}

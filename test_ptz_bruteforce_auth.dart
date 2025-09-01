import 'dart:convert';
import 'package:http/http.dart' as http;
import 'lib/utils/digest_auth.dart';

// Brute-force a few digest header variants to find a format the camera accepts.
// Edit HOST, USER, PASS, and COMMAND to match your camera before running.

const HOST = '192.168.1.14';
const PORT = 80;
const USER = 'admin';
const PASS = 'admin123';
const COMMAND = 'action=start&channel=0&code=Right&arg1=1&arg2=1&arg3=0';

Future<void> main() async {
  final url = Uri.parse('http://$HOST:$PORT/cgi-bin/ptz.cgi?$COMMAND');
  print('Brute-force digest auth against: $url');

  final client = http.Client();
  try {
    final initial = await client.get(url, headers: {'User-Agent': 'IntegriScan-Brute/1.0'});
    print('Initial status: ${initial.statusCode}');
    final www = initial.headers['www-authenticate'];
    print('WWW-Authenticate: $www');
    if (www == null) return;

    final params = DigestAuth.parseWWWAuthenticate(www);
    final realm = params['realm'] ?? '';
    final nonce = params['nonce'] ?? '';
    final opaque = params['opaque'];

    final ha2Variants = [
      '/cgi-bin/ptz.cgi', // path only
      '/cgi-bin/ptz.cgi?$COMMAND', // full URI
      'cgi-bin/ptz.cgi?$COMMAND', // no leading slash
    ];

    final qopModes = ['', 'auth'];
    final qopQuotedOptions = [true, false];
    final algorithmOptions = [true, false];

    for (final ha2 in ha2Variants) {
      for (final qop in qopModes) {
        for (final qopQuoted in qopQuotedOptions) {
          for (final includeAlg in algorithmOptions) {
            final cnonce = DigestAuth.generateCnonce();
            final nc = '00000001';

            final response = DigestAuth.generateDigestResponse(
              username: USER,
              password: PASS,
              method: 'GET',
              uri: ha2,
              realm: realm,
              nonce: nonce,
              qop: qop,
              opaque: opaque,
              cnonce: cnonce,
              nc: nc,
            );

            // Build header manually to vary ordering/format
            final fullUri = '/cgi-bin/ptz.cgi?$COMMAND';
            final parts = <String>[];
            parts.add('username="${USER}"');
            parts.add('realm="${realm}"');
            parts.add('nonce="${nonce}"');
            parts.add('uri="${fullUri}"');
            parts.add('response="${response}"');
            if (includeAlg) parts.add('algorithm=MD5');
            if (qop.isNotEmpty) {
              final qopPart = qopQuoted ? 'qop="${qop}"' : 'qop=${qop}';
              parts.add(qopPart);
              parts.add('nc=${nc}');
              parts.add('cnonce="${cnonce}"');
            }
            if (opaque != null && opaque.isNotEmpty) parts.add('opaque="${opaque}"');

            final header = 'Digest ' + parts.join(', ');

            print('\n--- Trying: HA2="$ha2", qop="${qop}", qopQuoted=$qopQuoted, alg=$includeAlg ---');
            print('Authorization: $header');

            try {
              final r = await client.get(url, headers: {
                'User-Agent': 'IntegriScan-Brute/1.0',
                'Authorization': header,
                'Connection': 'close',
              }).timeout(Duration(seconds: 6));

              print('Result: ${r.statusCode}');
              if (r.body.isNotEmpty) print('Body: ${r.body.trim()}');

              if (r.statusCode == 200) {
                print('>>> SUCCESS with these parameters <<<');
                return;
              }
            } catch (e) {
              print('Request error: $e');
            }
          }
        }
      }
    }

    print('\nNo variant returned 200.');
  } finally {
    client.close();
  }
}

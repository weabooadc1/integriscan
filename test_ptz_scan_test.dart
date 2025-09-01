import 'dart:async';

import 'lib/services/ptz_service.dart';

Future<void> main() async {
  final rtsp = 'rtsp://admin:admin123@192.168.1.14:554/cam/realmonitor?channel=1&subtype=0';

  print('\n🔍 Running automated scan test (micro-move)');
  final success = await PTZService.executeScanWorkflow(rtsp, PTZScanPattern.horizontalScan);

  print('\nTest complete. Success: $success');
}

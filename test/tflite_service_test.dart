import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:integriscan/services/tflite_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TFLiteService (unit tests)', () {
    test('initialize should enable mock mode in test environment and set initialized', () async {
      // Ensure a clean start
      TFLiteService.dispose();

      final initialized = await TFLiteService.initialize();
      // The initialize method is designed to fallback to mockMode on failure in many CI/test envs
      expect(initialized, isTrue);

      final info = TFLiteService.getModelInfo();
      expect(info, isA<Map<String, dynamic>>());
      expect(info['isInitialized'], isTrue);
      expect(info['mockMode'], isTrue);
      expect(info['labelsCount'], greaterThanOrEqualTo(0));
    });

    test('runInference should return mock-mode result structure and dispose resets state', () async {
      // Ensure initialize has been called
      await TFLiteService.initialize();

      // Provide a small empty image (1x1 pixel JPEG-like bytes will be fine for mock-mode)
      final Uint8List fakeImage = Uint8List.fromList([0, 0, 0]);

      final result = await TFLiteService.runInference(fakeImage);
      expect(result, isA<Map<String, dynamic>>());
      expect(result!.containsKey('mockMode'), isTrue);
      expect(result['mockMode'], isTrue);
      expect(result.containsKey('timestamp'), isTrue);
      expect(result.containsKey('detections'), isTrue);

      // Now dispose and check state
      TFLiteService.dispose();
      final infoAfterDispose = TFLiteService.getModelInfo();
      // After dispose, interpreterAvailable should be false and isInitialized false
      expect(infoAfterDispose['interpreterAvailable'], isFalse);
      expect(infoAfterDispose['isInitialized'], isFalse);
    });
  });
}

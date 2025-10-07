import 'package:flutter_test/flutter_test.dart';
import 'package:integriscan/services/compute_service.dart';
import 'dart:typed_data';
import 'dart:io';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String getTestFramesPath() => '${Directory.current.path}/test_frames';

  tearDownAll(() async {
    final testDir = Directory(getTestFramesPath());
    if (await testDir.exists()) {
      await testDir.delete(recursive: true);
    }
  });

  group('ComputeService.saveImageInBackground', () {
    test('saves image and returns valid path', () async {
      final testBytes = Uint8List.fromList(List.generate(100, (i) => i % 256));
      final result = await ComputeService.saveImageInBackground(
        imageBytes: testBytes,
        damageType: 'Crack',
        confidence: 0.85,
        framesDirectoryPath: getTestFramesPath(),
      );
      
      expect(result, isNotEmpty);
      expect(result, contains('crack'));
      expect(result, contains('85pct'));
      
      final file = File(result);
      expect(await file.exists(), isTrue);
      await file.delete();
    });

    test('sanitizes damage type', () async {
      final result = await ComputeService.saveImageInBackground(
        imageBytes: Uint8List.fromList([1, 2, 3]),
        damageType: 'Test Damage Type',
        confidence: 0.75,
        framesDirectoryPath: getTestFramesPath(),
      );
      
      expect(result, contains('test_damage_type'));
      if (result.isNotEmpty) await File(result).delete();
    });

    test('includes confidence percentage', () async {
      final result = await ComputeService.saveImageInBackground(
        imageBytes: Uint8List.fromList([1, 2, 3]),
        damageType: 'Corrosion',
        confidence: 0.92,
        framesDirectoryPath: getTestFramesPath(),
      );
      
      expect(result, contains('92pct'));
      if (result.isNotEmpty) await File(result).delete();
    });
  });

  group('ComputeService.processDetectionBatch', () {
    test('processes detections', () async {
      final detections = [
        {'damageType': 'Crack', 'confidence': 0.8},
      ];
      
      final result = await ComputeService.processDetectionBatch(detections);
      
      expect(result.length, equals(1));
      expect(result[0]['processed'], equals(true));
    });
  });

  group('ComputeService.runInferenceInBackground', () {
    test('deprecated method returns null', () async {
      final result = await ComputeService.runInferenceInBackground(
        Uint8List.fromList([1, 2, 3])
      );
      expect(result, isNull);
    });
  });
}

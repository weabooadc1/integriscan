import 'package:flutter_test/flutter_test.dart';
import 'package:integriscan/services/tflite_service.dart';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

void main() {
  group('TFLiteService Multiple Detections Tests', () {
    
    /// Helper function to create a test image
    Uint8List createTestImage({int width = 1920, int height = 1080}) {
      final image = img.Image(width, height);
      img.fill(image, img.getColor(128, 128, 128)); // Gray image
      
      // Add some colored rectangles to simulate damage areas
      img.fillRect(image, 100, 100, 200, 150, img.getColor(255, 0, 0)); // Red area
      img.fillRect(image, 500, 300, 600, 400, img.getColor(0, 255, 0)); // Green area
      img.fillRect(image, 900, 500, 1000, 600, img.getColor(0, 0, 255)); // Blue area
      
      return Uint8List.fromList(img.encodePng(image));
    }

    test('Mock mode should return allDetections key (not detections)', () async {
      // Initialize in mock mode (will auto-enable if model not available)
      await TFLiteService.initialize();
      
      final testImageBytes = createTestImage();
      final result = await TFLiteService.runInference(testImageBytes);
      
      expect(result, isNotNull, reason: 'Result should not be null');
      expect(result!.containsKey('allDetections'), isTrue, 
        reason: 'Result must contain allDetections key');
      expect(result.containsKey('detections'), isFalse, 
        reason: 'Result should NOT contain old detections key');
    });

    test('allDetections should be a List', () async {
      await TFLiteService.initialize();
      
      final testImageBytes = createTestImage();
      final result = await TFLiteService.runInference(testImageBytes);
      
      expect(result, isNotNull);
      expect(result!['allDetections'], isA<List>(), 
        reason: 'allDetections must be a List');
    });

    test('Each detection in allDetections should have required fields', () async {
      await TFLiteService.initialize();
      
      final testImageBytes = createTestImage();
      final result = await TFLiteService.runInference(testImageBytes);
      
      expect(result, isNotNull);
      final allDetections = result!['allDetections'] as List;
      
      if (allDetections.isNotEmpty) {
        for (var detection in allDetections) {
          expect(detection, isA<Map>(), reason: 'Each detection should be a Map');
          
          final detectionMap = detection as Map<String, dynamic>;
          
          // Check required fields
          expect(detectionMap.containsKey('label'), isTrue, 
            reason: 'Detection must have label field');
          expect(detectionMap.containsKey('confidence'), isTrue, 
            reason: 'Detection must have confidence field');
          expect(detectionMap.containsKey('box'), isTrue, 
            reason: 'Detection must have box field');
          
          // Validate confidence is between 0 and 1
          final confidence = detectionMap['confidence'] as double;
          expect(confidence, greaterThanOrEqualTo(0.0));
          expect(confidence, lessThanOrEqualTo(1.0));
          
          // Validate bounding box structure
          final box = detectionMap['box'] as Map<String, dynamic>;
          expect(box.containsKey('x'), isTrue);
          expect(box.containsKey('y'), isTrue);
          expect(box.containsKey('width'), isTrue);
          expect(box.containsKey('height'), isTrue);
          
          // Validate bounding box values are normalized (0-1)
          expect(box['x'], greaterThanOrEqualTo(0.0));
          expect(box['x'], lessThanOrEqualTo(1.0));
          expect(box['y'], greaterThanOrEqualTo(0.0));
          expect(box['y'], lessThanOrEqualTo(1.0));
          expect(box['width'], greaterThan(0.0));
          expect(box['width'], lessThanOrEqualTo(1.0));
          expect(box['height'], greaterThan(0.0));
          expect(box['height'], lessThanOrEqualTo(1.0));
        }
      }
    });

    test('Result should have both best detection and allDetections', () async {
      await TFLiteService.initialize();
      
      final testImageBytes = createTestImage();
      final result = await TFLiteService.runInference(testImageBytes);
      
      expect(result, isNotNull);
      
      // Check for best detection fields
      expect(result!.containsKey('isDamageDetected'), isTrue);
      expect(result.containsKey('confidence'), isTrue);
      expect(result.containsKey('damageType'), isTrue);
      expect(result.containsKey('boundingBox'), isTrue);
      
      // Check for allDetections
      expect(result.containsKey('allDetections'), isTrue);
    });

    test('When damage detected, allDetections should not be empty', () async {
      await TFLiteService.initialize();
      
      final testImageBytes = createTestImage();
      final result = await TFLiteService.runInference(testImageBytes);
      
      expect(result, isNotNull);
      
      if (result!['isDamageDetected'] == true) {
        final allDetections = result['allDetections'] as List;
        expect(allDetections.isNotEmpty, isTrue, 
          reason: 'When damage is detected, allDetections should contain at least one detection');
      }
    });

    test('When no damage detected, allDetections should be empty', () async {
      await TFLiteService.initialize();
      
      final testImageBytes = createTestImage();
      final result = await TFLiteService.runInference(testImageBytes);
      
      expect(result, isNotNull);
      
      if (result!['isDamageDetected'] == false) {
        final allDetections = result['allDetections'] as List;
        expect(allDetections.isEmpty, isTrue, 
          reason: 'When no damage is detected, allDetections should be empty');
      }
    });

    test('Damage types in allDetections should be valid', () async {
      await TFLiteService.initialize();
      
      final testImageBytes = createTestImage();
      final result = await TFLiteService.runInference(testImageBytes);
      
      expect(result, isNotNull);
      
      final allDetections = result!['allDetections'] as List;
      final validDamageTypes = ['Crack', 'Corrosion', 'Deformation', 'Rust', 'Scaling', 'No Damage'];
      
      for (var detection in allDetections) {
        final detectionMap = detection as Map<String, dynamic>;
        final label = detectionMap['label'] as String;
        
        // Check if damage type is one of the expected types
        // (may include numbers like "Crack #1" in real usage)
        final baseLabel = label.split('#').first.trim();
        expect(validDamageTypes.any((type) => baseLabel.contains(type)), isTrue,
          reason: 'Label "$label" should contain a valid damage type');
      }
    });

    test('Multiple detections should have different positions', () async {
      await TFLiteService.initialize();
      
      final testImageBytes = createTestImage();
      final result = await TFLiteService.runInference(testImageBytes);
      
      expect(result, isNotNull);
      
      final allDetections = result!['allDetections'] as List;
      
      if (allDetections.length > 1) {
        // Check that bounding boxes are different
        final boxes = allDetections.map((d) => (d as Map<String, dynamic>)['box']).toList();
        
        for (int i = 0; i < boxes.length - 1; i++) {
          for (int j = i + 1; j < boxes.length; j++) {
            final box1 = boxes[i] as Map<String, dynamic>;
            final box2 = boxes[j] as Map<String, dynamic>;
            
            // At least one coordinate should be different
            final isDifferent = 
              box1['x'] != box2['x'] ||
              box1['y'] != box2['y'] ||
              box1['width'] != box2['width'] ||
              box1['height'] != box2['height'];
            
            expect(isDifferent, isTrue, 
              reason: 'Multiple detections should have different bounding boxes');
          }
        }
      }
    });

    test('Best detection should match highest confidence in allDetections', () async {
      await TFLiteService.initialize();
      
      final testImageBytes = createTestImage();
      final result = await TFLiteService.runInference(testImageBytes);
      
      expect(result, isNotNull);
      
      if (result!['isDamageDetected'] == true) {
        final bestConfidence = result['confidence'] as double;
        final allDetections = result['allDetections'] as List;
        
        if (allDetections.isNotEmpty) {
          // Find max confidence in allDetections
          double maxConfidence = 0.0;
          for (var detection in allDetections) {
            final detectionMap = detection as Map<String, dynamic>;
            final conf = detectionMap['confidence'] as double;
            if (conf > maxConfidence) {
              maxConfidence = conf;
            }
          }
          
          expect(bestConfidence, equals(maxConfidence),
            reason: 'Best confidence should match the highest confidence in allDetections');
        }
      }
    });

    test('Image preprocessing should stretch to target size', () {
      // Test the letterbox function directly
      final sourceImage = img.Image(1920, 1080); // 16:9 aspect ratio
      img.fill(sourceImage, img.getColor(128, 128, 128));
      
      final processed = TFLiteService.letterbox(sourceImage, 960);
      
      expect(processed.width, equals(960), 
        reason: 'Processed image width should be exactly 960');
      expect(processed.height, equals(960), 
        reason: 'Processed image height should be exactly 960');
    });

    test('Different input sizes should all result in same output size', () {
      final testSizes = [
        [640, 480],   // 4:3
        [1920, 1080], // 16:9
        [1280, 720],  // 16:9
        [800, 600],   // 4:3
        [1024, 768],  // 4:3
      ];
      
      for (var size in testSizes) {
        final sourceImage = img.Image(size[0], size[1]);
        img.fill(sourceImage, img.getColor(128, 128, 128));
        
        final processed = TFLiteService.letterbox(sourceImage, 960);
        
        expect(processed.width, equals(960), 
          reason: 'Input ${size[0]}x${size[1]} should produce 960x960 output');
        expect(processed.height, equals(960), 
          reason: 'Input ${size[0]}x${size[1]} should produce 960x960 output');
      }
    });

    test('Model info should indicate initialization status', () {
      final modelInfo = TFLiteService.getModelInfo();
      
      expect(modelInfo, isA<Map<String, dynamic>>());
      expect(modelInfo.containsKey('isInitialized'), isTrue);
      expect(modelInfo.containsKey('mockMode'), isTrue);
      expect(modelInfo.containsKey('inputSize'), isTrue);
      expect(modelInfo['inputSize'], equals(960));
    });

    test('Confidence values should be reasonable', () async {
      await TFLiteService.initialize();
      
      final testImageBytes = createTestImage();
      final result = await TFLiteService.runInference(testImageBytes);
      
      expect(result, isNotNull);
      
      final allDetections = result!['allDetections'] as List;
      
      for (var detection in allDetections) {
        final detectionMap = detection as Map<String, dynamic>;
        final confidence = detectionMap['confidence'] as double;
        
        // Confidence should be between 0 and 1
        expect(confidence, greaterThanOrEqualTo(0.0));
        expect(confidence, lessThanOrEqualTo(1.0));
        
        // In mock mode or real detection, confidence above threshold should be > 0.2
        if (result['isDamageDetected'] == true) {
          expect(confidence, greaterThan(0.2),
            reason: 'Detected damage should have confidence above 0.2 threshold');
        }
      }
    });
  });
}

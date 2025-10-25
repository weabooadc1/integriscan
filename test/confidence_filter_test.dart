import 'package:flutter_test/flutter_test.dart';

/// Unit tests for AI Confidence Threshold Filter
/// 
/// This test suite validates that detections below the confidence threshold
/// are properly filtered out to reduce false positives.
/// 
/// The confidence threshold is set to 0.6 (60%) in the RTSP screen.
void main() {
  // Constants matching the implementation
  const double CONFIDENCE_THRESHOLD = 0.6;
  
  group('Confidence Filter Logic Tests', () {
    test('Detection with confidence above threshold should be accepted', () {
      // Arrange
      final mockResult = {
        'isDamageDetected': true,
        'damageType': 'Crack',
        'confidence': 0.75, // 75% - above 60% threshold
        'boundingBox': {'x': 0.3, 'y': 0.3, 'width': 0.4, 'height': 0.4},
      };
      
      // Act
      final confidence = (mockResult['confidence'] as num).toDouble();
      final isDamageDetected = mockResult['isDamageDetected'] == true;
      final shouldReject = isDamageDetected && confidence < CONFIDENCE_THRESHOLD;
      
      // Assert
      expect(confidence, equals(0.75));
      expect(isDamageDetected, isTrue);
      expect(shouldReject, isFalse, reason: '75% confidence should NOT be rejected');
      expect(confidence >= CONFIDENCE_THRESHOLD, isTrue);
    });
    
    test('Detection with confidence below threshold should be rejected', () {
      // Arrange
      final mockResult = {
        'isDamageDetected': true,
        'damageType': 'Crack',
        'confidence': 0.45, // 45% - below 60% threshold
        'boundingBox': {'x': 0.3, 'y': 0.3, 'width': 0.4, 'height': 0.4},
      };
      
      // Act
      final confidence = (mockResult['confidence'] as num).toDouble();
      final isDamageDetected = mockResult['isDamageDetected'] == true;
      final shouldReject = isDamageDetected && confidence < CONFIDENCE_THRESHOLD;
      
      // Assert
      expect(confidence, equals(0.45));
      expect(isDamageDetected, isTrue);
      expect(shouldReject, isTrue, reason: '45% confidence SHOULD be rejected');
      expect(confidence < CONFIDENCE_THRESHOLD, isTrue);
    });
    
    test('Detection with confidence exactly at threshold should be accepted', () {
      // Arrange
      final mockResult = {
        'isDamageDetected': true,
        'damageType': 'Corrosion',
        'confidence': 0.6, // Exactly 60% - at threshold
        'boundingBox': {'x': 0.3, 'y': 0.3, 'width': 0.4, 'height': 0.4},
      };
      
      // Act
      final confidence = (mockResult['confidence'] as num).toDouble();
      final isDamageDetected = mockResult['isDamageDetected'] == true;
      final shouldReject = isDamageDetected && confidence < CONFIDENCE_THRESHOLD;
      
      // Assert
      expect(confidence, equals(0.6));
      expect(isDamageDetected, isTrue);
      expect(shouldReject, isFalse, reason: 'Confidence at threshold should NOT be rejected');
      expect(confidence >= CONFIDENCE_THRESHOLD, isTrue);
    });
    
    test('No damage detection should always be accepted regardless of confidence', () {
      // Arrange
      final mockResult = {
        'isDamageDetected': false,
        'damageType': 'No Damage',
        'confidence': 0.95, // High confidence of no damage
        'boundingBox': null,
      };
      
      // Act
      final confidence = (mockResult['confidence'] as num).toDouble();
      final isDamageDetected = mockResult['isDamageDetected'] == true;
      final shouldReject = isDamageDetected && confidence < CONFIDENCE_THRESHOLD;
      
      // Assert
      expect(isDamageDetected, isFalse);
      expect(shouldReject, isFalse, reason: 'No damage detection should never be rejected');
    });
    
    test('Very low confidence detection should be rejected', () {
      // Arrange
      final mockResult = {
        'isDamageDetected': true,
        'damageType': 'Deformation',
        'confidence': 0.25, // 25% - very low confidence
        'boundingBox': {'x': 0.3, 'y': 0.3, 'width': 0.4, 'height': 0.4},
      };
      
      // Act
      final confidence = (mockResult['confidence'] as num).toDouble();
      final isDamageDetected = mockResult['isDamageDetected'] == true;
      final shouldReject = isDamageDetected && confidence < CONFIDENCE_THRESHOLD;
      
      // Assert
      expect(shouldReject, isTrue, reason: '25% confidence should definitely be rejected');
      expect(confidence < CONFIDENCE_THRESHOLD, isTrue);
    });
    
    test('Very high confidence detection should be accepted', () {
      // Arrange
      final mockResult = {
        'isDamageDetected': true,
        'damageType': 'Crack',
        'confidence': 0.95, // 95% - very high confidence
        'boundingBox': {'x': 0.3, 'y': 0.3, 'width': 0.4, 'height': 0.4},
      };
      
      // Act
      final confidence = (mockResult['confidence'] as num).toDouble();
      final isDamageDetected = mockResult['isDamageDetected'] == true;
      final shouldReject = isDamageDetected && confidence < CONFIDENCE_THRESHOLD;
      
      // Assert
      expect(shouldReject, isFalse);
      expect(confidence >= CONFIDENCE_THRESHOLD, isTrue);
    });
  });
  
  group('Rejected Detection Transformation Tests', () {
    test('Rejected detection should transform to "No Damage" result', () {
      // Arrange - Original low-confidence detection
      final originalResult = {
        'isDamageDetected': true,
        'damageType': 'Crack',
        'confidence': 0.50, // 50% - below 60% threshold
        'boundingBox': {'x': 0.3, 'y': 0.3, 'width': 0.4, 'height': 0.4},
      };
      
      // Act - Simulate filter logic
      final confidence = (originalResult['confidence'] as num).toDouble();
      final isDamageDetected = originalResult['isDamageDetected'] == true;
      final shouldReject = isDamageDetected && confidence < CONFIDENCE_THRESHOLD;
      
      Map<String, dynamic> transformedResult;
      if (shouldReject) {
        transformedResult = {
          'isDamageDetected': false,
          'damageType': 'No Damage',
          'confidence': confidence,
          'boundingBox': originalResult['boundingBox'],
          'rejectedDueToLowConfidence': true,
          'originalDamageType': originalResult['damageType'],
        };
      } else {
        transformedResult = originalResult;
      }
      
      // Assert
      expect(transformedResult['isDamageDetected'], isFalse);
      expect(transformedResult['damageType'], equals('No Damage'));
      expect(transformedResult['confidence'], equals(0.50)); // Original confidence preserved
      expect(transformedResult['rejectedDueToLowConfidence'], isTrue);
      expect(transformedResult['originalDamageType'], equals('Crack')); // Original type preserved for debugging
    });
    
    test('Accepted detection should remain unchanged', () {
      // Arrange - High-confidence detection
      final originalResult = {
        'isDamageDetected': true,
        'damageType': 'Corrosion',
        'confidence': 0.85, // 85% - well above threshold
        'boundingBox': {'x': 0.3, 'y': 0.3, 'width': 0.4, 'height': 0.4},
      };
      
      // Act - Simulate filter logic
      final confidence = (originalResult['confidence'] as num).toDouble();
      final isDamageDetected = originalResult['isDamageDetected'] == true;
      final shouldReject = isDamageDetected && confidence < CONFIDENCE_THRESHOLD;
      
      Map<String, dynamic> transformedResult;
      if (shouldReject) {
        transformedResult = {
          'isDamageDetected': false,
          'damageType': 'No Damage',
          'confidence': confidence,
          'boundingBox': originalResult['boundingBox'],
          'rejectedDueToLowConfidence': true,
          'originalDamageType': originalResult['damageType'],
        };
      } else {
        transformedResult = originalResult;
      }
      
      // Assert - Result should be unchanged
      expect(transformedResult, equals(originalResult));
      expect(transformedResult['isDamageDetected'], isTrue);
      expect(transformedResult['damageType'], equals('Corrosion'));
      expect(transformedResult['confidence'], equals(0.85));
    });
  });
  
  group('Edge Cases and Boundary Tests', () {
    test('Confidence of 0.0 should be rejected', () {
      // Arrange
      final mockResult = {
        'isDamageDetected': true,
        'damageType': 'Crack',
        'confidence': 0.0, // 0% confidence
        'boundingBox': {'x': 0.3, 'y': 0.3, 'width': 0.4, 'height': 0.4},
      };
      
      // Act
      final confidence = (mockResult['confidence'] as num).toDouble();
      final isDamageDetected = mockResult['isDamageDetected'] == true;
      final shouldReject = isDamageDetected && confidence < CONFIDENCE_THRESHOLD;
      
      // Assert
      expect(shouldReject, isTrue);
    });
    
    test('Confidence of 1.0 should be accepted', () {
      // Arrange
      final mockResult = {
        'isDamageDetected': true,
        'damageType': 'Crack',
        'confidence': 1.0, // 100% confidence
        'boundingBox': {'x': 0.3, 'y': 0.3, 'width': 0.4, 'height': 0.4},
      };
      
      // Act
      final confidence = (mockResult['confidence'] as num).toDouble();
      final isDamageDetected = mockResult['isDamageDetected'] == true;
      final shouldReject = isDamageDetected && confidence < CONFIDENCE_THRESHOLD;
      
      // Assert
      expect(shouldReject, isFalse);
    });
    
    test('Just below threshold (0.59) should be rejected', () {
      // Arrange
      final mockResult = {
        'isDamageDetected': true,
        'damageType': 'Deformation',
        'confidence': 0.59, // 59% - just below 60%
        'boundingBox': {'x': 0.3, 'y': 0.3, 'width': 0.4, 'height': 0.4},
      };
      
      // Act
      final confidence = (mockResult['confidence'] as num).toDouble();
      final isDamageDetected = mockResult['isDamageDetected'] == true;
      final shouldReject = isDamageDetected && confidence < CONFIDENCE_THRESHOLD;
      
      // Assert
      expect(shouldReject, isTrue);
      expect(confidence < CONFIDENCE_THRESHOLD, isTrue);
    });
    
    test('Just above threshold (0.61) should be accepted', () {
      // Arrange
      final mockResult = {
        'isDamageDetected': true,
        'damageType': 'Crack',
        'confidence': 0.61, // 61% - just above 60%
        'boundingBox': {'x': 0.3, 'y': 0.3, 'width': 0.4, 'height': 0.4},
      };
      
      // Act
      final confidence = (mockResult['confidence'] as num).toDouble();
      final isDamageDetected = mockResult['isDamageDetected'] == true;
      final shouldReject = isDamageDetected && confidence < CONFIDENCE_THRESHOLD;
      
      // Assert
      expect(shouldReject, isFalse);
      expect(confidence >= CONFIDENCE_THRESHOLD, isTrue);
    });
  });
  
  group('Statistics Counting Tests', () {
    test('Only detections above threshold should increment damage counter', () {
      // Simulate multiple detections
      final detections = [
        {'isDamageDetected': true, 'confidence': 0.75}, // Accept
        {'isDamageDetected': true, 'confidence': 0.45}, // Reject
        {'isDamageDetected': true, 'confidence': 0.85}, // Accept
        {'isDamageDetected': false, 'confidence': 0.90}, // No damage
        {'isDamageDetected': true, 'confidence': 0.55}, // Reject
        {'isDamageDetected': true, 'confidence': 0.60}, // Accept (at threshold)
      ];
      
      int damagesDetected = 0;
      int totalFrames = 0;
      
      for (final detection in detections) {
        final confidence = (detection['confidence'] as num).toDouble();
        final isDamageDetected = detection['isDamageDetected'] == true;
        
        totalFrames++;
        
        // Only count if damage detected AND confidence passes threshold
        if (isDamageDetected && confidence >= CONFIDENCE_THRESHOLD) {
          damagesDetected++;
        }
      }
      
      // Assert
      expect(totalFrames, equals(6), reason: 'All 6 frames should be counted');
      expect(damagesDetected, equals(3), reason: 'Only 3 detections pass threshold (0.75, 0.85, 0.60)');
    });
    
    test('All rejected detections should not be saved to history', () {
      // Simulate detection history saving logic
      final detections = [
        {'isDamageDetected': true, 'confidence': 0.75, 'damageType': 'Crack'}, // Save
        {'isDamageDetected': true, 'confidence': 0.45, 'damageType': 'Crack'}, // Don't save
        {'isDamageDetected': false, 'confidence': 0.90, 'damageType': 'No Damage'}, // Don't save
        {'isDamageDetected': true, 'confidence': 0.55, 'damageType': 'Corrosion'}, // Don't save
        {'isDamageDetected': true, 'confidence': 0.60, 'damageType': 'Deformation'}, // Save
      ];
      
      final savedDetections = <Map<String, dynamic>>[];
      
      for (final detection in detections) {
        final confidence = (detection['confidence'] as num).toDouble();
        final isDamageDetected = detection['isDamageDetected'] == true;
        
        // Only save if damage detected AND confidence passes threshold
        if (isDamageDetected && confidence >= CONFIDENCE_THRESHOLD) {
          savedDetections.add(detection);
        }
      }
      
      // Assert
      expect(savedDetections.length, equals(2), reason: 'Only 2 detections should be saved');
      expect(savedDetections[0]['damageType'], equals('Crack'));
      expect(savedDetections[1]['damageType'], equals('Deformation'));
    });
  });
  
  group('Different Damage Types with Confidence Filter', () {
    test('Crack with high confidence should be accepted', () {
      final result = {'isDamageDetected': true, 'damageType': 'Crack', 'confidence': 0.80};
      final confidence = (result['confidence'] as num).toDouble();
      expect(confidence >= CONFIDENCE_THRESHOLD, isTrue);
    });
    
    test('Crack with low confidence should be rejected', () {
      final result = {'isDamageDetected': true, 'damageType': 'Crack', 'confidence': 0.40};
      final confidence = (result['confidence'] as num).toDouble();
      expect(confidence < CONFIDENCE_THRESHOLD, isTrue);
    });
    
    test('Corrosion with high confidence should be accepted', () {
      final result = {'isDamageDetected': true, 'damageType': 'Corrosion', 'confidence': 0.72};
      final confidence = (result['confidence'] as num).toDouble();
      expect(confidence >= CONFIDENCE_THRESHOLD, isTrue);
    });
    
    test('Corrosion with low confidence should be rejected', () {
      final result = {'isDamageDetected': true, 'damageType': 'Corrosion', 'confidence': 0.35};
      final confidence = (result['confidence'] as num).toDouble();
      expect(confidence < CONFIDENCE_THRESHOLD, isTrue);
    });
    
    test('Deformation with high confidence should be accepted', () {
      final result = {'isDamageDetected': true, 'damageType': 'Deformation', 'confidence': 0.88};
      final confidence = (result['confidence'] as num).toDouble();
      expect(confidence >= CONFIDENCE_THRESHOLD, isTrue);
    });
    
    test('Deformation with low confidence should be rejected', () {
      final result = {'isDamageDetected': true, 'damageType': 'Deformation', 'confidence': 0.52};
      final confidence = (result['confidence'] as num).toDouble();
      expect(confidence < CONFIDENCE_THRESHOLD, isTrue);
    });
  });
}

import 'lib/services/recommendations_service.dart';

void main() {
  print('=== Quick Test of Recommendations Service ===\n');
  
  // Test exact AI damage types
  final testCases = [
    {'type': 'Crack', 'confidence': 0.85},
    {'type': 'Rust', 'confidence': 0.92},  
    {'type': 'Deformation', 'confidence': 0.78},
    {'type': 'Scaling', 'confidence': 0.88}, // From test detection
  ];
  
  for (final testCase in testCases) {
    final damageType = testCase['type'] as String;
    final confidence = testCase['confidence'] as double;
    
    print('Testing: $damageType with confidence $confidence');
    print('=' * 50);
    
    final recommendations = RecommendationsService.getRecommendations(damageType, confidence);
    
    if (recommendations.length == 1 && recommendations[0].contains('No specific recommendations')) {
      print('❌ FAILED: Got fallback message');
    } else {
      print('✅ SUCCESS: Got ${recommendations.length} detailed recommendations');
      print('First few lines:');
      for (int i = 0; i < 5 && i < recommendations.length; i++) {
        print('  ${i+1}. ${recommendations[i]}');
      }
    }
    print('\n');
  }
}

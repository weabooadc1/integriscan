void main() {
  print('=== Testing AI Damage Type Recommendations ===\n');
  
  // Test the exact damage types that the AI model detects
  final aiDamageTypes = ['Crack', 'Rust', 'Deformation', 'No Damage'];
  
  for (final damageType in aiDamageTypes) {
    print('Testing damage type: "$damageType"');
    
    // This simulates what happens in the RecommendationsService
    final lowerCase = damageType.toLowerCase();
    print('  Lowercase version: "$lowerCase"');
    
    // Check if we have recommendations for this type
    final hasRecommendations = ['crack', 'rust', 'deformation', 'scaling'].contains(lowerCase);
    print('  Has recommendations: $hasRecommendations');
    
    if (lowerCase == 'no damage') {
      print('  --> This is not a damage type, should be ignored');
    } else if (hasRecommendations) {
      print('  --> ✅ Should get detailed engineering recommendations');
    } else {
      print('  --> ❌ Will show "No recommendations available"');
    }
    print('');
  }
  
  print('=== Analysis ===');
  print('The AI detects: Crack, Rust, Deformation');
  print('Our templates have: crack, rust, deformation, scaling');
  print('All AI damage types should be covered!');
  print('');
  print('If you\'re still seeing "No recommendations available", the issue is likely:');
  print('1. The AI is detecting a different case variation');
  print('2. There\'s an issue in the report generation process');
  print('3. The damage type string has extra spaces or characters');
}

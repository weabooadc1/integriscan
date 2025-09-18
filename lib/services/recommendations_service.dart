class RecommendationsService {
  // Engineering recommendations based on expert interviews
  static const Map<String, DamageRecommendation> _recommendations = {
    'crack': DamageRecommendation(
      damageType: 'Crack',
      severity: 'High',
      urgency: 'Immediate',
      recommendations: [
        'Clean the crack area thoroughly to remove debris and loose material',
        'Apply structural epoxy injection for load-bearing cracks',
        'Use flexible sealant for non-structural surface cracks',
        'Monitor crack progression weekly for the first month',
        'Consider professional structural assessment if crack exceeds 3mm width',
      ],
      materials: [
        'Structural epoxy resin',
        'Injection equipment',
        'Flexible polyurethane sealant',
        'Cleaning materials',
      ],
      estimatedCost: 'Low to Medium (\$50-\$500)',
      timeToComplete: '2-4 hours',
      skillLevel: 'Intermediate',
      safetyNotes: [
        'Wear protective gloves and safety glasses',
        'Ensure proper ventilation when using epoxy',
        'Do not perform repairs during wet conditions',
      ],
    ),
    'rust': DamageRecommendation(
      damageType: 'Rust',
      severity: 'Medium',
      urgency: 'Within 2 weeks',
      recommendations: [
        'Remove rust using wire brush or sandpaper',
        'Apply rust converter to neutralize remaining rust',
        'Clean surface with degreaser',
        'Apply primer suitable for metal surfaces',
        'Paint with corrosion-resistant coating',
        'Inspect surrounding area for additional rust spots',
      ],
      materials: [
        'Wire brush or sandpaper',
        'Rust converter/neutralizer',
        'Metal primer',
        'Corrosion-resistant paint',
        'Degreaser',
      ],
      estimatedCost: 'Low (\$30-\$150)',
      timeToComplete: '3-6 hours',
      skillLevel: 'Beginner',
      safetyNotes: [
        'Wear dust mask when sanding',
        'Use drop cloths to protect surrounding areas',
        'Work in well-ventilated area',
      ],
    ),
    'deformation': DamageRecommendation(
      damageType: 'Deformation',
      severity: 'Medium',
      urgency: 'Within 2 weeks',
      recommendations: [
        'Assess the extent and type of deformation',
        'Check if deformation affects structural integrity',
        'For minor deformation: use hydraulic jacks or mechanical straightening',
        'For severe deformation: consider professional structural repair',
        'Reinforce area with additional support if needed',
        'Apply protective coating after repair',
        'Monitor for recurring deformation',
      ],
      materials: [
        'Hydraulic equipment',
        'Mechanical straightening tools',
        'Reinforcement materials',
        'Protective coatings',
        'Measuring tools',
      ],
      estimatedCost: 'Medium to High (\$100-\$1000)',
      timeToComplete: '4-8 hours',
      skillLevel: 'Advanced',
      safetyNotes: [
        'Use proper lifting and support equipment',
        'Ensure structural stability during repair',
        'Wear appropriate personal protective equipment',
        'Consult structural engineer for severe cases',
      ],
    ),
    'scaling': DamageRecommendation(
      damageType: 'Scaling',
      severity: 'Medium',
      urgency: 'Within 3 weeks',
      recommendations: [
        'Remove all loose and flaking material completely',
        'Clean the surface thoroughly with wire brush',
        'Apply bonding agent to improve adhesion',
        'Use appropriate patching compound for the surface type',
        'Apply primer suitable for the substrate',
        'Finish with protective coating or paint',
        'Inspect regularly for recurring scaling',
      ],
      materials: [
        'Wire brushes',
        'Scrapers',
        'Bonding agent',
        'Patching compound',
        'Primer',
        'Protective coating',
        'Sandpaper',
      ],
      estimatedCost: 'Low to Medium (\$50-\$400)',
      timeToComplete: '3-6 hours',
      skillLevel: 'Intermediate',
      safetyNotes: [
        'Wear dust mask and safety glasses',
        'Work in well-ventilated area',
        'Handle chemicals according to manufacturer instructions',
        'Dispose of debris properly',
      ],
    ),
  };

  /// Normalize damage type string to handle variations from AI detection
  static String _normalizeDamageType(String damageType) {
    // Remove extra spaces, convert to lowercase, and handle common variations
    String normalized = damageType.toLowerCase().trim();
    
    // Handle potential AI detection variations
    switch (normalized) {
      case 'cracks':
        return 'crack';
      case 'rusting':
      case 'corrosion':
      case 'scaling':
        return 'rust';
      case 'deform':
      case 'deformations':
        return 'deformation';
      case 'scale':
      case 'scales':
      case 'peeling':
        return 'rust';
      default:
        return normalized;
    }
  }

  static DamageRecommendation? getRecommendation(String damageType) {
    final normalizedType = _normalizeDamageType(damageType);
    return _recommendations[normalizedType];
  }

  static List<String> getRecommendations(String damageType, double confidence) {
    final normalizedType = _normalizeDamageType(damageType);
    final rec = _recommendations[normalizedType];
    
    if (rec == null) {
      print('⚠️ No recommendations found for damage type: "$damageType" (normalized: "$normalizedType")');
      print('   Available types: ${_recommendations.keys.toList()}');
      return ['No specific recommendations available for this damage type.'];
    }
    
    print('✅ Generating detailed engineering recommendations for: ${rec.damageType}');
    
    List<String> recommendations = [];
    
    // Add engineering overview
    recommendations.add('=== ENGINEERING ASSESSMENT ===');
    recommendations.add('Damage Type: ${rec.damageType}');
    recommendations.add('Severity Level: ${rec.severity}');
    recommendations.add('Urgency: ${rec.urgency}');
    recommendations.add('Skill Level Required: ${rec.skillLevel}');
    recommendations.add('Estimated Cost: ${rec.estimatedCost}');
    recommendations.add('Time to Complete: ${rec.timeToComplete}');
    recommendations.add('');
    
    // Add step-by-step repair instructions
    recommendations.add('=== REPAIR INSTRUCTIONS ===');
    recommendations.addAll(rec.recommendations);
    recommendations.add('');
    
    // Add materials needed
    recommendations.add('=== MATERIALS REQUIRED ===');
    recommendations.addAll(rec.materials);
    recommendations.add('');
    
    // Add safety notes
    recommendations.add('=== SAFETY PRECAUTIONS ===');
    recommendations.addAll(rec.safetyNotes);
    recommendations.add('');
    
    // Add confidence-based recommendations
    recommendations.add('=== DETECTION CONFIDENCE ===');
    if (confidence > 0.9) {
      recommendations.add('High confidence detection (${(confidence * 100).toInt()}%) - proceed with repairs immediately');
    } else if (confidence > 0.7) {
      recommendations.add('Medium confidence detection (${(confidence * 100).toInt()}%) - verify damage before proceeding');
    } else {
      recommendations.add('Low confidence detection (${(confidence * 100).toInt()}%) - manual inspection recommended before repairs');
    }
    
    return recommendations;
  }

  static String getSeverity(String damageType, double confidence) {
    final normalizedType = _normalizeDamageType(damageType);
    final rec = _recommendations[normalizedType];
    
    if (rec == null) {
      print('⚠️ No severity data found for damage type: "$damageType" (normalized: "$normalizedType")');
      return 'Unknown';
    }
    
    // Adjust severity based on confidence
    if (confidence < 0.5) {
      return 'Low';
    }
    
    return rec.severity;
  }

  static String getUrgency(String damageType) {
    final normalizedType = _normalizeDamageType(damageType);
    final rec = _recommendations[normalizedType];
    return rec?.urgency ?? 'Unknown';
  }

  /// Get full engineering recommendation details for a damage type
  static DamageRecommendation? getFullRecommendation(String damageType) {
    final normalizedType = _normalizeDamageType(damageType);
    return _recommendations[normalizedType];
  }

  /// Get a formatted engineering report for a specific damage detection
  static Map<String, dynamic> getDetailedEngineeringReport(String damageType, double confidence) {
    final normalizedType = _normalizeDamageType(damageType);
    final rec = _recommendations[normalizedType];
    if (rec == null) {
      return {
        'available': false,
        'message': 'No specific engineering recommendations available for this damage type.'
      };
    }
    
    return {
      'available': true,
      'damageType': rec.damageType,
      'severity': rec.severity,
      'urgency': rec.urgency,
      'skillLevel': rec.skillLevel,
      'estimatedCost': rec.estimatedCost,
      'timeToComplete': rec.timeToComplete,
      'repairInstructions': rec.recommendations,
      'materialsRequired': rec.materials,
      'safetyPrecautions': rec.safetyNotes,
      'confidence': confidence,
      'confidenceLevel': confidence > 0.9 ? 'High' : confidence > 0.7 ? 'Medium' : 'Low',
      'confidenceRecommendation': confidence > 0.9 
        ? 'High confidence detection - proceed with repairs immediately'
        : confidence > 0.7 
          ? 'Medium confidence detection - verify damage before proceeding'
          : 'Low confidence detection - manual inspection recommended before repairs'
    };
  }
}

class DamageRecommendation {
  final String damageType;
  final String severity;
  final String urgency;
  final List<String> recommendations;
  final List<String> materials;
  final String estimatedCost;
  final String timeToComplete;
  final String skillLevel;
  final List<String> safetyNotes;

  const DamageRecommendation({
    required this.damageType,
    required this.severity,
    required this.urgency,
    required this.recommendations,
    required this.materials,
    required this.estimatedCost,
    required this.timeToComplete,
    required this.skillLevel,
    required this.safetyNotes,
  });
}

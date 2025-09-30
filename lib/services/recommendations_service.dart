class RecommendationsService {
  // Engineering recommendations based on expert interviews
  static const Map<String, DamageRecommendation> _recommendations = {
    'crack': DamageRecommendation(
      damageType: 'Structural Cracks',
      severity: 'Variable',
      urgency: 'Immediate Assessment Required',
      immediateSafety: [
        'Restrict heavy loads or occupant access near the damaged zone',
        'If cracks are in beams, columns, or foundations with visible sagging/tilting, evacuate area immediately',
        'Document crack width, depth, and location with photos and measurements',
        'Monitor for active movement or widening',
      ],
      minorRepairs: [
        'Minor Cracks (≤0.3 mm, non-structural, stable):',
        '• Clean crack thoroughly to remove debris and loose material',
        '• Seal with structural epoxy or specialized grout to prevent water ingress',
        '• Apply flexible sealant for non-load bearing surface cracks',
        '• Monitor periodically (monthly initially) for widening or new cracking',
      ],
      majorRepairs: [
        'Major Cracks (widening, in beams/columns/foundations):',
        '• Engage licensed structural engineer for load analysis immediately',
        '• Implement structural retrofitting (concrete jacketing or fiber-reinforced polymer wrapping)',
        '• Address root cause: soil settlement, seismic movement, or design inadequacy',
        '• Install structural monitoring systems for ongoing assessment',
        '• Consider temporary shoring during repair work',
      ],
      preventiveMeasures: [
        'Conduct regular structural inspections (residential: bi-annually, commercial: quarterly)',
        'Monitor foundation settlement and soil conditions',
        'Maintain proper drainage around structure',
        'Address design loads and environmental factors proactively',
      ],
      recommendations: [
       'Restrict heavy loads or occupant access near the damaged zone',
        'If cracks are in beams, columns, or foundations with visible sagging/tilting, evacuate area immediately',
        'Document crack width, depth, and location with photos and measurements',
        'Monitor for active movement or widening',
        'Minor Cracks (≤0.3 mm, non-structural, stable):',
        '• Clean crack thoroughly to remove debris and loose material',
        '• Seal with structural epoxy or specialized grout to prevent water ingress',
        '• Apply flexible sealant for non-load bearing surface cracks',
        '• Monitor periodically (monthly initially) for widening or new cracking',
        'Major Cracks (widening, in beams/columns/foundations):',
        '• Engage licensed structural engineer for load analysis immediately',
        '• Implement structural retrofitting (concrete jacketing or fiber-reinforced polymer wrapping)',
        '• Address root cause: soil settlement, seismic movement, or design inadequacy',
        '• Install structural monitoring systems for ongoing assessment',
        '• Consider temporary shoring during repair work',

        
      ],
      materials: [
        'Structural epoxy resin and injection equipment',
        'Specialized repair grout',
        'Flexible polyurethane sealant',
        'FRP wrapping materials (for major repairs)',
        'Concrete jacketing materials',
        'Crack monitoring gauges',
      ],
      estimatedCost: 'Minor: \$100-\$500 | Major: \$2,000-\$15,000+',
      timeToComplete: 'Minor: 2-4 hours | Major: 1-4 weeks',
      skillLevel: 'Minor: Intermediate | Major: Professional Required',
      safetyNotes: [
        'Never ignore cracks in load-bearing elements',
        'Wear protective equipment when using epoxy materials',
        'Ensure proper ventilation during chemical applications',
        'Do not perform major repairs without structural engineer approval',
        'Evacuate if structural integrity is compromised',
      ],
    ),
    'rust': DamageRecommendation(
      damageType: 'Steel Corrosion',
      severity: 'Variable',
      urgency: 'Within 2-4 weeks',
      immediateSafety: [
        'Assess extent of corrosion and steel loss percentage',
        'If spalling concrete is present, restrict access to prevent falling debris',
        'Test for structural capacity reduction in corroded elements',
        'Document corrosion pattern and environmental exposure conditions',
      ],
      minorRepairs: [
        'Surface Rust Only (no structural steel loss):',
        '• Remove rust mechanically using wire brushes or sandpaper',
        '• Apply rust converters to neutralize remaining rust',
        '• Clean surface with appropriate degreaser',
        '• Apply anti-corrosive primer and protective coating',
        '• Ensure adequate concrete cover (min 25mm for mild exposure)',
        '• Implement galvanic or cathodic protection if necessary',
      ],
      majorRepairs: [
        'Deep Corrosion (spalling concrete, significant steel loss):',
        '• Engage structural engineer to assess remaining capacity',
        '• Remove and replace severely corroded reinforcement',
        '• Patch spalled concrete with structural repair mortar',
        '• Install cathodic protection system for ongoing prevention',
        '• Consider steel plate bonding or FRP strengthening',
        '• Address moisture source and improve waterproofing',
      ],
      preventiveMeasures: [
        'Maintain proper concrete cover and quality',
        'Improve drainage and moisture control',
        'Apply protective coatings regularly',
        'Monitor chloride exposure in coastal environments',
        'Use corrosion-resistant reinforcement in new construction',
      ],
      recommendations: [
        'Assess extent of corrosion and steel loss percentage',
        'If spalling concrete is present, restrict access to prevent falling debris',
        'Test for structural capacity reduction in corroded elements',
        'Document corrosion pattern and environmental exposure conditions',
        'Surface Rust Only (no structural steel loss):',
        '• Remove rust mechanically using wire brushes or sandpaper',
        '• Apply rust converters to neutralize remaining rust',
        '• Clean surface with appropriate degreaser',
        '• Apply anti-corrosive primer and protective coating',
        '• Ensure adequate concrete cover (min 25mm for mild exposure)',
        '• Implement galvanic or cathodic protection if necessary',
        'Deep Corrosion (spalling concrete, significant steel loss):',
        '• Engage structural engineer to assess remaining capacity',
        '• Remove and replace severely corroded reinforcement',
        '• Patch spalled concrete with structural repair mortar',
        '• Install cathodic protection system for ongoing prevention',
        '• Consider steel plate bonding or FRP strengthening',
        '• Address moisture source and improve waterproofing',
      ],
      materials: [
        'Wire brushes and mechanical cleaning tools',
        'Rust converter/neutralizer chemicals',
        'Anti-corrosive primer and protective coatings',
        'Structural repair mortar',
        'Replacement reinforcement steel',
        'Cathodic protection systems',
        'Waterproofing materials',
      ],
      estimatedCost: 'Surface: \$200-\$800 | Deep: \$1,500-\$10,000+',
      timeToComplete: 'Surface: 4-8 hours | Deep: 1-3 weeks',
      skillLevel: 'Surface: Intermediate | Deep: Professional Required',
      safetyNotes: [
        'Wear dust mask and eye protection when removing rust',
        'Handle chemical rust converters according to manufacturer instructions',
        'Ensure proper ventilation in enclosed areas',
        'Use drop cloths to contain debris and chemicals',
        'Test for lead paint before disturbing old coatings',
      ],
    ),
    'deformation': DamageRecommendation(
      damageType: 'Structural Deformation',
      severity: 'High',
      urgency: 'Immediate Professional Assessment',
      immediateSafety: [
        'Evacuate area if visible sagging, tilting, or severe deflection is observed',
        'Implement temporary shoring immediately for safety',
        'Restrict all loads and occupancy until professional assessment',
        'Document deflection values using precision measurement tools',
        'Engage licensed structural engineer within 24 hours',
      ],
      minorRepairs: [
        'Within Code Limits (deflection < L/250 for typical structures):',
        '• Monitor with deflection gauges and document readings',
        '• Verify loads remain within original design parameters',
        '• Investigate soil conditions or temperature effects if movement continues',
        '• Implement load restrictions if necessary',
        '• Schedule regular monitoring (weekly initially)',
      ],
      majorRepairs: [
        'Beyond Code Limits (visible sag, tilt, deflection > L/180):',
        '• Implement immediate structural retrofitting measures',
        '• Options: steel plate bonding, FRP wrapping, or additional support columns',
        '• Correct foundation issues through underpinning or soil stabilization',
        '• Install permanent structural monitoring systems',
        '• Redesign load paths if necessary',
        '• Consider complete structural rehabilitation',
      ],
      preventiveMeasures: [
        'Regular structural health monitoring',
        'Foundation settlement monitoring',
        'Load management and restrictions',
        'Environmental factor control (temperature, moisture)',
        'Proactive maintenance scheduling',
      ],
      recommendations: [
        'Within Code Limits (deflection < L/250 for typical structures):',
        '• Monitor with deflection gauges and document readings',
        '• Verify loads remain within original design parameters',
        '• Investigate soil conditions or temperature effects if movement continues',
        '• Implement load restrictions if necessary',
        '• Schedule regular monitoring (weekly initially)',
        'Beyond Code Limits (visible sag, tilt, deflection > L/180):',
        '• Implement immediate structural retrofitting measures',
        '• Options: steel plate bonding, FRP wrapping, or additional support columns',
        '• Correct foundation issues through underpinning or soil stabilization',
        '• Install permanent structural monitoring systems',
        '• Redesign load paths if necessary',
        '• Consider complete structural rehabilitation',

      ],
      materials: [
        'Deflection monitoring equipment',
        'Steel plates and welding materials',
        'FRP wrapping systems',
        'Additional support columns and foundations',
        'Hydraulic jacking equipment',
        'Soil stabilization materials',
        'Permanent monitoring sensors',
      ],
      estimatedCost: 'Minor: \$500-\$2,000 | Major: \$5,000-\$50,000+',
      timeToComplete: 'Minor: 1-2 weeks | Major: 1-6 months',
      skillLevel: 'Professional Engineering Required',
      safetyNotes: [
        'Never attempt repairs without professional structural analysis',
        'Maintain temporary shoring throughout repair process',
        'Use proper lifting and support equipment',
        'Ensure worker safety with fall protection systems',
        'Coordinate with local building authorities',
      ],
    ),
    'scaling': DamageRecommendation(
      damageType: 'Surface Scaling',
      severity: 'Medium',
      urgency: 'Within 3 weeks',
      immediateSafety: [
        'Assess if scaling affects structural elements',
        'Check for underlying corrosion or damage',
        'Protect surrounding areas from falling debris',
      ],
      minorRepairs: [
        'Surface scaling only (cosmetic):',
        '• Remove all loose and flaking material completely',
        '• Clean surface thoroughly with wire brush',
        '• Apply bonding agent to improve adhesion',
        '• Use appropriate patching compound for surface type',
      ],
      majorRepairs: [
        'Deep scaling affecting substrate:',
        '• Investigate underlying cause (corrosion, freeze-thaw, etc.)',
        '• Remove material to sound substrate',
        '• Apply structural repair if needed',
        '• Use high-performance repair materials',
      ],
      preventiveMeasures: [
        'Regular surface inspections',
        'Moisture control and drainage',
        'Protective coating maintenance',
        'Address environmental exposure issues',
      ],
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
        'Wire brushes and scrapers',
        'Bonding agent',
        'Patching compound',
        'Primer and protective coatings',
        'Sandpaper and cleaning materials',
      ],
      estimatedCost: 'Minor: \$50-\$400 | Major: \$200-\$1,000',
      timeToComplete: 'Minor: 3-6 hours | Major: 1-2 days',
      skillLevel: 'Minor: Intermediate | Major: Professional Recommended',
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
      case 'cracking':
        return 'crack';
      case 'rusting':
      case 'corrosion':
      case 'corroding':
        return 'rust';
      case 'deform':
      case 'deformations':
      case 'deflection':
        return 'deformation';
      case 'scale':
      case 'scales':
      case 'peeling':
        return 'scaling';
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
    
    // Professional Engineering Assessment Header
    recommendations.add('=== STRUCTURAL ENGINEERING ASSESSMENT ===');
    recommendations.add('Damage Classification: ${rec.damageType}');
    recommendations.add('Assessment Priority: ${rec.urgency}');
    recommendations.add('Skill Level Required: ${rec.skillLevel}');
    recommendations.add('Estimated Cost Range: ${rec.estimatedCost}');
    recommendations.add('Completion Timeline: ${rec.timeToComplete}');
    recommendations.add('');
    
    // Immediate Safety Measures
    recommendations.add('=== 1. IMMEDIATE SAFETY & ASSESSMENT ===');
    recommendations.addAll(rec.immediateSafety);
    recommendations.add('');
    
    // Repair Recommendations
    recommendations.add('=== 2. REPAIR RECOMMENDATIONS ===');
    recommendations.addAll(rec.minorRepairs);
    recommendations.add('');
    recommendations.addAll(rec.majorRepairs);
    recommendations.add('');
    
    // Materials and Resources
    recommendations.add('=== 3. MATERIALS & RESOURCES REQUIRED ===');
    recommendations.addAll(rec.materials);
    recommendations.add('');
    
    // Safety Precautions
    recommendations.add('=== 4. SAFETY PRECAUTIONS ===');
    recommendations.addAll(rec.safetyNotes);
    recommendations.add('');
    
    // Preventive Measures
    recommendations.add('=== 5. PREVENTIVE & LONG-TERM MEASURES ===');
    recommendations.addAll(rec.preventiveMeasures);
    recommendations.add('');
    
    // AI Detection Confidence Assessment
    recommendations.add('=== 6. AI DETECTION CONFIDENCE ANALYSIS ===');
    recommendations.add('Detection Confidence: ${(confidence * 100).toInt()}%');
    if (confidence > 0.9) {
      recommendations.add('HIGH CONFIDENCE - Proceed with professional assessment immediately');
      recommendations.add('Recommendation: Engage structural engineer within 24-48 hours');
    } else if (confidence > 0.7) {
      recommendations.add('MEDIUM CONFIDENCE - Verify damage through manual inspection');
      recommendations.add('Recommendation: Site visit by qualified inspector required before proceeding');
    } else {
      recommendations.add('LOW CONFIDENCE - Manual verification essential');
      recommendations.add('Recommendation: Professional inspection required; AI detection may be inconclusive');
    }
    recommendations.add('');
    
    // Professional Guidance
    recommendations.add('=== 7. PROFESSIONAL GUIDANCE ===');
    recommendations.add('• Seek licensed structural engineer consultation for all structural repairs');
    recommendations.add('• Prioritize life-safety repairs (load-bearing elements) over cosmetic issues');
    recommendations.add('• Budget for phased repairs if financial constraints exist');
    recommendations.add('• Maintain detailed documentation throughout repair process');
    recommendations.add('• Comply with local building codes and permit requirements');
    
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
      'immediateSafety': rec.immediateSafety,
      'minorRepairs': rec.minorRepairs,
      'majorRepairs': rec.majorRepairs,
      'preventiveMeasures': rec.preventiveMeasures,
      'repairInstructions': rec.recommendations,
      'materialsRequired': rec.materials,
      'safetyPrecautions': rec.safetyNotes,
      'confidence': confidence,
      'confidenceLevel': confidence > 0.9 ? 'High' : confidence > 0.7 ? 'Medium' : 'Low',
      'professionalRequired': true,
      'priorityLevel': rec.damageType == 'Structural Deformation' ? 'Critical' : 'High',
      'confidenceRecommendation': confidence > 0.9 
        ? 'High confidence detection - proceed with professional assessment immediately'
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
  final List<String> immediateSafety;
  final List<String> minorRepairs;
  final List<String> majorRepairs;
  final List<String> preventiveMeasures;
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
    required this.immediateSafety,
    required this.minorRepairs,
    required this.majorRepairs,
    required this.preventiveMeasures,
    required this.recommendations,
    required this.materials,
    required this.estimatedCost,
    required this.timeToComplete,
    required this.skillLevel,
    required this.safetyNotes,
  });
}

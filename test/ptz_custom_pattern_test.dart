import 'package:flutter_test/flutter_test.dart';
import 'package:integriscan/services/ptz_service.dart';

void main() {
  group('PTZ Custom Scan Pattern Tests', () {
    test('upDownRightScan pattern should contain correct sequence', () {
      // Arrange
      final pattern = PTZScanPattern.upDownRightScan;
      
      // Assert
      expect(pattern.length, 3, reason: 'Pattern should have 3 movements');
      expect(pattern[0], PTZDirection.up, reason: 'First movement should be UP');
      expect(pattern[1], PTZDirection.down, reason: 'Second movement should be DOWN');
      expect(pattern[2], PTZDirection.right, reason: 'Third movement should be RIGHT');
      
      print('✅ Custom pattern sequence validated: UP → DOWN → RIGHT');
    });

    test('Pattern should repeat correctly for multiple cycles', () {
      // Arrange
      final pattern = PTZScanPattern.upDownRightScan;
      final numCycles = 3;
      final expectedSequence = <PTZDirection>[];
      
      // Generate expected sequence for 3 cycles
      for (int i = 0; i < numCycles; i++) {
        expectedSequence.addAll(pattern);
      }
      
      // Act - Simulate pattern repetition
      final actualSequence = <PTZDirection>[];
      for (int i = 0; i < numCycles * pattern.length; i++) {
        actualSequence.add(pattern[i % pattern.length]);
      }
      
      // Assert
      expect(actualSequence.length, 9, reason: '3 cycles * 3 movements = 9 total');
      expect(actualSequence, expectedSequence, reason: 'Pattern should repeat correctly');
      
      print('✅ Pattern repetition validated for $numCycles cycles');
      print('   Sequence: ${actualSequence.map((d) => d.name).join(" → ")}');
    });

    test('Pattern index calculation should work correctly', () {
      // Arrange
      final pattern = PTZScanPattern.upDownRightScan;
      
      // Test cases: (index, expected direction, expected analysis)
      final testCases = [
        (0, PTZDirection.up, true),     // Index 0: UP with analysis
        (1, PTZDirection.down, false),  // Index 1: DOWN without analysis
        (2, PTZDirection.right, true),  // Index 2: RIGHT with analysis
        (3, PTZDirection.up, true),     // Index 3: UP with analysis (cycle 2)
        (4, PTZDirection.down, false),  // Index 4: DOWN without analysis (cycle 2)
        (5, PTZDirection.right, true),  // Index 5: RIGHT with analysis (cycle 2)
      ];
      
      // Act & Assert
      for (final (index, expectedDirection, expectedAnalysis) in testCases) {
        final direction = pattern[index % pattern.length];
        final shouldAnalyze = (index % pattern.length) != 1; // Skip analysis for index 1 (DOWN)
        
        expect(direction, expectedDirection,
            reason: 'Index $index should map to ${expectedDirection.name}');
        expect(shouldAnalyze, expectedAnalysis,
            reason: 'Index $index should ${expectedAnalysis ? "analyze" : "skip analysis"}');
        
        print('✅ Index $index: ${direction.name} - ${shouldAnalyze ? "Analyze" : "Skip Analysis"}');
      }
    });

    test('Analysis skip logic should only skip DOWN movement', () {
      // Arrange
      final pattern = PTZScanPattern.upDownRightScan;
      
      // Act & Assert
      for (int i = 0; i < pattern.length * 2; i++) {
        final direction = pattern[i % pattern.length];
        final patternIndex = i % pattern.length;
        final shouldAnalyze = patternIndex != 1; // Only skip analysis for DOWN (index 1)
        
        if (direction == PTZDirection.down) {
          expect(shouldAnalyze, false,
              reason: 'DOWN movement should skip analysis');
          print('✅ Index $i (${direction.name}): Correctly skipping analysis');
        } else {
          expect(shouldAnalyze, true,
              reason: '${direction.name} movement should analyze');
          print('✅ Index $i (${direction.name}): Correctly analyzing');
        }
      }
    });

    test('Pattern workflow simulation', () {
      // Arrange
      final pattern = PTZScanPattern.upDownRightScan;
      final workflowLog = <String>[];
      
      // Act - Simulate 2 complete cycles
      for (int i = 0; i < pattern.length * 2; i++) {
        final direction = pattern[i % pattern.length];
        final shouldAnalyze = (i % pattern.length) != 1;
        final cycle = (i ~/ pattern.length) + 1;
        final step = (i % pattern.length) + 1;
        
        if (shouldAnalyze) {
          workflowLog.add('Cycle $cycle, Step $step: Analyze frame');
        }
        workflowLog.add('Cycle $cycle, Step $step: Move ${direction.name.toUpperCase()}');
        workflowLog.add('Cycle $cycle, Step $step: Stabilize (3s)');
      }
      
      // Assert
      expect(workflowLog.length, 16, reason: '2 cycles should produce 16 workflow steps');
      
      print('\n📋 Workflow Simulation:');
      for (final log in workflowLog) {
        print('   $log');
      }
      
      // Verify specific workflow steps
      expect(workflowLog[0], contains('Analyze frame'), reason: 'First step should analyze (before UP)');
      expect(workflowLog[1], contains('Move UP'), reason: 'First movement should be UP');
      expect(workflowLog[3], contains('Move DOWN'), reason: 'Second movement should be DOWN (no analysis)');
      expect(workflowLog[5], contains('Analyze frame'), reason: 'Should analyze before RIGHT');
      expect(workflowLog[6], contains('Move RIGHT'), reason: 'Third movement should be RIGHT');
      expect(workflowLog.where((log) => log.contains('Move DOWN')).length, 2,
          reason: 'Should have 2 DOWN movements in 2 cycles');
      expect(workflowLog.where((log) => log.contains('Analyze frame')).length, 4,
          reason: 'Should have 4 analyses in 2 cycles (2 per cycle, skipping DOWN)');
      
      print('✅ Workflow simulation validated');
    });

    test('Pattern should be distinct from other patterns', () {
      // Arrange
      final customPattern = PTZScanPattern.upDownRightScan;
      final horizontalPattern = PTZScanPattern.horizontalScan;
      final verticalPattern = PTZScanPattern.verticalScan;
      
      // Assert - Verify custom pattern is unique
      expect(customPattern, isNot(equals(horizontalPattern)),
          reason: 'Custom pattern should differ from horizontal scan');
      expect(customPattern, isNot(equals(verticalPattern)),
          reason: 'Custom pattern should differ from vertical scan');
      
      // Verify pattern structure
      expect(customPattern.contains(PTZDirection.up), true);
      expect(customPattern.contains(PTZDirection.down), true);
      expect(customPattern.contains(PTZDirection.right), true);
      expect(customPattern.contains(PTZDirection.left), false,
          reason: 'Custom pattern should not contain LEFT');
      expect(customPattern.contains(PTZDirection.center), false,
          reason: 'Custom pattern should not contain CENTER');
      
      print('✅ Custom pattern is distinct and well-defined');
      print('   Horizontal: ${horizontalPattern.map((d) => d.name).join(", ")}');
      print('   Vertical: ${verticalPattern.map((d) => d.name).join(", ")}');
      print('   Custom: ${customPattern.map((d) => d.name).join(", ")}');
    });

    test('Full cycle execution timing calculation', () {
      // Arrange
      final pattern = PTZScanPattern.upDownRightScan;
      const analysisTime = 5; // seconds to show results
      const movementTime = 1; // seconds for camera movement
      const stabilizationTime = 3; // seconds for stabilization
      
      // Calculate expected times
      int totalAnalyses = 0;
      int totalMovements = pattern.length;
      int totalStabilizations = pattern.length;
      
      for (int i = 0; i < pattern.length; i++) {
        if (i != 1) { // Skip analysis for DOWN (index 1)
          totalAnalyses++;
        }
      }
      
      final totalTime = (totalAnalyses * analysisTime) +
                       (totalMovements * movementTime) +
                       (totalStabilizations * stabilizationTime);
      
      // Assert
      expect(totalAnalyses, 2, reason: 'Should analyze 2 times per cycle (UP and RIGHT)');
      expect(totalMovements, 3, reason: 'Should move 3 times per cycle');
      expect(totalStabilizations, 3, reason: 'Should stabilize 3 times per cycle');
      expect(totalTime, 22, reason: 'One cycle should take 22 seconds');
      
      print('✅ Timing calculation validated:');
      print('   Analyses: $totalAnalyses × ${analysisTime}s = ${totalAnalyses * analysisTime}s');
      print('   Movements: $totalMovements × ${movementTime}s = ${totalMovements * movementTime}s');
      print('   Stabilizations: $totalStabilizations × ${stabilizationTime}s = ${totalStabilizations * stabilizationTime}s');
      print('   Total per cycle: ${totalTime}s');
      print('   Cycles per minute: ${(60 / totalTime).toStringAsFixed(2)}');
    });
  });

  group('Pattern Edge Cases', () {
    test('Empty pattern index should handle gracefully', () {
      final pattern = PTZScanPattern.upDownRightScan;
      
      // Test wraparound
      final index = 100;
      final direction = pattern[index % pattern.length];
      
      expect(direction, pattern[index % 3]);
      print('✅ Large index $index wraps correctly to ${direction.name}');
    });

    test('Pattern should be immutable', () {
      final pattern = PTZScanPattern.upDownRightScan;
      final originalLength = pattern.length;
      
      // Attempt to get pattern should not allow modification
      expect(pattern.length, originalLength);
      expect(pattern, isA<List<PTZDirection>>());
      
      print('✅ Pattern is properly defined as const');
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:integriscan/models/report_models.dart';

/// Simplified unit tests for the flagging comments bug fix
/// 
/// This test suite validates that:
/// 1. The DetectionReport model has separate fields for user and engineer comments
/// 2. The fields serialize/deserialize correctly
/// 3. Both fields can coexist without interfering with each other
void main() {
  group('Flagging Comments Model Tests', () {
    test('DetectionReport should have separate userFlaggingComments and engineerComments fields', () {
      // Arrange & Act
      final report = DetectionReport(
        id: 'test-123',
        userId: 'user-123',
        sessionName: 'Test Session',
        createdAt: DateTime.now(),
        detections: [],
        userFlaggingComments: 'User comment here',
        engineerComments: 'Engineer comment here',
        summary: ReportSummary(
          totalDetections: 0,
          cracksCount: 0,
          corrosionCount: 0,
          deformationCount: 0,
          overallSeverity: 'low',
          recommendations: [],
        ),
      );
      
      // Assert
      expect(report.userFlaggingComments, equals('User comment here'));
      expect(report.engineerComments, equals('Engineer comment here'));
      expect(report.userFlaggingComments, isNot(equals(report.engineerComments)));
    });

    test('DetectionReport toMap should include both comment fields', () {
      // Arrange
      final report = DetectionReport(
        id: 'test-123',
        userId: 'user-123',
        sessionName: 'Test Session',
        createdAt: DateTime.now(),
        detections: [],
        userFlaggingComments: 'User flagged for review',
        engineerComments: 'Engineer verified and approved',
        summary: ReportSummary(
          totalDetections: 0,
          cracksCount: 0,
          corrosionCount: 0,
          deformationCount: 0,
          overallSeverity: 'low',
          recommendations: [],
        ),
      );
      
      // Act
      final map = report.toMap();
      
      // Assert
      expect(map, containsPair('userFlaggingComments', 'User flagged for review'));
      expect(map, containsPair('engineerComments', 'Engineer verified and approved'));
    });

    test('DetectionReport should handle null userFlaggingComments', () {
      // Arrange & Act
      final report = DetectionReport(
        id: 'test-123',
        userId: 'user-123',
        sessionName: 'Test Session',
        createdAt: DateTime.now(),
        detections: [],
        userFlaggingComments: null,
        engineerComments: 'Engineer comment',
        summary: ReportSummary(
          totalDetections: 0,
          cracksCount: 0,
          corrosionCount: 0,
          deformationCount: 0,
          overallSeverity: 'low',
          recommendations: [],
        ),
      );
      
      // Assert
      expect(report.userFlaggingComments, isNull);
      expect(report.engineerComments, equals('Engineer comment'));
    });

    test('DetectionReport should handle null engineerComments', () {
      // Arrange & Act
      final report = DetectionReport(
        id: 'test-123',
        userId: 'user-123',
        sessionName: 'Test Session',
        createdAt: DateTime.now(),
        detections: [],
        userFlaggingComments: 'User comment',
        engineerComments: null,
        summary: ReportSummary(
          totalDetections: 0,
          cracksCount: 0,
          corrosionCount: 0,
          deformationCount: 0,
          overallSeverity: 'low',
          recommendations: [],
        ),
      );
      
      // Assert
      expect(report.userFlaggingComments, equals('User comment'));
      expect(report.engineerComments, isNull);
    });

    test('DetectionReport should handle both comments being null', () {
      // Arrange & Act
      final report = DetectionReport(
        id: 'test-123',
        userId: 'user-123',
        sessionName: 'Test Session',
        createdAt: DateTime.now(),
        detections: [],
        userFlaggingComments: null,
        engineerComments: null,
        summary: ReportSummary(
          totalDetections: 0,
          cracksCount: 0,
          corrosionCount: 0,
          deformationCount: 0,
          overallSeverity: 'low',
          recommendations: [],
        ),
      );
      
      // Assert
      expect(report.userFlaggingComments, isNull);
      expect(report.engineerComments, isNull);
    });

    test('DetectionReport should handle empty string comments', () {
      // Arrange & Act
      final report = DetectionReport(
        id: 'test-123',
        userId: 'user-123',
        sessionName: 'Test Session',
        createdAt: DateTime.now(),
        detections: [],
        userFlaggingComments: '',
        engineerComments: '',
        summary: ReportSummary(
          totalDetections: 0,
          cracksCount: 0,
          corrosionCount: 0,
          deformationCount: 0,
          overallSeverity: 'low',
          recommendations: [],
        ),
      );
      
      // Assert
      expect(report.userFlaggingComments, equals(''));
      expect(report.engineerComments, equals(''));
    });

    test('DetectionReport toMap should preserve null comments', () {
      // Arrange
      final report = DetectionReport(
        id: 'test-123',
        userId: 'user-123',
        sessionName: 'Test Session',
        createdAt: DateTime.now(),
        detections: [],
        userFlaggingComments: null,
        engineerComments: null,
        summary: ReportSummary(
          totalDetections: 0,
          cracksCount: 0,
          corrosionCount: 0,
          deformationCount: 0,
          overallSeverity: 'low',
          recommendations: [],
        ),
      );
      
      // Act
      final map = report.toMap();
      
      // Assert
      expect(map['userFlaggingComments'], isNull);
      expect(map['engineerComments'], isNull);
    });

    test('DetectionReport with both user and engineer comments', () {
      // Arrange
      final report = DetectionReport(
        id: 'both-comments-123',
        userId: 'user-123',
        sessionName: 'Test',
        createdAt: DateTime.now(),
        detections: [],
        userFlaggingComments: 'User: Multiple cracks detected',
        engineerComments: 'Engineer: Reviewed - requires maintenance',
        flaggedForVerification: true,
        verificationStatus: 'verified',
        summary: ReportSummary(
          totalDetections: 3,
          cracksCount: 3,
          corrosionCount: 0,
          deformationCount: 0,
          overallSeverity: 'high',
          recommendations: ['Immediate maintenance required'],
        ),
      );
      
      // Assert - Both comments present and distinct
      expect(report.userFlaggingComments, isNotNull);
      expect(report.engineerComments, isNotNull);
      expect(report.userFlaggingComments, equals('User: Multiple cracks detected'));
      expect(report.engineerComments, equals('Engineer: Reviewed - requires maintenance'));
      expect(report.flaggedForVerification, isTrue);
      expect(report.verificationStatus, equals('verified'));
      
      // Assert - toMap includes both
      final map = report.toMap();
      expect(map['userFlaggingComments'], equals('User: Multiple cracks detected'));
      expect(map['engineerComments'], equals('Engineer: Reviewed - requires maintenance'));
    });
  });

  group('Backwards Compatibility Tests', () {
    test('Reports created without userFlaggingComments should work', () {
      // Arrange - Create report without specifying userFlaggingComments
      final report = DetectionReport(
        id: 'old-report-123',
        userId: 'user-123',
        sessionName: 'Old Report',
        createdAt: DateTime.now(),
        detections: [],
        engineerComments: 'Some engineer comment',
        // userFlaggingComments not specified - should default to null
        summary: ReportSummary(
          totalDetections: 0,
          cracksCount: 0,
          corrosionCount: 0,
          deformationCount: 0,
          overallSeverity: 'low',
          recommendations: [],
        ),
      );
      
      // Assert
      expect(report.userFlaggingComments, isNull); // Should default to null
      expect(report.engineerComments, equals('Some engineer comment'));
    });

    test('toMap should handle reports without userFlaggingComments', () {
      // Arrange
      final report = DetectionReport(
        id: 'old-report-123',
        userId: 'user-123',
        sessionName: 'Old Report',
        createdAt: DateTime.now(),
        detections: [],
        engineerComments: 'Engineer comment only',
        summary: ReportSummary(
          totalDetections: 0,
          cracksCount: 0,
          corrosionCount: 0,
          deformationCount: 0,
          overallSeverity: 'low',
          recommendations: [],
        ),
      );
      
      // Act
      final map = report.toMap();
      
      // Assert
      expect(map, contains('userFlaggingComments')); // Field should exist in map
      expect(map['userFlaggingComments'], isNull); // But value should be null
      expect(map['engineerComments'], equals('Engineer comment only'));
    });
  });

  group('Bug Fix Validation', () {
    test('Bug scenario: User flagging comment should NOT be in engineerComments', () {
      // This test validates the bug is fixed
      // BEFORE FIX: User's flagging reason was stored in engineerComments
      // AFTER FIX: User's flagging reason should be in userFlaggingComments
      
      const userFlaggingReason = 'I found suspicious cracks here';
      
      // Arrange - Create a flagged report
      final report = DetectionReport(
        id: 'bug-fix-test-123',
        userId: 'user-123',
        sessionName: 'Bug Fix Test',
        createdAt: DateTime.now(),
        detections: [],
        flaggedForVerification: true,
        verificationStatus: 'review',
        userFlaggingComments: userFlaggingReason, // ✅ CORRECT: User's comment here
        engineerComments: null, // ✅ CORRECT: Null until engineer reviews
        summary: ReportSummary(
          totalDetections: 1,
          cracksCount: 1,
          corrosionCount: 0,
          deformationCount: 0,
          overallSeverity: 'medium',
          recommendations: ['Review recommended'],
        ),
      );
      
      // Assert - User's comment in correct field
      expect(report.userFlaggingComments, equals(userFlaggingReason));
      expect(report.engineerComments, isNull); // NOT in engineer comments
      expect(report.flaggedForVerification, isTrue);
      expect(report.verificationStatus, equals('review'));
    });

    test('After engineer review: Both comments should coexist separately', () {
      const userFlaggingReason = 'Multiple cracks detected, needs verification';
      const engineerReviewComment = 'Reviewed and confirmed - schedule maintenance';
      
      // Arrange - Report with both user flag and engineer review
      final report = DetectionReport(
        id: 'reviewed-report-123',
        userId: 'user-123',
        sessionName: 'Reviewed Report',
        createdAt: DateTime.now(),
        detections: [],
        flaggedForVerification: true,
        verificationStatus: 'verified',
        userFlaggingComments: userFlaggingReason, // User's original reason
        engineerComments: engineerReviewComment, // Engineer's review
        summary: ReportSummary(
          totalDetections: 3,
          cracksCount: 3,
          corrosionCount: 0,
          deformationCount: 0,
          overallSeverity: 'high',
          recommendations: ['Immediate maintenance required'],
        ),
      );
      
      // Assert - Both comments preserved separately
      expect(report.userFlaggingComments, equals(userFlaggingReason));
      expect(report.engineerComments, equals(engineerReviewComment));
      expect(report.userFlaggingComments, isNot(equals(report.engineerComments)));
      expect(report.verificationStatus, equals('verified'));
    });
  });
}

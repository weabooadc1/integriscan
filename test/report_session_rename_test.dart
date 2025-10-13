import 'package:flutter_test/flutter_test.dart';
import 'package:integriscan/database/database_helper.dart';
import 'package:integriscan/models/report_models.dart';
import 'package:integriscan/services/report_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  // Initialize FFI for desktop testing
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Report Session Name Rename Tests', () {
    late DatabaseHelper db;
    late String testReportId;
    late String testUserId;

    setUp(() async {
      // Initialize database helper
      db = DatabaseHelper();
      await db.database; // Ensure database is initialized
      
      // Create test data
      testUserId = 'test_user_${DateTime.now().millisecondsSinceEpoch}';
      testReportId = 'test_report_${DateTime.now().millisecondsSinceEpoch}';
      
      // Create a test report
      final testReport = DetectionReport(
        id: testReportId,
        userId: testUserId,
        sessionName: 'Original Session Name',
        createdAt: DateTime.now(),
        detections: [],
        summary: ReportSummary(
          overallSeverity: 'low',
          recommendations: ['Test recommendation'],
          totalDetections: 0,
          cracksCount: 0,
          corrosionCount: 0,
          deformationCount: 0,
        ),
        synced: false,
      );
      
      // Save test report to database using DatabaseHelper
      await db.insertReport(testReport.toMap());
      print('✅ Test report created: $testReportId');
    });

    tearDown(() async {
      // Clean up test data
      try {
        await db.deleteReport(testReportId);
        print('🧹 Cleaned up test report: $testReportId');
      } catch (e) {
        print('⚠️ Error cleaning up test data: $e');
      }
    });

    test('Should successfully update session name in database', () async {
      print('\n🧪 TEST: Update session name in database');
      
      // Arrange
      const newSessionName = 'Updated Session Name';
      print('📝 Original name: "Original Session Name"');
      print('📝 New name: "$newSessionName"');
      
      // Act - Update session name directly in database (simulating the UI action)
      final database = await db.database;
      final updateCount = await database.update(
        'reports',
        {'sessionName': newSessionName},
        where: 'id = ?',
        whereArgs: [testReportId],
      );
      
      print('✅ Database update affected $updateCount row(s)');
      
      // Assert - Verify the update was successful
      expect(updateCount, 1, reason: 'Should update exactly one row');
      
      // Verify by reading back from database
      final report = await ReportService.getReport(testReportId);
      expect(report, isNotNull, reason: 'Report should still exist');
      expect(report!.sessionName, newSessionName, 
             reason: 'Session name should be updated');
      
      print('✅ Verified: Session name updated to "$newSessionName"');
      print('🎉 TEST PASSED: Session name update successful\n');
    });

    test('Should persist session name change after database reload', () async {
      print('\n🧪 TEST: Session name persists after database reload');
      
      // Arrange
      const newSessionName = 'Persistent Session Name';
      
      // Act - Update session name
      final database = await db.database;
      await database.update(
        'reports',
        {'sessionName': newSessionName},
        where: 'id = ?',
        whereArgs: [testReportId],
      );
      
      print('✅ Session name updated in database');
      
      // Simulate app restart by creating new database helper instance
      final newDb = DatabaseHelper();
      await newDb.database;
      
      // Assert - Read from fresh database instance
      final report = await ReportService.getReport(testReportId);
      expect(report, isNotNull);
      expect(report!.sessionName, newSessionName,
             reason: 'Session name should persist across database instances');
      
      print('✅ Verified: Session name persisted after database reload');
      print('🎉 TEST PASSED: Session name persistence confirmed\n');
    });

    test('Should handle empty session name gracefully', () async {
      print('\n🧪 TEST: Handle empty session name');
      
      // Arrange
      const emptyName = '';
      
      // Act - Try to update with empty name
      final database = await db.database;
      final updateCount = await database.update(
        'reports',
        {'sessionName': emptyName},
        where: 'id = ?',
        whereArgs: [testReportId],
      );
      
      // Assert - Update should technically work (validation is UI-level)
      expect(updateCount, 1);
      
      final report = await ReportService.getReport(testReportId);
      expect(report!.sessionName, emptyName,
             reason: 'Database allows empty name (UI should prevent this)');
      
      print('✅ Database allows empty name (validation should be in UI)');
      print('🎉 TEST PASSED: Empty name handling confirmed\n');
    });

    test('Should handle very long session names', () async {
      print('\n🧪 TEST: Handle long session name');
      
      // Arrange - Create a 100-character session name
      final longName = 'A' * 100;
      
      // Act
      final database = await db.database;
      final updateCount = await database.update(
        'reports',
        {'sessionName': longName},
        where: 'id = ?',
        whereArgs: [testReportId],
      );
      
      // Assert
      expect(updateCount, 1);
      
      final report = await ReportService.getReport(testReportId);
      expect(report!.sessionName, longName,
             reason: 'Should handle long session names');
      expect(report.sessionName.length, 100);
      
      print('✅ Successfully stored and retrieved 100-character name');
      print('🎉 TEST PASSED: Long name handling confirmed\n');
    });

    test('Should handle special characters in session name', () async {
      print('\n🧪 TEST: Handle special characters in session name');
      
      // Arrange - Session name with special characters
      const specialName = 'Test @#\$% 123 & "quotes" \'apostrophe\'';
      
      // Act
      final database = await db.database;
      final updateCount = await database.update(
        'reports',
        {'sessionName': specialName},
        where: 'id = ?',
        whereArgs: [testReportId],
      );
      
      // Assert
      expect(updateCount, 1);
      
      final report = await ReportService.getReport(testReportId);
      expect(report!.sessionName, specialName,
             reason: 'Should handle special characters correctly');
      
      print('✅ Special characters handled correctly: "$specialName"');
      print('🎉 TEST PASSED: Special character handling confirmed\n');
    });

    test('Should not affect other report fields when updating session name', () async {
      print('\n🧪 TEST: Session name update preserves other fields');
      
      // Arrange - Get initial report state
      final originalReport = await ReportService.getReport(testReportId);
      expect(originalReport, isNotNull);
      
      final originalUserId = originalReport!.userId;
      final originalCreatedAt = originalReport.createdAt;
      final originalSynced = originalReport.synced;
      
      print('📊 Original report state:');
      print('   userId: $originalUserId');
      print('   createdAt: $originalCreatedAt');
      print('   synced: $originalSynced');
      
      // Act - Update only session name
      const newSessionName = 'Updated Without Affecting Others';
      final database = await db.database;
      await database.update(
        'reports',
        {'sessionName': newSessionName},
        where: 'id = ?',
        whereArgs: [testReportId],
      );
      
      // Assert - All other fields should remain unchanged
      final updatedReport = await ReportService.getReport(testReportId);
      expect(updatedReport, isNotNull);
      expect(updatedReport!.sessionName, newSessionName,
             reason: 'Session name should be updated');
      expect(updatedReport.userId, originalUserId,
             reason: 'User ID should not change');
      expect(updatedReport.createdAt, originalCreatedAt,
             reason: 'Created date should not change');
      expect(updatedReport.synced, originalSynced,
             reason: 'Synced status should not change');
      
      print('✅ All other fields preserved:');
      print('   userId: ${updatedReport.userId}');
      print('   createdAt: ${updatedReport.createdAt}');
      print('   synced: ${updatedReport.synced}');
      print('🎉 TEST PASSED: Other fields preserved correctly\n');
    });

    test('Should handle updating non-existent report gracefully', () async {
      print('\n🧪 TEST: Update non-existent report');
      
      // Arrange
      const nonExistentId = 'non_existent_report_id';
      const newSessionName = 'This Should Not Work';
      
      // Act
      final database = await db.database;
      final updateCount = await database.update(
        'reports',
        {'sessionName': newSessionName},
        where: 'id = ?',
        whereArgs: [nonExistentId],
      );
      
      // Assert - Should affect 0 rows
      expect(updateCount, 0,
             reason: 'Should not update any rows for non-existent report');
      
      print('✅ Correctly handled non-existent report (0 rows affected)');
      print('🎉 TEST PASSED: Non-existent report handling confirmed\n');
    });

    test('Should support multiple consecutive updates', () async {
      print('\n🧪 TEST: Multiple consecutive session name updates');
      
      // Arrange
      final sessionNames = [
        'First Update',
        'Second Update',
        'Third Update',
        'Final Update',
      ];
      
      final database = await db.database;
      
      // Act - Perform multiple updates
      for (int i = 0; i < sessionNames.length; i++) {
        print('📝 Update ${i + 1}: "${sessionNames[i]}"');
        
        await database.update(
          'reports',
          {'sessionName': sessionNames[i]},
          where: 'id = ?',
          whereArgs: [testReportId],
        );
        
        // Verify each update
        final report = await ReportService.getReport(testReportId);
        expect(report!.sessionName, sessionNames[i],
               reason: 'Update ${i + 1} should be reflected');
      }
      
      // Assert - Final state should be the last update
      final finalReport = await ReportService.getReport(testReportId);
      expect(finalReport!.sessionName, sessionNames.last,
             reason: 'Final session name should be the last update');
      
      print('✅ All ${sessionNames.length} updates successful');
      print('🎉 TEST PASSED: Multiple updates handled correctly\n');
    });
  });
}

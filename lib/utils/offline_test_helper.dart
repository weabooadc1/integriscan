import 'package:integriscan/services/report_service.dart';
import 'package:integriscan/services/connectivity_service.dart';

class OfflineTestHelper {
  /// Test report generation in offline mode
  static Future<void> testOfflineReportGeneration() async {
    print('=== Testing Offline Report Generation ===');
    
    // Sample detection data
    final sampleDetections = [
      {
        'damageType': 'Crack',
        'confidence': 0.85,
        'imagePath': '',
        'timestamp': DateTime.now().subtract(const Duration(minutes: 5)).millisecondsSinceEpoch,
        'boundingBox': {
          'x': 0.2,
          'y': 0.3,
          'width': 0.15,
          'height': 0.1,
        },
      },
      {
        'damageType': 'Rust',
        'confidence': 0.72,
        'imagePath': '',
        'timestamp': DateTime.now().subtract(const Duration(minutes: 3)).millisecondsSinceEpoch,
        'boundingBox': {
          'x': 0.6,
          'y': 0.4,
          'width': 0.12,
          'height': 0.08,
        },
      },
    ];

    try {
      print('Creating report in offline mode...');
      
      final report = await ReportService.generateReport(
        userId: 'offline_test_user',
        sessionName: 'Offline Test Report',
        detections: sampleDetections,
        trySyncToCloud: false, // Explicitly disable cloud sync for this test
      );

      print('✅ Offline report generated successfully!');
      print('Report ID: ${report.id}');
      print('Synced: ${report.synced}');
      print('Total detections: ${report.detections.length}');
      print('Overall severity: ${report.summary.overallSeverity}');
      
      // Test connectivity status
      final connectivityService = ConnectivityService();
      print('Current connectivity status: ${connectivityService.isConnected ? "Online" : "Offline"}');
      
      print('=== Offline Test Completed Successfully ===');
      
    } catch (e) {
      print('❌ Offline test failed: $e');
      rethrow;
    }
  }

  /// Test background sync when connectivity is restored
  static Future<void> testBackgroundSync() async {
    print('=== Testing Background Sync ===');
    
    try {
      final connectivityService = ConnectivityService();
      
      if (!connectivityService.isConnected) {
        print('Device is offline - background sync will be skipped');
        return;
      }
      
      print('Device is online - testing background sync...');
      await ReportService.syncAllUnsyncedReportsStatic(userId: 'offline_test_user');
      print('✅ Background sync completed successfully');
      
    } catch (e) {
      print('❌ Background sync test failed: $e');
      rethrow;
    }
  }

  /// Show current unsynced reports count
  static Future<void> showUnsyncedReportsStatus({String? userId}) async {
    try {
      final reports = await ReportService.getReports(userId: userId);
      final unsyncedReports = reports.where((r) => !r.synced).toList();
      
      print('=== Unsynced Reports Status ===');
      print('Total reports: ${reports.length}');
      print('Unsynced reports: ${unsyncedReports.length}');
      
      if (unsyncedReports.isNotEmpty) {
        print('Unsynced report IDs:');
        for (final report in unsyncedReports) {
          print('  - ${report.id} (${report.sessionName})');
        }
      }
      
    } catch (e) {
      print('❌ Error checking unsynced reports: $e');
    }
  }
}

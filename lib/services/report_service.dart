import 'package:integriscan/models/report_models.dart';
import 'package:integriscan/services/recommendations_service.dart';
import 'package:integriscan/database/database_helper.dart';
import 'package:integriscan/services/firestore_sync_service.dart';

class ReportService {
  /// Static wrapper for background sync
  static Future<void> syncAllUnsyncedReportsStatic({String? userId}) async {
    await ReportService().syncAllUnsyncedReports(userId: userId);
  }

  /// Static wrapper for single report sync
  static Future<void> trySyncReportToCloudStatic(DetectionReport report) async {
    await ReportService().trySyncReportToCloud(report);
  }
  /// Try to sync a single report to Firestore and mark as synced if successful
  Future<void> trySyncReportToCloud(DetectionReport report) async {
    try {
      print('Attempting to sync report ${report.id} to Firestore...');
      
      // Try to upload to Firestore
      await FirestoreSyncService.uploadReport(report);
      print('Report uploaded to Firestore successfully');
      
      // Mark as synced in local DB
      final db = DatabaseHelper();
      await db.markReportAsSynced(report.id);
      print('Report marked as synced in local database');
      
    } catch (e) {
      print('Firestore sync failed for report ${report.id}: $e');
      // Don't rethrow - we want to continue with other reports
    }
  }

  /// Background sync for all unsynced reports
  Future<void> syncAllUnsyncedReports({String? userId}) async {
    try {
      print('Starting background sync for all unsynced reports...');
      final db = DatabaseHelper();
      final unsyncedMaps = await db.getUnsyncedReports(userId: userId);
      print('Found ${unsyncedMaps.length} unsynced reports for userId: $userId');
      
      for (final map in unsyncedMaps) {
        print('Syncing report: ${map['id']}');
        final report = await getReport(map['id']);
        if (report != null) {
          await trySyncReportToCloud(report);
        } else {
          print('Warning: Could not retrieve report ${map['id']} for sync');
        }
      }
      
      print('Background sync completed');
    } catch (e) {
      print('Error during background sync: $e');
    }
  }

  static Future<DetectionReport> generateReport({
    required String userId,
    required String sessionName,
    required List<Map<String, dynamic>> detections,
    bool trySyncToCloud = true,
  }) async {
    print('ReportService.generateReport called with:');
    print('  userId: $userId');
    print('  sessionName: $sessionName');
    print('  detections count: ${detections.length}');
    print('  detections: $detections');
    
    final reportId = DateTime.now().millisecondsSinceEpoch.toString();
    
    // Convert detections to DamageDetection objects
    print('Converting ${detections.length} detections to DamageDetection objects...');
    final damageDetections = <DamageDetection>[];
    
    for (int i = 0; i < detections.length; i++) {
      final detection = detections[i];
      print('Processing detection $i: $detection');
      
      final recommendations = RecommendationsService.getRecommendations(
        detection['damageType'],
        detection['confidence'],
      );
      
      // Generate unique ID for each detection using report ID + index
      final detectionId = '${reportId}_${i}';
      print('Generated detection ID: $detectionId');
      
      damageDetections.add(DamageDetection(
        id: detectionId,
        reportId: reportId,
        damageType: detection['damageType'],
        confidence: detection['confidence'],
        imagePath: detection['imagePath'],
        timestamp: DateTime.fromMillisecondsSinceEpoch(detection['timestamp']),
        boundingBox: detection['boundingBox'] != null
            ? BoundingBox.fromMap(detection['boundingBox'])
            : null,
        severity: RecommendationsService.getSeverity(
          detection['damageType'],
          detection['confidence'],
        ),
        recommendations: recommendations,
      ));
    }

    print('Created ${damageDetections.length} DamageDetection objects');

    // Generate summary
    print('Generating summary...');
    final summary = _generateSummary(damageDetections);
    print('Summary generated: ${summary.toMap()}');

    // Create report
    print('Creating DetectionReport object...');
    final report = DetectionReport(
      id: reportId,
      userId: userId,
      sessionName: sessionName,
      createdAt: DateTime.now(),
      detections: damageDetections,
      summary: summary,
      synced: false,
    );
    print('DetectionReport created with ID: ${report.id}');

    // Save to database (unsynced)
    print('Saving report to database...');
    await _saveReportToDatabase(report);
    print('Report saved to database successfully');

    // Try to sync to Firestore if requested and connection is available
    if (trySyncToCloud) {
      // Use an instance to call non-static method
      await ReportService().trySyncReportToCloud(report);
    }

    return report;
  /// Try to sync a single report to Firestore and mark as synced if successful
  }

  static ReportSummary _generateSummary(List<DamageDetection> detections) {
    int criticalCount = 0;
    int moderateCount = 0;
    int minorCount = 0;
    Set<String> allRecommendations = {};

    for (final detection in detections) {
      switch (detection.severity.toLowerCase()) {
        case 'high':
          criticalCount++;
          break;
        case 'medium':
          moderateCount++;
          break;
        case 'low':
          minorCount++;
          break;
      }
      allRecommendations.addAll(detection.recommendations);
    }

    String overallSeverity = 'Low';
    if (criticalCount > 0) {
      overallSeverity = 'Critical';
    } else if (moderateCount > 0) {
      overallSeverity = 'Moderate';
    }

    return ReportSummary(
      overallSeverity: overallSeverity,
      recommendations: allRecommendations.toList(),
      totalDetections: detections.length,
      criticalCount: criticalCount,
      moderateCount: moderateCount,
      minorCount: minorCount,
    );
  }

  static Future<void> _saveReportToDatabase(DetectionReport report) async {
    final db = DatabaseHelper();
    
    // Save report
    await db.insertReport(report.toMap());
    
    // Save detections
    for (final detection in report.detections) {
      await db.insertDetection(detection.toMap());
    }
  }

  static Future<List<DetectionReport>> getReports({String? userId}) async {
    final db = DatabaseHelper();
    final reportMaps = await db.getReports(userId: userId);
    List<DetectionReport> reports = [];
    for (final reportMap in reportMaps) {
      final detectionMaps = await db.getDetectionsByReport(reportMap['id']);
      final detections = detectionMaps.map((map) => DamageDetection.fromMap(map)).toList();
      // Build summary with correct counts
      final summary = ReportSummary(
        overallSeverity: reportMap['severityLevel'],
        recommendations: (reportMap['recommendations'] ?? '').toString().split('|'),
        totalDetections: detections.length,
        criticalCount: detections.where((d) => d.severity == 'High').length,
        moderateCount: detections.where((d) => d.severity == 'Medium').length,
        minorCount: detections.where((d) => d.severity == 'Low').length,
      );
      reports.add(DetectionReport.fromMap(reportMap, detections: detections, summary: summary));
    }
    return reports;
  }

  static Future<DetectionReport?> getReport(String id) async {
    final db = DatabaseHelper();
    final reportMap = await db.getReport(id);
    
    if (reportMap == null) return null;
    
    final detectionMaps = await db.getDetectionsByReport(id);
    final detections = detectionMaps.map((map) => DamageDetection.fromMap(map)).toList();
    
    final summary = ReportSummary(
      overallSeverity: reportMap['severityLevel'],
      recommendations: (reportMap['recommendations'] ?? '').toString().split('|'),
      totalDetections: detections.length,
      criticalCount: detections.where((d) => d.severity == 'High').length,
      moderateCount: detections.where((d) => d.severity == 'Medium').length,
      minorCount: detections.where((d) => d.severity == 'Low').length,
    );
    return DetectionReport.fromMap(reportMap, detections: detections, summary: summary);
  }

  /// Delete a report and all its associated detections
  static Future<void> deleteReport(String reportId) async {
    try {
      print('Deleting report: $reportId');
      final db = DatabaseHelper();
      
      // Delete from local database first
      await db.deleteReport(reportId);
      print('Report deleted from local database: $reportId');
      
      // Try to delete from Firestore if connected
      try {
        print('Attempting to delete from Firestore...');
        final connectionOk = await FirestoreSyncService.testConnection();
        if (connectionOk) {
          await FirestoreSyncService.deleteReport(reportId);
          print('Report deleted from Firestore successfully: $reportId');
        } else {
          print('Firestore connection failed - skipping cloud deletion');
        }
      } catch (e) {
        print('Firestore deletion failed (report still deleted locally): $e');
        // Don't rethrow - local deletion succeeded, cloud failure is non-critical
      }
      
      print('Report deletion completed: $reportId');
    } catch (e) {
      print('Error deleting report: $e');
      throw Exception('Failed to delete report: $e');
    }
  }

  /// Delete multiple reports
  static Future<void> deleteReports(List<String> reportIds) async {
    try {
      print('Deleting ${reportIds.length} reports: $reportIds');
      final db = DatabaseHelper();
      
      // Delete from local database first
      await db.deleteReports(reportIds);
      print('Reports deleted from local database');
      
      // Try to delete from Firestore if connected
      try {
        print('Attempting to delete from Firestore...');
        final connectionOk = await FirestoreSyncService.testConnection();
        if (connectionOk) {
          await FirestoreSyncService.deleteReports(reportIds);
          print('Reports deleted from Firestore successfully');
        } else {
          print('Firestore connection failed - skipping cloud deletion');
        }
      } catch (e) {
        print('Firestore deletion failed (reports still deleted locally): $e');
        // Don't rethrow - local deletion succeeded, cloud failure is non-critical
      }
      
      print('Reports deletion completed');
    } catch (e) {
      print('Error deleting reports: $e');
      throw Exception('Failed to delete reports: $e');
    }
  }
}

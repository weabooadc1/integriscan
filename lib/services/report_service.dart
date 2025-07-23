import 'package:integriscan/models/report_models.dart';
import 'package:integriscan/services/recommendations_service.dart';
import 'package:integriscan/database/database_helper.dart';
import 'package:integriscan/services/firestore_sync_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ReportService {
  /// Check if a user has engineer privileges
  static Future<bool> isUserEngineer(String userId) async {
    try {
      // Check in Firestore users collection for engineer role
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      
      if (userDoc.exists) {
        final userData = userDoc.data();
        final role = userData?['role'] ?? 'user';
        return role == 'engineer' || role == 'admin';
      }
      
      // If user document doesn't exist, default to false
      return false;
    } catch (e) {
      print('Error checking engineer privileges: $e');
      // In case of error, default to false for security
      return false;
    }
  }

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

  /// Engineer Verification Methods
  
  /// Flag a report for engineer verification
  Future<void> flagReportForVerification(String reportId, String userId, {String? comments}) async {
    try {
      final db = DatabaseHelper();
      final now = DateTime.now().toIso8601String();
      
      // Update the report with verification flag
      await db.updateReportVerificationStatus(reportId, {
        'flaggedForVerification': 1,
        'flaggedAt': now,
        'verificationStatus': 'review',
        'engineerComments': comments,
      });
      
      // Create engineer verification record (for local tracking)
      final report = await getReport(reportId);
      if (report != null) {
        final verification = EngineerVerification(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          originalReportId: reportId,
          userId: userId,
          flaggedAt: DateTime.now(),
          reportSnapshot: report.toMap(),
          status: 'review',
          engineerComments: comments,
        );
        
        await db.insertEngineerVerification(verification.toMap());
        
        // Send to dedicated flagged_reports Firestore collection
        try {
          await FirestoreSyncService.uploadFlaggedReport(report, userId, comments);
          print('Report successfully sent to flagged_reports collection in Firestore');
        } catch (e) {
          print('Failed to sync flagged report to Firestore: $e');
          // Still continue with local storage even if Firestore sync fails
        }
      }
      
      print('Report $reportId flagged for engineer verification and sent to Firestore flagged_reports collection');
    } catch (e) {
      print('Error flagging report for verification: $e');
      throw Exception('Failed to flag report for verification: $e');
    }
  }
  
  /// Unflag a report from engineer verification
  Future<void> unflagReportFromVerification(String reportId) async {
    try {
      final db = DatabaseHelper();
      
      // Update the report to remove verification flag
      await db.updateReportVerificationStatus(reportId, {
        'flaggedForVerification': 0,
        'flaggedAt': null,
        'verificationStatus': 'none',
        'engineerComments': null,
        'reviewedAt': null,
      });
      
      // Remove engineer verification record
      final verification = await db.getEngineerVerificationByReportId(reportId);
      if (verification != null) {
        await db.deleteEngineerVerification(verification['id']);
        
        // Try to delete from both Firestore collections
        try {
          await FirestoreSyncService.deleteFlaggedReport(reportId);
          print('Report removed from flagged_reports collection');
        } catch (e) {
          print('Failed to delete flagged report from Firestore: $e');
        }
      }
      
      print('Report $reportId unflagged from engineer verification');
    } catch (e) {
      print('Error unflagging report from verification: $e');
      throw Exception('Failed to unflag report from verification: $e');
    }
  }
  
  /// Approve a report by an engineer (Engineers only)
  Future<void> approveReport(String reportId, String engineerUserId, String comments) async {
    try {
      // Check if user has engineer privileges
      final isEngineer = await ReportService.isUserEngineer(engineerUserId);
      if (!isEngineer) {
        throw Exception('Access denied: Only engineers can approve reports. Regular users cannot approve their own flagged reports.');
      }
      
      await _updateVerificationStatus(reportId, 'clear', engineerUserId, comments);
      
      // Update status in Firestore flagged_reports collection
      try {
        await FirestoreSyncService.updateFlaggedReportStatus(reportId, 'clear', engineerUserId, comments);
        print('Flagged report status updated to clear in Firestore');
      } catch (e) {
        print('Failed to update flagged report status in Firestore: $e');
      }
      
      print('Report $reportId cleared by engineer $engineerUserId');
    } catch (e) {
      print('Error approving report: $e');
      throw Exception('Failed to approve report: $e');
    }
  }
  
  /// Reject a report by an engineer (Engineers only)
  Future<void> rejectReport(String reportId, String engineerUserId, String comments) async {
    try {
      // Check if user has engineer privileges
      final isEngineer = await ReportService.isUserEngineer(engineerUserId);
      if (!isEngineer) {
        throw Exception('Access denied: Only engineers can reject reports. Regular users cannot reject their own flagged reports.');
      }
      
      await _updateVerificationStatus(reportId, 'issues', engineerUserId, comments);
      
      // Update status in Firestore flagged_reports collection
      try {
        await FirestoreSyncService.updateFlaggedReportStatus(reportId, 'issues', engineerUserId, comments);
        print('Flagged report status updated to issues in Firestore');
      } catch (e) {
        print('Failed to update flagged report status in Firestore: $e');
      }
      
      print('Report $reportId marked with issues by engineer $engineerUserId');
    } catch (e) {
      print('Error rejecting report: $e');
      throw Exception('Failed to reject report: $e');
    }
  }
  
  /// Get all reports under review by engineer
  Future<List<DetectionReport>> getReportsUnderReview() async {
    try {
      final db = DatabaseHelper();
      final reportMaps = await db.getReportsByVerificationStatus('review');
      
      List<DetectionReport> reports = [];
      for (final map in reportMaps) {
        final report = await getReport(map['id']);
        if (report != null) {
          reports.add(report);
        }
      }
      
      return reports;
    } catch (e) {
      print('Error getting reports under review: $e');
      throw Exception('Failed to get reports under review: $e');
    }
  }
  
  /// Get all engineer verification records
  Future<List<EngineerVerification>> getAllEngineerVerifications() async {
    try {
      final db = DatabaseHelper();
      final verificationMaps = await db.getAllEngineerVerifications();
      
      return verificationMaps
          .map((map) => EngineerVerification.fromMap(map))
          .toList();
    } catch (e) {
      print('Error getting engineer verifications: $e');
      throw Exception('Failed to get engineer verifications: $e');
    }
  }
  
  /// Get engineer verification by status
  Future<List<EngineerVerification>> getEngineerVerificationsByStatus(String status) async {
    try {
      final db = DatabaseHelper();
      final verificationMaps = await db.getEngineerVerificationsByStatus(status);
      
      return verificationMaps
          .map((map) => EngineerVerification.fromMap(map))
          .toList();
    } catch (e) {
      print('Error getting verifications by status: $e');
      throw Exception('Failed to get verifications by status: $e');
    }
  }

  /// Private helper method to update verification status
  Future<void> _updateVerificationStatus(String reportId, String status, String engineerUserId, String comments) async {
    final db = DatabaseHelper();
    final now = DateTime.now().toIso8601String();
    
    // Update the report
    await db.updateReportVerificationStatus(reportId, {
      'verificationStatus': status,
      'engineerComments': comments,
      'reviewedAt': now,
    });
    
    // Update flagged report in Firestore with new single-collection approach
    try {
      await FirestoreSyncService.updateFlaggedReportStatus(
        reportId, 
        status, 
        engineerUserId, 
        comments
      );
    } catch (e) {
      print('Failed to sync updated verification to Firestore: $e');
    }
  }
  }

  /// Update engineer verification status and sync to Firestore
  Future<bool> updateVerificationStatus(String reportId, String status, 
      {String? comments, String? engineerId}) async {
    try {
      // Update verification status using new single-collection approach
      await FirestoreSyncService.updateFlaggedReportStatus(
        reportId, 
        status, 
        engineerId ?? 'unknown', 
        comments
      );
      
      return true;
    } catch (e) {
      print('Error updating verification status: $e');
      throw Exception('Failed to update verification status: $e');
    }
  }

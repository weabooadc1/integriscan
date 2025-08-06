import 'package:integriscan/models/report_models.dart';
import 'package:integriscan/services/recommendations_service.dart';
import 'package:integriscan/database/database_helper.dart';
import 'package:integriscan/services/firestore_sync_service.dart';
import 'package:integriscan/services/connectivity_service.dart';
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
      
      // Check connectivity first
      final connectivityService = ConnectivityService();
      if (!connectivityService.isConnected) {
        print('No connectivity - skipping sync for report ${report.id}');
        return;
      }
      
      // Test Firebase connection
      final connectionOk = await FirestoreSyncService.testConnection();
      if (!connectionOk) {
        print('Firebase connection test failed - skipping sync for report ${report.id}');
        return;
      }
      
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
      
      // Check connectivity first
      final connectivityService = ConnectivityService();
      if (!connectivityService.isConnected) {
        print('No connectivity - skipping background sync');
        return;
      }
      
      final db = DatabaseHelper();
      final unsyncedMaps = await db.getUnsyncedReports(userId: userId);
      print('Found ${unsyncedMaps.length} unsynced reports for userId: $userId');
      
      if (unsyncedMaps.isEmpty) {
        print('No unsynced reports found');
        return;
      }
      
      // Test Firebase connection before attempting to sync multiple reports
      final connectionOk = await FirestoreSyncService.testConnection();
      if (!connectionOk) {
        print('Firebase connection test failed - skipping background sync');
        return;
      }
      
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

  /// Download and sync reports from Firestore to local database
  static Future<void> syncReportsFromCloud({String? userId}) async {
    try {
      print('Starting sync from Firestore to local database...');
      
      if (userId == null) {
        print('No userId provided for sync from cloud');
        return;
      }
      
      // Check connectivity first
      final connectivityService = ConnectivityService();
      if (!connectivityService.isConnected) {
        print('No connectivity - skipping sync from cloud');
        return;
      }
      
      // Test Firebase connection
      final connectionOk = await FirestoreSyncService.testConnection();
      if (!connectionOk) {
        print('Firebase connection test failed - skipping sync from cloud');
        return;
      }
      
      // Download reports from Firestore
      final cloudReports = await FirestoreSyncService.downloadUserReports(userId);
      print('Downloaded ${cloudReports.length} reports from Firestore');
      
      final db = DatabaseHelper();
      
      // Get all local reports for this user
      final localReports = await db.getReports(userId: userId);
      print('Found ${localReports.length} local reports for user $userId');
      
      // Check for reports that exist locally but not in cloud (deleted reports)
      final cloudReportIds = cloudReports.map((r) => r['id'] as String).toSet();
      final localReportIds = localReports.map((r) => r['id'] as String).toSet();
      final deletedReportIds = localReportIds.difference(cloudReportIds);
      
      if (deletedReportIds.isNotEmpty) {
        print('Found ${deletedReportIds.length} reports deleted from cloud: $deletedReportIds');
        // Delete these reports from local database
        for (final deletedId in deletedReportIds) {
          try {
            print('Deleting local report that was removed from cloud: $deletedId');
            await db.deleteReport(deletedId);
          } catch (e) {
            print('Error deleting local report $deletedId: $e');
          }
        }
      }
      
      if (cloudReports.isEmpty && deletedReportIds.isEmpty) {
        print('No reports found in Firestore for user $userId and no deletions needed');
        return;
      }
      
      int newReports = 0;
      int updatedReports = 0;
      
      for (final cloudReport in cloudReports) {
        try {
          final reportId = cloudReport['id'] as String;
          
          // Check if report already exists locally
          final existingReport = await db.getReport(reportId);
          
          if (existingReport == null) {
            // New report - save to local database
            print('Saving new report to local database: $reportId');
            
            // Extract detections
            final detections = (cloudReport['detections'] as List<dynamic>? ?? [])
                .map((d) => d as Map<String, dynamic>)
                .toList();
            
            // Save report to local database
            await db.insertReport({
              'id': reportId,
              'userId': cloudReport['userId'],
              'sessionName': cloudReport['sessionName'] ?? 'Downloaded Report',
              'createdAt': cloudReport['createdAt'],
              'detectionsCount': detections.length, // Add the missing field
              'severityLevel': cloudReport['severityLevel'] ?? 'Low',
              'recommendations': (cloudReport['recommendations'] as List<dynamic>? ?? []).join('|'),
              'synced': 1, // Mark as synced since it came from cloud
            });
            
            // Save detections
            for (final detection in detections) {
              await db.insertDetection({
                'id': detection['id'],
                'reportId': reportId,
                'damageType': detection['damageType'],
                'confidence': detection['confidence'],
                'imagePath': detection['imagePath'],
                'timestamp': detection['timestamp'],
                'boundingBox': detection['boundingBox']?.toString(),
                'severity': detection['severity'],
                'recommendations': (detection['recommendations'] as List<dynamic>? ?? []).join('|'),
              });
            }
            
            newReports++;
            print('Successfully saved report $reportId with ${detections.length} detections');
          } else {
            // Report exists - potentially update if cloud version is newer
            final cloudDate = DateTime.parse(cloudReport['createdAt'] as String);
            final localDate = DateTime.parse(existingReport['createdAt'] as String);
            
            if (cloudDate.isAfter(localDate)) {
              print('Cloud version is newer, updating local report: $reportId');
              // Update logic here if needed
              updatedReports++;
            }
          }
        } catch (e) {
          print('Error processing cloud report: $e');
          continue;
        }
      }
      
      print('Sync from cloud completed: $newReports new, $updatedReports updated, ${deletedReportIds.length} deleted');
      
      // Also sync flagged reports
      await syncFlaggedReportsFromCloud(userId: userId);
      
    } catch (e) {
      print('Error during sync from cloud: $e');
    }
  }

  /// Download and sync flagged reports from Firestore to local database
  static Future<void> syncFlaggedReportsFromCloud({String? userId}) async {
    try {
      print('Starting flagged reports sync from Firestore to local database...');
      
      if (userId == null) {
        print('No userId provided for flagged reports sync from cloud');
        return;
      }
      
      // Check connectivity first
      final connectivityService = ConnectivityService();
      if (!connectivityService.isConnected) {
        print('No connectivity - skipping flagged reports sync from cloud');
        return;
      }
      
      // Test Firebase connection
      final connectionOk = await FirestoreSyncService.testConnection();
      if (!connectionOk) {
        print('Firebase connection test failed - skipping flagged reports sync from cloud');
        return;
      }
      
      // Download flagged reports from Firestore
      final flaggedReports = await FirestoreSyncService.downloadFlaggedReports(userId);
      print('Downloaded ${flaggedReports.length} flagged reports from Firestore');
      
      final db = DatabaseHelper();
      
      // Get all local flagged reports for this user
      final localFlaggedReports = await db.getReports(userId: userId);
      final localFlaggedReportIds = localFlaggedReports
          .where((r) => r['flaggedForVerification'] == 1)
          .map((r) => r['id'] as String)
          .toSet();
      
      // Get cloud flagged report IDs that involve this user
      final cloudFlaggedReportIds = flaggedReports
          .where((r) => 
              (r['userId'] == userId || r['flaggedByUserId'] == userId))
          .map((r) => r['id'] as String)
          .toSet();
      
      // Check for flagged reports that exist locally but not in cloud (unflagged/deleted)
      final unflaggedReportIds = localFlaggedReportIds.difference(cloudFlaggedReportIds);
      
      if (unflaggedReportIds.isNotEmpty) {
        print('Found ${unflaggedReportIds.length} reports unflagged in cloud: $unflaggedReportIds');
        // Reset flagged status for these reports
        for (final unflaggedId in unflaggedReportIds) {
          try {
            print('Resetting flagged status for report: $unflaggedId');
            await db.updateReportVerificationStatus(unflaggedId, {
              'flaggedForVerification': 0,
              'flaggedAt': null,
              'verificationStatus': null,
              'engineerComments': null,
              'reviewedAt': null,
            });
          } catch (e) {
            print('Error resetting flagged status for report $unflaggedId: $e');
          }
        }
      }
      
      if (flaggedReports.isEmpty && unflaggedReportIds.isEmpty) {
        print('No flagged reports found in Firestore and no unflagging needed');
        return;
      }
      
      int flaggedReportsUpdated = 0;
      
      for (final flaggedReport in flaggedReports) {
        try {
          final reportId = flaggedReport['id'] as String;
          final reportUserId = flaggedReport['userId'] as String?;
          final flaggedByUserId = flaggedReport['flaggedByUserId'] as String?;
          
          // Only process flagged reports that involve the current user
          // (either they own the report or they flagged it)
          if (reportUserId != userId && flaggedByUserId != userId) {
            continue;
          }
          
          print('Processing flagged report: $reportId');
          
          // Check if the base report exists locally
          final existingReport = await db.getReport(reportId);
          if (existingReport != null) {
            // Update the report's flagged status and verification details
            await db.updateReportVerificationStatus(reportId, {
              'flaggedForVerification': 1,
              'flaggedAt': flaggedReport['flaggedAt'],
              'verificationStatus': flaggedReport['status'] ?? 'review',
              'engineerComments': flaggedReport['engineerComments'],
              'reviewedAt': flaggedReport['reviewedAt'],
            });
            
            flaggedReportsUpdated++;
            print('Updated flagged report: $reportId');
          } else {
            print('Base report not found locally for flagged report: $reportId');
            // The base report might need to be downloaded first
            // This could happen if a report was flagged on another device
            // but the base report sync hasn't happened yet
          }
        } catch (e) {
          print('Error processing flagged report: $e');
          continue;
        }
      }
      
      print('Flagged reports sync completed: $flaggedReportsUpdated updated, ${unflaggedReportIds.length} unflagged');
    } catch (e) {
      print('Error during flagged reports sync from cloud: $e');
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
      
      // Always use RecommendationsService for consistent expert recommendations
      final recommendations = RecommendationsService.getRecommendations(
        detection['damageType'],
        detection['confidence'],
      );
      print('Using RecommendationsService recommendations: ${recommendations.length} items');
      
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

    // Save to database (always save locally first)
    print('Saving report to local database...');
    await _saveReportToDatabase(report);
    print('Report saved to local database successfully');

    // Try to sync to Firestore if requested and connection is available
    if (trySyncToCloud) {
      print('Attempting cloud sync...');
      // Use an instance to call non-static method
      await ReportService().trySyncReportToCloud(report);
    } else {
      print('Cloud sync skipped (offline mode)');
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
    var reportMaps = await db.getReports(userId: userId);
    
    // If local database is empty and user is provided, try to sync from cloud
    if (reportMaps.isEmpty && userId != null) {
      print('Local reports empty for user $userId, attempting to sync from cloud...');
      await syncReportsFromCloud(userId: userId);
      
      // Retry getting reports after sync
      reportMaps = await db.getReports(userId: userId);
      print('After cloud sync, found ${reportMaps.length} reports locally');
    }
    
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
      
      // Always try to delete from Firestore (let Firestore handle connectivity)
      try {
        print('Attempting Firestore deletion...');
        await FirestoreSyncService.deleteReport(reportId)
            .timeout(const Duration(seconds: 30));
        print('Report deleted from Firestore successfully: $reportId');
      } catch (e) {
        print('Firestore deletion failed for report $reportId: $e');
        if (e.toString().contains('timeout') || e.toString().contains('TimeoutException')) {
          print('Deletion timed out - network may be slow or unstable');
        } else if (e.toString().contains('permission') || e.toString().contains('PERMISSION_DENIED')) {
          print('Permission denied - user may not be authenticated');
        } else if (e.toString().contains('network') || e.toString().contains('unavailable')) {
          print('Network unavailable - skipping cloud deletion');
        } else {
          print('Other Firestore error: $e');
        }
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
      
      // Always try to delete from Firestore (let Firestore handle connectivity)
      try {
        print('Attempting bulk Firestore deletion...');
        await FirestoreSyncService.deleteReports(reportIds)
            .timeout(const Duration(seconds: 60)); // Longer timeout for multiple deletes
        print('All ${reportIds.length} reports deleted from Firestore successfully');
      } catch (e) {
        print('Firestore bulk deletion failed for ${reportIds.length} reports: $e');
        if (e.toString().contains('timeout') || e.toString().contains('TimeoutException')) {
          print('Bulk deletion timed out - network may be slow or too many reports');
        } else if (e.toString().contains('permission') || e.toString().contains('PERMISSION_DENIED')) {
          print('Permission denied - user may not be authenticated');
        } else if (e.toString().contains('network') || e.toString().contains('unavailable')) {
          print('Network unavailable - skipping cloud deletion');
        } else {
          print('Other Firestore error: $e');
        }
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

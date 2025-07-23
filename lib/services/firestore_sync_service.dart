import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:integriscan/models/report_models.dart';

class FirestoreSyncService {
  static final _firestore = FirebaseFirestore.instance;

  static Future<void> uploadReport(DetectionReport report) async {
    try {
      print('Starting Firestore upload for report: ${report.id}');
      
      // Upload main report document
      final reportRef = _firestore.collection('reports').doc(report.id);
      final reportData = {
        'id': report.id,
        'userId': report.userId,
        'sessionName': report.sessionName,
        'createdAt': report.createdAt.toIso8601String(),
        'detectionsCount': report.detections.length,
        'severityLevel': report.summary.overallSeverity,
        'recommendations': report.summary.recommendations,
        'summary': report.summary.toMap(),
        'syncedAt': DateTime.now().toIso8601String(),
      };
      
      print('Uploading report data to Firestore...');
      await reportRef.set(reportData);
      print('Report document uploaded successfully');
      
      // Upload detections as subcollection
      print('Uploading ${report.detections.length} detections...');
      final detectionsRef = reportRef.collection('detections');
      
      for (final detection in report.detections) {
        final detectionData = {
          'id': detection.id,
          'reportId': detection.reportId,
          'damageType': detection.damageType,
          'confidence': detection.confidence,
          'imagePath': detection.imagePath,
          'timestamp': detection.timestamp.toIso8601String(),
          'boundingBox': detection.boundingBox?.toMap(),
          'severity': detection.severity,
          'recommendations': detection.recommendations,
        };
        
        await detectionsRef.doc(detection.id).set(detectionData);
        print('Detection ${detection.id} uploaded');
      }
      
      print('All detections uploaded successfully');
    } catch (e) {
      print('Error uploading report to Firestore: $e');
      rethrow; // Re-throw so caller can handle
    }
  }
  
  /// Test Firestore connectivity
  static Future<bool> testConnection() async {
    try {
      print('Testing Firestore connection...');
      await _firestore.collection('test').doc('connectivity').set({
        'timestamp': DateTime.now().toIso8601String(),
        'test': true,
      });
      print('Firestore connection test successful');
      return true;
    } catch (e) {
      print('Firestore connection test failed: $e');
      return false;
    }
  }

  /// Delete a report and all its detections from Firestore
  static Future<void> deleteReport(String reportId) async {
    try {
      print('Starting Firestore delete for report: $reportId');
      
      final reportRef = _firestore.collection('reports').doc(reportId);
      
      // First, delete all detections in the subcollection
      print('Deleting detections subcollection...');
      final detectionsRef = reportRef.collection('detections');
      final detectionsSnapshot = await detectionsRef.get();
      
      // Delete each detection document
      final batch = _firestore.batch();
      for (final detectionDoc in detectionsSnapshot.docs) {
        batch.delete(detectionDoc.reference);
      }
      
      // Delete the main report document
      batch.delete(reportRef);
      
      // Also clean up any related verification records
      print('Cleaning up verification records...');
      try {
        // Delete from flagged_reports collection if exists
        final flaggedRef = _firestore.collection('flagged_reports').doc(reportId);
        batch.delete(flaggedRef);
        
        print('Added flagged report cleanup to batch');
      } catch (e) {
        print('Warning: Could not clean up flagged report: $e');
        // Continue with report deletion even if flagged report cleanup fails
      }
      
      // Commit all deletions
      await batch.commit();
      print('Report, detections, and flagged report deleted from Firestore successfully');
      
    } catch (e) {
      print('Error deleting report from Firestore: $e');
      rethrow; // Re-throw so caller can handle
    }
  }

  /// Delete multiple reports from Firestore
  static Future<void> deleteReports(List<String> reportIds) async {
    try {
      print('Starting Firestore delete for ${reportIds.length} reports');
      
      final batch = _firestore.batch();
      
      for (final reportId in reportIds) {
        print('Processing delete for report: $reportId');
        
        final reportRef = _firestore.collection('reports').doc(reportId);
        
        // Get and delete all detections in the subcollection
        final detectionsRef = reportRef.collection('detections');
        final detectionsSnapshot = await detectionsRef.get();
        
        // Add each detection deletion to batch
        for (final detectionDoc in detectionsSnapshot.docs) {
          batch.delete(detectionDoc.reference);
        }
        
        // Add report deletion to batch
        batch.delete(reportRef);
        
        // Also clean up any related verification records
        try {
          // Delete from flagged_reports collection if exists
          final flaggedRef = _firestore.collection('flagged_reports').doc(reportId);
          batch.delete(flaggedRef);
          
        } catch (e) {
          print('Warning: Could not clean up flagged report for $reportId: $e');
          // Continue with report deletion even if flagged report cleanup fails
        }
      }
      
      // Commit all deletions
      await batch.commit();
      print('All reports, detections, and flagged reports deleted from Firestore successfully');
      
    } catch (e) {
      print('Error deleting reports from Firestore: $e');
      rethrow; // Re-throw so caller can handle
    }
  }

  /// Engineer Verification Firestore Methods
  
  /// Upload flagged report to dedicated flagged_reports collection
  static Future<void> uploadFlaggedReport(DetectionReport report, String flaggedByUserId, String? comments) async {
    try {
      print('Starting Firestore upload for flagged report: ${report.id}');
      
      final flaggedReportRef = _firestore.collection('flagged_reports').doc(report.id);
      final flaggedReportData = {
        'id': report.id,
        'userId': report.userId, // Report owner
        'flaggedByUserId': flaggedByUserId, // User who flagged it
        'flaggedAt': DateTime.now().toIso8601String(),
        'flaggedComments': comments,
        
        // Verification fields (initially null/review)
        'status': 'review', // review, clear, issues
        'engineerId': null, // Will be set when engineer reviews
        'engineerComments': null, // Will be set when engineer reviews
        'reviewedAt': null, // Will be set when engineer reviews
        
        // Full report data
        'reportData': {
          'id': report.id,
          'userId': report.userId,
          'sessionName': report.sessionName,
          'createdAt': report.createdAt.toIso8601String(),
          'detectionsCount': report.detections.length,
          'severityLevel': report.summary.overallSeverity,
          'recommendations': report.summary.recommendations,
          'summary': report.summary.toMap(),
          'detections': report.detections.map((d) => {
            'id': d.id,
            'reportId': d.reportId,
            'damageType': d.damageType,
            'confidence': d.confidence,
            'imagePath': d.imagePath,
            'timestamp': d.timestamp.toIso8601String(),
            'boundingBox': d.boundingBox?.toMap(),
            'severity': d.severity,
            'recommendations': d.recommendations,
          }).toList(),
        },
        'syncedAt': DateTime.now().toIso8601String(),
      };
      
      await flaggedReportRef.set(flaggedReportData);
      print('Flagged report uploaded to Firestore successfully');
      
    } catch (e) {
      print('Error uploading flagged report to Firestore: $e');
      rethrow;
    }
  }
  
  /// Update flagged report verification status
  static Future<void> updateFlaggedReportStatus(String reportId, String status, String engineerId, String? comments) async {
    try {
      print('Updating flagged report status: $reportId to $status');
      
      await _firestore.collection('flagged_reports').doc(reportId).update({
        'status': status,
        'engineerId': engineerId,
        'engineerComments': comments ?? '',
        'reviewedAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
      });
      print('Flagged report status updated in Firestore successfully');
      
    } catch (e) {
      print('Error updating flagged report status in Firestore: $e');
      rethrow;
    }
  }
  
  /// Delete flagged report from Firestore
  static Future<void> deleteFlaggedReport(String reportId) async {
    try {
      print('Deleting flagged report $reportId from Firestore...');
      
      await _firestore.collection('flagged_reports').doc(reportId).delete();
      print('Flagged report deleted from Firestore successfully');
      
    } catch (e) {
      print('Error deleting flagged report from Firestore: $e');
      rethrow;
    }
  }
  
  /// Get all flagged reports from Firestore
  static Future<List<Map<String, dynamic>>> downloadFlaggedReports() async {
    try {
      print('Downloading flagged reports from Firestore...');
      
      final querySnapshot = await _firestore.collection('flagged_reports').get();
      final flaggedReports = <Map<String, dynamic>>[];
      
      for (final doc in querySnapshot.docs) {
        flaggedReports.add({
          'id': doc.id,
          ...doc.data(),
        });
      }
      
      print('Downloaded ${flaggedReports.length} flagged reports from Firestore');
      return flaggedReports;
      
    } catch (e) {
      print('Error downloading flagged reports from Firestore: $e');
      rethrow;
    }
  }

  /// Stream flagged reports for real-time updates
  static Stream<List<Map<String, dynamic>>> streamFlaggedReports([String? userId]) {
    try {
      Query query = _firestore.collection('flagged_reports');
      
      // If userId is provided, filter by userId (report owner) or flaggedByUserId (flagger)
      if (userId != null) {
        // For now, let's get all and filter in memory to avoid complex queries
        // In production, you might want separate methods for different user perspectives
      }
      
      return query.snapshots().map((snapshot) {
        return snapshot.docs.map((doc) => {
          'id': doc.id,
          'reportId': doc.id, // For compatibility with existing UI code
          ...doc.data() as Map<String, dynamic>,
        }).toList();
      });
    } catch (e) {
      print('Error creating flagged reports stream: $e');
      // Return an empty stream on error
      return Stream.value([]);
    }
  }

  /// Stream a specific flagged report for real-time updates
  static Stream<Map<String, dynamic>?> streamFlaggedReport(String reportId) {
    try {
      return _firestore
          .collection('flagged_reports')
          .doc(reportId)
          .snapshots()
          .map((doc) {
        if (doc.exists) {
          return {
            'id': doc.id,
            ...doc.data() as Map<String, dynamic>,
          };
        }
        return null;
      });
    } catch (e) {
      print('Error creating flagged report stream: $e');
      return Stream.value(null);
    }
  }

  /// Stream flagged report by ID for real-time updates
  static Stream<Map<String, dynamic>?> streamFlaggedReportById(String reportId) {
    try {
      return _firestore
          .collection('flagged_reports')
          .doc(reportId)
          .snapshots()
          .map((snapshot) {
        if (snapshot.exists) {
          return {
            'id': snapshot.id,
            'reportId': snapshot.id, // For compatibility
            ...snapshot.data() as Map<String, dynamic>,
          };
        }
        return null;
      });
    } catch (e) {
      print('Error creating flagged report stream: $e');
      return Stream.value(null);
    }
  }
}

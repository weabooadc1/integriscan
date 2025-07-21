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
      
      // Commit all deletions
      await batch.commit();
      print('Report and all detections deleted from Firestore successfully');
      
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
      }
      
      // Commit all deletions
      await batch.commit();
      print('All reports and their detections deleted from Firestore successfully');
      
    } catch (e) {
      print('Error deleting reports from Firestore: $e');
      rethrow; // Re-throw so caller can handle
    }
  }
}

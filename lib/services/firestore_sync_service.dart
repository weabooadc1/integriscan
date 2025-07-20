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
}

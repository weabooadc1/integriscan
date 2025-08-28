import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:integriscan/models/report_models.dart';
import 'package:integriscan/services/firebase_storage_service.dart';

class FirestoreSyncService {
  static final _firestore = FirebaseFirestore.instance;

  static Future<void> uploadReport(DetectionReport report) async {
    try {
      print('Starting Firestore upload for report: ${report.id}');
      
      // First, upload images to Firebase Storage and get download URLs
      print('Uploading images to Firebase Storage...');
      final detectionMaps = report.detections.map((d) => {
        'id': d.id,
        'imagePath': d.imagePath,
      }).toList();
      
      final imageUrls = await FirebaseStorageService.uploadReportImages(detectionMaps, report.id, report.userId);
      print('Uploaded ${imageUrls.length} images to Firebase Storage');
      
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
      
      // Upload detections as subcollection with Firebase Storage URLs
      print('Uploading ${report.detections.length} detections...');
      final detectionsRef = reportRef.collection('detections');
      
      for (final detection in report.detections) {
        // Use Firebase Storage URL if available, otherwise use local path
        final imageUrl = imageUrls[detection.id] ?? detection.imagePath;
        
        final detectionData = {
          'id': detection.id,
          'reportId': detection.reportId,
          'damageType': detection.damageType,
          'confidence': detection.confidence,
          'imagePath': imageUrl, // This will be the Firebase Storage download URL
          'timestamp': detection.timestamp.toIso8601String(),
          'boundingBox': detection.boundingBox?.toMap(),
          'severity': detection.severity,
          'recommendations': detection.recommendations,
        };
        
        await detectionsRef.doc(detection.id).set(detectionData);
        print('Detection ${detection.id} uploaded with image URL: ${imageUrl.length > 50 ? '${imageUrl.substring(0, 50)}...' : imageUrl}');
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
      }).timeout(const Duration(seconds: 5));
      print('Firestore connection test successful');
      return true;
    } catch (e) {
      print('Firestore connection test failed: $e');
      return false;
    }
  }

  /// Download all reports for a user from Firestore
  static Future<List<Map<String, dynamic>>> downloadUserReports(String userId) async {
    try {
      print('Downloading reports for user: $userId');
      
      final querySnapshot = await _firestore
          .collection('reports')
          .where('userId', isEqualTo: userId)
          .get()
          .timeout(const Duration(seconds: 30));
      
      List<Map<String, dynamic>> reports = [];
      
      for (final doc in querySnapshot.docs) {
        final reportData = doc.data();
        
        // Download detections for this report
        final detectionsSnapshot = await doc.reference
            .collection('detections')
            .get()
            .timeout(const Duration(seconds: 15));
        
        final detections = detectionsSnapshot.docs
            .map((detectionDoc) => detectionDoc.data())
            .toList();
        
        // Download images from Firebase Storage for detections
        print('Downloading images for report ${reportData['id']}...');
        final localImagePaths = await FirebaseStorageService.downloadReportImages(detections, reportData['id']);
        
        // Update detection image paths with local paths
        for (final detection in detections) {
          final detectionId = detection['id'];
          if (localImagePaths.containsKey(detectionId)) {
            detection['imagePath'] = localImagePaths[detectionId];
          }
        }
        
        // Add detections to report data
        reportData['detections'] = detections;
        reports.add(reportData);
        
        print('Downloaded report ${reportData['id']} with ${detections.length} detections');
      }
      
      print('Downloaded ${reports.length} reports from Firestore');
      return reports;
    } catch (e) {
      print('Error downloading user reports: $e');
      return [];
    }
  }

  /// Download a specific report from Firestore
  static Future<Map<String, dynamic>?> downloadReport(String reportId) async {
    try {
      print('Downloading report: $reportId');
      
      final docSnapshot = await _firestore
          .collection('reports')
          .doc(reportId)
          .get()
          .timeout(const Duration(seconds: 15));
      
      if (!docSnapshot.exists) {
        print('Report not found in Firestore: $reportId');
        return null;
      }
      
      final reportData = docSnapshot.data()!;
      
      // Download detections for this report
      final detectionsSnapshot = await docSnapshot.reference
          .collection('detections')
          .get()
          .timeout(const Duration(seconds: 15));
      
      final detections = detectionsSnapshot.docs
          .map((detectionDoc) => detectionDoc.data())
          .toList();
      
      // Download images from Firebase Storage for detections
      print('Downloading images for report $reportId...');
      final localImagePaths = await FirebaseStorageService.downloadReportImages(detections, reportId);
      
      // Update detection image paths with local paths
      for (final detection in detections) {
        final detectionId = detection['id'];
        if (localImagePaths.containsKey(detectionId)) {
          detection['imagePath'] = localImagePaths[detectionId];
        }
      }
      
      // Add detections to report data
      reportData['detections'] = detections;
      
      print('Downloaded report $reportId with ${detections.length} detections');
      return reportData;
    } catch (e) {
      print('Error downloading report $reportId: $e');
      return null;
    }
  }

  /// Delete a report and all its detections from Firestore
  static Future<void> deleteReport(String reportId) async {
    try {
      print('Starting Firestore delete for report: $reportId');
      
      final reportRef = _firestore.collection('reports').doc(reportId);
      
      // First, get detections to delete their images from Firebase Storage
      print('Getting detections for image cleanup...');
      final detectionsRef = reportRef.collection('detections');
      final detectionsSnapshot = await detectionsRef.get()
          .timeout(const Duration(seconds: 15));
      
      // Delete images from Firebase Storage
      print('Deleting images from Firebase Storage...');
      for (final detectionDoc in detectionsSnapshot.docs) {
        final detectionData = detectionDoc.data();
        final imagePath = detectionData['imagePath'] as String?;
        
        if (imagePath != null && FirebaseStorageService.isFirebaseUrl(imagePath)) {
          try {
            await FirebaseStorageService.deleteImage(imagePath);
            print('Deleted image for detection ${detectionDoc.id}');
          } catch (e) {
            print('Warning: Could not delete image for detection ${detectionDoc.id}: $e');
          }
        }
      }
      
      // Delete detection documents
      print('Deleting detections subcollection...');
      final batch = _firestore.batch();
      for (final detectionDoc in detectionsSnapshot.docs) {
        batch.delete(detectionDoc.reference);
      }
      
      // Delete the main report document
      batch.delete(reportRef);
      
      // Also clean up any related verification records
      print('Cleaning up verification records...');
      try {
        // Check if flagged report exists and delete it separately (not in batch)
        // This ensures security rules can be properly evaluated
        final flaggedRef = _firestore.collection('flagged_reports').doc(reportId);
        final flaggedDoc = await flaggedRef.get();
        
        if (flaggedDoc.exists) {
          print('Flagged report exists, deleting separately...');
          await flaggedRef.delete().timeout(const Duration(seconds: 10));
          print('Flagged report deleted successfully');
        } else {
          print('No flagged report found for this report');
        }
      } catch (e) {
        print('Warning: Could not clean up flagged report: $e');
        // Continue with report deletion even if flagged report cleanup fails
      }
      
      // Commit all deletions with timeout
      await batch.commit().timeout(const Duration(seconds: 20));
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
        final detectionsSnapshot = await detectionsRef.get()
            .timeout(const Duration(seconds: 15));
        
        // Add each detection deletion to batch
        for (final detectionDoc in detectionsSnapshot.docs) {
          batch.delete(detectionDoc.reference);
        }
        
        // Add report deletion to batch
        batch.delete(reportRef);
        
        // Clean up flagged reports separately (not in batch to ensure security rules work)
        try {
          final flaggedRef = _firestore.collection('flagged_reports').doc(reportId);
          final flaggedDoc = await flaggedRef.get();
          
          if (flaggedDoc.exists) {
            print('Deleting flagged report for batch deletion: $reportId');
            await flaggedRef.delete().timeout(const Duration(seconds: 10));
            print('Flagged report deleted successfully: $reportId');
          }
        } catch (e) {
          print('Warning: Could not clean up flagged report for $reportId: $e');
          // Continue with report deletion even if flagged report cleanup fails
        }
      }
      
      // Commit all deletions with timeout
      await batch.commit().timeout(const Duration(seconds: 30));
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
      
      // First, upload images to Firebase Storage and get download URLs
      print('Uploading images to Firebase Storage for flagged report...');
      final detectionMaps = report.detections.map((d) => {
        'id': d.id,
        'imagePath': d.imagePath,
      }).toList();
      
      final imageUrls = await FirebaseStorageService.uploadReportImages(detectionMaps, report.id, report.userId);
      print('Uploaded ${imageUrls.length} images to Firebase Storage for flagged report');
      
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
            'imagePath': imageUrls[d.id] ?? d.imagePath, // Use Firebase Storage URL if available
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
  
  /// Get flagged reports for a specific user from Firestore
  static Future<List<Map<String, dynamic>>> downloadFlaggedReports([String? userId]) async {
    try {
      print('Downloading flagged reports from Firestore...');
      
      Query query = _firestore.collection('flagged_reports');
      
      // If userId is provided, filter to get flagged reports where the user is either
      // the report owner or the one who flagged it
      if (userId != null) {
        // Note: Firestore doesn't support OR queries directly, so we'll get all and filter
        // In production, you might want to create compound indexes or separate queries
        print('Filtering flagged reports for user: $userId');
      }
      
      final querySnapshot = await query.get().timeout(const Duration(seconds: 30));
      final flaggedReports = <Map<String, dynamic>>[];
      
      for (final doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        
        // Filter by userId if provided
        if (userId != null) {
          final reportUserId = data['userId'] as String?;
          final flaggedByUserId = data['flaggedByUserId'] as String?;
          
          // Include if user owns the report or flagged it
          if (reportUserId == userId || flaggedByUserId == userId) {
            flaggedReports.add({
              'id': doc.id,
              ...data,
            });
          }
        } else {
          // Include all if no userId filter
          flaggedReports.add({
            'id': doc.id,
            ...data,
          });
        }
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
      
      return query.snapshots().handleError((error) {
        print('Firestore stream error: $error');
        // If it's a permission error, just return empty data instead of crashing
        if (error.toString().contains('permission-denied') || 
            error.toString().contains('PERMISSION_DENIED')) {
          print('Permission denied in Firestore stream - user likely logged out');
          return [];
        }
        throw error;
      }).map((snapshot) {
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

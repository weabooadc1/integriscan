import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class FirebaseStorageService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Upload an image file to Firebase Storage
  static Future<String?> uploadImage(String localPath, String reportId, String detectionId) async {
    try {
      if (localPath.isEmpty || !File(localPath).existsSync()) {
        print('Image file does not exist: $localPath');
        return null;
      }

      final file = File(localPath);
      final fileName = path.basename(localPath);
      
      // Create a reference to the storage location
      final storageRef = _storage.ref().child('detection_images/$reportId/$detectionId/$fileName');
      
      print('Uploading image to Firebase Storage: $fileName');
      
      // Upload the file
      final uploadTask = storageRef.putFile(file);
      final snapshot = await uploadTask.timeout(const Duration(minutes: 2));
      
      // Get the download URL
      final downloadUrl = await snapshot.ref.getDownloadURL();
      
      print('Image uploaded successfully: $downloadUrl');
      return downloadUrl;
      
    } catch (e) {
      print('Error uploading image to Firebase Storage: $e');
      return null;
    }
  }

  /// Download an image from Firebase Storage and save it locally
  static Future<String?> downloadImage(String downloadUrl, String reportId, String detectionId) async {
    try {
      if (downloadUrl.isEmpty || !downloadUrl.startsWith('http')) {
        print('Invalid download URL: $downloadUrl');
        return null;
      }

      // Create local storage directory
      final directory = await getApplicationDocumentsDirectory();
      final framesDir = Directory('${directory.path}/frames');
      
      if (!await framesDir.exists()) {
        await framesDir.create(recursive: true);
      }

      // Generate local file name
      final fileName = 'downloaded_${reportId}_${detectionId}_${DateTime.now().millisecondsSinceEpoch}.png';
      final localFile = File('${framesDir.path}/$fileName');

      // Check if we already have this image locally
      if (await localFile.exists()) {
        print('Image already exists locally: ${localFile.path}');
        return localFile.path;
      }

      print('Downloading image from Firebase Storage...');
      
      // Create a reference from the download URL
      final ref = _storage.refFromURL(downloadUrl);
      
      // Download the file
      await ref.writeToFile(localFile).timeout(const Duration(minutes: 2));
      
      print('Image downloaded successfully: ${localFile.path}');
      return localFile.path;
      
    } catch (e) {
      print('Error downloading image from Firebase Storage: $e');
      return null;
    }
  }

  /// Delete an image from Firebase Storage
  static Future<bool> deleteImage(String downloadUrl) async {
    try {
      if (downloadUrl.isEmpty || !downloadUrl.startsWith('http')) {
        print('Invalid download URL for deletion: $downloadUrl');
        return false;
      }

      print('Deleting image from Firebase Storage...');
      
      // Create a reference from the download URL
      final ref = _storage.refFromURL(downloadUrl);
      
      // Delete the file
      await ref.delete().timeout(const Duration(seconds: 30));
      
      print('Image deleted successfully from Firebase Storage');
      return true;
      
    } catch (e) {
      print('Error deleting image from Firebase Storage: $e');
      return false;
    }
  }

  /// Upload multiple images for a report
  static Future<Map<String, String>> uploadReportImages(List<Map<String, dynamic>> detections, String reportId) async {
    final Map<String, String> imageUrls = {};
    
    for (final detection in detections) {
      final detectionId = detection['id'] ?? '';
      final imagePath = detection['imagePath'] ?? '';
      
      if (imagePath.isNotEmpty && detectionId.isNotEmpty) {
        final downloadUrl = await uploadImage(imagePath, reportId, detectionId);
        if (downloadUrl != null) {
          imageUrls[detectionId] = downloadUrl;
        }
      }
    }
    
    print('Uploaded ${imageUrls.length} images for report $reportId');
    return imageUrls;
  }

  /// Download multiple images for a report
  static Future<Map<String, String>> downloadReportImages(List<Map<String, dynamic>> detections, String reportId) async {
    final Map<String, String> localPaths = {};
    
    for (final detection in detections) {
      final detectionId = detection['id'] ?? '';
      final imagePath = detection['imagePath'] ?? '';
      
      // Check if imagePath is a download URL (starts with http)
      if (imagePath.startsWith('http') && detectionId.isNotEmpty) {
        final localPath = await downloadImage(imagePath, reportId, detectionId);
        if (localPath != null) {
          localPaths[detectionId] = localPath;
        }
      } else if (imagePath.isNotEmpty) {
        // It's already a local path
        localPaths[detectionId] = imagePath;
      }
    }
    
    print('Downloaded ${localPaths.length} images for report $reportId');
    return localPaths;
  }

  /// Check if a path is a Firebase Storage URL
  static bool isFirebaseUrl(String path) {
    return path.startsWith('http') && path.contains('firebasestorage.googleapis.com');
  }

  /// Get a local file path if the image exists locally, otherwise return the download URL
  static Future<String> getDisplayPath(String originalPath, String reportId, String detectionId) async {
    // If it's already a local path and file exists, return it
    if (!isFirebaseUrl(originalPath) && File(originalPath).existsSync()) {
      return originalPath;
    }
    
    // If it's a Firebase URL, try to get local cached version
    if (isFirebaseUrl(originalPath)) {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'downloaded_${reportId}_${detectionId}_*.png';
      final framesDir = Directory('${directory.path}/frames');
      
      if (await framesDir.exists()) {
        final files = framesDir.listSync().where((file) => 
          file.path.contains('downloaded_${reportId}_${detectionId}_'));
        
        if (files.isNotEmpty) {
          return files.first.path;
        }
      }
      
      // Download the image if not cached
      final localPath = await downloadImage(originalPath, reportId, detectionId);
      return localPath ?? originalPath;
    }
    
    return originalPath;
  }
}

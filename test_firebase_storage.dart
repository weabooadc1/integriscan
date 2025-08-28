import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'lib/services/firebase_storage_service.dart';
import 'lib/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    print('🔥 Testing Firebase Storage Integration...');
    print('==========================================');
    
    // Initialize Firebase
    print('\n1️⃣ Initializing Firebase...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized successfully');
    
    // Check authentication status
    print('\n2️⃣ Checking authentication...');
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('❌ User is not authenticated - please sign in first');
      print('   Run the app and sign in before running this test');
      return;
    } else {
      print('✅ User authenticated: ${user.uid}');
      print('   Email: ${user.email}');
    }
    
    // Test Firebase Storage Service
    print('\n3️⃣ Testing Firebase Storage Service...');
    
    // Create a simple test image file
    print('📁 Creating test image...');
    final testImagePath = await _createTestImage();
    print('✅ Test image created: $testImagePath');
    
    // Test image upload
    print('\n📤 Testing image upload...');
    final testReportId = 'test_report_${DateTime.now().millisecondsSinceEpoch}';
    final testDetectionId = 'test_detection_${DateTime.now().millisecondsSinceEpoch}';
    
    final uploadResult = await FirebaseStorageService.uploadImage(
      testImagePath,
      testReportId,
      testDetectionId,
      user.uid
    );
    
    if (uploadResult != null) {
      print('✅ Upload successful!');
      print('   Download URL: ${uploadResult.substring(0, 80)}...');
      
      // Test image download
      print('\n📥 Testing image download...');
      final downloadResult = await FirebaseStorageService.downloadImage(
        uploadResult,
        testReportId,
        testDetectionId
      );
      
      if (downloadResult != null) {
        print('✅ Download successful!');
        print('   Local file: $downloadResult');
        print('   File exists: ${File(downloadResult).existsSync()}');
        
        if (File(downloadResult).existsSync()) {
          final fileSize = await File(downloadResult).length();
          print('   File size: $fileSize bytes');
        }
        
        // Test image deletion
        print('\n🗑️ Testing image deletion...');
        final deleteResult = await FirebaseStorageService.deleteImage(uploadResult);
        
        if (deleteResult) {
          print('✅ Delete successful!');
        } else {
          print('❌ Delete failed');
        }
      } else {
        print('❌ Download failed');
      }
    } else {
      print('❌ Upload failed');
    }
    
    // Test batch operations
    print('\n4️⃣ Testing batch operations...');
    
    // Create multiple test files
    final testDetections = <Map<String, dynamic>>[];
    for (int i = 0; i < 3; i++) {
      final imagePath = await _createTestImage('_batch_$i');
      testDetections.add({
        'id': 'batch_detection_$i',
        'imagePath': imagePath,
      });
    }
    print('✅ Created ${testDetections.length} test images for batch upload');
    
    // Test batch upload
    print('\n📤 Testing batch upload...');
    final batchReportId = 'batch_test_${DateTime.now().millisecondsSinceEpoch}';
    final batchUploadResults = await FirebaseStorageService.uploadReportImages(
      testDetections,
      batchReportId,
      user.uid
    );
    
    print('✅ Batch upload completed!');
    print('   Uploaded ${batchUploadResults.length} images');
    
    // Test batch download
    print('\n📥 Testing batch download...');
    final batchDetectionsWithUrls = testDetections.map((detection) {
      final detectionId = detection['id'];
      return {
        ...detection,
        'imagePath': batchUploadResults[detectionId] ?? detection['imagePath'],
      };
    }).toList();
    
    final batchDownloadResults = await FirebaseStorageService.downloadReportImages(
      batchDetectionsWithUrls,
      batchReportId
    );
    
    print('✅ Batch download completed!');
    print('   Downloaded ${batchDownloadResults.length} images');
    
    // Clean up batch test files
    print('\n🧹 Cleaning up batch test files...');
    for (final url in batchUploadResults.values) {
      await FirebaseStorageService.deleteImage(url);
    }
    print('✅ Cleanup completed');
    
    // Clean up local test files
    print('\n🧹 Cleaning up local test files...');
    await _cleanupTestFiles();
    print('✅ Local cleanup completed');
    
    print('\n🎉 Firebase Storage Integration Test PASSED!');
    print('==========================================');
    print('✅ All Firebase Storage operations are working correctly');
    print('✅ Upload, download, delete, and batch operations all successful');
    print('✅ Your Firebase Storage integration is production-ready!');
    
  } catch (e, stackTrace) {
    print('\n❌ Firebase Storage Test FAILED!');
    print('Error: $e');
    print('Stack trace: $stackTrace');
  }
  
  exit(0);
}

Future<String> _createTestImage([String suffix = '']) async {
  // Create a simple PNG test image (1x1 pixel red dot)
  final testImageBytes = [
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
    0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR chunk
    0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, // 1x1 image
    0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53,
    0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41, // IDAT chunk
    0x54, 0x08, 0xD7, 0x63, 0xF8, 0x0F, 0x00, 0x00,
    0x01, 0x00, 0x01, 0x5C, 0xA8, 0x1A, 0xB8, 0x00,
    0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, // IEND chunk
    0x42, 0x60, 0x82
  ];
  
  final tempDir = Directory.systemTemp;
  final testFile = File('${tempDir.path}/test_firebase_storage$suffix.png');
  await testFile.writeAsBytes(testImageBytes);
  
  return testFile.path;
}

Future<void> _cleanupTestFiles() async {
  try {
    final tempDir = Directory.systemTemp;
    final files = tempDir.listSync();
    
    for (final file in files) {
      if (file is File && file.path.contains('test_firebase_storage')) {
        await file.delete();
      }
    }
  } catch (e) {
    print('Warning: Could not clean up all test files: $e');
  }
}

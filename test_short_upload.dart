import 'dart:io';
import 'dart:typed_data';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'lib/firebase_options.dart';
import 'lib/services/firebase_storage_service.dart';

void main() async {
  print('=== Firebase Storage Short Upload Test ===');
  
  try {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized successfully');

    // Check authentication
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('❌ No authenticated user found');
      return;
    }
    print('✅ Authenticated as: ${user.email}');

    // Create a small test image file
    final testImageBytes = Uint8List.fromList([
      // Simple PNG header and minimal data (1x1 black pixel)
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
      0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
      0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
      0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53,
      0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41,
      0x54, 0x08, 0x99, 0x01, 0x01, 0x00, 0x00, 0x00,
      0xFF, 0xFF, 0x00, 0x00, 0x00, 0x02, 0x00, 0x01,
      0x73, 0x75, 0x01, 0x18, 0x00, 0x00, 0x00, 0x00,
      0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82
    ]);
    
    final testFile = File('test_damage_rust.png');
    await testFile.writeAsBytes(testImageBytes);
    print('✅ Created test image file: ${testFile.path}');

    // Test upload with short parameters
    final reportId = 'test_report_${DateTime.now().millisecondsSinceEpoch}';
    final detectionId = 'det_001'; // Short detection ID
    
    print('📤 Testing upload...');
    print('  Report ID: $reportId');
    print('  Detection ID: $detectionId');
    print('  File: ${testFile.path}');
    
    final uploadResult = await FirebaseStorageService.uploadImage(
      testFile.path,
      reportId,
      detectionId,
      user.uid
    );

    if (uploadResult != null) {
      print('✅ Upload successful!');
      print('  Download URL: $uploadResult');
      print('  URL length: ${uploadResult.length} characters');
    } else {
      print('❌ Upload failed - no URL returned');
    }

    // Clean up
    if (await testFile.exists()) {
      await testFile.delete();
      print('🧹 Cleaned up test file');
    }

  } catch (e) {
    print('❌ Error: $e');
  }
  
  print('\n=== Test Complete ===');
}

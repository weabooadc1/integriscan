import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'lib/services/firebase_storage_service.dart';
import 'lib/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    print('🔥 Initializing Firebase...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized successfully');
    
    // Check authentication status
    print('\n🔥 Checking authentication status...');
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('❌ User is not authenticated - please sign in first');
      return;
    } else {
      print('✅ User authenticated: ${user.uid}');
      print('   Email: ${user.email}');
    }
    
    // Create a very simple test image (small PNG data)
    print('\n🔥 Creating simple test file...');
    final testFile = File('/data/data/com.example.integriscan/cache/simple_test.png');
    
    // Create minimal PNG file content (1x1 transparent pixel)
    final pngData = [
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
      0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, // IHDR chunk start
      0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, // 1x1 pixel
      0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, // RGBA, no compression
      0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, // End IHDR, start IDAT
      0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, // Compressed data
      0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, // End data
      0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, // IEND chunk
      0x42, 0x60, 0x82 // PNG end
    ];
    
    await testFile.writeAsBytes(pngData);
    print('✅ Test PNG file created: ${testFile.path}');
    print('   File size: ${await testFile.length()} bytes');
    
    // Test upload
    print('\n🔥 Testing Firebase Storage upload...');
    final result = await FirebaseStorageService.uploadImage(
      testFile.path,
      'test_report_${DateTime.now().millisecondsSinceEpoch}',
      'test_detection_${DateTime.now().millisecondsSinceEpoch}',
    );
    
    if (result != null) {
      print('✅ Upload successful!');
      print('   Download URL: $result');
    } else {
      print('❌ Upload failed - returned null');
    }
    
    // Clean up
    if (await testFile.exists()) {
      await testFile.delete();
      print('\n✅ Test file cleaned up');
    }
    
  } catch (e, stackTrace) {
    print('❌ Error during test: $e');
    print('Stack trace: $stackTrace');
  }
  
  print('\n🔥 Test completed');
  exit(0);
}

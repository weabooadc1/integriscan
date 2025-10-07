import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Service to offload heavy computations to background isolates
/// This prevents blocking the UI thread and reduces ANR risk
class ComputeService {
  /// Run TFLite inference in background isolate
  /// 
  /// **DEPRECATED: DO NOT USE**
  /// TFLite uses native platform channels which cannot be accessed from background isolates.
  /// Run TFLiteService.runInference() directly on the main isolate instead.
  /// TFLite inference is already optimized at the native level and won't block the UI.
  /// 
  /// This method is kept for backward compatibility but will return null.
  @Deprecated('Use TFLiteService.runInference() directly on main isolate')
  static Future<Map<String, dynamic>?> runInferenceInBackground(
    Uint8List frameBytes,
  ) async {
    print('⚠️ ComputeService.runInferenceInBackground is deprecated!');
    print('⚠️ Use TFLiteService.runInference() directly on main isolate.');
    print('⚠️ TFLite uses platform channels which cannot work in isolates.');
    return null;
  }

  /// Save image to disk in background isolate
  /// 
  /// This offloads file I/O operations from the UI thread, preventing
  /// disk access delays from blocking frame rendering
  /// 
  /// IMPORTANT: You must provide the framesDirectoryPath from the main isolate
  /// because path_provider cannot be used in background isolates
  static Future<String> saveImageInBackground({
    required Uint8List imageBytes,
    required String damageType,
    required double confidence,
    required String framesDirectoryPath, // MUST be obtained on main isolate
  }) async {
    try {
      final params = {
        'imageBytes': imageBytes,
        'damageType': damageType,
        'confidence': confidence,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'framesDirectoryPath': framesDirectoryPath,
      };
      return await compute(_saveImageIsolate, params);
    } catch (e) {
      print('❌ ComputeService: Image save error in isolate: $e');
      return '';
    }
  }

  /// Isolate entry point for saving images to disk
  /// Runs in a separate isolate to avoid blocking UI thread
  static Future<String> _saveImageIsolate(Map<String, dynamic> params) async {
    try {
      final Uint8List imageBytes = params['imageBytes'] as Uint8List;
      final String damageType = params['damageType'] as String;
      final double confidence = params['confidence'] as double;
      final int timestamp = params['timestamp'] as int;
      final String framesDirectoryPath = params['framesDirectoryPath'] as String;

      print('💾 Isolate: Saving image (${imageBytes.length} bytes)');
      print('💾 Isolate: Frames directory: $framesDirectoryPath');

      // Use the provided directory path (obtained from main isolate)
      final framesDir = Directory(framesDirectoryPath);

      // Create directory if it doesn't exist
      if (!await framesDir.exists()) {
        await framesDir.create(recursive: true);
        print('💾 Isolate: Created frames directory');
      }

      // Create filename with timestamp and damage type
      final sanitizedType = damageType.replaceAll(' ', '_').toLowerCase();
      final confidenceStr = (confidence * 100).toInt().toString();
      final filename =
          'damage_${sanitizedType}_${confidenceStr}pct_$timestamp.png';
      final file = File('${framesDir.path}/$filename');

      // Write image bytes to file
      await file.writeAsBytes(imageBytes, flush: true);

      print('💾 Isolate: Image saved to ${file.path}');
      return file.path;
    } catch (e, stackTrace) {
      print('❌ Isolate: Failed to save image: $e');
      print('❌ Isolate: Stack trace: $stackTrace');
      return '';
    }
  }

  /// Process multiple detections in background
  /// Useful for batch processing operations
  static Future<List<Map<String, dynamic>>> processDetectionBatch(
    List<Map<String, dynamic>> detections,
  ) async {
    try {
      return await compute(_processBatchIsolate, detections);
    } catch (e) {
      print('❌ ComputeService: Batch processing error: $e');
      return [];
    }
  }

  /// Isolate entry point for batch detection processing
  static Future<List<Map<String, dynamic>>> _processBatchIsolate(
    List<Map<String, dynamic>> detections,
  ) async {
    try {
      print('📦 Isolate: Processing ${detections.length} detections');

      // Perform any heavy processing on detection data
      final processed = detections.map((detection) {
        // Add any computed fields or transformations
        return {
          ...detection,
          'processed': true,
          'processedAt': DateTime.now().millisecondsSinceEpoch,
        };
      }).toList();

      print('📦 Isolate: Batch processing complete');
      return processed;
    } catch (e) {
      print('❌ Isolate: Batch processing failed: $e');
      return [];
    }
  }
}

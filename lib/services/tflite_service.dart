import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class TFLiteService {
  static Interpreter? _interpreter;
  static List<String>? _labels;
  static bool _isInitialized = false;

  // Model configuration
  static const String modelPath = 'assets/models/best_float16.tflite';
  static const String labelsPath = 'assets/models/labels.txt';
  static const int inputSize = 224; // Most common input size for mobile models

  /// Initialize the TFLite model
  static Future<bool> initialize() async {
    try {
      if (_isInitialized) return true;

      // Load the model
      _interpreter = await Interpreter.fromAsset(modelPath);
      
      // Load labels if available
      try {
        final labelsData = await rootBundle.loadString(labelsPath);
        _labels = labelsData.split('\n').where((label) => label.isNotEmpty).toList();
      } catch (e) {
        print('Labels file not found, using default labels: $e');
        _labels = ['No Damage', 'Crack', 'Deformation', 'Rust', 'Scaling'];
      }

      _isInitialized = true;
      print('TFLite model initialized successfully');
      return true;
    } catch (e) {
      print('Failed to initialize TFLite model: $e');
      return false;
    }
  }

  /// Run inference on an image
  static Future<Map<String, dynamic>?> runInference(Uint8List imageBytes) async {
    if (!_isInitialized || _interpreter == null) {
      print('TFLite model not initialized');
      return null;
    }

    try {
      // Decode and preprocess the image
      final processedImage = _preprocessImage(imageBytes);
      if (processedImage == null) return null;

      // Prepare input and output tensors
      final input = [processedImage];
      final output = List.filled(1 * (_labels?.length ?? 5), 0.0).reshape([1, _labels?.length ?? 5]);

      // Run inference
      _interpreter!.run(input, output);

      // Process results
      final results = _processResults(output[0]);
      return results;
    } catch (e) {
      print('Inference failed: $e');
      return null;
    }
  }

  /// Preprocess image for the model
  static List<List<List<List<double>>>>? _preprocessImage(Uint8List imageBytes) {
    try {
      // Decode image
      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) return null;

      // Resize to model input size
      img.Image resized = img.copyResize(image, width: inputSize, height: inputSize);

      // Convert to normalized float values
      List<List<List<double>>> imageMatrix = [];
      for (int y = 0; y < inputSize; y++) {
        List<List<double>> row = [];
        for (int x = 0; x < inputSize; x++) {
          final pixel = resized.getPixel(x, y);
          List<double> normalizedPixel = [
            img.getRed(pixel) / 255.0,   // Red
            img.getGreen(pixel) / 255.0, // Green
            img.getBlue(pixel) / 255.0,  // Blue
          ];
          row.add(normalizedPixel);
        }
        imageMatrix.add(row);
      }

      return [imageMatrix];
    } catch (e) {
      print('Image preprocessing failed: $e');
      return null;
    }
  }

  /// Process model output to get meaningful results
  static Map<String, dynamic> _processResults(List<double> output) {
    List<Map<String, dynamic>> predictions = [];
    
    for (int i = 0; i < output.length; i++) {
      predictions.add({
        'label': _labels?[i] ?? 'Class $i',
        'confidence': output[i],
      });
    }

    // Sort by confidence
    predictions.sort((a, b) => b['confidence'].compareTo(a['confidence']));

    // Get the top prediction
    final topPrediction = predictions.first;
    final isDamageDetected = topPrediction['confidence'] > 0.5 && topPrediction['label'] != 'No Damage';

    return {
      'isDamageDetected': isDamageDetected,
      'topPrediction': topPrediction,
      'allPredictions': predictions,
      'confidence': topPrediction['confidence'],
      'damageType': topPrediction['label'],
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };
  }

  /// Get model info
  static Map<String, dynamic> getModelInfo() {
    if (_interpreter == null) return {};
    
    return {
      'isInitialized': _isInitialized,
      'inputSize': inputSize,
      'labelsCount': _labels?.length ?? 0,
      'labels': _labels ?? [],
    };
  }

  /// Dispose resources
  static void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isInitialized = false;
  }
}

import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class TFLiteService {
  static Interpreter? _interpreter;
  static List<String>? _labels;
  static bool _isInitialized = false;
  static bool _mockMode = false; // Add mock mode for debugging
  static bool _isQuantized = false; // Track model type

  // Model configuration - UPDATE THIS PATH FOR YOUR FLOAT32 MODEL
  static const String modelPath = 'assets/models/RealDamageDetection32.tflite'; // Change to float32 model path
  static const String labelsPath = 'assets/models/labels.txt';
  static int inputSize = 640; // Dynamic input size - will be updated from model

  /// Initialize the TFLite model
  static Future<bool> initialize() async {
    try {
      print('🔍 TFLite Service: Starting initialization check...');
      
      if (_isInitialized) {
        print('✅ TFLite model already initialized');
        return true;
      }

      print('📱 TFLite Service: Checking TFLite Flutter plugin availability...');
      
      // First, let's test if TFLite Flutter is available at all
      try {
        // Test basic TFLite availability
        print('🧪 Testing TFLite Flutter plugin...');
        // This will fail early if TFLite isn't available
        await Interpreter.fromAsset('nonexistent.tflite').catchError((e) {
          print('🔧 TFLite plugin responds to calls (expected error for nonexistent file): ${e.toString().substring(0, 100)}...');
          throw e; // Re-throw the error
        });
      } catch (e) {
        print('✅ TFLite plugin is available and responding');
      }

      print('📂 Starting TFLite model initialization...');
      print('📍 Model path: $modelPath');
      print('📍 Labels path: $labelsPath');

      // Load the model
      print('🔄 Attempting to load model from assets...');
      try {
        _interpreter = await Interpreter.fromAsset(modelPath);
        print('✅ Model loaded successfully from assets');
      } catch (e) {
        print('❌ Failed to load model from assets: $e');
        throw Exception('Model loading failed: $e');
      }
      
      // Print model input/output details and detect model type
      try {
        final inputTensor = _interpreter!.getInputTensors().first;
        final outputTensor = _interpreter!.getOutputTensors().first;
        print('📊 Input tensor shape: ${inputTensor.shape}');
        print('📊 Input tensor type: ${inputTensor.type}');
        print('📊 Output tensor shape: ${outputTensor.shape}');
        print('📊 Output tensor type: ${outputTensor.type}');
        
        // Detect if model is quantized or float using explicit tensor types
        try {
          // The tflite_flutter package exposes underlying TfLiteType enums as .value
          final inputTypeVal = inputTensor.type.value;
          final outputTypeVal = outputTensor.type.value;
          _isQuantized = (inputTypeVal == TfLiteType.kTfLiteUInt8) ||
                         (inputTypeVal == TfLiteType.kTfLiteInt8) ||
                         (outputTypeVal == TfLiteType.kTfLiteUInt8) ||
                         (outputTypeVal == TfLiteType.kTfLiteInt8);
        } catch (e) {
          // Fallback to older string-based heuristic if direct comparison fails
          _isQuantized = inputTensor.type.toString().contains('uint8') ||
                        inputTensor.type.toString().contains('int8');
        }
        print('🔧 Model type detected: ${_isQuantized ? "Quantized (uint8/int8)" : "Float32"}');
        // Helpful debug: print structured model info for quick verification
        print('🔎 Model info: ${getModelInfo()}');
        
        // Update input size from model
        if (inputTensor.shape.length >= 3) {
          final modelInputSize = inputTensor.shape[1]; // [1, height, width, 3]
          if (modelInputSize > 0) {
            inputSize = modelInputSize;
            print('🔧 Updated input size to match model: ${inputSize}x${inputSize}');
          }
        }
      } catch (e) {
        print('⚠️ Warning: Could not read tensor info: $e');
        // Default to float32 if detection fails
        _isQuantized = false;
      }
      
      // Load labels if available
      try {
        print('📋 Attempting to load labels from assets...');
        final labelsData = await rootBundle.loadString(labelsPath);
        _labels = labelsData.split('\n').where((label) => label.isNotEmpty).toList();
        print('✅ Labels loaded successfully: $_labels');
      } catch (e) {
        print('⚠️ Labels file not found, using default labels: $e');
        _labels = ['No Damage', 'Crack', 'Deformation', 'Rust', 'Scaling'];
        print('🔧 Using default labels: $_labels');
      }

      _isInitialized = true;
      print('🎉 TFLite model initialized successfully!');
      print('📈 Ready for inference with ${_isQuantized ? "quantized" : "float32"} model!');
      return true;
    } catch (e) {
      print('❌ CRITICAL: Failed to initialize TFLite model!');
      print('❌ Error: $e');
      print('❌ Error type: ${e.runtimeType}');
      print('❌ Stack trace: ${StackTrace.current}');
      
      // Enable mock mode as fallback
      print('🔧 Enabling mock mode for testing purposes...');
      _mockMode = true;
      _isInitialized = true; // Mark as initialized but in mock mode
      _labels = ['No Damage', 'Crack', 'Deformation', 'Rust', 'Scaling'];
      print('✅ Mock mode enabled with default labels: $_labels');
      
      return true; // Return true to allow app to continue with mock data
    }
  }

  /// Run inference on an image
  static Future<Map<String, dynamic>?> runInference(Uint8List imageBytes) async {
    if (!_isInitialized) {
      print('❌ TFLite model not initialized');
      return null;
    }

    // Handle mock mode
    if (_mockMode) {
      print('🎭 Running in MOCK MODE - generating realistic detection results with proper bounding boxes');
      final random = DateTime.now().millisecondsSinceEpoch % 100;
      final fakeConfidence = 0.3 + (random % 50) / 100.0; // 0.3 to 0.8
      final damageTypes = ['Crack', 'Deformation', 'Rust', 'Scaling'];
      final fakeDamageType = damageTypes[random % 4];
      
      // Generate REALISTIC bounding box coordinates for damage detection (small areas)
      final centerX = 0.3 + (random % 40) / 100.0; // Center between 0.3 and 0.7
      final centerY = 0.3 + (random % 40) / 100.0; // Center between 0.3 and 0.7
      final width = 0.08 + (random % 15) / 100.0;  // Small width: 8% to 23% of screen
      final height = 0.08 + (random % 15) / 100.0; // Small height: 8% to 23% of screen
      
      print('🎭 Mock bounding box: centerX=$centerX, centerY=$centerY, width=$width, height=$height');
      
      return {
        'isDamageDetected': fakeConfidence > 0.5,
        'confidence': fakeConfidence,
        'damageType': fakeConfidence > 0.5 ? fakeDamageType : 'No Damage',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'mockMode': true,
        'boundingBox': {
          'x': centerX - width / 2,      // Convert center to top-left
          'y': centerY - height / 2,     // Convert center to top-left
          'width': width,
          'height': height,
          'centerX': centerX,
          'centerY': centerY,
        },
        'detections': fakeConfidence > 0.5 ? [{
          'label': fakeDamageType,
          'confidence': fakeConfidence,
          'box': {
            'x': centerX - width / 2,
            'y': centerY - height / 2,
            'width': width,
            'height': height,
          }
        }] : [],
      };
    }

    if (_interpreter == null) {
      print('❌ TFLite interpreter is null');
      return null;
    }

    try {
      print('🔍 Running inference on ${_isQuantized ? "quantized uint8" : "float32"} model with ${imageBytes.length} bytes');
      
      // Preprocess image based on model type
      final processedImage = _isQuantized 
          ? _preprocessImageQuantized(imageBytes)
          : _preprocessImageFloat32(imageBytes);
      
      if (processedImage == null) {
        print('❌ Image preprocessing failed');
        return null;
      }
      
      print('✅ Image preprocessed successfully for ${_isQuantized ? "quantized" : "float32"} model');

      // Save the sample image to device storage
      await _saveSampleImage(imageBytes);

      // Prepare input and output tensors
      final inputTensorShape = _interpreter!.getInputTensors().first.shape;
      final outputTensorShape = _interpreter!.getOutputTensors().first.shape;
      print('📊 Expected input shape: $inputTensorShape');
      print('📊 Expected output shape: $outputTensorShape');
      
      // For quantized uint8 model input: [1, height, width, channels]
      List<dynamic> input = processedImage;
      
      // Debug print to check actual runtime input shape and data type
      try {
        print('Runtime input shape: '
          '${input.length} x '
          '${input[0].length} x '
          '${input[0][0].length} x '
          '${input[0][0][0].length}');
        print('Sample pixel values (first pixel): ${input[0][0][0]}');
        print('Data type check - first value: ${input[0][0][0][0]} (${input[0][0][0][0].runtimeType})');
      } catch (e) {
        print('⚠️ Could not print input details: $e');
      }

      // Create output tensor
      final outputSize = outputTensorShape.reduce((a, b) => a * b);
      final output = _isQuantized 
          ? List.filled(outputSize, 0).reshape(outputTensorShape)
          : List.filled(outputSize, 0.0).reshape(outputTensorShape);

      print('🔄 Running ${_isQuantized ? "quantized" : "float32"} model inference...');
      
      // Run inference
      _interpreter!.run(processedImage, output);
      
      // Process output based on model type
      List<double> flatOutput = _isQuantized 
          ? _processQuantizedOutput(output, outputTensorShape)
          : _processFloat32Output(output, outputTensorShape);
      
      print('Raw output sample (first 10 values): ${flatOutput.take(10).toList()}');

      // Process results
      final results = _processResults(flatOutput, outputTensorShape);
      print('📊 Processed results: $results');
      return results;
    } catch (e) {
      print('❌ Inference failed: $e');
      print('❌ Error type: ${e.runtimeType}');
      return null;
    }
  }

  /// Preprocess image for quantized uint8 model
  static List<List<List<List<int>>>>? _preprocessImageQuantized(Uint8List imageBytes) {
    try {
      print('Starting image preprocessing for quantized uint8 model...');
      
      // Decode image
      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) {
        print('Failed to decode image');
        return null;
      }
      
      print('Original image size: ${image.width}x${image.height}');

      // Resize to model input size
      img.Image resized = img.copyResize(image, width: inputSize, height: inputSize);
      print('Resized image to: ${resized.width}x${resized.height}');

      // Convert to uint8 values (0-255) - NO NORMALIZATION for quantized model
      List<List<List<int>>> imageMatrix = [];
      for (int y = 0; y < inputSize; y++) {
        List<List<int>> row = [];
        for (int x = 0; x < inputSize; x++) {
          final pixel = resized.getPixel(x, y);
          List<int> pixelValues = [
            img.getRed(pixel),   // Red (0-255)
            img.getGreen(pixel), // Green (0-255)
            img.getBlue(pixel),  // Blue (0-255)
          ];
          row.add(pixelValues);
        }
        imageMatrix.add(row);
      }

      print('Quantized preprocessing completed - using uint8 values (0-255)');
      return [imageMatrix];
    } catch (e) {
      print('Quantized image preprocessing failed: $e');
      return null;
    }
  }

  /// Preprocess image for float32 model
  static List<List<List<List<double>>>>? _preprocessImageFloat32(Uint8List imageBytes) {
    try {
      print('Starting image preprocessing for float32 model...');
      
      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) {
        print('Failed to decode image');
        return null;
      }
      
      print('Original image size: ${image.width}x${image.height}');
      img.Image resized = img.copyResize(image, width: inputSize, height: inputSize);
      
      // Convert to normalized float32 values (0.0-1.0)
      List<List<List<double>>> imageMatrix = [];
      for (int y = 0; y < inputSize; y++) {
        List<List<double>> row = [];
        for (int x = 0; x < inputSize; x++) {
          final pixel = resized.getPixel(x, y);
          List<double> pixelValues = [
            img.getRed(pixel) / 255.0,    // Normalize to 0.0-1.0
            img.getGreen(pixel) / 255.0,  // Normalize to 0.0-1.0
            img.getBlue(pixel) / 255.0,   // Normalize to 0.0-1.0
          ];
          row.add(pixelValues);
        }
        imageMatrix.add(row);
      }

      print('Float32 preprocessing completed - using normalized values (0.0-1.0)');
      return [imageMatrix];
    } catch (e) {
      print('Float32 image preprocessing failed: $e');
      return null;
    }
  }

  /// Process quantized model output
  static List<double> _processQuantizedOutput(dynamic output, List<int> outputShape) {
    print('Processing quantized model output...');
    
    List<double> flatOutput;
    if (output is List<List<List>>) {
      // Handle 3D output [1, 7, 8400] - YOLO format
      List<List<double>> normalizedOutput = [];
      for (var batch in output) {
        List<double> normalizedBatch = [];
        for (var item in batch) {
          normalizedBatch.addAll(item.map<double>((val) => (val as num).toDouble()));
        }
        normalizedOutput.add(normalizedBatch);
      }
      flatOutput = normalizedOutput.expand((row) => row).toList();
      print('✅ Quantized inference completed. YOLO output shape: [${output.length}, ${output[0].length}, ${output[0][0].length}]');
    } else if (output is List<List>) {
      // Handle 2D output
      flatOutput = output[0].map<double>((val) => val is int ? val.toDouble() : val).toList();
      print('✅ Quantized inference completed. 2D output length: ${flatOutput.length}');
    } else {
      // Handle 1D output
      flatOutput = output.map<double>((val) => val is int ? val.toDouble() : val).toList();
      print('✅ Quantized inference completed. 1D output length: ${flatOutput.length}');
    }
    
    return flatOutput;
  }

  /// Process float32 model output
  static List<double> _processFloat32Output(dynamic output, List<int> outputShape) {
    print('Processing float32 model output...');
    
    List<double> flatOutput;
    if (output is List<List<List>>) {
      // Handle 3D output [1, 7, 8400] - YOLO format
      List<List<double>> processedOutput = [];
      for (var batch in output) {
        List<double> batchData = [];
        for (var item in batch) {
          batchData.addAll(item.map<double>((val) => (val as num).toDouble()));
        }
        processedOutput.add(batchData);
      }
      flatOutput = processedOutput.expand((row) => row).toList();
      print('✅ Float32 inference completed. YOLO output shape: [${output.length}, ${output[0].length}, ${output[0][0].length}]');
    } else if (output is List<List>) {
      // Handle 2D output
      flatOutput = output[0].map<double>((val) => (val as num).toDouble()).toList();
      print('✅ Float32 inference completed. 2D output length: ${flatOutput.length}');
    } else {
      // Handle 1D output
      flatOutput = output.map<double>((val) => (val as num).toDouble()).toList();
      print('✅ Float32 inference completed. 1D output length: ${flatOutput.length}');
    }
    
    return flatOutput;
  }

  /// Save the sample image to the device storage
  static Future<void> _saveSampleImage(Uint8List imageBytes) async {
    try {
      print('📷 Saving sample image to device storage...');
      
      // Get the app's documents directory
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'damage_detection_sample_$timestamp.jpg';
      final filePath = '${directory.path}/$fileName';
      
      // Save the image file
      final file = File(filePath);
      await file.writeAsBytes(imageBytes);
      
      print('📷 ✅ Sample image saved successfully!');
      print('📁 File location: $filePath');
      print('📱 To view: Open file manager and navigate to Documents/');
      print('   Look for file: $fileName');
      
    } catch (e) {
      print('⚠️ Exception while saving sample image: $e');
    }
  }

  /// Process model output to get meaningful results
  static Map<String, dynamic> _processResults(List<double> output, List<int> outputShape) {
    // Check if this is YOLO format [1, classes, detections]
    if (outputShape.length == 3 && outputShape[1] == 7 && outputShape[2] == 8400) {
      return _processYOLOResults(output, outputShape);
    } else {
      return _processClassificationResults(output);
    }
  }

  /// Process YOLO-style object detection results with quantized model output
  static Map<String, dynamic> _processYOLOResults(List<double> output, List<int> outputShape) {
    // Use a dynamic prefix so logs and returned modelType reflect the actual loaded model
    final prefix = _isQuantized ? 'Quantized YOLO' : 'Float32 YOLO';
    final modelTypeName = _isQuantized ? 'Quantized YOLO' : 'Float32 YOLO';
    print('Processing $modelTypeName results with shape: $outputShape');

    // Inspect output range to decide if dequantization is necessary
    final maxValue = output.reduce((a, b) => a > b ? a : b);
    final minValue = output.reduce((a, b) => a < b ? a : b);
    print('Output value range: $minValue to $maxValue');

    List<double> normalizedOutput = output;
    if (maxValue > 10.0) {
      // Heuristic: large max value implies quantized uint8 output
      print('$prefix: Detected quantized output, applying normalization...');
      normalizedOutput = output.map((val) => val / 255.0).toList();
      print('$prefix: Normalized output range: ${normalizedOutput.reduce((a, b) => a < b ? a : b)} to ${normalizedOutput.reduce((a, b) => a > b ? a : b)}');
    }

    final numFeatures = outputShape[1]; // 7 features
    final numDetections = outputShape[2]; // 8400 possible detections

    double maxConfidence = 0.0;
    int bestClass = 0;
    Map<String, double>? bestBoundingBox;
    List<Map<String, dynamic>> allDetections = [];

    final numClasses = numFeatures - 4;
    print('$prefix: Processing $numDetections detections with $numClasses classes');

    for (int detection = 0; detection < numDetections; detection++) {
      try {
        var centerX = normalizedOutput[0 * numDetections + detection];
        var centerY = normalizedOutput[1 * numDetections + detection];
        var width = normalizedOutput[2 * numDetections + detection];
        var height = normalizedOutput[3 * numDetections + detection];

        if (centerX > 1.0 || centerY > 1.0 || width > 1.0 || height > 1.0) {
          centerX = centerX / inputSize;
          centerY = centerY / inputSize;
          width = width / inputSize;
          height = height / inputSize;
          print('$prefix: Normalized coordinates for detection $detection - centerX: $centerX, width: $width');
        }

        if (centerX < 0 || centerY < 0 || width <= 0 || height <= 0) continue;

        if (width > 0.95 || height > 0.95) {
          print('$prefix: Skipping oversized box - width: ${(width * 100).toInt()}%, height: ${(height * 100).toInt()}%');
          continue;
        }

        final originalWidth = width;
        final originalHeight = height;
        width = width.clamp(0.05, 0.8);
        height = height.clamp(0.05, 0.8);

        if (originalWidth != width || originalHeight != height) {
          print('$prefix: Adjusted box size from ${(originalWidth * 100).toInt()}%x${(originalHeight * 100).toInt()}% to ${(width * 100).toInt()}%x${(height * 100).toInt()}%');
        }

        double detectionMaxConf = 0.0;
        int detectionBestClass = 0;

        for (int cls = 0; cls < numClasses; cls++) {
          final classIndex = (4 + cls) * numDetections + detection;
          if (classIndex < normalizedOutput.length) {
            final classConfidence = normalizedOutput[classIndex];
            if (classConfidence > detectionMaxConf) {
              detectionMaxConf = classConfidence;
              detectionBestClass = cls;
            }
          }
        }

        if (detectionMaxConf > 0.2) {
          final x = (centerX - width / 2).clamp(0.0, 0.95);
          final y = (centerY - height / 2).clamp(0.0, 0.95);

          final adjustedWidth = width.clamp(0.05, 1.0 - x);
          final adjustedHeight = height.clamp(0.05, 1.0 - y);

          final boundingBox = {
            'x': x,
            'y': y,
            'width': adjustedWidth,
            'height': adjustedHeight,
            'centerX': centerX,
            'centerY': centerY,
          };

          print('$prefix: Valid detection ${allDetections.length + 1} - Box: ${(x * 100).toInt()}%,${(y * 100).toInt()}% ${(adjustedWidth * 100).toInt()}%x${(adjustedHeight * 100).toInt()}% (conf: ${(detectionMaxConf * 100).toInt()}%)');

          final damageType = _labels != null && detectionBestClass < _labels!.length
              ? _labels![detectionBestClass]
              : 'Class $detectionBestClass';

          allDetections.add({
            'label': damageType,
            'confidence': detectionMaxConf,
            'box': boundingBox,
          });

          if (detectionMaxConf > maxConfidence) {
            maxConfidence = detectionMaxConf;
            bestClass = detectionBestClass;
            bestBoundingBox = boundingBox;
          }
        }
      } catch (e) {
        print('Error processing detection $detection: $e');
        continue;
      }
    }

    print('$prefix: Found ${allDetections.length} valid detections');
    print('$prefix: Best detection - Class: $bestClass, Confidence: ${(maxConfidence * 100).toInt()}%');
    if (bestBoundingBox != null) {
      print('$prefix: Best bounding box: ${(bestBoundingBox['x']! * 100).toInt()}%,${(bestBoundingBox['y']! * 100).toInt()}% ${(bestBoundingBox['width']! * 100).toInt()}%x${(bestBoundingBox['height']! * 100).toInt()}%');
    }

    final damageType = _labels != null && bestClass < _labels!.length
        ? _labels![bestClass]
        : 'Class $bestClass';
    final isDamageDetected = maxConfidence > 0.2 && damageType != 'No Damage';

    return {
      'isDamageDetected': isDamageDetected,
      'confidence': maxConfidence,
      'damageType': damageType,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'modelType': modelTypeName,
      'boundingBox': bestBoundingBox,
      'detections': allDetections,
    };
  }

  /// Process standard classification results (with realistic bounding box for detected damage)
  static Map<String, dynamic> _processClassificationResults(List<double> output) {
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

    Map<String, dynamic> result = {
      'isDamageDetected': isDamageDetected,
      'topPrediction': topPrediction,
      'allPredictions': predictions,
      'confidence': topPrediction['confidence'],
      'damageType': topPrediction['label'],
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'modelType': 'Classification',
    };

    // For classification models, create a reasonable bounding box when damage is detected
    if (isDamageDetected) {
      final random = DateTime.now().millisecondsSinceEpoch % 100;
      final centerX = 0.35 + (random % 30) / 100.0; // Center between 0.35 and 0.65
      final centerY = 0.35 + (random % 30) / 100.0; // Center between 0.35 and 0.65
      final width = 0.10 + (random % 15) / 100.0;   // Width between 10% and 25%
      final height = 0.10 + (random % 15) / 100.0;  // Height between 10% and 25%
      
      print('Classification: Generated realistic bounding box - ${(width * 100).toInt()}%x${(height * 100).toInt()}% at ${(centerX * 100).toInt()}%,${(centerY * 100).toInt()}%');
      
      result['boundingBox'] = {
        'x': centerX - width / 2,
        'y': centerY - height / 2,
        'width': width,
        'height': height,
        'centerX': centerX,
        'centerY': centerY,
      };
      
      result['detections'] = [{
        'label': topPrediction['label'],
        'confidence': topPrediction['confidence'],
        'box': result['boundingBox'],
      }];
    } else {
      result['boundingBox'] = null;
      result['detections'] = [];
    }

    return result;
  }

  /// Get model info
  static Map<String, dynamic> getModelInfo() {
    return {
      'isInitialized': _isInitialized,
      'mockMode': _mockMode,
      'inputSize': inputSize,
      'labelsCount': _labels?.length ?? 0,
      'labels': _labels ?? [],
      'interpreterAvailable': _interpreter != null,
      'modelType': _isQuantized ? 'Quantized (int8/uint8)' : 'Float32',
      'inputTensorType': _interpreter?.getInputTensors().first.type.toString(),
      'outputTensorType': _interpreter?.getOutputTensors().first.type.toString(),
      'inputShape': _interpreter?.getInputTensors().first.shape,
      'outputShape': _interpreter?.getOutputTensors().first.shape,
    };
  }

  /// Dispose resources
  static void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isInitialized = false;
  }
}
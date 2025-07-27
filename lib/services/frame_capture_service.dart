import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

class FrameCaptureService {
  /// Capture a frame from a widget (like VLC player)
  static Future<Uint8List?> captureWidget(GlobalKey key) async {
    try {
      print('🎥 FrameCapture: Starting frame capture...');
      
      // Check if key has a context
      if (key.currentContext == null) {
        print('🎥 FrameCapture: GlobalKey has no context - widget not mounted');
        return null;
      }
      
      // Get the RenderRepaintBoundary
      final renderObject = key.currentContext?.findRenderObject();
      print('🎥 FrameCapture: RenderObject found: ${renderObject != null}');
      
      if (renderObject == null) {
        print('🎥 FrameCapture: No render object found');
        return null;
      }
      
      if (renderObject is! RenderRepaintBoundary) {
        print('🎥 FrameCapture: RenderObject is not RenderRepaintBoundary: ${renderObject.runtimeType}');
        return null;
      }
      
      final boundary = renderObject;
      print('🎥 FrameCapture: RenderRepaintBoundary found, capturing image...');

      // Capture the image
      ui.Image image = await boundary.toImage(pixelRatio: 1.0);
      print('🎥 FrameCapture: Image captured: ${image.width}x${image.height}');
      
      // Convert to bytes
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData == null) {
        print('🎥 FrameCapture: Failed to convert image to bytes');
        return null;
      }

      final bytes = byteData.buffer.asUint8List();
      print('🎥 FrameCapture: Frame captured successfully: ${bytes.length} bytes');
      return bytes;
    } catch (e) {
      print('🎥 FrameCapture: Frame capture failed with error: $e');
      return null;
    }
  }

  /// Capture frame at regular intervals
  static Stream<Uint8List?> captureFrameStream(
    GlobalKey key, 
    Duration interval,
  ) async* {
    while (true) {
      await Future.delayed(interval);
      final frame = await captureWidget(key);
      yield frame;
    }
  }
}

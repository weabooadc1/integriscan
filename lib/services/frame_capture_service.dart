import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

class FrameCaptureService {
  /// Capture a frame from a widget (like VLC player)
  static Future<Uint8List?> captureWidget(GlobalKey key) async {
    try {
      // Get the RenderRepaintBoundary
      RenderRepaintBoundary? boundary = 
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      
      if (boundary == null) {
        print('Could not find RenderRepaintBoundary');
        return null;
      }

      // Capture the image
      ui.Image image = await boundary.toImage(pixelRatio: 1.0);
      
      // Convert to bytes
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData == null) {
        print('Failed to convert image to bytes');
        return null;
      }

      return byteData.buffer.asUint8List();
    } catch (e) {
      print('Frame capture failed: $e');
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

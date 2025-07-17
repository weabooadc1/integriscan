import 'package:integriscan/services/report_service.dart';

class ReportTestHelper {
  static Future<void> generateSampleReport() async {
    // Sample detection data
    final sampleDetections = [
      {
        'damageType': 'Crack',
        'confidence': 0.85,
        'imagePath': '',
        'timestamp': DateTime.now().subtract(const Duration(minutes: 5)).millisecondsSinceEpoch,
        'boundingBox': {
          'x': 0.2,
          'y': 0.3,
          'width': 0.15,
          'height': 0.1,
        },
      },
      {
        'damageType': 'Rust',
        'confidence': 0.72,
        'imagePath': '',
        'timestamp': DateTime.now().subtract(const Duration(minutes: 3)).millisecondsSinceEpoch,
        'boundingBox': {
          'x': 0.6,
          'y': 0.4,
          'width': 0.12,
          'height': 0.08,
        },
      },
      {
        'damageType': 'Deformation',
        'confidence': 0.68,
        'imagePath': '',
        'timestamp': DateTime.now().subtract(const Duration(minutes: 1)).millisecondsSinceEpoch,
        'boundingBox': {
          'x': 0.4,
          'y': 0.6,
          'width': 0.18,
          'height': 0.14,
        },
      },
      {
        'damageType': 'Scaling',
        'confidence': 0.75,
        'imagePath': '',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'boundingBox': {
          'x': 0.1,
          'y': 0.2,
          'width': 0.2,
          'height': 0.15,
        },
      },
    ];

    try {
      final report = await ReportService.generateReport(
        userId: 'test_user_123',
        sessionName: 'Sample Inspection Report',
        detections: sampleDetections,
      );

      print('Sample report generated successfully: ${report.id}');
      print('Total detections: ${report.detections.length}');
      print('Overall severity: ${report.summary.overallSeverity}');
    } catch (e) {
      print('Error generating sample report: $e');
    }
  }
}

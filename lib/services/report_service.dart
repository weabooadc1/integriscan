import 'package:integriscan/models/report_models.dart';
import 'package:integriscan/services/recommendations_service.dart';
import 'package:integriscan/database/database_helper.dart';

class ReportService {
  static Future<DetectionReport> generateReport({
    required String userId,
    required String sessionName,
    required List<Map<String, dynamic>> detections,
  }) async {
    final reportId = DateTime.now().millisecondsSinceEpoch.toString();
    
    // Convert detections to DamageDetection objects
    final damageDetections = detections.map((detection) {
      final recommendations = RecommendationsService.getRecommendations(
        detection['damageType'],
        detection['confidence'],
      );
      
      return DamageDetection(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        reportId: reportId,
        damageType: detection['damageType'],
        confidence: detection['confidence'],
        imagePath: detection['imagePath'],
        timestamp: DateTime.fromMillisecondsSinceEpoch(detection['timestamp']),
        boundingBox: detection['boundingBox'] != null
            ? BoundingBox.fromMap(detection['boundingBox'])
            : null,
        severity: RecommendationsService.getSeverity(
          detection['damageType'],
          detection['confidence'],
        ),
        recommendations: recommendations,
      );
    }).toList();

    // Generate summary
    final summary = _generateSummary(damageDetections);

    // Create report
    final report = DetectionReport(
      id: reportId,
      userId: userId,
      sessionName: sessionName,
      createdAt: DateTime.now(),
      detections: damageDetections,
      summary: summary,
    );

    // Save to database
    await _saveReportToDatabase(report);

    return report;
  }

  static ReportSummary _generateSummary(List<DamageDetection> detections) {
    int criticalCount = 0;
    int moderateCount = 0;
    int minorCount = 0;
    Set<String> allRecommendations = {};

    for (final detection in detections) {
      switch (detection.severity.toLowerCase()) {
        case 'high':
          criticalCount++;
          break;
        case 'medium':
          moderateCount++;
          break;
        case 'low':
          minorCount++;
          break;
      }
      allRecommendations.addAll(detection.recommendations);
    }

    String overallSeverity = 'Low';
    if (criticalCount > 0) {
      overallSeverity = 'Critical';
    } else if (moderateCount > 0) {
      overallSeverity = 'Moderate';
    }

    return ReportSummary(
      overallSeverity: overallSeverity,
      recommendations: allRecommendations.toList(),
      totalDetections: detections.length,
      criticalCount: criticalCount,
      moderateCount: moderateCount,
      minorCount: minorCount,
    );
  }

  static Future<void> _saveReportToDatabase(DetectionReport report) async {
    final db = DatabaseHelper();
    
    // Save report
    await db.insertReport(report.toMap());
    
    // Save detections
    for (final detection in report.detections) {
      await db.insertDetection(detection.toMap());
    }
  }

  static Future<List<DetectionReport>> getReports() async {
    final db = DatabaseHelper();
    final reportMaps = await db.getReports();
    
    List<DetectionReport> reports = [];
    for (final reportMap in reportMaps) {
      final detectionMaps = await db.getDetectionsByReport(reportMap['id']);
      final detections = detectionMaps.map((map) => DamageDetection.fromMap(map)).toList();
      
      final report = DetectionReport.fromMap(reportMap);
      reports.add(DetectionReport(
        id: report.id,
        userId: report.userId,
        sessionName: report.sessionName,
        createdAt: report.createdAt,
        detections: detections,
        summary: ReportSummary(
          overallSeverity: report.summary.overallSeverity,
          recommendations: report.summary.recommendations,
          totalDetections: detections.length,
          criticalCount: detections.where((d) => d.severity == 'High').length,
          moderateCount: detections.where((d) => d.severity == 'Medium').length,
          minorCount: detections.where((d) => d.severity == 'Low').length,
        ),
      ));
    }
    
    return reports;
  }

  static Future<DetectionReport?> getReport(String id) async {
    final db = DatabaseHelper();
    final reportMap = await db.getReport(id);
    
    if (reportMap == null) return null;
    
    final detectionMaps = await db.getDetectionsByReport(id);
    final detections = detectionMaps.map((map) => DamageDetection.fromMap(map)).toList();
    
    final report = DetectionReport.fromMap(reportMap);
    return DetectionReport(
      id: report.id,
      userId: report.userId,
      sessionName: report.sessionName,
      createdAt: report.createdAt,
      detections: detections,
      summary: ReportSummary(
        overallSeverity: report.summary.overallSeverity,
        recommendations: report.summary.recommendations,
        totalDetections: detections.length,
        criticalCount: detections.where((d) => d.severity == 'High').length,
        moderateCount: detections.where((d) => d.severity == 'Medium').length,
        minorCount: detections.where((d) => d.severity == 'Low').length,
      ),
    );
  }
}

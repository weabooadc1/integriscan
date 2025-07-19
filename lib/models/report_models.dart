import 'dart:convert';
class DetectionReport {
  final String id;
  final String userId;
  final String sessionName;
  final DateTime createdAt;
  final List<DamageDetection> detections;
  final ReportSummary summary;

  DetectionReport({
    required this.id,
    required this.userId,
    required this.sessionName,
    required this.createdAt,
    required this.detections,
    required this.summary,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'sessionName': sessionName,
      'createdAt': createdAt.toIso8601String(),
      'detectionsCount': detections.length,
      'severityLevel': summary.overallSeverity,
      'recommendations': summary.recommendations.join('|'),
    };
  }

  factory DetectionReport.fromMap(
    Map<String, dynamic> map, {
    List<DamageDetection>? detections,
    ReportSummary? summary,
  }) {
    return DetectionReport(
      id: map['id'],
      userId: map['userId'],
      sessionName: map['sessionName'],
      createdAt: DateTime.parse(map['createdAt']),
      detections: detections ?? [],
      summary: summary ?? ReportSummary(
        overallSeverity: map['severityLevel'],
        recommendations: map['recommendations'].split('|'),
        totalDetections: map['detectionsCount'],
        criticalCount: 0,
        moderateCount: 0,
        minorCount: 0,
      ),
    );
  }
}

class DamageDetection {
  final String id;
  final String reportId;
  final String damageType;
  final double confidence;
  final String imagePath;
  final DateTime timestamp;
  final BoundingBox? boundingBox;
  final String severity;
  final List<String> recommendations;

  DamageDetection({
    required this.id,
    required this.reportId,
    required this.damageType,
    required this.confidence,
    required this.imagePath,
    required this.timestamp,
    this.boundingBox,
    required this.severity,
    required this.recommendations,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'reportId': reportId,
      'damageType': damageType,
      'confidence': confidence,
      'imagePath': imagePath,
      'timestamp': timestamp.toIso8601String(),
      'boundingBox': boundingBox?.toMap(),
      'severity': severity,
      'recommendations': recommendations.join('|'),
    };
  }

  factory DamageDetection.fromMap(Map<String, dynamic> map) {
    dynamic bbox = map['boundingBox'];
    if (bbox != null && bbox is String && bbox.isNotEmpty) {
      try {
        bbox = jsonDecode(bbox);
      } catch (_) {
        bbox = null;
      }
    }
    return DamageDetection(
      id: map['id'],
      reportId: map['reportId'],
      damageType: map['damageType'],
      confidence: map['confidence'],
      imagePath: map['imagePath'],
      timestamp: DateTime.parse(map['timestamp']),
      boundingBox: bbox != null ? BoundingBox.fromMap(bbox) : null,
      severity: map['severity'],
      recommendations: map['recommendations'].split('|'),
    );
  }
}

class BoundingBox {
  final double x, y, width, height;

  BoundingBox({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  Map<String, dynamic> toMap() {
    return {'x': x, 'y': y, 'width': width, 'height': height};
  }

  factory BoundingBox.fromMap(Map<String, dynamic> map) {
    return BoundingBox(
      x: map['x'],
      y: map['y'],
      width: map['width'],
      height: map['height'],
    );
  }
}

class ReportSummary {
  final String overallSeverity;
  final List<String> recommendations;
  final int totalDetections;
  final int criticalCount;
  final int moderateCount;
  final int minorCount;

  ReportSummary({
    required this.overallSeverity,
    required this.recommendations,
    required this.totalDetections,
    required this.criticalCount,
    required this.moderateCount,
    required this.minorCount,
  });

  Map<String, dynamic> toMap() {
    return {
      'overallSeverity': overallSeverity,
      'recommendations': recommendations.join('|'),
      'totalDetections': totalDetections,
      'criticalCount': criticalCount,
      'moderateCount': moderateCount,
      'minorCount': minorCount,
    };
  }

  factory ReportSummary.fromMap(Map<String, dynamic> map) {
    return ReportSummary(
      overallSeverity: map['overallSeverity'] ?? '',
      recommendations: (map['recommendations'] ?? '').toString().split('|'),
      totalDetections: map['totalDetections'] ?? 0,
      criticalCount: map['criticalCount'] ?? 0,
      moderateCount: map['moderateCount'] ?? 0,
      minorCount: map['minorCount'] ?? 0,
    );
  }
}

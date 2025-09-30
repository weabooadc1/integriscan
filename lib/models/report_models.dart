import 'dart:convert';
class DetectionReport {
  final String id;
  final String userId;
  final String sessionName;
  final DateTime createdAt;
  final List<DamageDetection> detections;
  final ReportSummary summary;
  final bool synced;
  
  // Engineer verification fields
  final bool flaggedForVerification;
  final DateTime? flaggedAt;
  final String verificationStatus; // "none", "review", "clear", "issues"
  final String? engineerComments;
  final DateTime? reviewedAt;
  
  // Offline flagging support
  final bool pendingFlagSync;
  final DateTime? offlineFlaggedAt;
  final bool deleted;

  DetectionReport({
    required this.id,
    required this.userId,
    required this.sessionName,
    required this.createdAt,
    required this.detections,
    required this.summary,
    this.synced = false,
    this.flaggedForVerification = false,
    this.flaggedAt,
    this.verificationStatus = 'none',
    this.engineerComments,
    this.reviewedAt,
    this.pendingFlagSync = false,
    this.offlineFlaggedAt,
    this.deleted = false,
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
      'cracksCount': summary.cracksCount,
      'corrosionCount': summary.corrosionCount,
      'deformationCount': summary.deformationCount,
      'synced': synced ? 1 : 0,
      'flaggedForVerification': flaggedForVerification ? 1 : 0,
      'flaggedAt': flaggedAt?.toIso8601String(),
      'verificationStatus': verificationStatus,
      'engineerComments': engineerComments,
      'reviewedAt': reviewedAt?.toIso8601String(),
      'pendingFlagSync': pendingFlagSync ? 1 : 0,
      'offlineFlaggedAt': offlineFlaggedAt?.toIso8601String(),
      'deleted': deleted ? 1 : 0,
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
        cracksCount: map['cracksCount'] ?? 0,
        corrosionCount: map['corrosionCount'] ?? 0,
        deformationCount: map['deformationCount'] ?? 0,
      ),
      synced: (map['synced'] ?? 0) == 1,
      flaggedForVerification: (map['flaggedForVerification'] ?? 0) == 1,
      flaggedAt: map['flaggedAt'] != null ? DateTime.parse(map['flaggedAt']) : null,
      verificationStatus: map['verificationStatus'] ?? 'none',
      engineerComments: map['engineerComments'],
      reviewedAt: map['reviewedAt'] != null ? DateTime.parse(map['reviewedAt']) : null,
      pendingFlagSync: (map['pendingFlagSync'] ?? 0) == 1,
      offlineFlaggedAt: map['offlineFlaggedAt'] != null ? DateTime.parse(map['offlineFlaggedAt']) : null,
      deleted: (map['deleted'] ?? 0) == 1,
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
      'boundingBox': boundingBox != null ? jsonEncode(boundingBox!.toMap()) : null,
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
  final int cracksCount;
  final int corrosionCount;
  final int deformationCount;

  ReportSummary({
    required this.overallSeverity,
    required this.recommendations,
    required this.totalDetections,
    required this.cracksCount,
    required this.corrosionCount,
    required this.deformationCount,
  });

  Map<String, dynamic> toMap() {
    return {
      'overallSeverity': overallSeverity,
      'recommendations': recommendations.join('|'),
      'totalDetections': totalDetections,
      'cracksCount': cracksCount,
      'corrosionCount': corrosionCount,
      'deformationCount': deformationCount,
    };
  }

  factory ReportSummary.fromMap(Map<String, dynamic> map) {
    return ReportSummary(
      overallSeverity: map['overallSeverity'] ?? '',
      recommendations: (map['recommendations'] ?? '').toString().split('|'),
      totalDetections: map['totalDetections'] ?? 0,
      cracksCount: map['cracksCount'] ?? 0,
      corrosionCount: map['corrosionCount'] ?? 0,
      deformationCount: map['deformationCount'] ?? 0,
    );
  }
}

/// Model for engineer verification records
class EngineerVerification {
  final String id;
  final String originalReportId;
  final String userId; // Who flagged it
  final DateTime flaggedAt;
  final Map<String, dynamic> reportSnapshot; // Full copy of report
  final String status; // "review", "clear", "issues"
  final String? engineerComments;
  final String? engineerId; // Who reviewed it
  final DateTime? reviewedAt;

  EngineerVerification({
    required this.id,
    required this.originalReportId,
    required this.userId,
    required this.flaggedAt,
    required this.reportSnapshot,
    this.status = 'review',
    this.engineerComments,
    this.engineerId,
    this.reviewedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'originalReportId': originalReportId,
      'userId': userId,
      'flaggedAt': flaggedAt.toIso8601String(),
      'reportSnapshot': jsonEncode(reportSnapshot), // Convert Map to JSON string
      'status': status,
      'engineerComments': engineerComments,
      'engineerId': engineerId,
      'reviewedAt': reviewedAt?.toIso8601String(),
    };
  }

  factory EngineerVerification.fromMap(Map<String, dynamic> map) {
    return EngineerVerification(
      id: map['id'],
      originalReportId: map['originalReportId'],
      userId: map['userId'],
      flaggedAt: DateTime.parse(map['flaggedAt']),
      reportSnapshot: jsonDecode(map['reportSnapshot']), // Convert JSON string back to Map
      status: map['status'] ?? 'review',
      engineerComments: map['engineerComments'],
      engineerId: map['engineerId'],
      reviewedAt: map['reviewedAt'] != null ? DateTime.parse(map['reviewedAt']) : null,
    );
  }
}

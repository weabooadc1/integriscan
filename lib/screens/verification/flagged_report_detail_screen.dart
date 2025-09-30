import 'package:flutter/material.dart';
import 'package:integriscan/models/report_models.dart';
import 'package:integriscan/services/firebase_storage_service.dart';
import 'package:integriscan/services/recommendations_service.dart';
import 'package:integriscan/component/primarybutton.dart';
import 'dart:io';

class FlaggedReportDetailScreen extends StatelessWidget {
  final DetectionReport report;

  const FlaggedReportDetailScreen({
    super.key, 
    required this.report,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(report.sessionName),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildReportHeader(),
            _buildVerificationStatusCard(),
            _buildSummaryCard(),
            _buildDetectionsList(),
            _buildRecommendationsCard(),
            if (report.engineerComments != null && report.engineerComments!.isNotEmpty)
              _buildEngineerCommentsCard(),
            _buildFinishButton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildReportHeader() {
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.flag,
                color: Colors.orange[700],
                size: 24,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Flagged Report',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange[700],
                  ),
                ),
              ),
              _buildStatusBadge(),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Generated: ${_formatDate(report.createdAt)}',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          if (report.flaggedAt != null) ...[
            const SizedBox(height: 4),
            Text(
              'Flagged: ${_formatDate(report.flaggedAt!)}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
          if (report.reviewedAt != null) ...[
            const SizedBox(height: 4),
            Text(
              'Reviewed: ${_formatDate(report.reviewedAt!)}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    Color color;
    String text;
    IconData icon;

    switch (report.verificationStatus.toLowerCase()) {
      case 'clear':
        color = Colors.green;
        text = 'CLEARED';
        icon = Icons.check_circle;
        break;
      case 'issues':
        color = Colors.red;
        text = 'ISSUES FOUND';
        icon = Icons.error;
        break;
      default:
        color = Colors.orange;
        text = 'UNDER REVIEW';
        icon = Icons.pending;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationStatusCard() {
    if (report.verificationStatus == 'review') {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.pending_actions,
              color: Colors.orange[700],
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pending Review',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange[700],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'This report has been flagged for engineer verification and is currently under review.',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.orange[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final isCleared = report.verificationStatus.toLowerCase() == 'clear';
    final color = isCleared ? Colors.green : Colors.red;
    final icon = isCleared ? Icons.check_circle : Icons.error;
    final title = isCleared ? 'Report Cleared' : 'Issues Found';
    final subtitle = isCleared 
        ? 'Engineer verification confirms no issues with this report.'
        : 'Engineer verification found issues that need attention.';

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: color.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Detection Summary',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSummaryItem(
                'Total',
                report.summary.totalDetections.toString(),
                Colors.blue,
              ),
              _buildSummaryItem(
                'Cracks',
                report.summary.cracksCount.toString(),
                Colors.red,
              ),
              _buildSummaryItem(
                'Corrosion',
                report.summary.corrosionCount.toString(),
                Colors.orange,
              ),
              _buildSummaryItem(
                'Deformation',
                report.summary.deformationCount.toString(),
                Colors.purple,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildDetectionsList() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Detected Issues',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: report.detections.length,
            itemBuilder: (context, index) {
              final detection = report.detections[index];
              return _buildDetectionItem(detection, index);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDetectionItem(DamageDetection detection, int index) {
    Color damageTypeColor;
    switch (detection.damageType.toLowerCase()) {
      case 'crack':
      case 'cracks':
        damageTypeColor = Colors.red;
        break;
      case 'corrosion':
      case 'rust':
      case 'scaling':
        damageTypeColor = Colors.orange;
        break;
      case 'deformation':
      case 'deform':
        damageTypeColor = Colors.purple;
        break;
      default:
        damageTypeColor = Colors.blue;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          top: index > 0 ? BorderSide(color: Colors.grey[200]!) : BorderSide.none,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: damageTypeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  detection.damageType,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: damageTypeColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Confidence: ${(detection.confidence * 100).toInt()}%',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
              Icon(
                _getDamageTypeIcon(detection.damageType),
                color: damageTypeColor,
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (detection.imagePath.isNotEmpty) ...[
            _buildDetectionImage(detection),
            const SizedBox(height: 12),
          ],
          // Recommendations are now shown in dedicated card below
        ],
      ),
    );
  }

  Widget _buildDetectionImage(DamageDetection detection) {
    // Check if it's a Firebase Storage URL
    if (FirebaseStorageService.isFirebaseUrl(detection.imagePath)) {
      return FutureBuilder<String>(
        future: FirebaseStorageService.getDisplayPath(detection.imagePath, detection.reportId, detection.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            );
          }
          
          final imagePath = snapshot.data ?? detection.imagePath;
          
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: _buildImageWidget(imagePath),
          );
        },
      );
    } else {
      // It's a local file path
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: _buildImageWidget(detection.imagePath),
      );
    }
  }

  Widget _buildImageWidget(String imagePath) {
    // If it's a URL, use Image.network, otherwise use Image.file
    if (imagePath.startsWith('http')) {
      return Image.network(
        imagePath,
        height: 200,
        width: double.infinity,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                    : null,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.image_not_supported, color: Colors.grey, size: 48),
                  SizedBox(height: 8),
                  Text('Image not available', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          );
        },
      );
    } else {
      return Image.file(
        File(imagePath),
        height: 200,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.image_not_supported, color: Colors.grey, size: 48),
                  SizedBox(height: 8),
                  Text('Image not available', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          );
        },
      );
    }
  }

  Widget _buildRecommendationsCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.engineering,
                  color: Colors.blue.shade600,
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Engineering Recommendations',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.verified_user,
                    size: 16,
                    color: Colors.blue.shade700,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Professional Engineer Recommendations',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (report.detections.isEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green.shade600, size: 24),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'No structural damage detected. Infrastructure appears to be in good condition.',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Group detections by damage type to avoid duplicate recommendations
              ..._getUniqueRecommendationsByDamageType().entries.map((entry) => 
                _buildRecommendationSection(entry.key, entry.value)),
            ],
          ],
        ),
      ),
    );
  }

  // Helper method to group detections by damage type
  Map<String, List<DamageDetection>> _getUniqueRecommendationsByDamageType() {
    final Map<String, List<DamageDetection>> groupedDetections = {};
    
    for (final detection in report.detections) {
      final damageType = detection.damageType.toLowerCase();
      if (groupedDetections.containsKey(damageType)) {
        groupedDetections[damageType]!.add(detection);
      } else {
        groupedDetections[damageType] = [detection];
      }
    }
    
    return groupedDetections;
  }

  Widget _buildRecommendationSection(String damageType, List<DamageDetection> detections) {
    // Get full recommendation data from RecommendationsService
    final recommendation = RecommendationsService.getRecommendation(damageType);
    
    if (recommendation == null) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${damageType.toUpperCase()} - No Recommendations Available',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'No specific recommendations found for this damage type.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    return ExpansionTile(
      title: Text(
        'Engineer Recommendation for ${damageType.toUpperCase()} Damage',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              const Text('Recommendation', style: TextStyle(fontWeight: FontWeight.w600)),
              ...recommendation.recommendations.map((rec) => Padding(
                padding: const EdgeInsets.only(left: 16, top: 4),
                child: Text('$rec'),
              )),
              
              const SizedBox(height: 16),
              const Text('Safety Notes:', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.red)),
              ...recommendation.safetyNotes.map((note) => Padding(
                padding: const EdgeInsets.only(left: 16, top: 4),
                child: Text('⚠️ $note'),
              )),
              
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  detections.length == 1 
                    ? 'Detection Confidence: ${(detections.first.confidence * 100).toStringAsFixed(1)}%'
                    : 'Total Detections: ${detections.length} instances',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.green.shade700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEngineerCommentsCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.engineering, color: Colors.blue[700], size: 24),
              const SizedBox(width: 8),
              Text(
                'Engineer Comments',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withOpacity(0.2)),
            ),
            child: Text(
              report.engineerComments!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                height: 1.5,
              ),
            ),
          ),
          if (report.reviewedAt != null) ...[
            const SizedBox(height: 8),
            Text(
              'Reviewed on ${_formatDate(report.reviewedAt!)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFinishButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              text: 'Back to Flagged Reports',
              press: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  IconData _getDamageTypeIcon(String damageType) {
    switch (damageType.toLowerCase()) {
      case 'crack':
      case 'cracks':
        return Icons.broken_image;
      case 'corrosion':
      case 'rust':
      case 'scaling':
        return Icons.warning;
      case 'deformation':
      case 'deform':
        return Icons.architecture;
      default:
        return Icons.info;
    }
  }
}

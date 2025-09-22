import 'package:flutter/material.dart';
import 'package:integriscan/models/report_models.dart';
import 'package:integriscan/services/recommendations_service.dart';
import 'package:integriscan/services/firebase_storage_service.dart';
import 'package:integriscan/component/primarybutton.dart';
import 'dart:io';

class ReportDetailScreen extends StatefulWidget {
  final DetectionReport report;
  final bool fromAnalysis; // New parameter to indicate if coming from analysis

  const ReportDetailScreen({
    super.key, 
    required this.report,
    this.fromAnalysis = false, // Default to false for backward compatibility
  });

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  bool _isInitializing = true;
  
  @override
  void initState() {
    super.initState();
    // If coming from analysis, add extra delay to ensure all resources are cleaned up
    if (widget.fromAnalysis) {
      print('🔍 ReportDetailScreen: Coming from analysis, adding initialization delay...');
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          setState(() {
            _isInitializing = false;
          });
          print('🔍 ReportDetailScreen: Initialization complete, showing content');
        }
      });
    } else {
      // Normal initialization for regular navigation
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() {
            _isInitializing = false;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading screen if initializing from analysis
    if (_isInitializing) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                widget.fromAnalysis 
                  ? 'Preparing report...\nEnsuring system stability...'
                  : 'Loading report...',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return WillPopScope(
      onWillPop: () async {
        // Force garbage collection when leaving the screen
        await Future.delayed(const Duration(milliseconds: 100));
        return true;
      },
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: Text(widget.report.sessionName),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.share),
              onPressed: () => _shareReport(),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildReportHeader(),
                _buildSummaryCard(),
                _buildDetectionsList(),
                _buildRecommendationsCard(),
                _buildFinishButton(context),
                // Add some padding at the bottom to prevent overflow
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReportHeader() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade600, Colors.blue.shade800],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Inspection Report',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Generated: ${_formatDate(widget.report.createdAt)}',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Summary',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSummaryItem('Total Detections', widget.report.summary.totalDetections.toString(), Colors.blue),
                _buildSummaryItem('Cracks', widget.report.summary.cracksCount.toString(), Colors.red),
                _buildSummaryItem('Corrosion', widget.report.summary.corrosionCount.toString(), Colors.orange),
                _buildSummaryItem('Deformation', widget.report.summary.deformationCount.toString(), Colors.purple),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
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
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Detected Damages',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 16),
            ...widget.report.detections.map((detection) => _buildDetectionItem(detection)),
          ],
        ),
      ),
    );
  }

  Widget _buildDetectionItem(DamageDetection detection) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  detection.damageType,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Confidence: ${(detection.confidence * 100).toStringAsFixed(1)}%'),
          Text('Detected: ${_formatDate(detection.timestamp)}'),
          if (detection.imagePath.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildDetectionImage(detection),
          ],
        ],
      ),
    );
  }

  Widget _buildDetectionImage(DamageDetection detection) {
    // Always check if it's a Firebase Storage URL first for cross-device compatibility
    if (FirebaseStorageService.isFirebaseUrl(detection.imagePath)) {
      return FutureBuilder<String>(
        future: FirebaseStorageService.getDisplayPath(detection.imagePath, detection.reportId, detection.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Container(
              height: 150,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 8),
                    Text('Loading image...', style: TextStyle(color: Colors.grey)),
                  ],
                ),
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
      // For local files, check if they exist; if not, show a cloud sync message
      final file = File(detection.imagePath);
      if (!file.existsSync()) {
        return Container(
          height: 150,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_download, color: Colors.grey, size: 48),
                SizedBox(height: 8),
                Text('Image available on original device', style: TextStyle(color: Colors.grey)),
                Text('Sync with cloud to access', style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
        );
      }
      
      // It's a local file path that exists
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
        height: 150,
        width: double.infinity,
        fit: BoxFit.cover,
        // Add memory cache settings to prevent memory issues
        cacheHeight: 300, // Limit cache height
        cacheWidth: 600,  // Limit cache width
        // Add memory allocation limits to prevent native crashes
        isAntiAlias: false, // Disable anti-aliasing to reduce memory usage
        filterQuality: FilterQuality.low, // Use low quality filtering to reduce memory
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            height: 150,
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
          print('Error loading network image: $error');
          return Container(
            height: 150,
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
      // For local files, check if file exists first
      final file = File(imagePath);
      if (!file.existsSync()) {
        return Container(
          height: 150,
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
                Text('Image file not found', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        );
      }

      // Add try-catch around image loading to prevent native crashes
      try {
        return Image.file(
          file,
          height: 150,
          width: double.infinity,
          fit: BoxFit.cover,
          // Add memory cache settings to prevent memory issues
          cacheHeight: 300,
          cacheWidth: 600,
          // Add memory allocation limits to prevent native crashes
          isAntiAlias: false, // Disable anti-aliasing to reduce memory usage
          filterQuality: FilterQuality.low, // Use low quality filtering to reduce memory
          errorBuilder: (context, error, stackTrace) {
            print('Error loading local image: $error');
            print('Stack trace: $stackTrace');
            return Container(
              height: 150,
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
      } catch (e) {
        print('Exception creating Image.file widget: $e');
        return Container(
          height: 150,
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
                Text('Image loading failed', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
        );
      }
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
                Expanded(
                  child: const Text(
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
                      fontWeight: FontWeight.w500,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (widget.report.detections.isEmpty) ...[
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
                        'Good news! No damage detected. Your structure appears to be in good condition.',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              ...widget.report.detections.map((detection) => _buildRecommendationSection(detection)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationSection(DamageDetection detection) {
    // Get full recommendation data from RecommendationsService
    final recommendation = RecommendationsService.getRecommendation(detection.damageType);
    
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
              '${detection.damageType} - No Recommendations Available',
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
        '${detection.damageType} Repair Guide',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildRecommendationItem('Urgency', recommendation.urgency, Colors.red),
              _buildRecommendationItem('Estimated Cost', recommendation.estimatedCost, Colors.green),
              _buildRecommendationItem('Time to Complete', recommendation.timeToComplete, Colors.blue),
              _buildRecommendationItem('Skill Level', recommendation.skillLevel, Colors.orange),
              
              const SizedBox(height: 16),
              const Text('Steps:', style: TextStyle(fontWeight: FontWeight.w600)),
              ...recommendation.recommendations.map((rec) => Padding(
                padding: const EdgeInsets.only(left: 16, top: 4),
                child: Text('• $rec'),
              )),
              
              const SizedBox(height: 16),
              const Text('Materials Needed:', style: TextStyle(fontWeight: FontWeight.w600)),
              ...recommendation.materials.map((material) => Padding(
                padding: const EdgeInsets.only(left: 16, top: 4),
                child: Text('• $material'),
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
                  'Detection Confidence: ${(detection.confidence * 100).toStringAsFixed(1)}%',
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

  Widget _buildRecommendationItem(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(value, style: TextStyle(color: color)),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _shareReport() {
    // TODO: Implement report sharing functionality
    // This could export to PDF, email, etc.
  }

  Widget _buildFinishButton(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      width: double.infinity,
      child: Column(
        children: [
          if (widget.fromAnalysis) ...[
            // Show when coming from RTSP analysis - go to home
            PrimaryButton(
              text: "Finish & Go to Home",
              press: () {
                // Navigate to home screen and clear all previous routes
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/', // Home route
                  (Route<dynamic> route) => false, // Remove all routes
                );
              },
            ),
          ] else ...[
            // Show when viewing from reports list - just go back
            PrimaryButton(
              text: "Back to Reports",
              press: () {
                Navigator.of(context).pop(); // Go back to reports list
              },
            ),
          ],
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:integriscan/app_keys.dart';
import 'package:integriscan/models/report_models.dart';
import 'package:integriscan/services/recommendations_service.dart';
import 'package:integriscan/services/firebase_storage_service.dart';
import 'package:integriscan/services/report_service.dart';
import 'package:integriscan/component/primarybutton.dart';
import 'package:integriscan/database/database_helper.dart';

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
  late String _currentSessionName;
  
  @override
  void initState() {
    super.initState();
    // Initialize immediately without delay to prevent timing issues
    print('🔍 ReportDetailScreen: Initializing immediately...');
    _currentSessionName = widget.report.sessionName;
    _isInitializing = false;
    print('🔍 ReportDetailScreen: Initialization complete, ready to build content');
  }

  @override
  Widget build(BuildContext context) {
    print('🔍 ReportDetailScreen.build() START - context: ${context.mounted}');
    print('🔍 Report ID: ${widget.report.id}, fromAnalysis: ${widget.fromAnalysis}');
    print('🔍 Detections count: ${widget.report.detections.length}');
    print('🔍 IsInitializing: $_isInitializing');
    
    try {
      print('🔍 Starting widget construction...');
      
      // Show loading screen if initializing from analysis
      if (_isInitializing) {
        print('🔍 Building loading Scaffold...');
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
    
    print('🔍 Building main WillPopScope widget...');
    return WillPopScope(
      onWillPop: () async {
        print('🔍 WillPopScope onWillPop triggered');
        // Force garbage collection when leaving the screen
        await Future.delayed(const Duration(milliseconds: 100));
        return true;
      },
      child: () {
        print('🔍 Building main Scaffold widget...');
        return Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: Text(_currentSessionName),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Rename Session',
              onPressed: () => _showRenameSessionDialog(context),
            ),
          ],
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            child: (() {
              print('🔍 Building Column with child widgets...');
              return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                (() {
                  print('🔍 Building _buildReportHeader...');
                  return _buildReportHeader();
                })(),
                (() {
                  print('🔍 Building _buildSummaryCard...');
                  return _buildSummaryCard();
                })(),
                (() {
                  print('🔍 Building _buildDetectionsList...');
                  return _buildDetectionsList();
                })(),
                (() {
                  print('🔍 Building _buildRecommendationsCard...');
                  return _buildRecommendationsCard();
                })(),
                (() {
                  print('🔍 Building _buildFinishButton...');
                  return _buildFinishButton(context);
                })(),
                // Add some padding at the bottom to prevent overflow
                const SizedBox(height: 20),
              ],
            );
            })(),
          ),
        ),
      );
      }(),
    );
    } catch (e, stackTrace) {
      print('🚨 CRITICAL: ReportDetailScreen.build() CRASHED: $e');
      print('🚨 Stack trace: $stackTrace');
      return Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text('Report Error'),
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Unable to load report details',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Error: ${e.toString()}',
                style: const TextStyle(fontSize: 14, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }
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
    
    for (final detection in widget.report.detections) {
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
    // Calculate average confidence for this damage type
    final avgConfidence = detections.fold<double>(0, (sum, det) => sum + det.confidence) / detections.length;
    
    // Get structured recommendations from RecommendationsService
    final recommendations = RecommendationsService.getFilteredRecommendations(damageType, avgConfidence);
    
    if (recommendations.isEmpty || recommendations.first.contains('No specific recommendations')) {
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

    // Parse recommendations into sections
    final sections = _parseRecommendationSections(recommendations);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        initiallyExpanded: true,
        title: Text(
          'Recommendations for ${damageType.toUpperCase()} Damage',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          detections.length == 1 
            ? 'Confidence: ${(detections.first.confidence * 100).toStringAsFixed(1)}%'
            : '${detections.length} detections found',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: sections.entries.map((entry) => _buildSection(entry.key, entry.value)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // Parse recommendations into sections
  Map<String, List<String>> _parseRecommendationSections(List<String> recommendations) {
    final Map<String, List<String>> sections = {};
    String currentSection = '';
    
    for (final line in recommendations) {
      if (line.startsWith('===')) {
        currentSection = line.replaceAll('===', '').trim();
        sections[currentSection] = [];
      } else if (line.trim().isNotEmpty && currentSection.isNotEmpty) {
        sections[currentSection]!.add(line);
      }
    }
    
    return sections;
  }

  // Build a section widget
  Widget _buildSection(String title, List<String> content) {
    // Determine section color and icon
    IconData icon;
    Color color;
    
    if (title.contains('SAFETY')) {
      icon = Icons.shield;
      color = Colors.red;
    } else if (title.contains('IMMEDIATE')) {
      icon = Icons.emergency;
      color = Colors.orange;
    } else if (title.contains('REPAIR')) {
      icon = Icons.build;
      color = Colors.blue;
    } else if (title.contains('PREVENTIVE')) {
      icon = Icons.health_and_safety;
      color = Colors.green;
    } else if (title.contains('CONFIDENCE')) {
      icon = Icons.analytics;
      color = Colors.purple;
    } else if (title.contains('PROFESSIONAL')) {
      icon = Icons.engineering;
      color = Colors.indigo;
    } else {
      icon = Icons.info;
      color = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...content.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.startsWith('•') || item.startsWith('⚠️') ? '' : '• ',
                  style: TextStyle(color: color, fontSize: 14),
                ),
                Expanded(
                  child: Text(
                    item,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[800],
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }


  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _showRenameSessionDialog(BuildContext context) async {
    final controller = TextEditingController(text: _currentSessionName);
    
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Session'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Session Name',
            hintText: 'Enter new session name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          maxLength: 50,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty && newName != _currentSessionName) {
                // Update the session name in the database directly
                try {
                  final db = DatabaseHelper();
                  await db.database.then((database) async {
                    await database.update(
                      'reports',
                      {'sessionName': newName},
                      where: 'id = ?',
                      whereArgs: [widget.report.id],
                    );
                  });
                  
                  setState(() {
                    _currentSessionName = newName;
                  });
                  
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Session name updated successfully'),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to update session name: $e'),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                }
              } else if (newName.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Session name cannot be empty'),
                    backgroundColor: Colors.orange,
                    duration: Duration(seconds: 2),
                  ),
                );
              } else {
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildFinishButton(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      width: double.infinity,
      child: Column(
        children: [
          if (widget.fromAnalysis) ...[
            // Show when coming from RTSP analysis - offer choice to upload or not
            const SizedBox(height: 8),
            Text(
              'Choose what to do with this report:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            
            // Button to save and upload report
            PrimaryButton(
              text: "Save & Upload Report",
              press: () => _uploadReportAndGoHome(context),
            ),
            
            const SizedBox(height: 12),
            
            // Button to discard report and go home
            PrimaryButton(
              text: "Go Home (Discard Report)",
              press: () => _discardReportAndGoHome(context),
              color: Colors.red[600]!,
              textColor: Colors.white,
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

  Future<void> _uploadReportAndGoHome(BuildContext context) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Uploading report to cloud...'),
            ],
          ),
        );
      },
    );

    try {
      // Upload the report to cloud
      final success = await ReportService.uploadReportToCloud(widget.report.id);
      
      // Use Future.microtask to ensure all UI operations happen safely
      Future.microtask(() {
        if (mounted) {
          // Close loading dialog
          Navigator.of(context).pop();
          
          if (success) {
            // Show success message
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Report uploaded to cloud successfully!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 3),
              ),
            );
          }
          
          // Navigate to home after a short delay
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) {
              Navigator.of(context).pushNamedAndRemoveUntil(
                '/', // Home route
                (Route<dynamic> route) => false, // Remove all routes
              );
            }
          });
        }
      });
    } catch (e) {
      // Use Future.microtask to ensure all UI operations happen safely
      Future.microtask(() {
        if (!mounted) return;

        // Close loading dialog via the root navigator (safer)
        try {
          AppKeys.navigatorKey.currentState?.pop();
        } catch (_) {
          // Fallback to context pop if needed
          try {
            Navigator.of(context).pop();
          } catch (_) {}
        }

        // Show error dialog using the dialog's builder context so its pop only closes the dialog
        showDialog(
          context: context,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: const Text('Upload Failed'),
              content: Text(
                'Failed to upload report to cloud: ${e.toString()}\n\n'
                'The report is still saved locally. You can try uploading later from the reports list.',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    // Only close the error dialog and stay on this screen
                    Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Try Again Later'),
                ),
                TextButton(
                  onPressed: () {
                    // Close the dialog first
                    Navigator.of(dialogContext).pop();

                    // Then navigate home using the global navigator to avoid popping routes unintentionally
                    Future.delayed(const Duration(milliseconds: 300), () {
                      AppKeys.navigatorKey.currentState?.pushNamedAndRemoveUntil(
                        '/',
                        (Route<dynamic> route) => false,
                      );
                    });
                  },
                  child: const Text('Go Home Anyway'),
                ),
              ],
            );
          },
        );
      });
    }
  }

  void _discardReportAndGoHome(BuildContext context) {
    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Discard Report'),
          content: const Text(
            'Are you sure you want to discard this report? '
            'All detection data will be permanently deleted and cannot be recovered.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop(); // Close dialog
                
                // Show loading dialog while deleting
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (BuildContext context) {
                    return const AlertDialog(
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Deleting report...'),
                        ],
                      ),
                    );
                  },
                );
                
                try {
                  // Delete the report from local database
                  await ReportService.deleteReport(widget.report.id);
                  
                  // Use global navigator and scaffold messenger keys to avoid
                  // using a possibly deactivated BuildContext after async work.
                  try {
                    // Close loading dialog via global navigator
                    AppKeys.navigatorKey.currentState?.pop();
                  } catch (e) {
                    print('Error closing dialog: $e');
                  }

                  try {
                    // Show success snackbar via global scaffold messenger
                    AppKeys.scaffoldMessengerKey.currentState?.showSnackBar(
                      const SnackBar(
                        content: Text('Report discarded successfully'),
                        backgroundColor: Colors.orange,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  } catch (e) {
                    print('Error showing snackbar: $e');
                  }

                  // Navigate to home after a short delay using the global navigator
                  await Future.delayed(const Duration(milliseconds: 700));
                  try {
                    AppKeys.navigatorKey.currentState?.pushNamedAndRemoveUntil(
                      '/',
                      (Route<dynamic> route) => false,
                    );
                  } catch (e) {
                    print('Error navigating home: $e');
                    try {
                      AppKeys.navigatorKey.currentState?.popUntil((route) => route.isFirst);
                    } catch (e2) {
                      print('Error with fallback navigation: $e2');
                    }
                  }
                } catch (e) {
                  print('Error deleting report: $e');
                  if (mounted) {
                    try {
                      AppKeys.navigatorKey.currentState?.pop();
                    } catch (e) {
                      print('Error closing dialog: $e');
                    }

                    try {
                      AppKeys.scaffoldMessengerKey.currentState?.showSnackBar(
                        SnackBar(
                          content: Text('Failed to delete report: ${e.toString()}'),
                          backgroundColor: Colors.red,
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    } catch (e) {
                      print('Error showing error message: $e');
                    }
                  }
                }
              },
              child: const Text('Discard', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:integriscan/constant.dart';
import 'package:integriscan/models/report_models.dart';
import 'package:integriscan/services/report_service.dart';
import 'package:integriscan/services/firestore_sync_service.dart';
import 'package:integriscan/database/database_helper.dart';
import 'package:integriscan/providers/auth_provider.dart';
import 'package:integriscan/screens/reports/report_detail_screen.dart';
import 'package:integriscan/screens/reports/reports_list_screen.dart';
import 'package:integriscan/screens/verification/engineer_verification_screen.dart';
import 'package:provider/provider.dart';

class MyFlaggedReportsScreen extends StatefulWidget {
  const MyFlaggedReportsScreen({super.key});

  @override
  State<MyFlaggedReportsScreen> createState() => _MyFlaggedReportsScreenState();
}

class _MyFlaggedReportsScreenState extends State<MyFlaggedReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  bool _isEngineer = false;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializeUser();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _initializeUser() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _currentUserId = authProvider.user?.uid;
    
    if (_currentUserId != null) {
      _isEngineer = await ReportService.isUserEngineer(_currentUserId!);
      if (mounted) {
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserId == null) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'My Flagged Reports',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: kPrimaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Review'),
            Tab(text: 'Clear'),
            Tab(text: 'Issues'),
          ],
        ),
        actions: [
          if (_isEngineer)
            IconButton(
              icon: const Icon(Icons.admin_panel_settings),
              tooltip: 'Switch to Engineer View',
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const EngineerVerificationScreen(),
                  ),
                );
              },
            ),
        ],
      ),
      body: StreamBuilder<List<DetectionReport>>(
        stream: _getFlaggedReportsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading data',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {}); // Refresh the stream
                    },
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            );
          }

          final reports = snapshot.data ?? [];
          
          return Column(
            children: [
              // Statistics Dashboard
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
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
                      'Flagged Reports Overview',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildStatItem(
                            'Total',
                            reports.length.toString(),
                            Colors.blue,
                            Icons.flag,
                          ),
                        ),
                        Expanded(
                          child: _buildStatItem(
                            'Review',
                            reports.where((r) => r.verificationStatus == 'review').length.toString(),
                            Colors.orange,
                            Icons.schedule,
                          ),
                        ),
                        Expanded(
                          child: _buildStatItem(
                            'Clear',
                            reports.where((r) => r.verificationStatus == 'clear').length.toString(),
                            Colors.green,
                            Icons.check_circle,
                          ),
                        ),
                        Expanded(
                          child: _buildStatItem(
                            'Issues',
                            reports.where((r) => r.verificationStatus == 'issues').length.toString(),
                            Colors.red,
                            Icons.cancel,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Tab Content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildReportsList(reports, 'review'),
                    _buildReportsList(reports, 'clear'),
                    _buildReportsList(reports, 'issues'),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Stream<List<DetectionReport>> _getFlaggedReportsStream() async* {
    try {
      // Check if user is still authenticated
      if (_currentUserId == null) {
        yield [];
        return;
      }

      // Get initial reports from local database and filter for flagged ones
      var allReports = await ReportService.getReports(userId: _currentUserId);
      var flaggedReports = allReports.where((report) => 
        report.flaggedForVerification && report.userId == _currentUserId
      ).toList();

      yield flaggedReports;

      // Listen to real-time Firestore updates for flagged reports (now includes verification status)
      await for (final firestoreFlaggedReports in FirestoreSyncService.streamFlaggedReports(_currentUserId)) {
        try {
          bool hasUpdates = false;
          
          // Update both local database and in-memory reports with Firestore data
          for (final flaggedReport in firestoreFlaggedReports) {
            final reportId = flaggedReport['reportId'] as String?;
            if (reportId != null && flaggedReport['userId'] == _currentUserId) {
              final reportIndex = flaggedReports.indexWhere((r) => r.id == reportId);
              if (reportIndex != -1) {
                final currentReport = flaggedReports[reportIndex];
                final newStatus = flaggedReport['status'] as String? ?? 'review';
                final newComments = flaggedReport['engineerComments'] as String?;
                final newReviewedAt = flaggedReport['reviewedAt'] != null 
                    ? DateTime.parse(flaggedReport['reviewedAt'] as String)
                    : null;

                // Check if there are actual changes to avoid unnecessary updates
                if (currentReport.verificationStatus != newStatus ||
                    currentReport.engineerComments != newComments ||
                    currentReport.reviewedAt != newReviewedAt) {
                  
                  // Update local database
                  final db = DatabaseHelper();
                  await db.updateReportVerificationStatus(reportId, {
                    'verificationStatus': newStatus,
                    'engineerComments': newComments,
                    'reviewedAt': newReviewedAt?.toIso8601String(),
                  });

                  // Create updated report for in-memory list
                  final updatedReport = DetectionReport(
                    id: currentReport.id,
                    userId: currentReport.userId,
                    sessionName: currentReport.sessionName,
                    createdAt: currentReport.createdAt,
                    detections: currentReport.detections,
                    summary: currentReport.summary,
                    flaggedForVerification: currentReport.flaggedForVerification,
                    flaggedAt: currentReport.flaggedAt,
                    verificationStatus: newStatus,
                    engineerComments: newComments,
                    reviewedAt: newReviewedAt,
                  );
                  
                  flaggedReports[reportIndex] = updatedReport;
                  hasUpdates = true;
                }
              }
            }
          }
          
          // Only yield if there were actual updates
          if (hasUpdates) {
            yield List.from(flaggedReports);
          }
        } catch (e) {
          print('Error processing Firestore flagged report updates: $e');
          // Check if it's a permission error (user logged out)
          if (e.toString().contains('permission-denied') || e.toString().contains('PERMISSION_DENIED')) {
            print('Permission denied - user likely logged out, stopping stream');
            return;
          }
          // Continue with existing data on other errors
        }
      }
    } catch (e) {
      print('Error in flagged reports stream: $e');
      // Check if it's a permission error and handle gracefully
      if (e.toString().contains('permission-denied') || e.toString().contains('PERMISSION_DENIED')) {
        print('Permission denied - user not authenticated, returning empty list');
        yield [];
        return;
      }
      throw e;
    }
  }

  Widget _buildReportsList(List<DetectionReport> reports, String status) {
    final filteredReports = reports.where((report) =>
        report.verificationStatus == status).toList();

    if (filteredReports.isEmpty) {
      return _buildEmptyState(status);
    }

    return RefreshIndicator(
      onRefresh: () async {
        setState(() {}); // Refresh the stream
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filteredReports.length,
        itemBuilder: (context, index) {
          final report = filteredReports[index];
          return _buildReportCard(report);
        },
      ),
    );
  }

  Widget _buildEmptyState(String status) {
    String message;
    IconData icon;
    Color color;

    switch (status) {
      case 'review':
        message = 'No reports under review\nReports you flag will appear here awaiting engineer review';
        icon = Icons.schedule;
        color = Colors.orange;
        break;
      case 'clear':
        message = 'No cleared reports\nReports flagged but found to have no issues will appear here';
        icon = Icons.check_circle_outline;
        color = Colors.green;
        break;
      case 'issues':
        message = 'No reports with issues\nReports flagged and confirmed to have issues needing correction will appear here';
        icon = Icons.cancel_outlined;
        color = Colors.red;
        break;
      default:
        message = 'No reports found';
        icon = Icons.assignment_outlined;
        color = Colors.grey;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 80,
            color: color.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          if (status == 'review') ...[
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ReportsListScreen(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('View My Reports'),
            ),
            const SizedBox(height: 12),
            Text(
              'Tip: Use the three-dot menu on any report to flag it for engineer review',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReportCard(DetectionReport report) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ReportDetailScreen(report: report),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Expanded(
                    child: Text(
                      report.sessionName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildStatusChip(report.verificationStatus),
                ],
              ),
              const SizedBox(height: 8),

              // Date info
              Text(
                'Flagged: ${_formatDate(report.flaggedAt)}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              if (report.reviewedAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Reviewed: ${_formatDate(report.reviewedAt)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],

              // Engineer comments
              if (report.engineerComments != null && report.engineerComments!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.comment,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Engineer Comments:',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        report.engineerComments!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[800],
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // Report summary
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${report.summary.totalDetections} detections • ${report.summary.overallSeverity}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    'Created: ${_formatDate(report.createdAt)}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    IconData icon;
    String label;

    switch (status) {
      case 'clear':
        color = Colors.green;
        icon = Icons.check_circle;
        label = 'CLEAR';
        break;
      case 'issues':
        color = Colors.red;
        icon = Icons.cancel;
        label = 'ISSUES';
        break;
      default:
        color = Colors.orange;
        icon = Icons.schedule;
        label = 'REVIEW';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 12,
            color: color,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  Widget _buildStatItem(String label, String value, Color color, IconData icon) {
    return Flexible(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:integriscan/models/report_models.dart';
import 'package:integriscan/services/report_service.dart';
import 'package:integriscan/screens/reports/report_detail_screen.dart';
import 'package:integriscan/screens/verification/flag_report_screen.dart';
import 'package:integriscan/providers/auth_provider.dart';
import 'package:integriscan/widgets/connectivity_indicator.dart';
import 'package:provider/provider.dart';

class ReportsListScreen extends StatefulWidget {
  const ReportsListScreen({super.key});

  @override
  State<ReportsListScreen> createState() => _ReportsListScreenState();
}

class _ReportsListScreenState extends State<ReportsListScreen> with WidgetsBindingObserver {
  List<DetectionReport> _reports = [];
  bool _loading = true;
  bool _selectionMode = false;
  bool _syncing = false;
  Set<String> _selectedReportIds = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadReports();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Refresh the list when the app resumes to show any changes
    if (state == AppLifecycleState.resumed) {
      _loadReports();
    }
  }

  Future<void> _loadReports() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.user?.uid ?? 'anonymous';
      final reports = await ReportService.getReports(userId: userId);
      
      if (mounted) {
        setState(() {
          _reports = reports;
          _loading = false;
        });
      }
    } catch (e) {
      print('Error loading reports: $e');
      
      if (mounted) {
        setState(() {
          _reports = [];
          _loading = false;
        });
      }
    }
  }

  Future<void> _syncWithCloud() async {
    if (_syncing) return; // Prevent multiple concurrent syncs
    
    setState(() {
      _syncing = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.user?.uid;

      if (userId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please log in to sync with cloud'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Sync reports from cloud to local database (download new reports from other devices)
      await ReportService.syncReportsFromCloud(userId: userId);
      
      // Sync unsynced local reports to cloud (upload any local-only reports)
      await ReportService.syncAllUnsyncedReportsStatic(userId: userId);
      
      // Reload reports to show the updated data
      await _loadReports();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully synced with cloud'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print('Error syncing with cloud: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _syncing = false;
        });
      }
    }
  }

  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      if (!_selectionMode) {
        _selectedReportIds.clear();
      }
    });
  }

  void _toggleReportSelection(String reportId) {
    setState(() {
      if (_selectedReportIds.contains(reportId)) {
        _selectedReportIds.remove(reportId);
      } else {
        _selectedReportIds.add(reportId);
      }
    });
  }

  Future<void> _deleteSelectedReports() async {
    if (_selectedReportIds.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Reports'),
          content: Text(
            'Are you sure you want to delete ${_selectedReportIds.length} selected report${_selectedReportIds.length > 1 ? 's' : ''}? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        // Store the IDs to delete for rollback if needed
        final idsToDelete = _selectedReportIds.toList();
        
        // Immediately remove the reports from local state for instant UI feedback
        setState(() {
          _reports.removeWhere((r) => _selectedReportIds.contains(r.id));
          _selectedReportIds.clear();
          _selectionMode = false;
        });
        
        // Then delete from database (this will handle local and cloud deletion)
        await ReportService.deleteReports(idsToDelete);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${idsToDelete.length} report${idsToDelete.length > 1 ? 's' : ''} deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
        
        // Refresh the list to ensure consistency (in case of any sync issues)
        await _loadReports();
      } catch (e) {
        // If deletion failed, reload reports to restore the UI and exit selection mode
        await _loadReports();
        setState(() {
          _selectedReportIds.clear();
          _selectionMode = false;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting reports: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteSingleReport(DetectionReport report) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Report'),
          content: Text(
            'Are you sure you want to delete "${report.sessionName}"? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        // Immediately remove the report from local state for instant UI feedback
        setState(() {
          _reports.removeWhere((r) => r.id == report.id);
        });
        
        // Then delete from database (this will handle local and cloud deletion)
        await ReportService.deleteReport(report.id);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Report deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
        
        // Refresh the list to ensure consistency (in case of any sync issues)
        await _loadReports();
      } catch (e) {
        // If deletion failed, reload reports to restore the UI
        await _loadReports();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting report: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _navigateToFlagReport(DetectionReport report) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => FlagReportScreen(report: report),
      ),
    );
    
    // Refresh the list if the flag status was changed
    if (result == true) {
      await _loadReports();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: _selectionMode 
            ? Text('${_selectedReportIds.length} selected')
            : const Text('History'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        leading: _selectionMode 
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _toggleSelectionMode,
              )
            : null,
        actions: [
          if (_selectionMode) ...[
            if (_selectedReportIds.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: _deleteSelectedReports,
                tooltip: 'Delete Selected',
              ),
            IconButton(
              icon: Icon(_selectedReportIds.length == _reports.length 
                  ? Icons.deselect 
                  : Icons.select_all_outlined),
              onPressed: () {
                setState(() {
                  if (_selectedReportIds.length == _reports.length) {
                    _selectedReportIds.clear();
                  } else {
                    _selectedReportIds = _reports.map((r) => r.id).toSet();
                  }
                });
              },
              tooltip: _selectedReportIds.length == _reports.length 
                  ? 'Deselect All' 
                  : 'Select All',
            ),
          ] else ...[
            if (_reports.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                onPressed: _toggleSelectionMode,
                tooltip: 'Delete Reports',
              ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadReports,
            ),
          ],
          if (!_selectionMode) ...[
            // Sync button
            IconButton(
              icon: _syncing 
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                      ),
                    )
                  : const Icon(Icons.cloud_sync),
              onPressed: _syncing ? null : _syncWithCloud,
              tooltip: _syncing ? 'Syncing...' : 'Sync with Cloud',
            ),
            // Add connectivity chip to actions when not in selection mode
            const Padding(
              padding: EdgeInsets.only(right: 8.0),
              child: Center(child: ConnectivityStatusChip()),
            ),
          ],
        ],
      ),
      body: ConnectivityIndicator(
        showOnlineIndicator: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _reports.isEmpty
                ? _buildEmptyState()
                : _buildReportsList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assignment_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No Reports Yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start an inspection to generate your first report',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Or sync with cloud to see reports from other devices',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _syncing ? null : _syncWithCloud,
            icon: _syncing 
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.cloud_sync, size: 18),
            label: Text(_syncing ? 'Syncing...' : 'Sync with Cloud'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _reports.length,
      itemBuilder: (context, index) {
        final report = _reports[index];
        return _buildReportCard(report);
      },
    );
  }

  Widget _buildReportCard(DetectionReport report) {
    final isSelected = _selectedReportIds.contains(report.id);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: _selectionMode && isSelected ? Colors.blue.withOpacity(0.1) : null,
      child: InkWell(
        onTap: () async {
          if (_selectionMode) {
            _toggleReportSelection(report.id);
          } else {
            // Navigate to detail screen and refresh list when returning
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ReportDetailScreen(report: report),
              ),
            );
            
            // Always refresh the list when returning from detail screen
            // in case the report was modified or deleted
            await _loadReports();
          }
        },
        onLongPress: _selectionMode ? null : () {
          _toggleSelectionMode();
          _toggleReportSelection(report.id);
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with title and severity badge
              Row(
                children: [
                  if (_selectionMode)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Checkbox(
                        value: isSelected,
                        onChanged: (value) => _toggleReportSelection(report.id),
                      ),
                    ),
                  Expanded(
                    child: Text(
                      report.sessionName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  if (!_selectionMode)
                    PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'delete') {
                          _deleteSingleReport(report);
                        } else if (value == 'flag') {
                          _navigateToFlagReport(report);
                        }
                      },
                      itemBuilder: (BuildContext context) => [
                        PopupMenuItem<String>(
                          value: 'flag',
                          child: Row(
                            children: [
                              Icon(
                                report.flaggedForVerification ? Icons.flag : Icons.outlined_flag,
                                color: report.flaggedForVerification ? Colors.orange : Colors.grey[600],
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(report.flaggedForVerification ? 'Manage Flag' : 'Flag for Review'),
                            ],
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Colors.red, size: 20),
                              SizedBox(width: 8),
                              Text('Delete'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(width: 8),
                ],
              ),
              
              // Flagged status and date row
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Generated: ${_formatDate(report.createdAt)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                  if (report.flaggedForVerification)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.flag,
                            size: 12,
                            color: Colors.orange[700],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'FLAGGED FOR REVIEW',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              
              // Pending sync indicators row
              if (report.pendingFlagSync || (!report.synced)) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (!report.synced)
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.cloud_off,
                              size: 12,
                              color: Colors.grey[700],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'NOT SYNCED',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (report.pendingFlagSync)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.sync_disabled,
                              size: 12,
                              color: Colors.blue[700],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'FLAG SYNC PENDING',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.blue[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
              
              // Show verification status if available
              if (report.flaggedForVerification && report.verificationStatus != 'review') ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: report.verificationStatus == 'clear' 
                        ? Colors.green.withOpacity(0.1)
                        : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: report.verificationStatus == 'clear' 
                          ? Colors.green.withOpacity(0.3)
                          : Colors.red.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        report.verificationStatus == 'clear' 
                            ? Icons.check_circle_outline
                            : Icons.cancel_outlined,
                        size: 16,
                        color: report.verificationStatus == 'clear' 
                            ? Colors.green[700]
                            : Colors.red[700],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          report.verificationStatus == 'clear' 
                              ? 'Report Cleared - No Issues Found'
                              : 'Issues Found - Needs Correction',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: report.verificationStatus == 'clear' 
                                ? Colors.green[700]
                                : Colors.red[700],
                          ),
                        ),
                      ),
                      if (report.engineerComments != null && report.engineerComments!.isNotEmpty)
                        Icon(
                          Icons.comment,
                          size: 14,
                          color: Colors.grey[600],
                        ),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: 12),
              
              // Statistics
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatChip(
                    'Total',
                    report.summary.totalDetections.toString(),
                    Colors.blue,
                  ),
                  _buildStatChip(
                    'Cracks',
                    report.summary.cracksCount.toString(),
                    Colors.red,
                  ),
                  _buildStatChip(
                    'Corrosion',
                    report.summary.corrosionCount.toString(),
                    Colors.orange,
                  ),
                  _buildStatChip(
                    'Deformation',
                    report.summary.deformationCount.toString(),
                    Colors.purple,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}

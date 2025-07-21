import 'package:flutter/material.dart';
import 'package:integriscan/models/report_models.dart';
import 'package:integriscan/services/report_service.dart';
import 'package:integriscan/screens/reports/report_detail_screen.dart';
import 'package:integriscan/providers/auth_provider.dart';
import 'package:provider/provider.dart';

class ReportsListScreen extends StatefulWidget {
  const ReportsListScreen({super.key});

  @override
  State<ReportsListScreen> createState() => _ReportsListScreenState();
}

class _ReportsListScreenState extends State<ReportsListScreen> {
  List<DetectionReport> _reports = [];
  bool _loading = true;
  bool _selectionMode = false;
  Set<String> _selectedReportIds = {};

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.user?.uid ?? 'anonymous';
      final reports = await ReportService.getReports(userId: userId);
      setState(() {
        _reports = reports;
        _loading = false;
      });
    } catch (e) {
      print('Error loading reports: $e');
      setState(() {
        _reports = [];
        _loading = false;
      });
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
        await ReportService.deleteReports(_selectedReportIds.toList());
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${_selectedReportIds.length} report${_selectedReportIds.length > 1 ? 's' : ''} deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
        
        _toggleSelectionMode(); // Exit selection mode
        await _loadReports(); // Refresh the list
      } catch (e) {
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
        await ReportService.deleteReport(report.id);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Report deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
        
        await _loadReports(); // Refresh the list
      } catch (e) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: _selectionMode 
            ? Text('${_selectedReportIds.length} selected')
            : const Text('Inspection Reports'),
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
                  : Icons.select_all),
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
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _reports.isEmpty
              ? _buildEmptyState()
              : _buildReportsList(),
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
        onTap: () {
          if (_selectionMode) {
            _toggleReportSelection(report.id);
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ReportDetailScreen(report: report),
              ),
            );
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
              // Header
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
                        }
                      },
                      itemBuilder: (BuildContext context) => [
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
                  _buildSeverityBadge(report.summary.overallSeverity),
                ],
              ),
              const SizedBox(height: 8),
              
              // Date
              Text(
                'Generated: ${_formatDate(report.createdAt)}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 12),
              
              // Statistics
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildStatChip(
                    'Total Detections',
                    report.summary.totalDetections.toString(),
                    Colors.blue,
                  ),
                  _buildStatChip(
                    'Critical',
                    report.summary.criticalCount.toString(),
                    Colors.red,
                  ),
                  _buildStatChip(
                    'Moderate',
                    report.summary.moderateCount.toString(),
                    Colors.orange,
                  ),
                  _buildStatChip(
                    'Minor',
                    report.summary.minorCount.toString(),
                    Colors.green,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSeverityBadge(String severity) {
    Color color;
    switch (severity.toLowerCase()) {
      case 'critical':
        color = Colors.red;
        break;
      case 'moderate':
        color = Colors.orange;
        break;
      default:
        color = Colors.green;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        severity,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
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

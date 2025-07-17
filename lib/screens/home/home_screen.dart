import 'package:flutter/material.dart';
import 'package:integriscan/constant.dart';
import 'package:integriscan/providers/auth_provider.dart';
import 'package:integriscan/screens/mock_local_users_screen.dart';
import 'package:integriscan/screens/profile/profile_screen.dart';
import 'package:integriscan/screens/rtsp/rtsp_stream_screen.dart';
import 'package:integriscan/screens/reports/reports_list_screen.dart';
import 'package:integriscan/utils/report_test_helper.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final userProfile = authProvider.userProfile;
    
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              // Modern App Bar
              Container(
                width: double.infinity,
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    // Profile Avatar
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [kPrimaryColor, kPrimaryColor.withOpacity(0.7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Welcome Text
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Welcome back,',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w400,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            userProfile != null
                              ? ((userProfile['firstName'] ?? '') + ' ' + (userProfile['lastName'] ?? '')).trim()
                              : user?.displayName ?? user?.email?.split('@').first ?? 'User',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    // Logout Button
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.logout,
                          color: Colors.grey[600],
                          size: 20,
                        ),
                        onPressed: () async {
                          await authProvider.signOut();
                        },
                      ),
                    ),
                  ],
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // View Local Users Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const MockLocalUsersScreen(),
                            ),
                          );
                        },
                        child: const Text('View Local Users'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Generate Sample Report Button (for testing)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          await ReportTestHelper.generateSampleReport();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Sample report generated successfully!'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Generate Sample Report'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Stats Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [kPrimaryColor, kPrimaryColor.withOpacity(0.8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: kPrimaryColor.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.document_scanner,
                                color: Colors.white.withOpacity(0.9),
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'IntegriScan',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Ready to scan and analyze your documents with integrity verification.',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 14,
                              height: 1.4,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Quick Actions Title
                    const Text(
                      'Quick Actions',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 20),                    const SizedBox(height: 20),                    // Action Cards - Responsive Grid
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildModernActionCard(
                                    context,
                                    title: 'Start Scan',
                                    
                                    icon: Icons.document_scanner,
                                    color: Colors.blue,
                                    onTap: () {
                                      _showRtspUrlDialog(context);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildModernActionCard(
                                    context,
                                    title: 'View Reports',
                                    
                                    icon: Icons.assignment,
                                    color: Colors.green,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => const ReportsListScreen(),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildModernActionCard(
                                    context,
                                    title: 'Edit Profile',
                                    icon: Icons.settings,
                                    color: Colors.orange,
                                    onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => const ProfileScreen(),
                                          ),
                                        );
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildModernActionCard(
                                    context,
                                    title: 'Help',
                                    
                                    icon: Icons.help_outline,
                                    color: Colors.purple,
                                    onTap: () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Help functionality coming soon!'),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Recent Activity Section
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
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
                          Row(
                            children: [
                              Icon(
                                Icons.timeline,
                                color: Colors.grey[600],
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Recent Activity',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Colors.grey[400],
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'No recent activity yet',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }  
  
  Future<void> _showRtspUrlDialog(BuildContext context) async {
    final controller = TextEditingController(text: 'rtsp://');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter RTSP URL'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'rtsp://username:password@ip:port/path'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Start'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty && result.startsWith('rtsp://')) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RtspStreamScreen(rtspUrl: result),
        ),
      );
    }
  }

  Widget _buildModernActionCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      constraints: const BoxConstraints(
        minHeight: 100,
        maxHeight: 140,
      ),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 20,
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:integriscan/constant.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Help & Guide',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: kPrimaryColor,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            // Header Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [kPrimaryColor, kPrimaryColor.withOpacity(0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.help_outline_rounded,
                    size: 64,
                    color: Colors.white.withOpacity(0.9),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Welcome to IntegriScan',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your AI-powered visual damage detection assistant',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.9),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Getting Started Section
                  _buildSectionTitle('🚀 Getting Started'),
                  const SizedBox(height: 12),
                  _buildInfoCard(
                    title: 'What is IntegriScan?',
                    description:
                        'IntegriScan is an AI-powered mobile application that detects and analyzes structural damage in real-time using your PTZ camera. It helps you inspect buildings, infrastructure, and equipment efficiently.',
                    icon: Icons.info_outline,
                    color: Colors.blue,
                  ),

                  const SizedBox(height: 24),

                  // Functions Guide
                  _buildSectionTitle('📱 App Functions'),
                  const SizedBox(height: 12),

                  _buildFunctionCard(
                    title: 'Start Scan',
                    icon: Icons.document_scanner,
                    color: Colors.blue,
                    description: 'Connect to your PTZ camera and start analyzing for damage.',
                    steps: [
                      'Tap "Start Scan" from the home screen',
                      'The app will connect to your configured camera',
                      'Wait for the live video feed to appear',
                      'Use manual controls or auto-scan to inspect areas',
                    ],
                  ),

                  _buildFunctionCard(
                    title: 'View Reports',
                    icon: Icons.assignment,
                    color: Colors.green,
                    description: 'Access all your saved inspection reports and analysis history.',
                    steps: [
                      'Tap "View Reports" to see all saved scans',
                      'Each report shows damage type, location, and confidence',
                      'Tap any report to view detailed information',
                      'Export or share reports as needed',
                    ],
                  ),

                  _buildFunctionCard(
                    title: 'Edit Profile',
                    icon: Icons.settings,
                    color: Colors.orange,
                    description: 'Manage your account settings and personal information.',
                    steps: [
                      'Update your name and contact information',
                      'Change your password for security',
                      'Manage notification preferences',
                      'Configure app settings',
                    ],
                  ),

                  _buildFunctionCard(
                    title: 'Flagged Reports',
                    icon: Icons.verified_user,
                    color: Colors.purple,
                    description: 'View reports flagged for verification by administrators.',
                    steps: [
                      'See which reports need your attention',
                      'Verify or dispute flagged detections',
                      'Add notes or additional evidence',
                      'Track verification status',
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Scanning Guide
                  _buildSectionTitle('🎯 How to Scan'),
                  const SizedBox(height: 12),

                  _buildInfoCard(
                    title: 'Manual Control Mode',
                    description:
                        'Use the directional buttons to move the camera (Up, Down, Left, Right). Tap "Analyze" to detect damage in the current view. Results appear with bounding boxes showing detected damage types and confidence levels.',
                    icon: Icons.touch_app,
                    color: Colors.indigo,
                  ),

                  _buildInfoCard(
                    title: 'Auto-Scan Mode',
                    description:
                        'Enable auto-scan for automated inspection. Choose between "Continuous Right" (moves right continuously) or "Up-Down-Right" (systematic 3-direction pattern). The camera automatically moves, stabilizes, analyzes, and displays results.',
                    icon: Icons.auto_mode,
                    color: Colors.teal,
                  ),

                  _buildInfoCard(
                    title: 'Scan Patterns',
                    description:
                        '• Continuous Right: Simple horizontal sweep, 100% coverage\n• Up-Down-Right: Advanced pattern - UP (analyze), DOWN (skip), RIGHT (analyze), repeat. Best for systematic inspection.',
                    icon: Icons.pattern,
                    color: Colors.deepPurple,
                  ),

                  const SizedBox(height: 24),

                  // Understanding Results
                  _buildSectionTitle('📊 Understanding Results'),
                  const SizedBox(height: 12),

                  _buildResultTypeCard(
                    title: 'Crack',
                    color: Colors.red,
                    description: 'Linear fractures in concrete, walls, or surfaces. Requires immediate attention if confidence is high.',
                  ),

                  _buildResultTypeCard(
                    title: 'Corrosion',
                    color: Colors.orange,
                    description: 'Rust or material degradation. Common in metal structures and requires monitoring.',
                  ),

                  _buildResultTypeCard(
                    title: 'Deformation',
                    color: Colors.purple,
                    description: 'Structural warping, bending, or shape distortion. Indicates stress or load issues.',
                  ),

                  _buildResultTypeCard(
                    title: 'No Damage',
                    color: Colors.green,
                    description: 'Area inspected with no damage detected. The structure appears healthy.',
                  ),

                  const SizedBox(height: 24),

                  // Tips & Best Practices
                  _buildSectionTitle('💡 Tips & Best Practices'),
                  const SizedBox(height: 12),

                  _buildTipCard(
                    '1. Ensure Good Lighting',
                    'Detection accuracy improves with proper lighting. Avoid direct sunlight or harsh shadows.',
                    Icons.light_mode,
                  ),

                  _buildTipCard(
                    '2. Stable Connection',
                    'Use a reliable network connection for smooth video streaming and accurate analysis.',
                    Icons.wifi,
                  ),

                  _buildTipCard(
                    '3. Camera Positioning',
                    'Position the camera at appropriate distance - not too close or too far from the inspection area.',
                    Icons.camera_alt,
                  ),

                  _buildTipCard(
                    '4. Use Auto-Scan for Large Areas',
                    'For systematic inspection of large structures, use auto-scan mode with Up-Down-Right pattern.',
                    Icons.auto_awesome,
                  ),

                  _buildTipCard(
                    '5. Save Important Findings',
                    'Always save reports of significant damage for documentation and future reference.',
                    Icons.save,
                  ),

                  _buildTipCard(
                    '6. Verify Detections',
                    'High confidence (>80%) detections are usually accurate. Lower confidence may need manual verification.',
                    Icons.verified,
                  ),

                  const SizedBox(height: 24),

                  // Troubleshooting
                  _buildSectionTitle('🔧 Troubleshooting'),
                  const SizedBox(height: 12),

                  _buildTroubleshootCard(
                    problem: 'Camera Not Connecting',
                    solutions: [
                      'Check your RTSP URL format and credentials',
                      'Ensure camera is powered on and accessible',
                      'Verify network connectivity',
                      'Try restarting the app',
                    ],
                  ),

                  _buildTroubleshootCard(
                    problem: 'Video Feed is Laggy',
                    solutions: [
                      'Check your internet connection speed',
                      'Reduce other network activities',
                      'Move closer to WiFi router',
                      'Lower camera resolution if possible',
                    ],
                  ),

                  _buildTroubleshootCard(
                    problem: 'Analysis Not Working',
                    solutions: [
                      'Ensure camera has stable view (not moving)',
                      'Check if video feed is clear',
                      'Wait for camera to stabilize after movement',
                      'Restart the scan if issue persists',
                    ],
                  ),

                  _buildTroubleshootCard(
                    problem: 'Auto-Scan Stops Unexpectedly',
                    solutions: [
                      'Check camera PTZ support is enabled',
                      'Ensure camera hasn\'t reached movement limits',
                      'Verify stable network connection',
                      'Check if camera controls are responding',
                    ],
                  ),

                  const SizedBox(height: 24),


            

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFunctionCard({
    required String title,
    required IconData icon,
    required Color color,
    required String description,
    required List<String> steps,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
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
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          ...steps.asMap().entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    margin: const EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${entry.key + 1}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildResultTypeCard({
    required String title,
    required Color color,
    required String description,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipCard(String title, String description, IconData icon) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: kPrimaryColor, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTroubleshootCard({
    required String problem,
    required List<String> solutions,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withOpacity(0.3), width: 2),
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
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  problem,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...solutions.map((solution) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• ',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      solution,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}

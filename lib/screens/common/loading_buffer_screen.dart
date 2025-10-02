import 'package:flutter/material.dart';
import 'dart:async';

class LoadingBufferScreen extends StatefulWidget {
  final String title;
  final String message;
  final Future<bool> Function()? onComplete; // Changed to return bool for success/failure
  final Duration? duration;
  final Map<String, dynamic>? navigationData; // Add navigation data

  const LoadingBufferScreen({
    Key? key,
    required this.title,
    required this.message,
    this.onComplete,
    this.duration,
    this.navigationData, // Add navigation data parameter
  }) : super(key: key);

  @override
  _LoadingBufferScreenState createState() => _LoadingBufferScreenState();
}

class _LoadingBufferScreenState extends State<LoadingBufferScreen>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _onCompleteExecuted = false;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500), // Faster animation
      vsync: this,
    );
    
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    
    _controller.repeat(reverse: true);
    
    // Start cleanup immediately if callback provided
    if (widget.onComplete != null) {
      print('🔄 LoadingBufferScreen: Starting onComplete execution');
      Future.microtask(() async {
        if (mounted && !_onCompleteExecuted) {
          _onCompleteExecuted = true;
          try {
            // Execute cleanup and get result
            final success = await widget.onComplete!();
            print('✅ LoadingBufferScreen: onComplete executed with result: $success');
            
            if (success && mounted) {
              // Cleanup was successful, now handle navigation
              await _handleSuccessfulNavigation();
            } else if (mounted) {
              print('❌ LoadingBufferScreen: Cleanup failed, handling as navigation failure');
              _handleNavigationFailure();
            }
          } catch (e) {
            print('❌ LoadingBufferScreen: onComplete failed: $e');
            if (mounted) {
              _handleNavigationFailure();
            }
          }
        }
      });
    }
    
    // Set up timeout fallback (only if navigation truly fails)
    if (widget.duration != null) {
      print('⏰ LoadingBufferScreen: Setting up ${widget.duration!.inSeconds}s timeout fallback');
      _timeoutTimer = Timer(widget.duration!, () {
        print('⏰ LoadingBufferScreen: Timeout reached');
        if (mounted && !_onCompleteExecuted) {
          print('🚨 LoadingBufferScreen: CRITICAL - Timeout reached, onComplete never started');
          _handleNavigationFailure();
        }
        // Remove the case where onComplete finished but we're still here
        // This is normal if navigation is in progress
      });
    }
    
    // CRITICAL: Add absolute maximum timeout as final safety net (increased time)
    Timer(const Duration(seconds: 30), () {
      if (mounted) {
        print('🚨 LoadingBufferScreen: ABSOLUTE TIMEOUT - Force exiting after 30 seconds');
        _handleNavigationFailure();
      }
    });
  }

  Future<void> _handleSuccessfulNavigation() async {
    print('🎯 LoadingBufferScreen: Starting successful navigation');
    
    if (!mounted) {
      print('❌ LoadingBufferScreen: Widget not mounted, cannot navigate');
      return;
    }
    
    // Check if we have navigation data
    if (widget.navigationData == null) {
      print('❌ LoadingBufferScreen: No navigation data provided');
      _handleNavigationFailure();
      return;
    }
    
    try {
      print('🎯 LoadingBufferScreen: Navigation data: ${widget.navigationData}');
      
      // Import the ReportDetailScreen
      final report = widget.navigationData!['report'];
      final fromAnalysis = widget.navigationData!['fromAnalysis'] ?? false;
      
      print('🎯 LoadingBufferScreen: About to navigate to ReportDetailScreen');
      print('🎯 LoadingBufferScreen: Report ID: ${report?.id}');
      print('🎯 LoadingBufferScreen: From Analysis: $fromAnalysis');
      print('🎯 LoadingBufferScreen: Navigator can push replacement: ${Navigator.canPop(context)}');
      
      // Use pushReplacement to replace this loading screen
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) {
            // Import statement will be needed at top of file
            // For now, we'll use dynamic import
            print('🎯 LoadingBufferScreen: MaterialPageRoute builder called');
            return widget.navigationData!['screenWidget'];
          },
        ),
      );
      
      print('✅ LoadingBufferScreen: Navigation completed successfully');
      
    } catch (e, stackTrace) {
      print('❌ LoadingBufferScreen: Navigation failed: $e');
      print('❌ Stack trace: $stackTrace');
      _handleNavigationFailure();
    }
  }

  void _handleNavigationFailure() {
    print('🚨 LoadingBufferScreen: Handling navigation failure');
    if (mounted) {
      // Try to go back to previous screen
      if (Navigator.canPop(context)) {
        print('🔄 LoadingBufferScreen: Navigating back due to failure/timeout');
        Navigator.pop(context);
      } else {
        print('❌ LoadingBufferScreen: Cannot pop, no previous screen');
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Loading failed. Please try again.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _timeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated circular progress indicator
                AnimatedBuilder(
                  animation: _animation,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: 0.8 + (_animation.value * 0.2),
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.blue.withOpacity(0.1),
                          border: Border.all(
                            color: Colors.blue,
                            width: 3,
                          ),
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                
                const SizedBox(height: 32),
                
                // Title
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 16),
                
                // Message with animated dots
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    String dots = '';
                    int dotCount = ((_controller.value * 4).floor() % 4);
                    for (int i = 0; i < dotCount; i++) {
                      dots += '.';
                    }
                    
                    return Text(
                      '${widget.message}$dots',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    );
                  },
                ),
                
                const SizedBox(height: 24),
                
                // Progress steps
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildProgressStep('Cleanup', true),
                    _buildProgressConnector(true),
                    _buildProgressStep('Processing', !_onCompleteExecuted),
                    _buildProgressConnector(_onCompleteExecuted),
                    _buildProgressStep('Ready', _onCompleteExecuted),
                  ],
                ),
                
                const SizedBox(height: 32),
                
                // Info message
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.blue.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue[700],
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Please wait while we prepare your report...',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.blue[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressStep(String label, bool isActive) {
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive ? Colors.blue : Colors.grey[300],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isActive ? Colors.blue : Colors.grey[500],
            fontWeight: isActive ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressConnector(bool isActive) {
    return Container(
      width: 24,
      height: 2,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isActive ? Colors.blue : Colors.grey[300],
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }
}
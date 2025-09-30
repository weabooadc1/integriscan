import 'package:flutter/material.dart';

class LoadingBufferScreen extends StatefulWidget {
  final String title;
  final String message;
  final Future<void> Function()? onComplete;
  final Duration? duration;

  const LoadingBufferScreen({
    Key? key,
    required this.title,
    required this.message,
    this.onComplete,
    this.duration,
  }) : super(key: key);

  @override
  _LoadingBufferScreenState createState() => _LoadingBufferScreenState();
}

class _LoadingBufferScreenState extends State<LoadingBufferScreen>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

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
    
    // Auto-start cleanup immediately if callback provided
    if (widget.onComplete != null) {
      // Start cleanup immediately in background
      Future.microtask(() async {
        if (mounted) {
          await widget.onComplete!();
        }
      });
    }
    
    // Auto-complete after duration if provided (fallback)
    if (widget.duration != null) {
      Future.delayed(widget.duration!, () async {
        if (mounted && widget.onComplete != null) {
          await widget.onComplete!();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
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
                    _buildProgressStep('Processing', true),
                    _buildProgressConnector(false),
                    _buildProgressStep('Ready', false),
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
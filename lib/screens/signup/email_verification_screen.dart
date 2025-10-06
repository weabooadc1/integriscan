import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:integriscan/constant.dart';
import 'package:integriscan/component/primarybutton.dart';
import 'package:integriscan/utils/logger.dart';
import 'package:integriscan/database/database_helper.dart';
import 'package:integriscan/services/firestore_service.dart';
import 'package:integriscan/screens/signup/components/background.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;
  final String firstName;
  final String lastName;
  final String password;

  const EmailVerificationScreen({
    super.key,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.password,
  });

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _isCheckingVerification = false;
  bool _isResending = false;
  bool _canResend = true;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;
  Timer? _autoCheckTimer;
  String _statusMessage = 'Checking verification status...';
  
  @override
  void initState() {
    super.initState();
    _startAutoCheck();
    Logger.info("EmailVerificationScreen: Screen initialized for ${widget.email}");
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _autoCheckTimer?.cancel();
    super.dispose();
  }

  /// Auto-check verification status every 5 seconds
  void _startAutoCheck() {
    _autoCheckTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted && !_isCheckingVerification) {
        _checkEmailVerification(showMessage: false);
      }
    });
  }

  /// Check if email is verified
  Future<void> _checkEmailVerification({bool showMessage = true}) async {
    if (_isCheckingVerification) return;

    setState(() {
      _isCheckingVerification = true;
      _statusMessage = 'Checking verification status...';
    });

    try {
      // Reload user to get latest email verification status
      final user = FirebaseAuth.instance.currentUser;
      
      if (user == null) {
        Logger.error("EmailVerificationScreen: User is null during verification check");
        if (mounted) {
          setState(() {
            _statusMessage = 'Error: User session lost. Please sign up again.';
            _isCheckingVerification = false;
          });
        }
        return;
      }

      await user.reload();
      final updatedUser = FirebaseAuth.instance.currentUser;

      if (updatedUser != null && updatedUser.emailVerified) {
        Logger.info("EmailVerificationScreen: Email verified successfully!");
        
        // Stop auto-checking
        _autoCheckTimer?.cancel();
        
        if (mounted) {
          setState(() {
            _statusMessage = '✅ Email verified! Setting up your account...';
          });
        }

        // Now save to databases after verification
        await _saveUserToDatabase(updatedUser);

        // Navigate to home
        if (mounted) {
          Logger.info("EmailVerificationScreen: Navigating to home screen");
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      } else {
        if (mounted) {
          setState(() {
            _statusMessage = showMessage 
                ? '⏳ Email not verified yet. Please check your inbox.' 
                : 'Waiting for verification...';
            _isCheckingVerification = false;
          });
        }

        if (showMessage) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please verify your email first'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      Logger.error("EmailVerificationScreen: Error checking verification", e);
      if (mounted) {
        setState(() {
          _statusMessage = 'Error checking verification. Please try again.';
          _isCheckingVerification = false;
        });
      }
    }
  }

  /// Save user to SQLite and Firestore after verification
  Future<void> _saveUserToDatabase(User user) async {
    try {
      Logger.info("EmailVerificationScreen: Saving verified user to databases");

      // Save to SQLite (NO PASSWORD - security fix)
      await DatabaseHelper().insertUser({
        'firstName': widget.firstName,
        'lastName': widget.lastName,
        'email': widget.email,
        'firebaseUid': user.uid, // Link to Firebase Auth
        'createdAt': DateTime.now().toIso8601String(),
        // ❌ REMOVED: 'password': widget.password - Never store passwords locally!
      });
      Logger.info("EmailVerificationScreen: User saved to SQLite (without password)");

      // Save to Firestore (already doesn't include password)
      await FirestoreService.saveUser(
        uid: user.uid,
        firstName: widget.firstName,
        lastName: widget.lastName,
        email: widget.email,
      );
      Logger.info("EmailVerificationScreen: User saved to Firestore");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Account created successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      Logger.error("EmailVerificationScreen: Error saving user to database", e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Warning: Account created but data sync failed: $e'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Resend verification email
  Future<void> _resendVerificationEmail() async {
    if (!_canResend || _isResending) return;

    setState(() {
      _isResending = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        throw Exception('User session lost');
      }

      await user.sendEmailVerification();
      Logger.info("EmailVerificationScreen: Verification email resent to ${widget.email}");

      if (mounted) {
        setState(() {
          _isResending = false;
          _canResend = false;
          _resendCooldown = 60; // 60 second cooldown
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📧 Verification email sent! Please check your inbox.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );

        // Start cooldown timer
        _startCooldownTimer();
      }
    } catch (e) {
      Logger.error("EmailVerificationScreen: Error resending verification email", e);
      
      if (mounted) {
        setState(() {
          _isResending = false;
        });

        String errorMessage = 'Failed to resend email';
        if (e.toString().contains('too-many-requests')) {
          errorMessage = 'Too many requests. Please wait before trying again.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ $errorMessage'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Start cooldown timer for resend button
  void _startCooldownTimer() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          if (_resendCooldown > 0) {
            _resendCooldown--;
          } else {
            _canResend = true;
            timer.cancel();
          }
        });
      } else {
        timer.cancel();
      }
    });
  }

  /// Sign out and return to login
  Future<void> _signOutAndReturn() async {
    try {
      await FirebaseAuth.instance.signOut();
      Logger.info("EmailVerificationScreen: User signed out");
      
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      Logger.error("EmailVerificationScreen: Error signing out", e);
    }
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;

    return Scaffold(
      body: SignupBackground(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: size.height,
            ),
            child: IntrinsicHeight(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [

                  const SizedBox(height: 30),
                  
                  // Title
                  Text(
                    'Verify Your Email',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: kPrimaryColor,
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Instructions
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      'We sent a verification email to:',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[700],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 10),
                  
                  // Email display
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: kPrimaryLightColor,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: kPrimaryColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.email,
                            color: kPrimaryColor,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              widget.email,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: kPrimaryColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // Instructions continued
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      'Please check your inbox and click the verification link to continue.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Status message
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_isCheckingVerification)
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(kPrimaryColor),
                              ),
                            ),
                          if (_isCheckingVerification) const SizedBox(width: 10),
                          Flexible(
                            child: Text(
                              _statusMessage,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.blue[900],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // I've Verified Button
                  PrimaryButton(
                    text: _isCheckingVerification ? 'Checking...' : "I've Verified My Email",
                    press: _isCheckingVerification 
                        ? () {} 
                        : () => _checkEmailVerification(showMessage: true),
                    color: kPrimaryColor,
                    textColor: Colors.white,
                  ),
                  
                  const SizedBox(height: 15),
                  
                  // Resend Email Button
                  TextButton.icon(
                    onPressed: _canResend && !_isResending
                        ? _resendVerificationEmail
                        : null,
                    icon: _isResending
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                kPrimaryColor.withOpacity(0.5),
                              ),
                            ),
                          )
                        : Icon(
                            Icons.refresh,
                            color: _canResend ? kPrimaryColor : Colors.grey,
                          ),
                    label: Text(
                      _canResend
                          ? 'Resend Verification Email'
                          : 'Resend in ${_resendCooldown}s',
                      style: TextStyle(
                        color: _canResend ? kPrimaryColor : Colors.grey,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 30),
                  
                  // Divider
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 60),
                    child: Divider(color: Colors.grey[400]),
                  ),
                  
                  const SizedBox(height: 10),
                  
                  // Wrong email? Sign out button
                  TextButton(
                    onPressed: _signOutAndReturn,
                    child: Text(
                      'Wrong email? Sign up again',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Helper text
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      "Didn't receive the email? Check your spam folder or click resend.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

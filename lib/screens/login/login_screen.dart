import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:integriscan/component/already_have_an_acc_check.dart';
import 'package:integriscan/component/primarybutton.dart';
import 'package:integriscan/component/rounded_input_field.dart';
import 'package:integriscan/component/rounded_password_field.dart';
import 'package:integriscan/constant.dart';
import 'package:integriscan/providers/auth_provider.dart' as custom_auth;
import 'package:integriscan/screens/signup/signup_page.dart';
import 'package:integriscan/screens/signup/email_verification_screen.dart';
import 'package:integriscan/utils/logger.dart';
import 'package:integriscan/utils/validation_utils.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: LoginBody(),
    );
  }
}

class LoginBody extends StatefulWidget {
  const LoginBody({super.key});

  @override
  State<LoginBody> createState() => _LoginBodyState();
}

class _LoginBodyState extends State<LoginBody> {
  String _email = '';
  String _password = '';
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    final authProvider = Provider.of<custom_auth.AuthProvider>(context);

    return Container(
      width: double.infinity,
      height: size.height,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Positioned(
            top: 0,
            left: 0,
            child: Image.asset(
              "assets/images/main_top.png",
              width: size.width * 0.35,
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Image.asset(
              "assets/images/login_bottom.png",
              width: size.width * 0.4,
            ),
          ),
          SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                // Back button at the top
                SafeArea(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: IconButton(
                        icon: Icon(Icons.arrow_back, color: kPrimaryColor),
                        onPressed: () {
                          Navigator.pop(context);
                        },
                      ),
                    ),
                  ),
                ),
                
                Text(
                  "LOGIN",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 25,
                    color: kPrimaryColor,
                  ),
                ),
                SizedBox(height: size.height * 0.03),
                SvgPicture.asset(
                  'assets/icons/login.svg',
                  height: size.height * 0.3,
                ),
                SizedBox(height: size.height * 0.03),
                
                // Show error message if any
                if (authProvider.error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      authProvider.error!,
                      style: TextStyle(
                        color: Colors.red[700],
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                SizedBox(height: size.height * 0.02),
                
                RoundedInputField(
                  hint: "Your Email",
                  icon: Icons.email,
                  onChanged: (value) {
                    setState(() {
                      _email = value.trim();
                    });
                  },
                ),
                SizedBox(height: size.height * 0.02),
                RoundedPasswordField(
                  onChanged: (value) {
                    setState(() {
                      _password = value;
                    });
                  },
                ),
                SizedBox(height: size.height * 0.03),
                
                // Forgot password link
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: () {
                        _showForgotPasswordDialog(context);
                      },
                      child: Text(
                        "Forgot Password?",
                        style: TextStyle(
                          color: kPrimaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: size.height * 0.03),
                
                // Login button with loading state
                _isLoading
                    ? CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(kPrimaryColor),
                      )
                    : PrimaryButton(
                        text: 'Login',                        press: () async {
                          // Store context references before async operations
                          final scaffoldMessenger = ScaffoldMessenger.of(context);
                          final navigator = Navigator.of(context);
                          
                          // Validate inputs
                          final emailValidation = ValidationUtils.validateEmail(_email);
                          if (!emailValidation.isValid) {
                            scaffoldMessenger.showSnackBar(
                              SnackBar(
                                content: Text(emailValidation.error!),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          if (_password.isEmpty) {
                            scaffoldMessenger.showSnackBar(
                              const SnackBar(
                                content: Text('Please enter your password'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                          
                          setState(() {
                            _isLoading = true;
                          });
                          
                          try {
                            final success = await authProvider.signInWithEmailAndPassword(
                              email: _email,
                              password: _password,
                            );
                            
                            if (mounted) {
                              setState(() {
                                _isLoading = false;
                              });
                              
                              if (!success) {
                                // Show SnackBar for immediate feedback
                                scaffoldMessenger.showSnackBar(
                                  SnackBar(
                                    content: Text(authProvider.error ?? 'Login failed'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                // The persistent error text will be shown automatically via authProvider.error
                              } else {
                                // Check if email is verified
                                final user = FirebaseAuth.instance.currentUser;
                                
                                if (user != null && !user.emailVerified) {
                                  Logger.info('Login successful but email not verified, redirecting to verification screen');
                                  
                                  // Navigate to email verification screen
                                  navigator.pushReplacement(
                                    MaterialPageRoute(
                                      builder: (context) => EmailVerificationScreen(
                                        email: _email,
                                        firstName: '', // We don't have these from login
                                        lastName: '',
                                        password: _password,
                                      ),
                                    ),
                                  );
                                } else {
                                  // If email is verified, navigate to root where the auth state can be detected
                                  Logger.info('Login successful and email verified, navigating to root');
                                  navigator.popUntil((route) => route.isFirst);
                                }
                              }
                            }
                          } catch (e) {
                            Logger.error('Login error', e);
                            if (mounted) {
                              setState(() {
                                _isLoading = false;
                              });
                              scaffoldMessenger.showSnackBar(
                                SnackBar(
                                  content: Text('Login failed: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                      ),
                SizedBox(height: size.height * 0.03),
                AlreadyHaveAnAccountCheck(
                  press: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) {
                          return const SignupPage();
                        },
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // Show enhanced dialog for password reset
  void _showForgotPasswordDialog(BuildContext context) {
    final TextEditingController emailController = TextEditingController();
    bool isLoading = false;
    String? errorMessage;
    bool emailSent = false;
    
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Icon(Icons.lock_reset, color: kPrimaryColor),
                  SizedBox(width: 8),
                  Text(
                    emailSent ? "Email Sent!" : "Reset Password",
                    style: TextStyle(
                      color: kPrimaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
              content: emailSent
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 64,
                        ),
                        SizedBox(height: 16),
                        Text(
                          "Password reset email has been sent to:",
                          style: TextStyle(fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 8),
                        Text(
                          emailController.text.trim(),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: kPrimaryColor,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: 16),
                        Text(
                          "Please check your inbox and follow the instructions to reset your password.",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Enter your email address and we'll send you a link to reset your password.",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                        SizedBox(height: 20),
                        TextField(
                          controller: emailController,
                          enabled: !isLoading,
                          decoration: InputDecoration(
                            hintText: "Email address",
                            prefixIcon: Icon(Icons.email, color: kPrimaryColor),
                            errorText: errorMessage,
                            errorMaxLines: 2,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: kPrimaryColor),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: kPrimaryColor, width: 2),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.red),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.red, width: 2),
                            ),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          onChanged: (value) {
                            if (errorMessage != null) {
                              setDialogState(() {
                                errorMessage = null;
                              });
                            }
                          },
                        ),
                        if (isLoading) ...[
                          SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(kPrimaryColor),
                                ),
                              ),
                              SizedBox(width: 12),
                              Text(
                                "Sending email...",
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
              actions: emailSent
                  ? [
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        child: Text(
                          "OK",
                          style: TextStyle(
                            color: kPrimaryLightColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ]
                  : [
                      TextButton(
                        onPressed: isLoading
                            ? null
                            : () {
                                Navigator.pop(dialogContext);
                              },
                        child: Text(
                          "Cancel",
                          style: TextStyle(
                            color: isLoading ? Colors.grey : kPrimaryColor,
                          ),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: isLoading
                            ? null
                            : () async {
                                final email = emailController.text.trim();
                                
                                // Validate email
                                if (email.isEmpty) {
                                  setDialogState(() {
                                    errorMessage = 'Please enter your email address';
                                  });
                                  return;
                                }
                                
                                if (!email.contains('@') || !email.contains('.')) {
                                  setDialogState(() {
                                    errorMessage = 'Please enter a valid email address';
                                  });
                                  return;
                                }
                                
                                setDialogState(() {
                                  isLoading = true;
                                  errorMessage = null;
                                });
                                
                                final authProvider = Provider.of<custom_auth.AuthProvider>(context, listen: false);
                                try {
                                  final success = await authProvider.sendPasswordResetEmail(email);
                                  
                                  setDialogState(() {
                                    isLoading = false;
                                  });
                                  
                                  if (success) {
                                    setDialogState(() {
                                      emailSent = true;
                                    });
                                  } else {
                                    setDialogState(() {
                                      errorMessage = authProvider.error ?? 'Failed to send reset email';
                                    });
                                  }
                                } catch (e) {
                                  setDialogState(() {
                                    isLoading = false;
                                    errorMessage = 'An unexpected error occurred';
                                  });
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isLoading ? Colors.grey : kPrimaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        child: Text(
                          "Send Reset Link",
                          style: TextStyle(
                            color: kPrimaryLightColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
            );
          },
        );
      },
    );
  }
}
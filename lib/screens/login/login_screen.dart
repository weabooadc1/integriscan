import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:integriscan/component/already_have_an_acc_check.dart';
import 'package:integriscan/component/primarybutton.dart';
import 'package:integriscan/component/rounded_input_field.dart';
import 'package:integriscan/component/rounded_password_field.dart';
import 'package:integriscan/constant.dart';
import 'package:integriscan/providers/auth_provider.dart';
import 'package:integriscan/screens/signup/signup_page.dart';
import 'package:integriscan/utils/logger.dart';
import 'package:integriscan/utils/validation_utils.dart';
import 'package:provider/provider.dart';

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
    final authProvider = Provider.of<AuthProvider>(context);

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
                          // Validate inputs
                          final emailValidation = ValidationUtils.validateEmail(_email);
                          if (!emailValidation.isValid) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(emailValidation.error!),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          if (_password.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
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
                            
                            if (!success && mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(authProvider.error ?? 'Login failed'),
                                  backgroundColor: Colors.red,
                                ),
                              );                            } else if (success && mounted) {
                              // If login successful, navigate to root where the auth state can be detected
                              Logger.info('Login successful, navigating to root');
                              Navigator.of(context).popUntil((route) => route.isFirst);
                            }
                          } finally {
                            if (mounted) {
                              setState(() {
                                _isLoading = false;
                              });
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
  
  // Show dialog for password reset
  void _showForgotPasswordDialog(BuildContext context) {
    final TextEditingController emailController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(
            "Reset Password",
            style: TextStyle(
              color: kPrimaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Enter your email address to receive a password reset link.",
                style: TextStyle(fontSize: 14),
              ),
              SizedBox(height: 16),
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  hintText: "Email address",
                  prefixIcon: Icon(Icons.email, color: kPrimaryColor),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(29),
                    borderSide: BorderSide(color: kPrimaryColor),
                  ),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: Text(
                "Cancel",
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (emailController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter your email address'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                
                Navigator.pop(dialogContext);
                
                final authProvider = Provider.of<AuthProvider>(context, listen: false);
                try {
                  final success = await authProvider.sendPasswordResetEmail(
                    emailController.text.trim(),
                  );
                  
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Password reset email sent. Check your inbox.'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(authProvider.error ?? 'Failed to send reset email'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimaryColor,
              ),
              child: Text("Send Reset Link"),
            ),
          ],
        );
      },
    );
  }
}
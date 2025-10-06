import 'package:flutter/material.dart';
import 'package:integriscan/component/primarybutton.dart';
import 'package:integriscan/constant.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:integriscan/component/rounded_input_field.dart';
import 'package:integriscan/component/rounded_password_field.dart';
import 'package:integriscan/component/already_have_an_acc_check.dart';
import 'package:integriscan/providers/auth_provider.dart' as custom_auth;
import 'package:integriscan/screens/login/login_screen.dart';
import 'package:integriscan/screens/signup/components/background.dart';
import 'package:integriscan/screens/signup/email_verification_screen.dart';
import 'package:integriscan/utils/logger.dart';
import 'package:integriscan/utils/validation_utils.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  String firstName = '';
  String lastName = '';
  String email = '';
  String password = '';
  String confirmPassword = '';
  String errorMessage = '';
  bool obscure = true;
  bool _isLoading = false;

  bool get passwordsMatch => password == confirmPassword;

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    final authProvider = Provider.of<custom_auth.AuthProvider>(context);
    
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SignupBackground(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: size.height,
            ),
            child: IntrinsicHeight(
              child: Column(
                children: <Widget>[
                  SafeArea(
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: IconButton(
                          icon: Icon(Icons.arrow_back, color: kPrimaryColor),
                          onPressed: () {
                            Navigator.pop(context);
                          },                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Text(
                          "SIGNUP",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 25,
                            color: kPrimaryColor,
                          ),
                        ),
                        SizedBox(height: size.height * 0.03),                        SvgPicture.asset(
                          'assets/icons/signup.svg',
                          height: size.height * 0.25,
                        ),
                        SizedBox(height: size.height * 0.01),
                        // First Name Field
                        RoundedInputField(
                          hint: "First Name",
                          icon: Icons.person,
                          onChanged: (value) {
                            setState(() {
                              firstName = value.trim();
                            });
                          },
                        ),
                        SizedBox(height: size.height * 0.01),
                        // Last Name Field
                        RoundedInputField(
                          hint: "Last Name",
                          icon: Icons.person,
                          onChanged: (value) {
                            setState(() {
                              lastName = value.trim();
                            });
                          },
                        ),
                        SizedBox(height: size.height * 0.01),
                        // Email Field
                        RoundedInputField(
                          hint: "Enter Your Email",
                          icon: Icons.email,
                          onChanged: (value) {
                            setState(() {
                              email = value.trim();
                            });
                          },
                        ),
                        SizedBox(height: size.height * 0.01),
                        // Error message
                        if (errorMessage.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Text(
                              errorMessage,
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        // Show Firebase auth error if any
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
                        RoundedPasswordField(
                          onChanged: (value) {
                            setState(() {
                              password = value;
                              _validatePasswords();
                            });
                          },
                        ),
                        SizedBox(height: size.height * 0.01),
                        // Confirm Password Field
                        ConfirmPassword(size),
                        _isLoading
                          ? CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(kPrimaryColor),
                            )
                          : PrimaryButton(
                              text: 'Sign Up',
                              press: _handleSignup,
                            ),                        SizedBox(height: size.height * 0.01),
                        AlreadyHaveAnAccountCheck(
                          login: false,
                          press:(){
                            Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) {
                                return LoginScreen();
                              },
                            ),
                          );
                          }),

                        SizedBox(height: 20),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ignore: non_constant_identifier_names
  Container ConfirmPassword(Size size) {
    return Container(
                        margin: EdgeInsets.symmetric(vertical: 10),
                        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                        width: size.width * 0.8,
                        decoration: BoxDecoration(
                          color: kPrimaryLightColor,
                          borderRadius: BorderRadius.circular(29),
                          border: Border.all(
                            color: confirmPassword.isNotEmpty && !passwordsMatch
                                ? Colors.red
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: TextFormField(
                          obscureText: obscure,
                          onChanged: (value) {
                            setState(() {
                              confirmPassword = value;
                              _validatePasswords();
                            });
                          },
                          cursorColor: kPrimaryColor,
                          decoration: InputDecoration(
                            icon: Icon(
                              Icons.lock,
                              color: kPrimaryColor,
                            ),
                            suffixIcon: IconButton(
                              icon: Icon(
                                obscure ? Icons.visibility : Icons.visibility_off,
                                color: kPrimaryColor,
                              ),
                              onPressed: () {
                                setState(() {
                                  obscure = !obscure;
                                });
                              },
                            ),
                            hintText: "Confirm Password",
                            hintStyle: TextStyle(color: Colors.grey),
                            border: InputBorder.none,
                          ),
                        ),
                      );
  }

  void _validatePasswords() {
    if (confirmPassword.isNotEmpty && !passwordsMatch) {
      errorMessage = "Passwords do not match";
    } else {
      errorMessage = "";
    }
  }  Future<void> _handleSignup() async {
    // First Name validation
    final firstNameValidation = ValidationUtils.validateName(firstName, "First name");
    if (!firstNameValidation.isValid) {
      setState(() {
        errorMessage = firstNameValidation.error!;
      });
      return;
    }
    
    // Last Name validation
    final lastNameValidation = ValidationUtils.validateName(lastName, "Last name");
    if (!lastNameValidation.isValid) {
      setState(() {
        errorMessage = lastNameValidation.error!;
      });
      return;
    }
    
    // Email validation
    final emailValidation = ValidationUtils.validateEmail(email);
    if (!emailValidation.isValid) {
      setState(() {
        errorMessage = emailValidation.error!;
      });
      return;
    }
    
    // Password validation
    final passwordValidation = ValidationUtils.validatePassword(password);
    if (!passwordValidation.isValid) {
      setState(() {
        errorMessage = passwordValidation.error!;
      });
      return;
    }

    // Confirm password validation
    final passwordMatchValidation = ValidationUtils.validatePasswordMatch(password, confirmPassword);
    if (!passwordMatchValidation.isValid) {
      setState(() {
        errorMessage = passwordMatchValidation.error!;
      });
      return;
    }

    setState(() {
      errorMessage = "";
      _isLoading = true;
    });

    try {
      // Get the AuthProvider and store context references
      final authProvider = Provider.of<custom_auth.AuthProvider>(context, listen: false);
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);

      // Attempt to register with Firebase
      Logger.secureLog("Component body: Attempting to register with email", email);
      final success = await authProvider.registerWithEmailAndPassword(
        email: email,
        password: password,
        firstName: firstName,
        lastName: lastName,
      );
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        if (success) {
          // Get current user
          final user = FirebaseAuth.instance.currentUser;
          
          if (user != null && !user.emailVerified) {
            // Send email verification
            try {
              Logger.info("Component body: Sending verification email to $email");
              await user.sendEmailVerification();
              
              Logger.info("Component body: Verification email sent successfully");
              
              // Navigate to email verification screen
              // DON'T save to SQLite or Firestore yet - wait for verification
              navigator.pushReplacement(
                MaterialPageRoute(
                  builder: (context) => EmailVerificationScreen(
                    email: email,
                    firstName: firstName,
                    lastName: lastName,
                    password: password,
                  ),
                ),
              );
            } catch (e) {
              Logger.error("Component body: Failed to send verification email", e);
              
              // If email sending fails, still navigate to verification screen
              // User can resend from there
              scaffoldMessenger.showSnackBar(
                SnackBar(
                  content: Text('Account created. Please check your email to verify.'),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 3),
                ),
              );
              
              navigator.pushReplacement(
                MaterialPageRoute(
                  builder: (context) => EmailVerificationScreen(
                    email: email,
                    firstName: firstName,
                    lastName: lastName,
                    password: password,
                  ),
                ),
              );
            }
          } else {
            // User is null or already verified (shouldn't happen in normal flow)
            Logger.error("Component body: User is null or already verified during signup", "Unexpected state");
            setState(() {
              errorMessage = "An unexpected error occurred. Please try again.";
            });
          }
        } else {
          // Show error from provider
          Logger.error("Component body: Registration failed with error", authProvider.error);
          setState(() {
            errorMessage = authProvider.error ?? "Registration failed";
          });
        }
      }
    } catch (e) {
      Logger.error("Component body: Error during signup", e);
      if (mounted) {
        setState(() {
          _isLoading = false;
          errorMessage = "An error occurred during registration: $e";
        });
      }
    }
  }
}

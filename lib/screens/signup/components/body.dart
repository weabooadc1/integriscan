import 'package:flutter/material.dart';
import 'package:integriscan/component/primarybutton.dart';
import 'package:integriscan/constant.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:integriscan/component/rounded_input_field.dart';
import 'package:integriscan/component/rounded_password_field.dart';
import 'package:integriscan/component/already_have_an_acc_check.dart';
import 'package:integriscan/screens/login/components/body.dart';
import 'package:integriscan/screens/signup/components/background.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  String password = '';
  String confirmPassword = '';
  String errorMessage = '';
  bool obscure = true;

  bool get passwordsMatch => password == confirmPassword;

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
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
                          },
                        ),
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
                        SizedBox(height: size.height * 0.03),
                        SvgPicture.asset(
                          'assets/icons/signup.svg',
                          height: size.height * 0.25,
                        ),
                        SizedBox(height: size.height * 0.01),
                        RoundedInputField(
                          hint: "Enter Your Email",
                          onChanged: (value) {},
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
                        PrimaryButton(
                          text: 'Sign Up',
                          press: _handleSignup,
                        ),
                        SizedBox(height: size.height * 0.01),
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
  }

  void _handleSignup() {
    if (password.isEmpty || confirmPassword.isEmpty) {
      setState(() {
        errorMessage = "Please fill in both password fields";
      });
      return;
    }

    if (!passwordsMatch) {
      setState(() {
        errorMessage = "Passwords do not match";
      });
      return;
    }

    setState(() {
      errorMessage = "";
    });
    // Proceed with signup logic
  }
}

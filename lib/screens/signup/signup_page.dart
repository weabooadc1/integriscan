import 'package:flutter/material.dart';
import 'package:integriscan/screens/signup/components/body.dart';


class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SignupScreen(),
    );
  }
}
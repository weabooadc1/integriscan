import 'package:flutter/material.dart';
import 'package:integriscan/screens/welcome/welcome_screen.dart';
import 'package:integriscan/constant.dart';

void main() {
  runApp(const IndexPage());
}

class IndexPage extends StatelessWidget {
  const IndexPage({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'IntegriScan',
      theme: ThemeData(
        primaryColor: kPrimaryColor,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: WelcomeScreen(),
    );
  }
}
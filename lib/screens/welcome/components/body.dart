import 'package:flutter/material.dart';
import 'package:integriscan/constant.dart';
import 'package:integriscan/screens/signup/components/body.dart';

import 'package:integriscan/screens/welcome/components/background.dart';
import 'package:flutter_svg/svg.dart';
import 'package:integriscan/component/primarybutton.dart';
import 'package:integriscan/component/lightbutton.dart';
import 'package:integriscan/screens/login/components/body.dart';

class Body extends StatelessWidget {
  const Body({super.key});

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    // ignore: sized_box_for_whitespace
    return Background(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'Welcome to IntegriScan',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: kPrimaryColor,
              ),
            ),
            SizedBox(height: size.height * 0.02),
            SvgPicture.asset(
              'assets/icons/chat.svg',
              height: size.height * 0.4,
            ),
            SizedBox(height: size.height * 0.02),

            //Login Button
            PrimaryButton(
                text: "Login",
                press: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                  builder: (context) {
                    return LoginScreen();
                  },
                  ),
                );
                },
            ),
            SizedBox(height: size.height * 0.02),

            // Sign Up button 
            LightButton(
              text: "SignUp",
              press: () {

                Navigator.push(
                  context,
                  MaterialPageRoute(
                  builder: (context) {
                    return SignupScreen();
                  },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

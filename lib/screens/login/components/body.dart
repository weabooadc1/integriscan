import 'package:flutter/material.dart';
import 'package:integriscan/component/primarybutton.dart';
import 'package:integriscan/constant.dart';
import 'package:integriscan/screens/login/components/background.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:integriscan/component/rounded_input_field.dart';
import 'package:integriscan/component/rounded_password_field.dart';
import 'package:integriscan/component/already_have_an_acc_check.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return Scaffold(
      body: LoginBackground(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
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
            RoundedInputField(
              hint: "Your Email",
              icon: Icons.person,
              onChanged: (value) {},
            ),
            SizedBox(height: size.height * 0.03),
            RoundedPasswordField(
              onChanged: (value) {},
            ),
            SizedBox(height: size.height * 0.03),
            PrimaryButton(
              text: 'Login',
              press: () {},
            ),
            SizedBox(height: size.height * 0.03),

            AlreadyHaveAnAccountCheck(
              press: (){},
            ),
          ],
        ),
      ),
    );
  }
}

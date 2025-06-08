import 'package:flutter/material.dart';
import 'package:integriscan/constant.dart';

class AlreadyHaveAnAccountCheck extends StatelessWidget {
  final bool login;
  final VoidCallback press;
  const AlreadyHaveAnAccountCheck({
    this.login = true,
    required this.press,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Text(
         login ? "Don't have an account? " : "Already have an Account? ",
          style: TextStyle(
            color: kPrimaryColor,
          ),
        ),
        GestureDetector(
          onTap: press,
          child: Text(
            login ? "Sign Up" : "Sign In",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: kPrimaryColor
            ),
          ),
        )
      ],
    );
  }
}

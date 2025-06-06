import 'package:flutter/material.dart';
import 'package:integriscan/constant.dart';

class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback press;
  final Color color, textColor;

  const PrimaryButton({
    required this.text,
    required this.press,
    this.color = kPrimaryColor,
    this.textColor = kPrimaryLightColor,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return SizedBox(
      width: size.width * 0.8 ,
      child: TextButton(
        onPressed: press,
        style: TextButton.styleFrom(
          padding: EdgeInsets.symmetric(vertical: 20, horizontal: 40),
          backgroundColor: color,
        ),
        child: Text(
          text,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: textColor,
          ),)),
    );
  }
}

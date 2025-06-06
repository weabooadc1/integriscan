import 'package:flutter/material.dart';
import 'package:integriscan/constant.dart';
import 'package:integriscan/component/text_field_container.dart';

class RoundedPasswordField extends StatefulWidget {
  final ValueChanged<String> onChanged;

  const RoundedPasswordField({
    required this.onChanged,
    super.key,
  });

  @override
  State<RoundedPasswordField> createState() => _RoundedPasswordFieldState();
}

class _RoundedPasswordFieldState extends State<RoundedPasswordField> {
  bool obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextFieldContainer(
      child: TextField(
        onChanged: widget.onChanged,
        obscureText: obscure,
        decoration: InputDecoration(
          hintText: "Your Password",
          hintStyle: TextStyle(
            color: Colors.grey,
          ),
          icon: Icon(Icons.lock, color: kPrimaryColor),
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
          border: InputBorder.none,
        ),
      ),
    );
  }
}
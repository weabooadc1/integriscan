import 'package:flutter/material.dart';
import 'package:integriscan/constant.dart';
import 'package:integriscan/component/text_field_container.dart';


class RoundedInputField extends StatelessWidget {
  final String hint;
  final IconData icon;
  final ValueChanged<String> onChanged;
  const RoundedInputField({
    required this.hint,
    this.icon = Icons.person,
    required this.onChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return TextFieldContainer(
      child: TextField(
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          border: InputBorder.none,
          hintStyle: TextStyle(
            color: Colors.grey,
          ),
          icon: Icon(
            icon,
            color: kPrimaryColor,
          ),
        ),
      ),
    );
  }
}
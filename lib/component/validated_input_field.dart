import 'package:flutter/material.dart';
import 'package:integriscan/constant.dart';
import 'package:integriscan/component/text_field_container.dart';
import 'package:integriscan/models/auth_models.dart';

class ValidatedInputField extends StatelessWidget {
  final String hint;
  final IconData icon;
  final ValueChanged<String> onChanged;
  final ValidationResult? validation;
  final TextInputType keyboardType;
  final bool obscureText;

  const ValidatedInputField({
    required this.hint,
    this.icon = Icons.person,
    required this.onChanged,
    this.validation,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final hasError = validation != null && !validation!.isValid;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFieldContainer(
          child: TextField(
            onChanged: onChanged,
            keyboardType: keyboardType,
            obscureText: obscureText,
            decoration: InputDecoration(
              hintText: hint,
              border: InputBorder.none,
              hintStyle: TextStyle(
                color: Colors.grey,
              ),
              icon: Icon(
                icon,
                color: hasError ? Colors.red : kPrimaryColor,
              ),
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(left: 20, top: 5),
            child: Text(
              validation!.error!,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }
}

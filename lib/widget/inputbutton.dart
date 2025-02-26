import 'package:flutter/material.dart';

Widget inputbutton({
  required String hintText,
  bool obscureText = false,
  Widget? suffixIcon,
  TextEditingController? controller,
  String? Function(String?)? validator,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: TextFormField(
      controller: controller,
      obscureText: obscureText,
      validator: validator,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(
          fontSize: 12,
          fontStyle: FontStyle.normal,
          color: Color(0xff8B8B8B),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            width: 2,
            color: Color(0xff8B8B8B),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            width: 2,
            color: Colors.blue,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: Colors.red,
            width: 2,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: Colors.red,
            width: 2,
          ),
        ),
        suffixIcon: suffixIcon,
      ),
    ),
  );
}

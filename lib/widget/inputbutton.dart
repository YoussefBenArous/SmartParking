import 'package:flutter/material.dart';

class inputbutton extends StatelessWidget {
  final String hintText;
  final bool? obscureText;
  final Widget? suffixIcon;
  const inputbutton({super.key, required this.hintText, this.suffixIcon, this.obscureText});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 375,
      height: 55,
      child: TextFormField(
        obscureText: obscureText ?? false,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(
            fontSize: 12,
            fontStyle: FontStyle.normal,
            color: Color(
              0xff8B8B8B,
            ),
          ),
          enabledBorder: const OutlineInputBorder(
            
            borderRadius: BorderRadius.all(
              Radius.circular(10),
            ),
            borderSide: BorderSide(
              width: 2,
              color: Color(0xff8B8B8B),
            ),
          ),
          focusedBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(10),
            ),
          ),
          errorBorder: const OutlineInputBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(10),
            ),  
            borderSide: BorderSide(
              color: Colors.red,
              width: 3,
            ),
            
          ),
          
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }
}

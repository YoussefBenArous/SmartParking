import 'package:flutter/material.dart';

class CustomTitle extends StatelessWidget {
  final String text;
  final Color color;
  final double size;
  const CustomTitle({super.key, required this.text, required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Title(
        color: color,
        child: Text(
          text,
          style: TextStyle(
            fontStyle: FontStyle.normal,
            fontSize: size,
            color: color,
          ),
        ),
      ),
    );
  }
}

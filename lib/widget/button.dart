import 'package:flutter/material.dart';

class button extends StatelessWidget {
  final VoidCallback onPressed;
  final String text;
  final double fontsize;
  final double width;
  final double height;
  final double radius;
  const button({super.key, required this.onPressed, required this.text, required this.fontsize, required this.width, required this.height, required this.radius});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      child: Text(
        text,
        style: TextStyle(
            color: Colors.white,
            fontStyle: FontStyle.normal,
            fontSize: fontsize),
      ),
      style: ButtonStyle(
        backgroundColor: MaterialStatePropertyAll(
          Color(0xff0079C0),
        ),
        minimumSize: MaterialStatePropertyAll(
          Size(width, height),
        ),
        shape: MaterialStateProperty.all(
          ContinuousRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      ),
    );
  }
}

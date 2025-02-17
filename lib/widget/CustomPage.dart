import 'package:flutter/cupertino.dart';

class CustomPage extends StatelessWidget {
  final String imagepath;
  final String title;
  final String? text;
  final double height;
  final double width;
  final double left;
  final double right;
  final double top;
  final double fontsize ;

  const CustomPage(
      {super.key,
      required this.imagepath,
      required this.title,
      this.text,
      required this.height,
      required this.width,
      required this.left,
      required this.right,
      required this.top, required this.fontsize});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Color(0XFFFFFFFF),
      child: Padding(
        padding: EdgeInsets.only(
          left: left,
          right: right,
          top: top,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Image.asset(
              imagepath,
              height: height,
              width: width,
            ),
            SizedBox(
              height: 20,
            ),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontStyle: FontStyle.normal,
                fontSize: fontsize,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(
              height: 5,
            ),
            if (text != null)
              Text(
                text!,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Color(0XFF8B8B8B),
                    fontSize: 12,
                    fontStyle: FontStyle.normal),
              ),
          ],
        ),
      ),
    );
  }
}

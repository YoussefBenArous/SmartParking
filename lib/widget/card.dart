import 'package:flutter/material.dart';

class BuildStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData? icon;
  final String? image;
  final Color? color;
  final double? imageheight;
  final double? imagewidth;
  final ButtonConfig? buttonConfig;

  const BuildStatCard({
    Key? key,
    required this.title,
    required this.value,
    this.icon,
    this.image,
    this.color,
    this.imageheight,
    this.imagewidth,
    this.buttonConfig,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shadowColor: Colors.black26,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null)
              Icon(
                icon!,
                size: 28,
                color: color ?? Theme.of(context).primaryColor,
              ),
            if (image != null)
              SizedBox(
                height: 28,
                child: Image.asset(
                  image!,
                  color: color,
                  fit: BoxFit.contain,
                  height: imageheight,
                  width: imagewidth,
                ),
              ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color ?? Theme.of(context).primaryColor,
                ),
              ),
            ),
            if (buttonConfig != null) ...[
              const SizedBox(height: 12),
              Center(
                child: ElevatedButton(
                  onPressed: buttonConfig!.onPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff0079C0),
                    minimumSize: Size(
                      buttonConfig!.width ?? 120,
                      buttonConfig!.height ?? 40,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        buttonConfig!.radius ?? 8,
                      ),
                    ),
                  ),
                  child: Text(
                    buttonConfig!.text,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: buttonConfig!.fontSize ?? 14,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ButtonConfig {
  final String text;
  final VoidCallback onPressed;
  final double? width;
  final double? height;
  final double? fontSize;
  final double? radius;

  ButtonConfig({
    required this.text,
    required this.onPressed,
    this.width,
    this.height,
    this.fontSize,
    this.radius,
  });
}

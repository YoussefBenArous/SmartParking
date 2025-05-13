import 'package:flutter/material.dart';

class BuildStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData? icon;
  final String? image;
  final Color? color;
  final double? imageheight ;
  final double? imagewidth ;

  const BuildStatCard({
    Key? key,
    required this.title,
    required this.value,
    this.icon,
    this.image,
    this.color, this.imageheight, this.imagewidth,
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
          ],
        ),
      ),
    );
  }
}

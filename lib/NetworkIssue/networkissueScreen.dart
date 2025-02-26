import 'package:flutter/material.dart';

class NoNetworkScreen extends StatelessWidget {
  const NoNetworkScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.signal_wifi_off,
              size: 80,
              color: Colors.red,
            ),
            SizedBox(height: 20),
            Text(
              'No Internet Connection',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Please check your network settings and try again.',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                // Retry logic
              },
              child: Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:smart_parking/Login_and_SignUp/LoginPage.dart';
import 'package:smart_parking/NetworkIssue/networkissueScreen.dart';
import 'package:smart_parking/WelcomePage/FirstPage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Check internet connectivity
  var connectivityResult = await Connectivity().checkConnectivity();
  if (connectivityResult == ConnectivityResult.none) {
    debugPrint("No internet connection. Firebase initialization skipped.");
    runApp(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const NoNetworkScreen(),),);
  } else {
    // Initialize Firebase
    if (kIsWeb) {
      await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: "AIzaSyDQXeWa2oNzh6WX17w7cdHT7pkmUizwJVc",
          authDomain: "smartparking-4025c.firebaseapp.com",
          projectId: "smartparking-4025c",
          storageBucket: "smartparking-4025c.firebasestorage.app",
          messagingSenderId: "786760277384",
          appId: "1:786760277384:web:891d912f6aed4dd3952e3d",
          measurementId: "G-SBERQ6WY93",
        ),
      );
    } else {
      await Firebase.initializeApp();
    }
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: "Smart Parking",
      debugShowCheckedModeBanner: false,
      
      home: FirstPage(),
    );
  }
}
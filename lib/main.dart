import 'package:flutter/material.dart';
import 'package:smart_parking/PayScreen/PayScreen.dart';
import 'package:smart_parking/WelcomePage/FirstPage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (kIsWeb) {
    
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: "AIzaSyDQXeWa2oNzh6WX17w7cdHT7pkmUizwJVc",
          authDomain: "smartparking-4025c.firebaseapp.com",
          databaseURL: "https://smartparking-4025c-default-rtdb.europe-west1.firebasedatabase.app",
          projectId: "smartparking-4025c",
          storageBucket: "smartparking-4025c.appspot.com",
          messagingSenderId: "786760277384",
          appId: "1:786760277384:web:891d912f6aed4dd3952e3d",
          measurementId: "G-SBERQ6WY93",
        ),
    );
  } else {
    await Firebase.initializeApp();
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
      
      home: PayScreen(),
    );
  }
}
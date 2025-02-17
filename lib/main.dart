import 'package:flutter/material.dart';
import 'package:smart_parking/HomePage/Home.dart';
import 'package:smart_parking/Login_and_SignUp/LoginPage.dart';


void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      
      debugShowCheckedModeBanner: false,
      home: HomePage(), 
    );
  }
}

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:smart_parking/Login_and_SignUp/LoginPage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_parking/WelcomePage/FirstPage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with proper error handling
  try {
    if (kIsWeb) {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
        apiKey: "Your API Key",
          authDomain: "Your Auth Domain",
          databaseURL: "Your databaseURL",
          projectId: "Your Project ID",
          storageBucket: "Your Storage Bucket",
          messagingSenderId: "Your Messaging Sender ID",
          appId: "Your App ID"
        ),
      );
    } else {
      await Firebase.initializeApp();
    }

    // Configure Firestore settings
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );

    // Initialize Stripe
    if (!kIsWeb) {
      Stripe.publishableKey = 'pk_test_51RUs4GPxnbPP7UD9AWWMDEOUZLj803GLYVjZ1eqTxCQvZDi3EMIuJfNVVvihlM3UO0zCSA6NNrNlXsCna2LVU3qJ00HrS77hUM';
      await Stripe.instance.applySettings();
    }

    // Set up auth state persistence
    await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);

  } catch (e) {
    print('Error initializing Firebase: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Smart Parking",
      debugShowCheckedModeBanner: false,
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          return const FirstPage();
        },
      ),
    );
  }
}
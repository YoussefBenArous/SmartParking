import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class FirebaseService {
  static final FirebaseDatabase rtdb = FirebaseDatabase.instance;
  static final FirebaseFirestore firestore = FirebaseFirestore.instance;

  static Future<void> initializeFirebase() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Check internet connectivity
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      throw Exception("No internet connection available");
    }

    // Initialize Firebase with correct options
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

    // Configure Realtime Database persistence
    rtdb.setPersistenceEnabled(true);
    
    // Configure Firestore settings
    firestore.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  }

  // Helper method to check connection status
  static Future<bool> checkConnection() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }
}
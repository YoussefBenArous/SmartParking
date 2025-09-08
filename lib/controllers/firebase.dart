import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseService {
  static final FirebaseDatabase rtdb = FirebaseDatabase.instance;
  static final FirebaseFirestore firestore = FirebaseFirestore.instance;

  static Future<void> initializeFirebase() async {
    try {
      WidgetsFlutterBinding.ensureInitialized();

      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: "AIzaSyBxB5NIsh-rcnJOHF_lkG9465N2gl19ByM",
          authDomain: "parking-da1e0.firebaseapp.com",
          databaseURL: "https://parking-da1e0-default-rtdb.firebaseio.com", // Fixed URL
          projectId: "parking-da1e0",
          storageBucket: "parking-da1e0.appspot.com",
          messagingSenderId: "923155382800",
          appId: "1:923155382800:web:7db8a68292817337e5c095"
        ),
      );
      
      // Initialize Realtime Database with persistence
      rtdb.setPersistenceEnabled(true);
      rtdb.setLoggingEnabled(true); // Enable logging for debugging
      
      // Configure Firestore settings
      firestore.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    } catch (e) {
      print('Failed to initialize Firebase: $e');
      throw e;
    }
  }

  // Helper method to check connection status
  static Future<bool> checkConnection() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }
}
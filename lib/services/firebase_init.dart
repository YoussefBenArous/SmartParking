import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class FirebaseInit {
  static Future<void> initializeFirebase() async {
    try {
      await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: "YOUR_API_KEY",
          authDomain: "smartparking-4025c.firebaseapp.com",
          projectId: "smartparking-4025c",
          storageBucket: "smartparking-4025c.appspot.com",
          messagingSenderId: "YOUR_SENDER_ID",
          appId: "YOUR_APP_ID",
          databaseURL: "YOUR_DATABASE_URL"
        ),
      );

      // Enable persistence
      await FirebaseFirestore.instance.enablePersistence(
        const PersistenceSettings(synchronizeTabs: true),
      );

      // Configure Database
      FirebaseDatabase.instance.setPersistenceEnabled(true);
      FirebaseDatabase.instance.setPersistenceCacheSizeBytes(10000000);
    } catch (e) {
      print('Firebase initialization error: $e');
    }
  }
}

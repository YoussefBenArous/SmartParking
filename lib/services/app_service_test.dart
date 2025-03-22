import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AppServiceTest {
  static Future<bool> verifyAllServices() async {
    try {
      // Test Firebase Connection
      bool firebaseOk = await _testFirebaseConnection();
      if (!firebaseOk) return false;

      // Test Database Structure
      bool dbStructureOk = await _testDatabaseStructure();
      if (!dbStructureOk) return false;

      // Test Security Rules
      bool securityRulesOk = await _testSecurityRules();
      if (!securityRulesOk) return false;

      return true;
    } catch (e) {
      print('Verification failed: $e');
      return false;
    }
  }

  static Future<bool> _testFirebaseConnection() async {
    try {
      await FirebaseFirestore.instance.collection('test').get();
      return true;
    } catch (e) {
      print('Firebase connection test failed: $e');
      return false;
    }
  }

  static Future<bool> _testDatabaseStructure() async {
    try {
      final collections = [
        'users',
        'parking',
        'bookings',
      ];

      for (var collection in collections) {
        await FirebaseFirestore.instance.collection(collection).limit(1).get();
      }
      return true;
    } catch (e) {
      print('Database structure test failed: $e');
      return false;
    }
  }

  static Future<bool> _testSecurityRules() async {
    try {
      // Test reading without auth
      try {
        await FirebaseFirestore.instance.collection('parking').get();
        print('Warning: Public read access enabled');
      } catch (e) {
        // This should fail - it's good
      }

      // Test user type restrictions
      if (FirebaseAuth.instance.currentUser != null) {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser!.uid)
            .get();
        
        if (!userDoc.exists || !userDoc.data()!.toString().contains('userType')) {
          print('Warning: User document missing required fields');
          return false;
        }
      }

      return true;
    } catch (e) {
      print('Security rules test failed: $e');
      return false;
    }
  }
}

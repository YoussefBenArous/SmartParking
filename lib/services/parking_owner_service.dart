import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ParkingOwnerService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Future<bool> hasExistingParking() async {
    try {
      User? user = _auth.currentUser;
      if (user == null) return false;

      // Check user document
      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) return false;

      // Check if user has hasParking field set to true
      return (userDoc.data() as Map<String, dynamic>)['hasParking'] == true;
    } catch (e) {
      print('Error checking parking owner status: $e');
      return false;
    }
  }

  static Future<String?> getExistingParkingId() async {
    try {
      User? user = _auth.currentUser;
      if (user == null) return null;

      QuerySnapshot parkingDocs = await _firestore
          .collection('parking')
          .where('ownerId', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (parkingDocs.docs.isEmpty) return null;
      return parkingDocs.docs.first.id;
    } catch (e) {
      print('Error getting parking ID: $e');
      return null;
    }
  }
}

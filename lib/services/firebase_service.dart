import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Authentication methods
  Future<UserCredential> signInWithEmailAndPassword(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> createUserWithEmailAndPassword(String email, String password, String userType) async {
    UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Create user document with required fields
    await _firestore.collection('users').doc(userCredential.user!.uid).set({
      'email': email,
      'userType': userType,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return userCredential;
  }

  // Parking methods
  Future<bool> createParking(Map<String, dynamic> parkingData) async {
    try {
      User? user = _auth.currentUser;
      if (user == null) throw Exception('Not authenticated');

      DocumentReference parkingRef = await _firestore.collection('parking').add({
        ...parkingData,
        'ownerId': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Add reference to user's parkings
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('parkings')
          .doc(parkingRef.id)
          .set({
        ...parkingData,
        'parkingId': parkingRef.id,
      });

      return true;
    } catch (e) {
      print('Error creating parking: $e');
      return false;
    }
  }

  // Booking methods
  Future<bool> createBooking(String parkingId) async {
    try {
      User? user = _auth.currentUser;
      if (user == null) throw Exception('Not authenticated');

      await _firestore.runTransaction((transaction) async {
        DocumentReference parkingRef = _firestore.collection('parking').doc(parkingId);
        DocumentSnapshot parkingDoc = await transaction.get(parkingRef);

        if (!parkingDoc.exists) throw Exception('Parking not found');

        Map<String, dynamic> parkingData = parkingDoc.data() as Map<String, dynamic>;
        int available = parkingData['available'] ?? 0;

        if (available <= 0) throw Exception('No spots available');

        // Create booking
        DocumentReference bookingRef = _firestore.collection('bookings').doc();
        transaction.set(bookingRef, {
          'parkingId': parkingId,
          'userId': user.uid,
          'status': 'pending',
          'timestamp': FieldValue.serverTimestamp(),
        });

        // Update parking availability
        transaction.update(parkingRef, {
          'available': available - 1,
        });
      });

      return true;
    } catch (e) {
      print('Error creating booking: $e');
      return false;
    }
  }

  // User methods
  Future<bool> isParkingOwner(String userId) async {
    try {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();
      return userDoc.exists && userDoc.get('userType') == 'Parking Owner';
    } catch (e) {
      print('Error checking user type: $e');
      return false;
    }
  }
}

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreListenerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  final Map<String, StreamSubscription> _listeners = {};

  // Listen to user's bookings
  Stream<QuerySnapshot> listenToUserBookings() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    return _firestore
        .collection('bookings')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: 'active')
        .snapshots();
  }

  // Listen to specific parking spots
  Stream<DocumentSnapshot> listenToParkingSpot(String parkingId, String spotId) {
    return _firestore
        .collection('parking')
        .doc(parkingId)
        .collection('spots')
        .doc(spotId)
        .snapshots();
  }

  // Listen to parking availability changes
  Stream<DocumentSnapshot> listenToParkingAvailability(String parkingId) {
    return _firestore
        .collection('parking')
        .doc(parkingId)
        .snapshots();
  }

  // Cleanup method
  void dispose() {
    for (var listener in _listeners.values) {
      listener.cancel();
    }
    _listeners.clear();
  }
}

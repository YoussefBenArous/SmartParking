import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:smart_parking/HomePage/userpages/UserHome.dart';

class FirebaseService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Authentication Methods
  static Future<bool> isUserLoggedIn() async {
    return _auth.currentUser != null;
  }

  // Parking Methods
  static Future<bool> isSpotAvailable(int spotNumber) async {
    try {
      // First check if user is logged in
      if (_auth.currentUser == null) {
        throw Exception('User not authenticated');
      }

      final doc = await _firestore
          .collection('parkingSpots')
          .doc(spotNumber.toString())
          .get();

      return !(doc.exists && doc.data()?['isOccupied'] == true);
    } catch (e) {
      debugPrint('Error checking spot availability: $e');
      rethrow;
    }
  }

  static Future<String> createBooking(int spotNumber) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('User not authenticated');

    try {
      return await _firestore.runTransaction<String>((transaction) async {
        // Check spot availability in transaction
        final spotRef = _firestore.collection('parkingSpots').doc(spotNumber.toString());
        final spotDoc = await transaction.get(spotRef);

        if (spotDoc.exists && spotDoc.data()?['isOccupied'] == true) {
          throw Exception('Spot already occupied');
        }

        // Create booking
        final bookingRef = _firestore.collection('bookings').doc();
        final bookingData = {
          'userId': user.uid,
          'spotNumber': spotNumber,
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'active',
          'bookingId': bookingRef.id
        };

        // Update spot status
        transaction.set(spotRef, {
          'isOccupied': true,
          'userId': user.uid,
          'lastUpdated': FieldValue.serverTimestamp()
        });

        // Save booking
        transaction.set(bookingRef, bookingData);

        return bookingRef.id;
      });
    } catch (e) {
      debugPrint('Error creating booking: $e');
      rethrow;
    }
  }

  static Stream<QuerySnapshot> getSpotStatuses() {
    return _firestore
        .collection('parkingSpots')
        .orderBy('spotNumber')
        .snapshots();
  }

  static Future<DocumentSnapshot> getBookingDetails(String bookingId) {
    return _firestore
        .collection('bookings')
        .doc(bookingId)
        .get();
  }
}

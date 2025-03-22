import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ParkingService {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  // Check spot availability
  static Future<bool> isSpotAvailable(int spotNumber) async {
    try {
      if (_auth.currentUser == null) throw Exception('User not authenticated');

      final doc = await _firestore
          .collection('parkingSpots')
          .doc(spotNumber.toString())
          .get();

      return !(doc.exists && doc.data()?['isOccupied'] == true);
    } catch (e) {
      throw Exception('Failed to check spot availability: $e');
    }
  }

  // Create new booking
  static Future<Map<String, dynamic>> createBooking(int spotNumber) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final bookingRef = _firestore.collection('bookings').doc();
      final spotRef = _firestore.collection('parkingSpots').doc(spotNumber.toString());

      await _firestore.runTransaction((transaction) async {
        final spotDoc = await transaction.get(spotRef);
        if (spotDoc.exists && spotDoc.data()?['isOccupied'] == true) {
          throw Exception('Spot already occupied');
        }

        // Update spot status
        transaction.set(spotRef, {
          'isOccupied': true,
          'userId': user.uid,
          'lastUpdated': FieldValue.serverTimestamp(),
          'spotNumber': spotNumber
        });

        // Create booking
        transaction.set(bookingRef, {
          'bookingId': bookingRef.id,
          'userId': user.uid,
          'spotNumber': spotNumber,
          'timestamp': FieldValue.serverTimestamp(),
          'status': 'active',
          'price': 2.0, // TND per hour
        });
      });

      return {
        'bookingId': bookingRef.id,
        'spotNumber': spotNumber,
      };
    } catch (e) {
      throw Exception('Failed to create booking: $e');
    }
  }

  // Get real-time parking spots status
  static Stream<QuerySnapshot> getParkingSpots() {
    return _firestore
        .collection('parkingSpots')
        .orderBy('spotNumber')
        .snapshots();
  }

  // Get booking details
  static Stream<DocumentSnapshot> getBookingDetails(String bookingId) {
    return _firestore
        .collection('bookings')
        .doc(bookingId)
        .snapshots();
  }

  // Get owner's parkings
  static Future<List<Map<String, dynamic>>> getOwnerParkings() async {
    try {
      User? user = _auth.currentUser;
      if (user == null) throw Exception('Not authenticated');

      QuerySnapshot parkingsSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('ownedParkings')
          .get();

      return parkingsSnapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          ...data,
        };
      }).toList();
    } catch (e) {
      print('Error fetching owner parkings: $e');
      return [];
    }
  }

  // Watch owner's profile
  static Stream<DocumentSnapshot> watchOwnerProfile() {
    User? user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    return _firestore
        .collection('users')
        .doc(user.uid)
        .snapshots();
  }

  // Watch owner's parkings
  static Stream<QuerySnapshot> watchOwnerParkings() {
    User? user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('ownedParkings')
        .snapshots();
  }
}

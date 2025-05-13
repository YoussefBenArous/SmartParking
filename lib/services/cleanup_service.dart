import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';

class CleanupService {
  final _firestore = FirebaseFirestore.instance;
  final _database = FirebaseDatabase.instance;

  Future<void> cleanupAfterBookingCancellation({
    required String bookingId,
    required String userId,
    required String parkingId,
    required String spotId,
  }) async {
    final batch = _firestore.batch();

    // Delete QR codes
    batch.delete(_firestore
        .collection('users')
        .doc(userId)
        .collection('qrcodes')
        .doc(bookingId));

    batch.delete(_firestore
        .collection('parking')
        .doc(parkingId)
        .collection('qrcodes')
        .doc(bookingId));

    // Update spot status
    batch.update(_firestore
        .collection('parking')
        .doc(parkingId)
        .collection('spots')
        .doc(spotId), {
      'isAvailable': true,
      'lastUpdated': FieldValue.serverTimestamp(),
      'lastAction': 'reset_after_cancellation'
    });

    // Update parking availability
    batch.update(_firestore.collection('parking').doc(parkingId), {
      'available': FieldValue.increment(1),
      'lastUpdated': FieldValue.serverTimestamp(),
    });

    // Update RTDB spot status
    await _database.ref()
        .child('spots')
        .child(parkingId)
        .child(spotId)
        .update({
      'status': 'available',
      'lastUpdated': ServerValue.timestamp,
      'lastAction': 'reset_after_cancellation',
      'lastUserId': null,
      'lastBookingId': null,
    });

    // Commit Firestore changes
    await batch.commit();
  }
}

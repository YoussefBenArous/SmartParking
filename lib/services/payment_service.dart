import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:convert';

class PaymentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _rtdb = FirebaseDatabase.instance;

  Future<Map<String, dynamic>?> getLastPayment(String userId) async {
    try {
      final payments = await _firestore
          .collection('payments')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'completed')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (payments.docs.isEmpty) return null;
      return payments.docs.first.data();
    } catch (e) {
      print('Error getting last payment: $e');
      return null;
    }
  }

  Future<bool> hasExistingPayment(String bookingId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return false;

      final payments = await _firestore
          .collection('payments')
          .where('bookingId', isEqualTo: bookingId)
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'completed')
          .get();

      return payments.docs.isNotEmpty;
    } catch (e) {
      print('Error checking payment status: $e');
      return false;
    }
  }

  Future<Map<String, dynamic>?> getSpotOccupancyTime(String parkingId, String spotNumber) async {
    try {
      final snapshot = await _rtdb
          .ref('spots/$parkingId/$spotNumber/occupancyHistory')
          .orderByChild('timestamp')
          .limitToLast(1)
          .get();

      if (!snapshot.exists) return null;

      final data = snapshot.value as Map<dynamic, dynamic>;
      final entry = data.values.first as Map<dynamic, dynamic>;
      
      // Check if status has been 'occupied' for at least 5 minutes
      final occupiedTime = DateTime.fromMillisecondsSinceEpoch(entry['timestamp']);
      final hasBeenOccupiedLongEnough = DateTime.now().difference(occupiedTime) >= Duration(minutes: 5);

      if (entry['status'] == 'occupied' && hasBeenOccupiedLongEnough) {
        return {
          'startTime': occupiedTime,
          'duration': DateTime.now().difference(occupiedTime).inHours,
        };
      }
      return null;
    } catch (e) {
      print('Error getting occupancy time: $e');
      return null;
    }
  }

  Future<bool> verifyUserPresence(String parkingId, String spotNumber) async {
    try {
      final snapshot = await _rtdb.ref('spots/$parkingId/$spotNumber').get();
      if (!snapshot.exists) return false;

      final data = snapshot.value as Map<dynamic, dynamic>;
      final lastUpdate = data['lastSensorUpdate'] as int?;
      final now = DateTime.now().millisecondsSinceEpoch;

      // Verify status has been stable for at least 5 minutes
      final isStatusStable = lastUpdate != null &&
          (now - lastUpdate) >= Duration(minutes: 5).inMilliseconds &&
          data['status'] == 'occupied' &&
          data['sensorDetected'] == true;

      return isStatusStable;
    } catch (e) {
      print('Error checking sensor status: $e');
      return false;
    }
  }

  Future<void> listenToSpotStatus(String parkingId, String spotNumber, Function(bool) onStatusChange) async {
    _rtdb
        .ref('spots/$parkingId/$spotNumber')
        .onValue
        .listen((event) {
      if (event.snapshot.exists) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        final isReady = data['status'] == 'occupied' && 
                       data['sensorDetected'] == true;
        onStatusChange(isReady);
      }
    });
  }

  Future<void> savePaymentAndGenerateQR({
    required String bookingId,
    required double amount,
    required String paymentMethod,
    required int duration,
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    try {
      // Start a batch write
      final batch = _firestore.batch();

      // Get booking details
      final bookingDoc = await _firestore.collection('bookings').doc(bookingId).get();
      if (!bookingDoc.exists) throw Exception('Booking not found');
      
      final bookingData = bookingDoc.data()!;
      final parkingId = bookingData['parkingId'];

      // Create refs
      final paymentRef = _firestore.collection('payments').doc();
      final bookingRef = _firestore.collection('bookings').doc(bookingId);
      final spotRef = _firestore
          .collection('parking')
          .doc(parkingId)
          .collection('spots')
          .doc(bookingData['spotId']);
      final userQRRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('qrcodes')
          .doc(bookingId);
      final parkingQRRef = _firestore
          .collection('parking')
          .doc(parkingId)
          .collection('qrcodes')
          .doc(bookingId);

      // Add all operations to batch
      batch.set(paymentRef, {
        'userId': userId,
        'parkingId': parkingId,
        'bookingId': bookingId,
        'amount': amount,
        'paymentMethod': paymentMethod,
        'duration': duration,
        'status': 'completed',
        'timestamp': FieldValue.serverTimestamp(),
        'parkingName': bookingData['parkingName'],
        'spotNumber': bookingData['spotNumber'],
      });

      batch.update(bookingRef, {
        'paymentStatus': 'paid',
        'paidAmount': amount,
        'paidDuration': duration,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      batch.update(spotRef, {
        'lastPaymentId': paymentRef.id,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      final qrData = {
        'parkingId': parkingId,
        'parkingName': bookingData['parkingName'],
        'spotNumber': bookingData['spotNumber'],
        'bookingId': bookingId,
        'timestamp': FieldValue.serverTimestamp(),
        'qrData': _generateQRData(bookingId, amount, duration),
        'status': 'active',
        'paymentId': paymentRef.id,
      };

      batch.set(userQRRef, qrData);
      batch.set(parkingQRRef, {...qrData, 'userId': userId});

      // Commit batch
      await batch.commit();

    } catch (e) {
      print('Error in savePaymentAndGenerateQR: $e');
      throw Exception('Failed to process payment: $e');
    }
  }

  Future<void> savePayment({
    required String bookingId,
    required double amount,
    required String paymentMethod,
    required int duration,
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    // Get booking details first
    final bookingDoc = await _firestore.collection('bookings').doc(bookingId).get();
    if (!bookingDoc.exists) throw Exception('Booking not found');
    
    final bookingData = bookingDoc.data()!;
    final parkingId = bookingData['parkingId'];

    // Verify user presence before payment
    final isPresent = await verifyUserPresence(
      bookingData['parkingId'], 
      bookingData['spotNumber']
    );
    
    if (!isPresent) {
      throw Exception('Please park your vehicle before making payment');
    }

    // Create payment document
    await _firestore.collection('payments').add({
      'userId': userId,
      'parkingId': parkingId,
      'bookingId': bookingId,
      'amount': amount,
      'paymentMethod': paymentMethod,
      'duration': duration,
      'status': 'completed',
      'timestamp': FieldValue.serverTimestamp(),
      'parkingName': bookingData['parkingName'],
      'spotNumber': bookingData['spotNumber'],
    });

    // Update booking status
    await _firestore.collection('bookings').doc(bookingId).update({
      'paymentStatus': 'paid',
      'paidAmount': amount,
      'paidDuration': duration,
      'lastUpdated': FieldValue.serverTimestamp(),
    });

    // Create QR code reference
    final qrData = {
      'parkingId': parkingId,
      'parkingName': bookingData['parkingName'],
      'spotNumber': bookingData['spotNumber'],
      'bookingId': bookingId,
      'timestamp': FieldValue.serverTimestamp(),
      'qrData': _generateQRData(bookingId, amount, duration),
      'status': 'active',
    };

    // Save QR code to user's collection
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('qrcodes')
        .doc(bookingId)
        .set(qrData);

    // Save QR code to parking's collection
    await _firestore
        .collection('parking')
        .doc(parkingId)
        .collection('qrcodes')
        .doc(bookingId)
        .set({...qrData, 'userId': userId});
  }

  String _generateQRData(String bookingId, double amount, int duration) {
    final timestamp = DateTime.now().toIso8601String();
    final data = {
      'bookingId': bookingId,
      'amount': amount,
      'duration': duration,
      'timestamp': timestamp,
      'type': 'exit',  // Added to identify QR type
      'validUntil': DateTime.now().add(Duration(hours: duration)).toIso8601String(),
    };
    return jsonEncode(data);
  }

  Future<void> saveExitQRCode({
    required String bookingId,
    required String parkingId,
    required String spotNumber,
    required double amount,
    required int duration,
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    final qrData = {
      'type': 'exit',
      'parkingId': parkingId,
      'spotNumber': spotNumber,
      'bookingId': bookingId,
      'amount': amount,
      'duration': duration,
      'timestamp': FieldValue.serverTimestamp(),
      'validUntil': DateTime.now().add(Duration(hours: duration)),
      'status': 'active',
      'userId': userId,
    };

    // Save exit QR code
    await _firestore
        .collection('parking')
        .doc(parkingId)
        .collection('exitQRCodes')
        .doc(bookingId)
        .set(qrData);

    // Save reference to user's collection
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('exitQRCodes')
        .doc(bookingId)
        .set(qrData);
  }

  Future<Map<String, dynamic>?> getBookingDetails(String bookingId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return null;

      final bookingDoc = await _firestore.collection('bookings').doc(bookingId).get();
      if (!bookingDoc.exists) return null;

      final bookingData = bookingDoc.data()!;
      
      // Get parking details
      final parkingDoc = await _firestore
          .collection('parking')
          .doc(bookingData['parkingId'])
          .get();

      if (!parkingDoc.exists) return null;

      // Get payment details if exists
      final paymentQuery = await _firestore
          .collection('payments')
          .where('bookingId', isEqualTo: bookingId)
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      final Map<String, dynamic> result = {
        ...bookingData,
        'parkingName': parkingDoc.data()?['name'] ?? '',
        'price': parkingDoc.data()?['price'] ?? '0',
      };

      if (paymentQuery.docs.isNotEmpty) {
        result.addAll(paymentQuery.docs.first.data());
      }

      return result;
    } catch (e) {
      print('Error getting booking details: $e');
      return null;
    }
  }

  Future<DocumentSnapshot?> getActiveBooking() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return null;

      final bookings = await _firestore
          .collection('bookings')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'active')
          .where('paymentStatus', isEqualTo: 'pending')
          .limit(1)
          .get();

      return bookings.docs.isNotEmpty ? bookings.docs.first : null;
    } catch (e) {
      print('Error getting active booking: $e');
      return null;
    }
  }

  Future<void> checkAndCleanupExpiredBookings() async {
    try {
      final now = DateTime.now();
      print('Checking for expired bookings at ${now.toString()}');
      
      // Use batch write instead of transaction
      final batch = _firestore.batch();
      
      // Query expired bookings with retry mechanism
      QuerySnapshot? expiredBookings;
      for (int i = 0; i < 3; i++) {
        try {
          expiredBookings = await _firestore
              .collection('bookings')
              .where('status', isEqualTo: 'active')
              .where('expiryTime', isLessThan: Timestamp.fromDate(now))
              .get();
          break;
        } catch (e) {
          if (i == 2) rethrow;
          await Future.delayed(Duration(seconds: 1));
        }
      }

      if (expiredBookings == null) return;

      for (var booking in expiredBookings.docs) {
        try {
          final bookingData = booking.data() as Map<String, dynamic>;
          
          // Update booking status
          batch.update(booking.reference, {
            'status': 'expired',
            'lastUpdated': FieldValue.serverTimestamp(),
          });

          // Reset spot status
          final spotRef = _firestore
              .collection('parking')
              .doc(bookingData['parkingId'])
              .collection('spots')
              .doc(bookingData['spotId']);
          
          batch.update(spotRef, {
            'isAvailable': true,
            'status': 'available',
            'lastUpdated': FieldValue.serverTimestamp(),
          });

          // Delete QR codes
          if (bookingData['userId'] != null) {
            final userQRRef = _firestore
                .collection('users')
                .doc(bookingData['userId'])
                .collection('qrcodes')
                .doc(booking.id);
            batch.delete(userQRRef);
          }

          final parkingQRRef = _firestore
              .collection('parking')
              .doc(bookingData['parkingId'])
              .collection('qrcodes')
              .doc(booking.id);
          batch.delete(parkingQRRef);

          // Update realtime database
          await _rtdb
              .ref('spots/${bookingData['parkingId']}/${bookingData['spotNumber']}')
              .update({
                'status': 'available',
                'lastUpdate': ServerValue.timestamp,
                'sensorDetected': false,
              });

        } catch (e) {
          print('Error processing expired booking ${booking.id}: $e');
          continue;
        }
      }

      // Commit all changes
      await batch.commit();

    } catch (e) {
      print('Error in checkAndCleanupExpiredBookings: $e');
    }
  }

  Future<void> _extendBooking(DocumentReference bookingRef, Map<String, dynamic> bookingData) async {
    // Extend booking by 15 minutes if spot is physically occupied
    final newExpiryTime = DateTime.now().add(Duration(minutes: 15));
    await bookingRef.update({
      'expiryTime': Timestamp.fromDate(newExpiryTime),
      'lastUpdated': FieldValue.serverTimestamp(),
      'autoExtended': true,
    });
  }

  // Add a helper method to validate expiry time
  bool _isExpired(DateTime? expiryTime) {
    if (expiryTime == null) return false;
    final now = DateTime.now();
    final difference = now.difference(expiryTime);
    return difference.inSeconds > 0;
  }

  // Add helper method to validate collections structure
  Future<void> validateCollectionsStructure() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      // Ensure user QR codes collection exists
      final userQRRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('qrcodes');
      
      final userQRDoc = await userQRRef.get();
      if (userQRDoc.docs.isEmpty) {
        await userQRRef.doc('placeholder').set({
          'created': FieldValue.serverTimestamp()
        });
        await userQRRef.doc('placeholder').delete();
      }

      // Validate bookings collection
      final bookingsRef = _firestore.collection('bookings');
      await bookingsRef.limit(1).get();

    } catch (e) {
      print('Error validating collections: $e');
    }
  }
}

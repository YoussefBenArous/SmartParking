import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart' as rtdb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';

class ParkingSpotService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  Future<void> initializeSpots(String parkingId, int capacity) async {
    try {
      // Initialize Firestore first
      final spotsCollection = _firestore.collection('parking').doc(parkingId).collection('spots');
      final existingSpots = await spotsCollection.get();
      
      if (existingSpots.docs.isEmpty) {
        final batch = _firestore.batch();
        
        // Create spots in Realtime Database first
        final realtimeRef = _database.ref('spots/$parkingId');
        Map<String, dynamic> realtimeSpots = {};

        for (int i = 1; i <= capacity; i++) {
          String spotId = 'spot_$i'; // Use consistent IDs
          
          // Realtime Database spot
          realtimeSpots[spotId] = {
            'number': 'P$i',
            'status': 'available',
            'lastUpdated': ServerValue.timestamp,
            'lastBookingId': '',
            'lastUserId': '',
            'ignoreStatusUpdates': false
          };

          // Firestore spot
          final spotRef = spotsCollection.doc(spotId);
          batch.set(spotRef, {
            'number': 'P$i',
            'isAvailable': true,
            'type': 'standard',
            'lastUpdated': FieldValue.serverTimestamp(),
            'status': 'available'
          });
        }

        // Commit both databases
        await Future.wait([
          realtimeRef.set(realtimeSpots),
          batch.commit()
        ]);
      }

      // Sync existing spots if needed
      await syncSpots(parkingId);

    } catch (e) {
      print('Error initializing spots: $e');
      throw e;
    }
  }

  Future<void> syncSpots(String parkingId) async {
    try {
      final realtimeRef = _database.ref('spots/$parkingId');
      final firestoreRef = _firestore.collection('parking').doc(parkingId).collection('spots');

      // Get current state from both databases
      final realtimeSnap = await realtimeRef.get();
      final firestoreSnap = await firestoreRef.get();

      if (!realtimeSnap.exists || firestoreSnap.docs.isEmpty) return;

      final realtimeSpots = realtimeSnap.value as Map<dynamic, dynamic>;
      final batch = _firestore.batch();

      // Update Firestore spots based on Realtime Database
      for (var doc in firestoreSnap.docs) {
        final spotId = doc.id;
        final realtimeSpot = realtimeSpots[spotId];
        
        if (realtimeSpot != null) {
          batch.update(doc.reference, {
            'isAvailable': realtimeSpot['status'] == 'available',
            'status': realtimeSpot['status'],
            'lastUpdated': FieldValue.serverTimestamp(),
            'syncedFromRealtime': true
          });
        }
      }

      await batch.commit();
    } catch (e) {
      print('Error syncing spots: $e');
    }
  }

  Future<bool> isSpotAvailable(String parkingId, String spotId) async {
    try {
      final results = await Future.wait([
        _firestore
            .collection('parking')
            .doc(parkingId)
            .collection('spots')
            .doc(spotId)
            .get(),
        _database.ref('spots/$parkingId/$spotId').get()
      ]);

      final firestoreSpot = results[0] as DocumentSnapshot;
      final realtimeSpot = results[1] as DataSnapshot;

      if (!firestoreSpot.exists || !realtimeSpot.exists) return false;

      final firestoreData = firestoreSpot.data() as Map<String, dynamic>;
      final realtimeData = realtimeSpot.value as Map<dynamic, dynamic>;

      return firestoreData['isAvailable'] == true && 
             realtimeData['status'] == 'available' &&
             !(realtimeData['ignoreStatusUpdates'] ?? false);

    } catch (e) {
      print('Error checking spot availability: $e');
      return false;
    }
  }

  Stream<DatabaseEvent> getSpotStatus(String parkingId, String spotId) {
    return _database.ref('spots/$parkingId/$spotId').onValue;
  }

  Future<void> fixSpotPaths(String parkingId) async {
    final oldRef = _database.ref();
    final newRef = _database.ref().child('spots').child(parkingId);
    
    // Get all spots at root level
    final snapshot = await oldRef.get();
    if (!snapshot.exists) return;

    final data = snapshot.value as Map<Object?, Object?>?;
    if (data == null) return;

    // Move spots to correct path
    await Future.wait(data.entries.map((entry) async {
      final spotId = entry.key.toString();
      final spotData = entry.value as Map<Object?, Object?>?;
      
      if (spotData != null && !spotId.contains('/')) {
        // Only move if it's a spot without proper path
        await newRef.child(spotId).set(spotData);
        await oldRef.child(spotId).remove();
      }
    }));
  }

  Future<bool> lockSpot(String parkingId, String spotId, String userId) async {
    try {
      // Update Firestore first
      await FirebaseFirestore.instance
          .collection('parking')
          .doc(parkingId)
          .collection('spots')
          .doc(spotId)
          .update({
        'status': 'reserved',
        'lastUserId': userId,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // Then update Realtime Database
      await FirebaseDatabase.instance
          .ref('parking/$parkingId/spots/$spotId')
          .update({
        'status': 'reserved',
        'lastUserId': userId,
        'lastUpdated': ServerValue.timestamp,
      });

      return true;
    } catch (e) {
      print('Error locking spot: $e');
      return false;
    }
  }

  Future<void> handleSensorData(String parkingId, String spotId, bool isOccupied) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email != 'esp32cam@gmail.com') {
        throw Exception('Unauthorized sensor update');
      }

      final spotRef = _database.ref().child('spots').child(parkingId).child(spotId);
      final snapshot = await spotRef.get();
      
      if (!snapshot.exists) {
        throw Exception('Spot not found');
      }

      await spotRef.update({
        'status': isOccupied ? 'occupied' : 'available',
        'lastUpdated': ServerValue.timestamp,
        'sensorUpdated': ServerValue.timestamp,
        'updatedBy': 'sensor',
        'sensorId': 'esp32cam'
      });
    } catch (e) {
      print('Error handling sensor data: $e');
      throw e;
    }
  }

  Future<void> releaseReservation(String parkingId, String spotId) async {
    final batch = _firestore.batch();
    
    // Update Firestore
    final spotDocRef = _firestore
        .collection('parking')
        .doc(parkingId)
        .collection('spots')
        .doc(spotId);
    
    batch.update(spotDocRef, {
      'isAvailable': true,
      'isReserved': false,
      'reservedBy': null,
      'lastUpdated': FieldValue.serverTimestamp()
    });

    await batch.commit();

    // Update Realtime Database
    await _database
        .ref()
        .child('spots')
        .child(parkingId)
        .child(spotId)
        .update({
      'status': 'available',
      'isReserved': false,
      'lastUserId': null,
      'lastUpdated': ServerValue.timestamp
    });
  }

  Future<void> saveBookingData({
    required String bookingId,
    required Map<String, dynamic> bookingData,
    required Map<String, dynamic> qrData,
    required String userId,
    required String parkingId,
  }) async {
    try {
      final batch = _firestore.batch();

      // Set booking with minimal required fields
      final bookingRef = _firestore.collection('bookings').doc(bookingId);
      batch.set(bookingRef, {
        'parkingId': parkingId,
        'spotId': bookingData['spotId'],
        'userId': userId,
        'status': 'active',
        'timestamp': DateTime.now().toIso8601String(),
        'spotNumber': bookingData['spotNumber'],
        'parkingName': bookingData['parkingName'],
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Save QR data under user's collection with minimal fields
      final userQRRef = _firestore
          .collection('users')
          .doc(userId)
          .collection('qrcodes')
          .doc(bookingId);
      batch.set(userQRRef, {
        'parkingId': parkingId,
        'parkingName': bookingData['parkingName'],
        'spotNumber': bookingData['spotNumber'],
        'bookingId': bookingId,
        'timestamp': DateTime.now().toIso8601String(),
        'qrData': qrData['qrData'],
      });

      // Save QR data under parking's collection with minimal fields
      final parkingQRRef = _firestore
          .collection('parking')
          .doc(parkingId)
          .collection('qrcodes')
          .doc(bookingId);
      batch.set(parkingQRRef, {
        'parkingId': parkingId,
        'parkingName': bookingData['parkingName'],
        'spotNumber': bookingData['spotNumber'],
        'bookingId': bookingId,
        'timestamp': DateTime.now().toIso8601String(),
        'qrData': qrData['qrData'],
        'userId': userId,
      });

      // Update parking availability with minimal fields
      final parkingRef = _firestore.collection('parking').doc(parkingId);
      batch.update(parkingRef, {
        'available': FieldValue.increment(-1),
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // Commit batch
      await batch.commit();
    } catch (e) {
      print('Error saving booking data: $e');
      throw Exception('Failed to save booking data');
    }
  }

  Future<void> updateSpotStatus(
    String parkingId,
    String spotId,
    String status,
    Map<String, dynamic> additionalData,
  ) async {
    try {
      // Check if user is authenticated
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User must be authenticated');
      }

      // Get spot reference
      final ref = _database.ref().child('spots').child(parkingId).child(spotId);
      
      // Get current data to verify permissions
      final snapshot = await ref.get();
      if (!snapshot.exists) {
        throw Exception('Spot does not exist');
      }

      final spotData = Map<String, dynamic>.from(snapshot.value as Map);
      
      // Verify user has permission
      if (spotData['lastUserId'] != user.uid && 
          !(await _isParkingOwner(parkingId, user.uid))) {
        throw Exception('Permission denied');
      }

      // Update with authenticated user
      await ref.update({
        'status': status,
        'lastUpdated': ServerValue.timestamp,
        'lastUserId': user.uid,
        ...additionalData,
      });
    } catch (e) {
      print('Error updating spot status: $e');
      throw e;
    }
  }

  Future<bool> _isParkingOwner(String parkingId, String userId) async {
    try {
      final doc = await _firestore.collection('parking').doc(parkingId).get();
      return doc.exists && doc.data()?['ownerId'] == userId;
    } catch (e) {
      return false;
    }
  }

  Future<void> unlockSpot(String parkingId, String spotId) async {
    try {
      final dbRef = FirebaseDatabase.instance
          .ref()
          .child('parking')
          .child(parkingId)
          .child('spots')
          .child(spotId);

      await dbRef.update({
        'status': 'available',
        'lastAction': 'cancelled',
        'lastUpdated': ServerValue.timestamp,
      });

      // Also update Firestore
      await FirebaseFirestore.instance
          .collection('parking')
          .doc(parkingId)
          .collection('spots')
          .doc(spotId)
          .update({
        'isAvailable': true,
        'lastUpdated': FieldValue.serverTimestamp(),
        'lastAction': 'cancelled'
      });
    } catch (e) {
      print('Error unlocking spot: $e');
      throw e;
    }
  }

  Future<void> cleanupExpiredReservations() async {
    try {
      final now = DateTime.now();
      
      // Get all active bookings
      final activeBookings = await _firestore
          .collection('bookings')
          .where('status', isEqualTo: 'active')
          .get();

      // Filter expired bookings locally
      final expiredBookings = activeBookings.docs.where((doc) {
        final expiryTime = doc.data()['expiryTime'] as Timestamp?;
        final arrivalTime = doc.data()['arrivalTime'] as Timestamp?;
        return (expiryTime?.toDate().isBefore(now) ?? false) || 
               (arrivalTime?.toDate().isBefore(now.subtract(Duration(minutes: 15))) ?? false);
      });

      for (var doc in expiredBookings) {
        final bookingData = doc.data();
        final parkingId = bookingData['parkingId'];
        final spotId = bookingData['spotId'];
        
        // Check sensor status from Realtime Database
        final sensorSnapshot = await _database
            .ref('spots/$parkingId/$spotId')
            .get();

        if (sensorSnapshot.exists) {
          final spotData = Map<String, dynamic>.from(sensorSnapshot.value as Map);
          final bool isSensorDetected = spotData['sensorDetected'] ?? false;
          
          // Only cancel if no vehicle is detected
          if (!isSensorDetected) {
            await _cancelExpiredBooking(
              doc.id,
              parkingId,
              spotId,
              bookingData['userId'],
            );
          }
        }
      }
    } catch (e) {
      print('Error cleaning up expired reservations: $e');
    }
  }

  Future<void> _cancelExpiredBooking(
    String bookingId,
    String parkingId,
    String spotId,
    String userId,
  ) async {
    try {
      final batch = _firestore.batch();

      // Update booking status
      final bookingRef = _firestore.collection('bookings').doc(bookingId);
      batch.update(bookingRef, {
        'status': 'expired',
        'lastUpdated': FieldValue.serverTimestamp(),
        'reason': 'No vehicle detected at reservation time'
      });

      // Update spot in Firestore
      final spotRef = _firestore
          .collection('parking')
          .doc(parkingId)
          .collection('spots')
          .doc(spotId);
      
      batch.update(spotRef, {
        'status': 'available',
        'isAvailable': true,
        'lastUserId': null,
        'lastUpdated': FieldValue.serverTimestamp(),
        'ignoreStatusUpdates': false,
        'lastBookingId': null
      });

      // Increment available spots in parking
      final parkingRef = _firestore.collection('parking').doc(parkingId);
      batch.update(parkingRef, {
        'available': FieldValue.increment(1),
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      // Commit Firestore changes
      await batch.commit();

      // Update Realtime Database
      await _database.ref('spots/$parkingId/$spotId').update({
        'status': 'available',
        'lastUserId': null,
        'lastBookingId': null,
        'lastUpdated': ServerValue.timestamp,
        'ignoreStatusUpdates': false,
        'sensorDetected': false,
        'lastSensorUpdate': ServerValue.timestamp
      });

      // Clean up QR codes
      await Future.wait([
        _firestore
            .collection('users')
            .doc(userId)
            .collection('qrcodes')
            .doc(bookingId)
            .delete(),
        _firestore
            .collection('parking')
            .doc(parkingId)
            .collection('qrcodes')
            .doc(bookingId)
            .delete(),
      ]);

      // Send notification if implemented
      // await _notifyUser(userId, 'Your reservation has expired due to no vehicle detection.');

    } catch (e) {
      print('Error canceling expired booking: $e');
      throw e;
    }
  }
}

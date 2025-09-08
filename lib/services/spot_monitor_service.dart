import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class SpotMonitorService {
  final _rtdb = FirebaseDatabase.instance;
  final _firestore = FirebaseFirestore.instance;
  final Map<String, StreamSubscription> _monitors = {};

  Future<void> startMonitoring(String parkingId, String spotId, String bookingId) async {
    final key = '${parkingId}_${spotId}';
    
    // Cancel existing monitor if any
    await _monitors[key]?.cancel();
    
    // Start new monitor
    _monitors[key] = _rtdb
        .ref('spots/$parkingId/$spotId')
        .onValue
        .listen((event) async {
          if (!event.snapshot.exists) return;
          
          final data = event.snapshot.value as Map<dynamic, dynamic>;
          final status = data['status'] as String?;
          final sensorDetected = data['sensorDetected'] as bool?;
          
          if (status == 'occupied' && sensorDetected == true) {
            // Spot is physically occupied, update Firestore
            await _firestore.collection('bookings').doc(bookingId).update({
              'status': 'active',
              'occupiedAt': FieldValue.serverTimestamp(),
              'lastUpdated': FieldValue.serverTimestamp()
            });
            
            // Stop ignoring sensor updates
            await Future.wait([
              _rtdb.ref('spots/$parkingId/$spotId/ignoreStatusUpdates').set(false),
              _firestore
                  .collection('parking')
                  .doc(parkingId)
                  .collection('spots')
                  .doc(spotId)
                  .update({'ignoreStatusUpdates': false})
            ]);
            
            // Stop monitoring
            await stopMonitoring(parkingId, spotId);
          }
        });
  }

  Future<void> stopMonitoring(String parkingId, String spotId) async {
    final key = '${parkingId}_${spotId}';
    await _monitors[key]?.cancel();
    _monitors.remove(key);
  }

  void dispose() {
    for (var monitor in _monitors.values) {
      monitor.cancel();
    }
    _monitors.clear();
  }
}

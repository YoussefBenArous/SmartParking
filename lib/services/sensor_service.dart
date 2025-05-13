import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SensorService {
  final _database = FirebaseDatabase.instance;
  final _firestore = FirebaseFirestore.instance;

  Future<void> processSensorData(String parkingId, String spotId, bool isOccupied) async {
    final spotRef = _database.ref().child('spots').child(parkingId).child(spotId);
    final snapshot = await spotRef.get();
    
    if (!snapshot.exists) return;
    
    final spotData = Map<String, dynamic>.from(snapshot.value as Map);
    
    // Don't update status if spot is reserved through booking
    if (spotData['isReserved'] == true && spotData['reservationType'] == 'booking') {
      // Log sensor reading but don't change status
      await spotRef.child('sensorReadings').push().set({
        'timestamp': ServerValue.timestamp,
        'isOccupied': isOccupied
      });
      return;
    }

    // Update status for non-reserved spots
    await spotRef.update({
      'status': isOccupied ? 'occupied' : 'available',
      'lastUpdated': ServerValue.timestamp,
      'sensorUpdated': ServerValue.timestamp,
      'lastSensorReading': isOccupied
    });
  }
}

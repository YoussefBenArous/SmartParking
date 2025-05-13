import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ParkingSpotWidget extends StatelessWidget {
  final String parkingId;
  final String spotId;

  ParkingSpotWidget({
    required this.parkingId,
    required this.spotId,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('parking')
          .doc(parkingId)
          .collection('spots')
          .doc(spotId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Icon(Icons.error, color: Colors.red);
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          );
        }

        final spotData = snapshot.data!.data() as Map<String, dynamic>;
        final isAvailable = spotData['isAvailable'] as bool;

        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isAvailable ? Colors.green : Colors.red,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'Spot ${spotData['number']}',
            style: const TextStyle(color: Colors.white),
          ),
        );
      },
    );
  }
}

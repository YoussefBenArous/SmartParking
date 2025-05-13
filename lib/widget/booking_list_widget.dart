import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/firestore_listener_service.dart';

class BookingListWidget extends StatelessWidget {
  final FirestoreListenerService _listenerService = FirestoreListenerService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _listenerService.listenToUserBookings(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No active bookings'));
        }

        return ListView.builder(
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final booking = snapshot.data!.docs[index];
            return ListTile(
              title: Text('Parking: ${booking['parkingName']}'),
              subtitle: Text('Spot: ${booking['spotNumber']}'),
              trailing: Text('Status: ${booking['status']}'),
            );
          },
        );
      },
    );
  }
}

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class QRCodeScreen extends StatelessWidget {
  final int spotNumber;
  final String parkingId;
  final String bookingId;

  const QRCodeScreen({
    super.key,
    required this.spotNumber,
    required this.parkingId,
    required this.bookingId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0XFF0079C0),
      appBar: AppBar(
        backgroundColor: const Color(0XFF0079C0),
        title: const Text('Your Booking QR Code'),
      ),
      body: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(50),
            topRight: Radius.circular(50),
          ),
        ),
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('bookings')
              .doc(bookingId)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final bookingData = snapshot.data!.data() as Map<String, dynamic>?;
            if (bookingData == null) {
              return const Center(child: Text('Booking not found'));
            }

            final qrData = '$parkingId:$spotNumber:$bookingId';
            
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Spot Number: $spotNumber',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  size: 200.0,
                ),
                const SizedBox(height: 20),
                const Text(
                  'Show this QR code at the parking entrance',
                  textAlign: TextAlign.center,
                ),
                if (bookingData['status'] == 'used')
                  const Text(
                    'This QR code has been used',
                    style: TextStyle(color: Colors.red),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

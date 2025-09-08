import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:smart_parking/PayScreen/QRForPayment.dart';
import 'package:smart_parking/widget/CustomTiltle.dart';

class PaymentSuccessScreen extends StatelessWidget {
  final String parkingId;
  final String spotId;
  final double totalCost;

  const PaymentSuccessScreen({
    Key? key,
    required this.parkingId,
    required this.spotId,
    required this.totalCost,
  }) : super(key: key);

  Future<void> _handlePaymentCompletion(BuildContext context) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Must be authenticated');

      // Create batch for Firestore operations
      final batch = FirebaseFirestore.instance.batch();
      
      // 1. Clean up all existing QR codes for this spot
      final existingUserQRCodes = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('qrcodes')
          .where('spotId', isEqualTo: spotId)
          .where('parkingId', isEqualTo: parkingId)
          .get();

      final existingParkingQRCodes = await FirebaseFirestore.instance
          .collection('parking')
          .doc(parkingId)
          .collection('qrcodes')
          .where('spotId', isEqualTo: spotId)
          .get();

      // Delete all existing QR codes
      for (var doc in existingUserQRCodes.docs) {
        batch.delete(doc.reference);
      }
      for (var doc in existingParkingQRCodes.docs) {
        batch.delete(doc.reference);
      }

      // 2. Clean up any existing bookings
      final existingBookings = await FirebaseFirestore.instance
          .collection('bookings')
          .where('spotId', isEqualTo: spotId)
          .where('parkingId', isEqualTo: parkingId)
          .where('status', isEqualTo: 'active')
          .get();

      for (var doc in existingBookings.docs) {
        batch.update(doc.reference, {
          'status': 'completed',
          'lastUpdated': FieldValue.serverTimestamp(),
          'completedBy': 'payment',
          'paymentTimestamp': FieldValue.serverTimestamp()
        });
      }

      // 3. Update spot status in Realtime Database
      final spotRTDB = FirebaseDatabase.instance
          .ref('spots')
          .child(parkingId)
          .child(spotId);

      await spotRTDB.update({
        'status': 'available',
        'lastUpdated': ServerValue.timestamp,
        'lastPaymentId': user.uid,
        'occupiedSince': null,
        'lastAction': 'payment_completed',
        'lastBookingId': null,
        'lastUserId': null,
        'qrCode': null,
        'reservationData': null,
        'ignoreStatusUpdates': false
      });

      // 4. Update spot in Firestore
      final spotRef = FirebaseFirestore.instance
          .collection('parking')
          .doc(parkingId)
          .collection('spots')
          .doc(spotId);
          
      batch.update(spotRef, {
        'isAvailable': true,
        'lastUpdated': FieldValue.serverTimestamp(),
        'lastPaymentId': user.uid,
        'status': 'available',
        'lastBookingId': null,
        'lastUserId': null,
        'reservationData': FieldValue.delete(),
        'qrCodeData': FieldValue.delete()
      });

      // 5. Create payment record
      final paymentRef = FirebaseFirestore.instance.collection('payments').doc();
      batch.set(paymentRef, {
        'userId': user.uid,
        'parkingId': parkingId,
        'spotId': spotId,
        'amount': totalCost,
        'timestamp': FieldValue.serverTimestamp(),
        'method': 'credit_card',
        'status': 'completed',
        'type': 'payment',
        'clearedAccessAt': FieldValue.serverTimestamp()
      });

      // 6. Update parking availability
      final parkingRef = FirebaseFirestore.instance.collection('parking').doc(parkingId);
      batch.update(parkingRef, {
        'available': FieldValue.increment(1),
        'lastUpdated': FieldValue.serverTimestamp()
      });

      // Commit all Firestore changes
      await batch.commit();

      // Navigate to QR screen
      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => QRForPayment(
              parkingId: parkingId,
              spotId: spotId,
              moneyPaid: totalCost,
              paymentId: paymentRef.id,
            ),
          ),
        );
      }
    } catch (e) {
      print('Error completing payment: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'))
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0XFF0079C0),
      appBar: AppBar(
        title: const CustomTitle(text: "Payment Success", color: Colors.white, size: 32),
        centerTitle: true,
        backgroundColor: const Color(0XFF0079C0),
        toolbarHeight: 100,
        automaticallyImplyLeading: false,
      ),
      body: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(50),
              topRight: Radius.circular(50),
            ),
          ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 100,
              ),
              const SizedBox(height: 20),
              const Text(
                "Payment Successful!",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Total Paid: ${totalCost.toStringAsFixed(2)} TND",
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () => _handlePaymentCompletion(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0XFF0079C0),
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text(
                  "Get Exit QR Code",
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

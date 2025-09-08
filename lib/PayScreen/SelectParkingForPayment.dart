import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smart_parking/PayScreen/PayScreen.dart';
import 'package:smart_parking/services/payment_service.dart';
import 'package:smart_parking/widget/CustomTiltle.dart';
import 'package:firebase_database/firebase_database.dart';

class SelectParkingForPayment extends StatefulWidget {
  @override
  State<SelectParkingForPayment> createState() => _SelectParkingForPaymentState();
}

class _SelectParkingForPaymentState extends State<SelectParkingForPayment> {
  final PaymentService _paymentService = PaymentService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseDatabase _rtdb = FirebaseDatabase.instance;
  bool _isLoading = true;
  String _errorMessage = '';
  List<DocumentSnapshot> _activeBookings = [];

  @override
  void initState() {
    super.initState();
    _cleanupAndLoadBookings();
  }

  Future<void> _cleanupAndLoadBookings() async {
    try {
      setState(() => _isLoading = true);
      
      // Run cleanup with retry mechanism
      for (int i = 0; i < 3; i++) {
        try {
          await _paymentService.checkAndCleanupExpiredBookings();
          break;
        } catch (e) {
          if (i == 2) throw e;
          await Future.delayed(Duration(seconds: 1));
        }
      }
      
      await _loadActiveBookings();
    } catch (e) {
      print('Error in cleanup and load: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadActiveBookings() async {
    try {
      setState(() => _isLoading = true);
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) throw Exception('User not authenticated');

      // First get all bookings grouped by parking
      final bookingsQuery = await _firestore
          .collection('bookings')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'active')
          .get();

      // Group bookings by parking
      final parkingGroups = <String, List<DocumentSnapshot>>{};
      for (var doc in bookingsQuery.docs) {
        final parkingId = doc.data()['parkingId'] as String;
        parkingGroups.putIfAbsent(parkingId, () => []).add(doc);
      }

      // Process each parking group
      final processedBookings = <DocumentSnapshot>[];
      for (var entry in parkingGroups.entries) {
        final parkingDoc = await _firestore.collection('parking').doc(entry.key).get();
        // Check realtime status for each spot in this parking
        for (var booking in entry.value) {
          final spotNumber = (booking.data() as Map<String, dynamic>)['spotNumber'];
          final spotStatus = await _rtdb
              .ref('spots/${entry.key}/$spotNumber')
              .get();

          if (spotStatus.exists) {
            final statusData = spotStatus.value as Map<dynamic, dynamic>;
            // Only add spots that are currently occupied
            if (statusData['status'] == 'occupied' && 
                statusData['sensorDetected'] == true &&
                DateTime.now().difference(
                  DateTime.fromMillisecondsSinceEpoch(statusData['lastSensorUpdate'])
                ) >= Duration(minutes: 5)) {
              processedBookings.add(booking);
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _activeBookings = processedBookings;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _verifyAndProceed(DocumentSnapshot booking) async {
    try {
      setState(() => _isLoading = true);

      // Verify user presence
      final isPresent = await _paymentService.verifyUserPresence(
        booking['parkingId'],
        booking['spotNumber'],
      );

      if (!isPresent) {
        throw Exception('Please park your vehicle at spot ${booking['spotNumber']} before proceeding');
      }

      // Navigate to payment screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => PayScreen(bookingId: booking.id),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildBookingCard(DocumentSnapshot booking) {
    return StreamBuilder(
      stream: _rtdb
          .ref('spots/${booking['parkingId']}/${booking['spotNumber']}')
          .onValue,
      builder: (context, AsyncSnapshot snapshot) {
        if (snapshot.hasData && snapshot.data?.snapshot?.value != null) {
          final spotData = snapshot.data!.snapshot.value as Map<dynamic, dynamic>;
          final isOccupied = spotData['status'] == 'occupied' && spotData['sensorDetected'] == true;
          final duration = DateTime.now().difference(
            DateTime.fromMillisecondsSinceEpoch(spotData['lastSensorUpdate'])
          );

          return Card(
            margin: EdgeInsets.only(bottom: 15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: ListTile(
              contentPadding: EdgeInsets.all(15),
              title: Text(
                booking['parkingName'] ?? 'Unknown Parking',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Spot: ${booking['spotNumber']}'),
                  Text(
                    isOccupied && duration >= Duration(minutes: 5)
                        ? 'Status: Ready for payment'
                        : 'Status: Awaiting vehicle detection (${5 - duration.inMinutes} minutes remaining)',
                    style: TextStyle(
                      color: isOccupied ? Colors.green : Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              trailing: ElevatedButton(
                onPressed: isOccupied && duration >= Duration(minutes: 5)
                    ? () => _verifyAndProceed(booking)
                    : null,
                child: Text('Pay Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF0079C0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          );
        }
        return Card(
          child: ListTile(
            title: Text('Loading spot status...'),
            leading: CircularProgressIndicator(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0XFF0079C0),
      appBar: AppBar(
        title: CustomTitle(
          text: "Select Parking",
          color: Colors.white,
          size: 32,
        ),
        centerTitle: true,
        toolbarHeight: 100,
        backgroundColor: Color(0xff0079C0),
      ),
      body: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(50),
            topRight: Radius.circular(50),
          ),
        ),
        child: _isLoading
            ? Center(child: CircularProgressIndicator())
            : _activeBookings.isEmpty
                ? Center(
                    child: Text('No active bookings found'),
                  )
                : ListView.builder(
                    padding: EdgeInsets.all(20),
                    itemCount: _activeBookings.length,
                    itemBuilder: (context, index) {
                      final booking = _activeBookings[index];
                      return _buildBookingCard(booking);
                    },
                  ),
      ),
    );
  }
}

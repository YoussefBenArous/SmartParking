import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smart_parking/QRcode/QRCodeScreen.dart';
import 'package:uuid/uuid.dart';

class SpotSelectionScreen extends StatefulWidget {
  final String parkingId;
  final String parkingName;
  final Map<String, dynamic> parkingData;

  const SpotSelectionScreen({
    Key? key,
    required this.parkingId,
    required this.parkingName,
    required this.parkingData,
  }) : super(key: key);

  @override
  _SpotSelectionScreenState createState() => _SpotSelectionScreenState();
}

class _SpotSelectionScreenState extends State<SpotSelectionScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isBooking = false;

  Future<bool> _checkExistingBooking() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw 'Must be logged in to book spots';

      // Check specifically for active bookings in this parking
      final existingBookings = await _firestore
          .collection('bookings')
          .where('userId', isEqualTo: user.uid)
          .where('parkingId', isEqualTo: widget.parkingId)
          .where('status', isEqualTo: 'active')
          .get();

      if (existingBookings.docs.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('You already have an active booking in this parking'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ));
        }
        return false;
      }

      return true;
    } catch (e) {
      print('Error checking bookings: $e');
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    // Check for existing booking when screen opens
    _checkExistingBooking().then((canBook) {
      if (!canBook && mounted) {
        Navigator.pop(context);  // Return to previous screen if can't book
      }
    });
  }

  Future<void> _bookSpot(String spotId, String spotNumber) async {
    if (_isBooking) return;
    setState(() => _isBooking = true);

    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Must be logged in to book');

      final String bookingId = const Uuid().v4();
      final DateTime now = DateTime.now();

      // Create all required data
      final bookingData = {
        'parkingId': widget.parkingId,
        'spotId': spotId,
        'userId': user.uid,
        'status': 'active',
        'timestamp': now.toIso8601String(),
        'spotNumber': int.parse(spotNumber.replaceAll(RegExp(r'[^0-9]'), '')),
        'parkingName': widget.parkingName,
      };

      final qrData = {
        'parkingId': widget.parkingId,
        'parkingName': widget.parkingName,
        'spotNumber': int.parse(spotNumber.replaceAll(RegExp(r'[^0-9]'), '')),
        'bookingId': bookingId,
        'timestamp': now.toIso8601String(),
        'userId': user.uid,
        'qrData': jsonEncode({
          'bookingId': bookingId,
          'userId': user.uid,
          'timestamp': now.toIso8601String(),
        })
      };

      // Single atomic transaction
      await _firestore.runTransaction((transaction) async {
        // 1. Check spot availability
        final spotDoc = await transaction.get(
          _firestore.collection('parking').doc(widget.parkingId).collection('spots').doc(spotId)
        );

        if (!spotDoc.exists || !spotDoc.data()?['isAvailable']) {
          throw Exception('Spot is no longer available');
        }

        // 2. Check for existing bookings
        final existingBookings = await _firestore
            .collection('bookings')
            .where('userId', isEqualTo: user.uid)
            .where('parkingId', isEqualTo: widget.parkingId)
            .where('status', isEqualTo: 'active')
            .get();

        if (existingBookings.docs.isNotEmpty) {
          throw Exception('Already have an active booking in this parking');
        }

        // 3. Create booking
        final bookingRef = _firestore.collection('bookings').doc(bookingId);
        transaction.set(bookingRef, bookingData);

        // 4. Update spot
        transaction.update(spotDoc.reference, {
          'isAvailable': false,
          'lastUpdated': FieldValue.serverTimestamp(),
          'lastBookingId': bookingId,
          'lastUserId': user.uid,
          'lastAction': 'booked'
        });

        // 5. Update parking availability
        final parkingRef = _firestore.collection('parking').doc(widget.parkingId);
        transaction.update(parkingRef, {
          'available': FieldValue.increment(-1)
        });

        // 6. Create QR codes
        transaction.set(
          _firestore.collection('users').doc(user.uid).collection('qrcodes').doc(bookingId),
          qrData
        );

        transaction.set(
          _firestore.collection('parking').doc(widget.parkingId).collection('qrcodes').doc(bookingId),
          qrData
        );
      });

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => QRCodeScreen(
              spotNumber: int.parse(spotNumber.replaceAll(RegExp(r'[^0-9]'), '')),
              parkingId: widget.parkingId,
              bookingId: bookingId,
              parkingName: widget.parkingName,
              existingQRData: qrData,
            ),
          ),
        );
      }
    } catch (e) {
      print('Booking error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }

  Future<void> _handleSpotSelection(String spotId, String spotNumber) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw 'Must be logged in to book spots';

      // Create booking document with all required fields matching security rules
      final bookingData = {
        'userId': user.uid,
        'parkingId': widget.parkingId,
        'spotId': spotId,
        'spotNumber': spotNumber,
        'status': 'active',
        'timestamp': FieldValue.serverTimestamp(),
        'parkingName': widget.parkingName,
      };

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // Create the booking
        final bookingRef = FirebaseFirestore.instance
            .collection('bookings')
            .doc();

        // Check the spot first
        final spotDoc = await transaction.get(
          FirebaseFirestore.instance
            .collection('parking')
            .doc(widget.parkingId)
            .collection('spots')
            .doc(spotId)
        );

        if (!spotDoc.exists || !spotDoc.data()?['isAvailable']) {
          throw 'Spot is no longer available';
        }

        // Update spot with all required fields
        transaction.update(spotDoc.reference, {
          'isAvailable': false,
          'lastUpdated': FieldValue.serverTimestamp(),
          'lastBookingId': bookingRef.id,
          'lastUserId': user.uid,
          'lastAction': 'booked', // Add this required field
        });

        transaction.set(bookingRef, bookingData);

        // Update parking availability
        transaction.update(
          FirebaseFirestore.instance.collection('parking').doc(widget.parkingId),
          {
            'available': FieldValue.increment(-1)
          }
        );

        // Only proceed to QR code screen after successful transaction
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => QRCodeScreen(
                spotNumber: int.parse(spotNumber.replaceAll('P', '')),
                parkingId: widget.parkingId,
                bookingId: bookingRef.id,
                parkingName: widget.parkingName,
              ),
            ),
          );
        }
      });

    } catch (e) {
      print('Booking error: $e'); // Add detailed error logging
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String extractSpotNumber(dynamic number) {
    if (number is int) return number.toString();
    if (number is String) return number;
    return 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.parkingName)),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('parking').doc(widget.parkingId).collection('spots').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

          var spots = snapshot.data!.docs;
          if (spots.isEmpty) return Center(child: Text("No spots available"));

          return GridView.builder(
            padding: EdgeInsets.all(16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: spots.length,
            itemBuilder: (context, index) {
              var spot = spots[index].data() as Map<String, dynamic>;
              String spotNumber = extractSpotNumber(spot['number']);
              return GestureDetector(
                onTap: spot['isAvailable'] && !_isBooking 
                    ? () async {
                        final canBook = await _checkExistingBooking();
                        if (!canBook) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('You already have a booking in this parking'),
                            backgroundColor: Colors.red,
                          ));
                          return;
                        }
                        _bookSpot(spots[index].id, spotNumber);
                      }
                    : null,
                child: Container(
                  decoration: BoxDecoration(
                    color: spot['isAvailable'] ? Colors.green : Colors.grey,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      spotNumber,
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

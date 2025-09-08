import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:smart_parking/PayScreen/CalculTimeSpend.dart';
import 'package:smart_parking/Setting/Setting.dart';
import 'package:smart_parking/widget/CustomTiltle.dart';

class SelectParkingToPay extends StatefulWidget {
  const SelectParkingToPay({super.key});

  @override
  State<SelectParkingToPay> createState() => _SelectParkingToPayState();
}

class _SelectParkingToPayState extends State<SelectParkingToPay> {
  final DatabaseReference _spotsRef = FirebaseDatabase.instance.ref('spots');
  final DatabaseReference _parkingRef = FirebaseDatabase.instance.ref('parking');
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _occupiedSpots = [];
  StreamSubscription? _spotsListener;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchOccupiedSpots();
  }

  Future<void> _fetchOccupiedSpots() async {
    try {
      setState(() => _isLoading = true);
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // 1. First fetch all active bookings for the user
      final activeBookings = await _firestore
          .collection('bookings')
          .where('userId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'active')
          .get();

      List<Map<String, dynamic>> userSpots = [];

      // 2. Process each booking
      for (var booking in activeBookings.docs) {
        final bookingData = booking.data();
        final parkingId = bookingData['parkingId'];
        final spotId = bookingData['spotId'];

        try {
          // 3. Get parking details from Firestore
          final parkingDoc = await _firestore
              .collection('parking')
              .doc(parkingId)
              .get();

          if (!parkingDoc.exists) continue;
          final parkingData = parkingDoc.data()!;

          // 4. Get real-time spot status
          final spotSnapshot = await _spotsRef
              .child(parkingId)
              .child(spotId)
              .get();

          if (!spotSnapshot.exists) continue;
          final spotData = spotSnapshot.value as Map<dynamic, dynamic>;

          userSpots.add({
            'parkingId': parkingId,
            'spotId': spotId,
            'parkingName': parkingData['name'] ?? 'Unknown Parking',
            'spotNumber': spotData['number'] ?? 'Unknown',
            'status': spotData['status'] ?? 'unknown',
            'isOccupied': spotData['status'] == 'occupied',
            'lastUpdated': spotData['lastUpdated'],
            'bookingId': booking.id
          });
        } catch (e) {
          print('Error processing spot $parkingId/$spotId: $e');
        }
      }

      if (mounted) {
        setState(() {
          _occupiedSpots = userSpots;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _verifySpotAndInitiatePayment(Map<String, dynamic> spot) async {
    try {
      final spotSnapshot = await _spotsRef
          .child(spot['parkingId'])
          .child(spot['spotId'])
          .get();

      if (!spotSnapshot.exists) {
        _showErrorDialog('Spot data not found');
        return;
      }

      final spotData = spotSnapshot.value as Map<dynamic, dynamic>;
      final user = FirebaseAuth.instance.currentUser;
      
      // Check if spot is occupied and if it's occupied by the current user through lastUserId
      if (spotData['status'] != 'occupied' || spotData['lastUserId'] != user?.uid) {
        // Check for expired reservation
        final lastBookingId = spotData['lastBookingId'];
        if (lastBookingId != null) {
          final bookingSnapshot = await _firestore
              .collection('bookings')
              .doc(lastBookingId)
              .get();

          if (bookingSnapshot.exists) {
            final bookingData = bookingSnapshot.data()!;
            final expiryTime = (bookingData['expiryTime'] as Timestamp).toDate();
            
            // If booking has expired but user is present (status is occupied)
            if (DateTime.now().isAfter(expiryTime) && 
                spotData['status'] == 'occupied' && 
                spotData['lastUserId'] == user?.uid) {
              // Allow payment
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CalculeTimeSpend(
                    parkingId: spot['parkingId'],
                    spotId: spot['spotId'],
                  ),
                ),
              );
              return;
            }
          }
        }
        _showErrorDialog('This spot is not assigned to you or you haven\'t entered the parking yet');
        return;
      }

      // If all checks pass, proceed to payment
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CalculeTimeSpend(
            parkingId: spot['parkingId'],
            spotId: spot['spotId'],
          ),
        ),
      );

    } catch (e) {
      _showErrorDialog('Error verifying spot: ${e.toString()}');
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Verification Failed'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 48),
            SizedBox(height: 16),
            Text(message),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _spotsListener?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0XFF0079C0),
      appBar: AppBar(
        backgroundColor: const Color(0XFF0079C0),
        title: const CustomTitle(
          text: "Select The Spot To Pay",
          color: Colors.white,
          size: 25,
        ),
        centerTitle: true,
        toolbarHeight: 100,
        leading: IconButton(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SettingPage())),
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(50),
            topRight: Radius.circular(50),
          ),
        ),
        child: _buildContent(),
      ),
    );
    
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            _errorMessage!,
            style: const TextStyle(color: Colors.red, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_occupiedSpots.isEmpty) {
      return const Center(
        child: Text(
          'No occupied parking spots found',
          style: TextStyle(fontSize: 16),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _occupiedSpots.length,
      itemBuilder: (context, index) => _buildBookingCard(_occupiedSpots[index]),
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> spot) {
    final bool isOccupied = spot['isOccupied'] ?? false;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Parking: ${spot['parkingName']}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Spot Number: ${spot['spotNumber']}',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
                Icon(
                  isOccupied ? Icons.directions_car : Icons.no_crash_outlined,
                  color: isOccupied ? Colors.green : Colors.red,
                  size: 32,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              isOccupied ? 'Car Is On Parking' : 'Car Is Not On Parking',
              style: TextStyle(
                color: isOccupied ? Colors.green : Colors.red,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: isOccupied 
                    ? () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CalculeTimeSpend(
                            parkingId: spot['parkingId'],
                            spotId: spot['spotId'],
                          ),
                        ),
                      )
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isOccupied ? Colors.green : Colors.grey,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Pay Now'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
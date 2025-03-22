import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ParkingOwnerDashboard extends StatefulWidget {
  @override
  _ParkingOwnerDashboardState createState() => _ParkingOwnerDashboardState();
}

class _ParkingOwnerDashboardState extends State<ParkingOwnerDashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Map<String, dynamic>? parkingData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadParkingData();
  }

  Future<void> _loadParkingData() async {
    try {
      User? user = _auth.currentUser;
      if (user == null) return;

      QuerySnapshot parkingDocs = await _firestore
          .collection('parking')
          .where('ownerId', isEqualTo: user.uid)
          .get();

      if (parkingDocs.docs.isNotEmpty) {
        setState(() {
          parkingData = parkingDocs.docs.first.data() as Map<String, dynamic>;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading parking data: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (parkingData == null) {
      return Scaffold(
        body: Center(child: Text('No parking data found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Your Parking Dashboard'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      parkingData!['name'],
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text('Capacity: ${parkingData!['capacity']} spots'),
                    Text('Available: ${parkingData!['available']} spots'),
                    Text('Price: ${parkingData!['price']}'),
                    Text('Status: ${parkingData!['status'] ?? 'active'}'),
                  ],
                ),
              ),
            ),
            // Add more dashboard features here
          ],
        ),
      ),
    );
  }
}

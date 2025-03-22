import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ParkingScreen extends StatefulWidget {
  final String parkingId;
  final String parkingName;
  final Map<String, dynamic> parkingData;

  const ParkingScreen({
    Key? key, 
    required this.parkingId, 
    required this.parkingName,
    required this.parkingData,
  }) : super(key: key);

  @override
  State<ParkingScreen> createState() => _ParkingScreenState();
}

class _ParkingScreenState extends State<ParkingScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> _parkingSpots = [];
  bool _isLoading = true;
  String? _selectedSpotId;

  @override
  void initState() {
    super.initState();
    _loadParkingSpots();
  }

  Future<void> _loadParkingSpots() async {
    try {
      // Listen to spots in real-time
      final spotsStream = _firestore
          .collection('parking')
          .doc(widget.parkingId)
          .collection('spots')
          .orderBy('number')
          .snapshots();

      spotsStream.listen((snapshot) {
        if (!mounted) return;
        
        setState(() {
          _parkingSpots = snapshot.docs
              .map((doc) => {
                    'id': doc.id,
                    'number': doc.data()['number'] ?? '',
                    'isAvailable': doc.data()['isAvailable'] ?? false,
                    'type': doc.data()['type'] ?? 'standard',
                    'lastUpdated': doc.data()['lastUpdated'],
                  })
              .toList();
          _isLoading = false;
        });
      }, onError: (error) {
        print('Error loading parking spots: $error');
        setState(() => _isLoading = false);
      });
    } catch (e) {
      print('Error setting up spots listener: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _bookSpot() async {
    if (_selectedSpotId == null) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Must be logged in to book');

      await _firestore.runTransaction((transaction) async {
        // Verify parking availability first
        final parkingRef = _firestore.collection('parking').doc(widget.parkingId);
        final parkingDoc = await transaction.get(parkingRef);
        
        if (!parkingDoc.exists) throw Exception('Parking not found');
        
        final parkingData = parkingDoc.data()!;
        if (parkingData['available'] <= 0) throw Exception('No spots available');

        // Update spot status
        final spotRef = parkingRef.collection('spots').doc(_selectedSpotId);
        final spotDoc = await transaction.get(spotRef);
        
        if (!spotDoc.exists) throw Exception('Spot not found');
        if (!spotDoc.data()!['isAvailable']) throw Exception('Spot already taken');

        // Create booking with required fields
        final bookingRef = _firestore.collection('bookings').doc();
        final bookingData = {
          'parkingId': widget.parkingId,
          'spotId': _selectedSpotId,
          'userId': user.uid,
          'status': 'pending',
          'timestamp': FieldValue.serverTimestamp(),
        };
        
        transaction.set(bookingRef, bookingData);
        transaction.update(spotRef, {'isAvailable': false});
        transaction.update(parkingRef, {
          'available': FieldValue.increment(-1)
        });
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Spot booked successfully!'))
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Booking failed: $e'),
          backgroundColor: Colors.red,
        )
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.parkingName)),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.parkingName),
        backgroundColor: Color(0XFF0079C0),
      ),
      body: Column(
        children: [
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.all(16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
              ),
              itemCount: _parkingSpots.length,
              itemBuilder: (context, index) {
                final spot = _parkingSpots[index];
                final isSelected = spot['id'] == _selectedSpotId;
                final isAvailable = spot['isAvailable'];

                return GestureDetector(
                  onTap: isAvailable ? () {
                    setState(() => _selectedSpotId = spot['id']);
                  } : null,
                  child: Container(
                    decoration: BoxDecoration(
                      color: isAvailable 
                          ? (isSelected ? Colors.blue : Colors.green)
                          : Colors.red,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected ? Colors.white : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        spot['number'],
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: _selectedSpotId != null ? _bookSpot : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0XFF0079C0),
                minimumSize: Size(double.infinity, 50),
              ),
              child: Text('Book Selected Spot'),
            ),
          ),
        ],
      ),
    );
  }
}

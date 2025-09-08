import 'dart:convert';
import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smart_parking/QRcode/QRCodeScreen.dart';
import 'package:uuid/uuid.dart';
import '../services/firebase_service.dart';
import '../widgets/ParkingSlot.dart';
import '../HomePage/userpages/BookingPage.dart';

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
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final ParkingSpotService _spotService = ParkingSpotService();
  bool _isBooking = false;
  List<Timer> _periodicTimers = [];

  @override
  void initState() {
    super.initState();
    _initializeParkingSpots();
    _startCleanupTimer();
  }

  void _startCleanupTimer() {
    // Check for expired reservations every minute
    Timer.periodic(Duration(minutes: 1), (timer) {
      _checkAndCleanupExpiredSpots();
    });
  }

  Future<void> _checkAndCleanupExpiredSpots() async {
    try {
      await _spotService.cleanupExpiredReservations();
    } catch (e) {
      print('Error checking expired spots: $e');
    }
  }

  Future<void> _initializeParkingSpots() async {
    try {
      await _checkExistingBooking().then((canBook) {
        if (!canBook && mounted) {
          Navigator.pop(context);
          return;
        }
      });

      // Get parking details including capacity
      final parkingDoc = await _firestore
          .collection('parking')
          .doc(widget.parkingId)
          .get();

      if (!parkingDoc.exists) {
        throw Exception('Parking not found');
      }

      final capacity = parkingDoc.data()?['capacity'] ?? 0;

      // Initialize spots in both databases
      await _spotService.initializeSpots(widget.parkingId, capacity);

      // Verify initialization
      final spotsSnapshot = await _firestore
          .collection('parking')
          .doc(widget.parkingId)
          .collection('spots')
          .get();

      if (spotsSnapshot.docs.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error initializing parking spots')));
        Navigator.pop(context);
        return;
      }

    } catch (e) {
      print('Error initializing parking spots: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading parking spots')));
        Navigator.pop(context);
      }
    }
  }

  Future<bool> _checkExistingBooking() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw 'Must be logged in to book spots';

      // Check for any active bookings in this parking
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
          ));
          Navigator.pop(context); // Return to previous screen
        }
        return false;
      }

      // Check total active bookings across all parkings
      final allActiveBookings = await _firestore
          .collection('bookings')
          .where('userId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'active')
          .get();

      if (allActiveBookings.docs.length >= 3) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('You have reached the maximum limit of 3 active bookings'),
            backgroundColor: Colors.red,
          ));
          Navigator.pop(context);
        }
        return false;
      }

      return true;
    } catch (e) {
      print('Error checking bookings: $e');
      return false;
    }
  }

  Future<void> _bookSpot(String spotId, String spotNumber) async {
    if (_isBooking) return;
    setState(() => _isBooking = true);

    try {
      final User? user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Must be logged in to book');

      // Check both Realtime Database and Firestore for spot availability
      final spotRealtimeSnapshot = await _database
          .ref('spots/${widget.parkingId}/$spotId')
          .get();
      
      final spotFirestoreSnapshot = await _firestore
          .collection('parking')
          .doc(widget.parkingId)
          .collection('spots')
          .doc(spotId)
          .get();

      // Verify spot is available in both databases
      bool isAvailableRealtime = spotRealtimeSnapshot.value != null &&
          (spotRealtimeSnapshot.value as Map)['status'] == 'available' &&
          !((spotRealtimeSnapshot.value as Map)['ignoreStatusUpdates'] ?? false);

      bool isAvailableFirestore = spotFirestoreSnapshot.exists &&
          spotFirestoreSnapshot.data()?['isAvailable'] == true;

      if (!isAvailableRealtime || !isAvailableFirestore) {
        throw Exception('Spot is no longer available');
      }

      // Lock the spot in both databases
      final batch = _firestore.batch();

      // Update Realtime Database
      await _database
          .ref('spots/${widget.parkingId}/$spotId')
          .update({
            'status': 'reserved',
            'lastUserId': user.uid,
            'lastUpdated': ServerValue.timestamp,
            'ignoreStatusUpdates': true, // Prevent sensor updates during reservation
          });

      // Update Firestore spot
      final spotRef = _firestore
          .collection('parking')
          .doc(widget.parkingId)
          .collection('spots')
          .doc(spotId);

      batch.update(spotRef, {
        'status': 'reserved',
        'isAvailable': false,
        'lastUserId': user.uid,
        'lastUpdated': FieldValue.serverTimestamp(),
        'ignoreStatusUpdates': true
      });

      await batch.commit();

      // Navigate to booking screen
      final bookingResult = await Navigator.push<Map<String, dynamic>>(
        context,
        MaterialPageRoute(
          builder: (context) => BookingPage(
            slotId: spotId,
            slotName: spotNumber,
            parkingId: widget.parkingId,
            parkingName: widget.parkingName,
          ),
        ),
      );

      if (bookingResult == null || bookingResult['success'] != true) {
        // Reset spot status if booking failed
        await Future.wait([
          _database
              .ref('spots/${widget.parkingId}/$spotId')
              .update({
                'status': 'available',
                'lastUserId': null,
                'lastUpdated': ServerValue.timestamp,
                'ignoreStatusUpdates': false
              }),
          spotRef.update({
            'status': 'available',
            'isAvailable': true,
            'lastUserId': null,
            'lastUpdated': FieldValue.serverTimestamp(),
            'ignoreStatusUpdates': false
          })
        ]);
      }
    } catch (e) {
      print('Error booking spot: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', '')),
          backgroundColor: Colors.red,
        ));
      }
      // Reset spot status on error
      await Future.wait([
        _database
            .ref('spots/${widget.parkingId}/$spotId')
            .update({
              'status': 'available',
              'lastUserId': null,
              'lastUpdated': ServerValue.timestamp,
              'ignoreStatusUpdates': false
            }),
        _firestore
            .collection('parking')
            .doc(widget.parkingId)
            .collection('spots')
            .doc(spotId)
            .update({
              'status': 'available',
              'isAvailable': true,
              'lastUserId': null,
              'lastUpdated': FieldValue.serverTimestamp(),
              'ignoreStatusUpdates': false
            })
      ]);
    } finally {
      if (mounted) setState(() => _isBooking = false);
    }
  }

  Future<bool> _isSpotOccupied(String spotId) async {
    try {
      final results = await Future.wait([
        // Check active bookings
        _firestore
            .collection('bookings')
            .where('spotId', isEqualTo: spotId)
            .where('parkingId', isEqualTo: widget.parkingId)
            .where('status', isEqualTo: 'active')
            .get(),
        // Check realtime database status
        _database.ref('spots/${widget.parkingId}/$spotId').get(),
      ]);

      final activeBookings = results[0] as QuerySnapshot;
      final realtimeStatus = results[1] as DataSnapshot;

      if (activeBookings.docs.isNotEmpty) return true;
      
      if (realtimeStatus.exists) {
        final spotData = Map<String, dynamic>.from(realtimeStatus.value as Map);
        return spotData['status'] == 'occupied' || 
               spotData['status'] == 'reserved' ||
               (spotData['lastUserId'] != null && spotData['lastUserId'].toString().isNotEmpty);
      }

      return false;
    } catch (e) {
      print('Error checking spot occupation: $e');
      return false;
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
      backgroundColor: Color(0XFF0079C0),
      appBar: AppBar(title: Text(widget.parkingName,style: TextStyle(fontSize: 32,color: Colors.white),
      ),
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      centerTitle: true,
      backgroundColor: Color(0XFF0079C0),
      toolbarHeight: 100,
      ),
      body: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(50),
            topRight: Radius.circular(50),
          ),
        ),
        child: StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('parking')
              .doc(widget.parkingId)
              .collection('spots')
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return Center(child: CircularProgressIndicator());
            }
        
            return StreamBuilder<DatabaseEvent>(
              stream: _database.ref('spots/${widget.parkingId}').onValue,
              builder: (context, realtimeSnapshot) {
                return StreamBuilder<QuerySnapshot>(
                  stream: _firestore
                      .collection('bookings')
                      .where('parkingId', isEqualTo: widget.parkingId)
                      .where('status', isEqualTo: 'active')
                      .snapshots(),
                  builder: (context, bookingsSnapshot) {
                    var spots = snapshot.data!.docs;
                    Map<String, dynamic>? realtimeData;
                    Map<String, dynamic> bookingsMap = {};
        
                    // Process realtime data
                    if (realtimeSnapshot.hasData && realtimeSnapshot.data?.snapshot.value != null) {
                      realtimeData = Map<String, dynamic>.from(realtimeSnapshot.data!.snapshot.value as Map);
                    }
        
                    // Process bookings data
                    if (bookingsSnapshot.hasData) {
                      for (var doc in bookingsSnapshot.data!.docs) {
                        final data = doc.data() as Map<String, dynamic>;
                        if (data['spotId'] != null) {
                          bookingsMap[data['spotId']] = data;
                        }
                      }
                    }
        
                    return GridView.builder(
                      padding: EdgeInsets.all(16),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.5,
                      ),
                      itemCount: spots.length,
                      itemBuilder: (context, index) {
                        var spot = spots[index].data() as Map<String, dynamic>;
                        String spotId = spots[index].id;
        
                        bool isOccupied = false;
                        DateTime? reservationExpiry;
        
                        // Check realtime status
                        if (realtimeData != null && realtimeData[spotId] != null) {
                          final realtimeSpot = realtimeData[spotId];
                          isOccupied = realtimeSpot['status'] == 'occupied' ||
                                     realtimeSpot['status'] == 'reserved';
                        }
        
                        // Check bookings
                        if (bookingsMap.containsKey(spotId)) {
                          isOccupied = true;
                          final booking = bookingsMap[spotId];
                          if (booking['expiryTime'] != null) {
                            reservationExpiry = (booking['expiryTime'] as Timestamp).toDate();
                          }
                        }
        
                        return ParkingSlot(
                          slotName: spot['number'],
                          slotId: spotId,
                          isBooked: isOccupied,
                          isReserved: isOccupied,
                          time: '',
                          onTap: isOccupied ? null : () => _bookSpot(spotId, spot['number']),
                          reservationExpiry: reservationExpiry,
                        );
                      },
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Cancel any active timers
    for (var timer in _periodicTimers) {
      timer.cancel();
    }
    super.dispose();
  }
}

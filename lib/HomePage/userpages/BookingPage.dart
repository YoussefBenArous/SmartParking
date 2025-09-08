import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smart_parking/QRcode/QRCodeScreen.dart';
import 'package:uuid/uuid.dart';
import 'package:firebase_database/firebase_database.dart';

class BookingPage extends StatefulWidget {
  final String slotId;
  final String slotName;
  final String parkingId;
  final String parkingName;

  const BookingPage({
    Key? key,
    required this.slotId,
    required this.slotName,
    required this.parkingId,
    required this.parkingName,
  }) : super(key: key);

  @override
  State<BookingPage> createState() => _BookingPageState();
}

class _BookingPageState extends State<BookingPage> {
  DateTime? selectedTime;
  bool isLoading = false;
  String? userName;
  final int maxWaitingHours = 3; // Maximum waiting time in hours

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userData = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        setState(() {
          userName = userData.get('name');
        });
      }
    } catch (e) {
      print('Error loading user name: $e');
    }
  }

  Future<void> _selectTime() async {
    final now = DateTime.now();
    final maxTime = now.add(Duration(hours: 3));
    
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (BuildContext context, Widget? child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );

    if (time != null) {
      final selectedDateTime = DateTime(
        now.year,
        now.month,
        now.day,
        time.hour,
        time.minute,
      );

      if (selectedDateTime.isBefore(now)) {
        // If selected time is before now, assume it's for tomorrow
        selectedDateTime.add(Duration(days: 1));
      }

      if (selectedDateTime.isAfter(maxTime)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please select a time within the next 3 hours'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() {
        selectedTime = selectedDateTime;
      });
    }
  }

  Future<void> makeReservation() async {
    if (selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select arrival time')),
      );
      return;
    }

    final now = DateTime.now();
    final maxTime = now.add(Duration(hours: 3));
    
    if (selectedTime!.isAfter(maxTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Selected time must be within 3 hours from now'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Must be logged in');

      final bookingId = const Uuid().v4();
      final now = DateTime.now();

      // Create booking data with all required fields
      final bookingData = {
        'bookingId': bookingId,
        'parkingId': widget.parkingId,
        'spotId': widget.slotId,
        'userId': user.uid,
        'userName': userName ?? 'User',
        'status': 'active',
        'arrivalTime': Timestamp.fromDate(selectedTime!),
        'createdAt': Timestamp.fromDate(now),
        'spotNumber':
            int.parse(widget.slotName.replaceAll(RegExp(r'[^0-9]'), '')),
        'parkingName': widget.parkingName,
        'expiryTime':
            Timestamp.fromDate(selectedTime!.add(Duration(minutes: 30))),
        'timestamp': Timestamp.now(),
      };

      // Use a batch write for atomic operation
      final batch = FirebaseFirestore.instance.batch();

      // Create booking document
      final bookingRef =
          FirebaseFirestore.instance.collection('bookings').doc(bookingId);
      batch.set(bookingRef, bookingData);

      // Update spot status
      final spotRef = FirebaseFirestore.instance
          .collection('parking')
          .doc(widget.parkingId)
          .collection('spots')
          .doc(widget.slotId);
      batch.update(spotRef, {
        'isAvailable': false,
        'lastBookingId': bookingId,
        'lastUserId': user.uid,
        'lastUpdated': FieldValue.serverTimestamp(),
        'expiryTime': Timestamp.fromDate(selectedTime!), // Add expiryTime
        'status': 'reserved'
      });

      // Save to Realtime Database
      final DatabaseReference realtimeRef = FirebaseDatabase.instance.ref();
      await realtimeRef
          .child('spots')
          .child(widget.parkingId)
          .child(widget.slotId)
          .update({
            'isAvailable': false,
            'lastBookingId': bookingId,
            'lastUserId': user.uid,
            'lastUpdated': ServerValue.timestamp,
            'expiryTime': selectedTime!.toIso8601String(), // Add expiryTime
            'status': 'reserved'
          });

      await batch.commit();

      // Return success and navigate to QR code screen
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => QRCodeScreen(
              spotNumber:
                  int.parse(widget.slotName.replaceAll(RegExp(r'[^0-9]'), '')),
              parkingId: widget.parkingId,
              bookingId: bookingId,
              parkingName: widget.parkingName,
              arrivalTime: selectedTime,
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Booking failed: $e')),
      );
      Navigator.pop(context, {'success': false});
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0XFF0079C0),
      extendBody: true,
      appBar: AppBar(
        backgroundColor: const Color(0XFF0079C0),
        centerTitle: true,
        toolbarHeight: 100,
        title: Text(
          'Select Arrival Time',
          style: TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontStyle: FontStyle.normal,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(50),
            topRight: Radius.circular(50),
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(50),
            child: Column(
              children: [
                Card(
                  child: Padding(
                    padding: EdgeInsets.all(30),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Spot Details',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 10),
                        Text(
                          'Parking: ${widget.parkingName}',
                          style: TextStyle(
                            fontSize: 20,
                            color: Colors.black,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        Text(
                          'Spot: ${widget.slotName}',
                          style: TextStyle(
                            fontSize: 20,
                            color: Colors.black,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        if (userName != null) Text('Booked by: $userName'),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 24),
                Text(
                  'Select your arrival time:',
                  style: TextStyle(fontSize: 18,color: Colors.black,fontStyle: FontStyle.italic,),
                ),
                SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _selectTime,
                  icon: Icon(Icons.access_time),
                  label: Text(
                    selectedTime != null
                        ? 'Selected: ${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}'
                        : 'Select Time',
                  ),
                ),
                if (selectedTime != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      'Booking will expire at ${(selectedTime!.add(Duration(minutes: 30))).hour.toString().padLeft(2, '0')}:${(selectedTime!.add(Duration(minutes: 30))).minute.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ),
                Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : makeReservation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xff0079C0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: isLoading
                        ? CircularProgressIndicator(color: Colors.white)
                        : Text(
                            'Confirm Booking',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

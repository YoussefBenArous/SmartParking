import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:smart_parking/HomePage/userpages/UserHome.dart';
import 'package:smart_parking/widget/CustomTiltle.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart'; // Add this import

class QRCodeScreen extends StatefulWidget {
  final int spotNumber;
  final String parkingId;
  final String bookingId;
  final String parkingName;
  final Map<String, dynamic>? existingQRData;
  final DateTime? arrivalTime; // Add this

  const QRCodeScreen({
    Key? key,
    required this.spotNumber,
    required this.parkingId,
    required this.bookingId,
    required this.parkingName,
    this.existingQRData,
    this.arrivalTime, // Add this
  }) : super(key: key);

  @override
  State<QRCodeScreen> createState() => _QRCodeScreenState();
}

class _QRCodeScreenState extends State<QRCodeScreen> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _verifiedData;

  @override
  void initState() {
    super.initState();
    if (widget.existingQRData != null) {
      setState(() {
        _verifiedData = widget.existingQRData;
        _isLoading = false;
      });
    } else {
      _verifyAndLoadData();
    }
  }

  Future<void> _uploadQRCode() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) throw 'User not authenticated';

      final qrDocRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('qrcodes')
          .doc(widget.bookingId); // Use bookingId as QR document ID

      await qrDocRef.set(_verifiedData!); // Store the verified QR data

      print('QR Code data uploaded successfully');
    } catch (e) {
      print('Error uploading QR Code: $e');
    }
  }

  Future<void> _verifyAndLoadData() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) throw 'User not authenticated';

      // Get booking data to verify and get expiry time
      final bookingDoc = await FirebaseFirestore.instance
          .collection('bookings')
          .doc(widget.bookingId)
          .get();

      if (!bookingDoc.exists) throw 'Booking not found';

      final bookingData = bookingDoc.data()!;
      final expiryTime = (bookingData['expiryTime'] as Timestamp).toDate();

      // Create structured QR data
      final qrData = {
        'bookingId': widget.bookingId,
        'parkingId': widget.parkingId,
        'spotNumber': widget.spotNumber,
        'userId': userId,
        'type': 'entry',
        'status': 'active',
        'timestamp': ServerValue.timestamp,
        'expiryTime': expiryTime.millisecondsSinceEpoch,
      };

      // Save to Realtime Database under qrcode/parkingId/spotNumber
      final realtimeDb = FirebaseDatabase.instance;
      final qrRef = realtimeDb
          .ref()
          .child('qrcode')
          .child(widget.parkingId)
          .child(widget.spotNumber.toString());

      await qrRef.set(qrData);

      // Listen for changes in the Realtime Database
      qrRef.onValue.listen((event) {
        if (event.snapshot.value != null && mounted) {
          final data = Map<String, dynamic>.from(event.snapshot.value as Map);
          setState(() {
            _verifiedData = {
              ...data,
              'parkingName': widget.parkingName,
            };
          });
        }
      });

      if (mounted) {
        setState(() {
          _verifiedData = {
            ...qrData,
            'parkingName': widget.parkingName,
          };
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error generating QR code: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  String _generateQRData() {
    try {
      if (_verifiedData == null) return '';
      
      // Ensure only required fields are included in QR code
      final qrContent = {
        'bookingId': _verifiedData!['bookingId'],
        'parkingId': _verifiedData!['parkingId'],
        'spotNumber': _verifiedData!['spotNumber'],
        'userId': _verifiedData!['userId'],
        'type': _verifiedData!['type'],
        'status': _verifiedData!['status'],
        'expiryTime': _verifiedData!['expiryTime'],
      };
      return jsonEncode(qrContent);
    } catch (e) {
      print('Error generating QR data: $e');
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0XFF0079C0),
      extendBody: true,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: Colors.white,
          ),
          onPressed: () {
             Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => HomePage(),
                ),
              );
          },
        ),
      
        backgroundColor: const Color(0XFF0079C0),
        title: CustomTitle(
          text: 'QR Code',
          color: Colors.white,
          size: 32,
        ),
        centerTitle: true,
        toolbarHeight: 100,
      ),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(50),
            topRight: Radius.circular(50),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.only(top: 70),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red, fontSize: 16),
                      ),
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Text(
                          widget.parkingName,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Spot ${_verifiedData?['spotNumber'] ?? widget.spotNumber}',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 20),
                        Card(
                          elevation: 4,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: QrImageView(
                              data: _generateQRData(),
                              version: QrVersions.auto,
                              size: 200.0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'This QR Code is your Parking Pass',
                          style: TextStyle(fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
        ),
      ),
    );
  }
}
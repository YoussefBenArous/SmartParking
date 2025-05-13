import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:smart_parking/HomePage/userpages/UserHome.dart';
import 'package:smart_parking/widget/CustomTiltle.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';

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

      // Create basic QR data without any server-side fields
      final qrData = {
        'parkingId': widget.parkingId,
        'parkingName': widget.parkingName,
        'spotNumber': widget.spotNumber,
        'bookingId': widget.bookingId,
        'timestamp': DateTime.now().toIso8601String(),
        'userId': userId,
      };

      // Generate QR content separately
      final qrContent = {
        'bookingId': widget.bookingId,
        'userId': userId,
        'timestamp': DateTime.now().toIso8601String(),
        'spotNumber': widget.spotNumber,
        'parkingId': widget.parkingId,
      };

      // Add encoded QR data
      qrData['qrData'] = jsonEncode(qrContent);

      // Save to Firestore
      final batch = FirebaseFirestore.instance.batch();

      // User QR
      final userQRRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('qrcodes')
          .doc(widget.bookingId);
      batch.set(userQRRef, qrData);

      // Parking QR
      final parkingQRRef = FirebaseFirestore.instance
          .collection('parking')
          .doc(widget.parkingId)
          .collection('qrcodes')
          .doc(widget.bookingId);
      batch.set(parkingQRRef, qrData);

      await batch.commit();

      if (mounted) {
        setState(() {
          _verifiedData = qrData;
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
      // Only include essential data for the QR code
      final qrContent = {
        'bookingId': _verifiedData!['bookingId'],
        'userId': _verifiedData!['userId'],
        'timestamp': _verifiedData!['timestamp'],
        'spotNumber': _verifiedData!['spotNumber'],
        'parkingId': _verifiedData!['parkingId'],
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
          icon: const Icon(Icons.arrow_back),
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

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:smart_parking/widget/CustomTiltle.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';

class QRCodeScreen extends StatefulWidget {
  final int spotNumber;
  final String parkingId;
  final String bookingId;
  final String parkingName;
  final Map<String, dynamic>? existingQRData; // Add this line

  const QRCodeScreen({
    Key? key,
    required this.spotNumber,
    required this.parkingId,
    required this.bookingId,
    required this.parkingName,
    this.existingQRData, // Add this line
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

    // Match required fields from security rules
    final qrData = {
      'parkingId': widget.parkingId,
      'parkingName': widget.parkingName,
      'spotNumber': widget.spotNumber,
      'bookingId': widget.bookingId,
      'timestamp': DateTime.now().toIso8601String(),
      'userId': userId,
      'qrData': jsonEncode({
        'bookingId': widget.bookingId,
        'userId': userId,
        'timestamp': DateTime.now().toIso8601String(),
      })
    };

    // Save QR data according to security rules
    final batch = FirebaseFirestore.instance.batch();
    
    batch.set(
      FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('qrcodes')
        .doc(widget.bookingId),
      qrData
    );

    batch.set(
      FirebaseFirestore.instance
        .collection('parking')
        .doc(widget.parkingId)
        .collection('qrcodes')
        .doc(widget.bookingId),
      qrData
    );

    await batch.commit();

    if (mounted) {
      setState(() {
        _verifiedData = qrData;
        _isLoading = false;
      });
    }
  } catch (e) {
    if (mounted) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }
}

  String _generateQRData() {
    return jsonEncode(_verifiedData);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0XFF0079C0),
      appBar: AppBar(
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

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:smart_parking/HomePage/userpages/UserHome.dart';
import 'package:smart_parking/widget/CustomTiltle.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';

class QRForPayment extends StatefulWidget {
  final String parkingId;
  final String spotId;
  final double moneyPaid;
  final String paymentId;

  const QRForPayment({
    Key? key,
    required this.parkingId,
    required this.spotId,
    required this.moneyPaid,
    required this.paymentId,
  }) : super(key: key);

  @override
  State<QRForPayment> createState() => _QRCodeScreenState();
}

class _QRCodeScreenState extends State<QRForPayment> {
  bool _isLoading = true;
  String? _error;
  Map<String, dynamic>? _verifiedData;
  bool _isExpiring = false;
  Timer? _expiryTimer;
  Timer? _cleanupTimer;
  StreamSubscription? _qrSubscription;

  @override
  void initState() {
    super.initState();
    _verifyAndLoadData();
    _setupExpiryTimers();
  }

  void _setupExpiryTimers() {
    // Warning timer - 45 minutes
    _expiryTimer = Timer(Duration(minutes: 45), () {
      if (mounted) {
        setState(() => _isExpiring = true);
      }
    });

    // Cleanup timer - 1 hour
    _cleanupTimer = Timer(Duration(hours: 1), _deleteQRCode);
  }

  Future<void> _verifyAndLoadData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw 'User not authenticated';
      }

      print('User authenticated: ${user.uid}');
      print('ParkingId: ${widget.parkingId}, SpotId: ${widget.spotId}');

      final expiryTime = DateTime.now().add(Duration(hours: 1));

      // Create structured QR data with all required fields matching the rules
      final qrData = {
        'parkingId': widget.parkingId,
        'spotId': widget.spotId,
        'userId': user.uid,
        'type': 'payment_exit',
        'expiryTime': expiryTime.millisecondsSinceEpoch,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'status': 'active',
        'paymentId': widget.paymentId,
        'moneyPaid': widget.moneyPaid,
      };

      print('Attempting to save QR data: $qrData');

      // Save to specific path in Realtime Database
      final realtimeDb = FirebaseDatabase.instance;
      final qrRef = realtimeDb
          .ref()
          .child('payment_qrcodes')
          .child(widget.parkingId)
          .child(widget.spotId);

      // Delete any existing QR code for this spot first
      await qrRef.remove();

      // Then set the new data
      await qrRef.set(qrData);
      print('QR data saved successfully');

      // Set initial data
      setState(() {
        _verifiedData = qrData;
        _isLoading = false;
        _error = null;
      });

      // Listen for realtime updates
      _qrSubscription = qrRef.onValue.listen(
        (event) {
          if (event.snapshot.value != null && mounted) {
            final data = Map<String, dynamic>.from(event.snapshot.value as Map);
            setState(() {
              _verifiedData = data;
            });
          }
        },
        onError: (error) {
          print('Error listening to QR updates: $error');
          if (mounted) {
            setState(() {
              _error = _getReadableError(error.toString());
            });
          }
        },
      );
    } catch (e) {
      print('Error generating payment QR: $e');
      setState(() {
        _error = _getReadableError(e.toString());
        _isLoading = false;
      });
    }
  }

  String _getReadableError(String error) {
    if (error.contains('permission-denied') ||
        error.contains('PERMISSION_DENIED')) {
      return 'Permission denied. Please check your Firebase security rules.';
    } else if (error.contains('network-request-failed')) {
      return 'Network error. Please check your internet connection.';
    } else if (error.contains('User not authenticated')) {
      return 'Please sign in to generate QR code.';
    }
    return 'Failed to generate QR code. Please try again.';
  }

  Future<void> _cleanupQRCode(String paymentId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await Future.wait([
        // Delete from Firestore
        FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('payment_qrcodes')
            .doc(paymentId)
            .delete(),

        // Delete from Realtime DB
        FirebaseDatabase.instance
            .ref('payment_qrcodes')
            .child(widget.parkingId)
            .child(widget.spotId)
            .remove()
      ]);
    } catch (e) {
      print('Error cleaning up QR code: $e');
    }
  }

  Future<void> _deleteOldQRCodes() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      // Find old bookings for this spot
      final oldBookings = await FirebaseFirestore.instance
          .collection('bookings')
          .where('userId', isEqualTo: userId)
          .where('parkingId', isEqualTo: widget.parkingId)
          .where('spotId', isEqualTo: widget.spotId)
          .get();

      // Delete old QR codes
      for (var doc in oldBookings.docs) {
        // Delete from user's QR codes
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('qrcodes')
            .doc(doc.id)
            .delete();

        // Delete from parking QR codes
        await FirebaseFirestore.instance
            .collection('parking')
            .doc(widget.parkingId)
            .collection('qrcodes')
            .doc(doc.id)
            .delete();

        // Delete from Realtime Database
        await FirebaseDatabase.instance
            .ref('qrcodes')
            .child(widget.parkingId)
            .child(widget.spotId)
            .remove();
      }
    } catch (e) {
      print('Error deleting old QR codes: $e');
    }
  }

  String _generateQRData() {
    try {
      if (_verifiedData == null) return '';

      // Ensure all required fields are included in QR code
      return jsonEncode({
        'parkingId': _verifiedData!['parkingId'],
        'spotId': _verifiedData!['spotId'],
        'userId': _verifiedData!['userId'],
        'type': _verifiedData!['type'],
        'expiryTime': _verifiedData!['expiryTime'],
        'timestamp': _verifiedData!['timestamp'],
        'status': _verifiedData!['status'],
        'paymentId': _verifiedData!['paymentId'],
        'moneyPaid': _verifiedData!['moneyPaid'],
      });
    } catch (e) {
      print('Error generating QR data: $e');
      return '';
    }
  }

  Future<void> _deleteQRCode() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) return;

      // Delete from payments collection
      await FirebaseFirestore.instance
          .collection('payments')
          .where('parkingId', isEqualTo: widget.parkingId)
          .where('spotId', isEqualTo: widget.spotId)
          .where('userId', isEqualTo: userId)
          .get()
          .then((snapshot) {
        for (var doc in snapshot.docs) {
          doc.reference.delete();
        }
      });

      // Delete from realtime database
      await FirebaseDatabase.instance
          .ref('payment_qrcodes')
          .child(widget.parkingId)
          .child(widget.spotId)
          .remove();

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomePage()),
        );
      }
    } catch (e) {
      print('Error deleting QR code: $e');
    }
  }

  Future<void> _retryGeneration() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    await _verifyAndLoadData();
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
      body: Center(
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(50),
              topRight: Radius.circular(50),
            ),
          ),
          child: Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 70),
                  child: _isLoading
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text('Generating QR Code...'),
                            ],
                          ),
                        )
                      : _error != null
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    size: 64,
                                    color: Colors.red,
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    _error!,
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 16,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  SizedBox(height: 24),
                                  ElevatedButton(
                                    onPressed: _retryGeneration,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0XFF0079C0),
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Payment QR Code',
                                  style: Theme.of(context).textTheme.titleLarge,
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
                                      backgroundColor: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                const Text(
                                  'Show this QR code to the attendant',
                                  style: TextStyle(fontSize: 16),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Amount Paid: \$${widget.moneyPaid.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0XFF0079C0),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'This QR code will expire in 1 hour',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (_isExpiring) ...[
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.red),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.warning, color: Colors.red),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'QR Code will expire soon! Please use it within 15 minutes.',
                                            style: TextStyle(color: Colors.red),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    _cleanupTimer?.cancel();
    _qrSubscription?.cancel();
    super.dispose();
  }
}

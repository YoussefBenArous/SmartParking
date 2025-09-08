import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:smart_parking/HomePage/userpages/UserHome.dart';
import 'package:smart_parking/QRcode/QRCodeScreen.dart';
import 'package:smart_parking/widget/CustomTiltle.dart';

class MultiQRCode extends StatefulWidget {
  const MultiQRCode({super.key});

  @override
  State<MultiQRCode> createState() => _MultiQRCodeState();
}

class _MultiQRCodeState extends State<MultiQRCode> {
  List<Map<String, dynamic>> _userQRCodes = [];
  bool _isLoading = true;
  final _firestore = FirebaseFirestore.instance;
  final user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _loadUserQRCodes();
  }

  Future<void> _loadUserQRCodes() async {
    try {
      if (user == null) throw Exception('Must be logged in to view QR codes');

      // Wait for all bookings query
      final bookingsQuery = await _firestore
          .collection('bookings')
          .where('userId', isEqualTo: user?.uid)
          .where('status', isEqualTo: 'active')
          .get();

      final parkingBookings = <String, List<Map<String, dynamic>>>{};

      // Process each booking
      for (var bookingDoc in bookingsQuery.docs) {
        final bookingData = bookingDoc.data();
        final parkingId = bookingData['parkingId'] as String;
        
        // Get QR code from both user and parking collections
        final userQrQuery = await _firestore
            .collection('users')
            .doc(user?.uid)
            .collection('qrcodes')
            .doc(bookingDoc.id)
            .get();

        final parkingQrQuery = await _firestore
            .collection('parking')
            .doc(parkingId)
            .collection('qrcodes')
            .doc(bookingDoc.id)
            .get();

        // Use either QR code data that exists
        final qrData = userQrQuery.exists ? userQrQuery.data() : 
                      parkingQrQuery.exists ? parkingQrQuery.data() : null;

        if (bookingData['expiryTime'] != null && 
            (bookingData['expiryTime'] as Timestamp).toDate().isBefore(DateTime.now())) {
          await _cancelExpiredBooking(bookingDoc.id, bookingData);
          continue;
        }

        final booking = {
          'bookingId': bookingDoc.id,
          'spotNumber': bookingData['spotNumber'],
          'parkingName': bookingData['parkingName'] ?? 'Unknown Parking',
          'parkingId': parkingId,
          'hasQR': qrData != null,
          'qrData': qrData,
          'timestamp': bookingData['createdAt'],
          'arrivalTime': bookingData['arrivalTime'],
          'expiryTime': bookingData['expiryTime'],
          'spotId': bookingData['spotId'],
        };

        parkingBookings
            .putIfAbsent(parkingId, () => [])
            .add(booking);
      }

      // Update UI
      if (mounted) {
        setState(() {
          _userQRCodes = parkingBookings.entries.map((entry) {
            return {
              'parkingId': entry.key,
              'parkingName': entry.value.first['parkingName'],
              'bookings': entry.value,
            };
          }).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading QR codes: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _cancelExpiredBooking(String bookingId, Map<String, dynamic> bookingData) async {
    try {
      final batch = _firestore.batch();

      // Update spot status in Firestore
      final spotRef = _firestore
          .collection('parking')
          .doc(bookingData['parkingId'])
          .collection('spots')
          .doc(bookingData['spotId']);
      
      batch.update(spotRef, {
        'isAvailable': true,
        'lastUpdated': FieldValue.serverTimestamp(),
        'status': 'available'
      });

      // Update booking status
      final bookingRef = _firestore.collection('bookings').doc(bookingId);
      batch.update(bookingRef, {
        'status': 'cancelled',
        'cancelReason': 'expired',
        'cancelledAt': FieldValue.serverTimestamp()
      });

      // Delete QR codes
      final userQRRef = _firestore
          .collection('users')
          .doc(user?.uid)
          .collection('qrcodes')
          .doc(bookingId);
      batch.delete(userQRRef);

      final parkingQRRef = _firestore
          .collection('parking')
          .doc(bookingData['parkingId'])
          .collection('qrcodes')
          .doc(bookingId);
      batch.delete(parkingQRRef);

      await batch.commit();
    } catch (e) {
      print('Error cancelling expired booking: $e');
    }
  }

  Widget _buildBookingCard(Map<String, dynamic> booking) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Spot ${booking['spotNumber']}'),
            const SizedBox(height: 8),
            if (booking['hasQR'])
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => QRCodeScreen(
                        spotNumber: booking['spotNumber'],
                        parkingId: booking['parkingId'],
                        bookingId: booking['bookingId'],
                        parkingName: booking['parkingName'],
                        existingQRData: booking['qrData'],
                        arrivalTime: booking['arrivalTime']?.toDate(),
                      ),
                    ),
                  );
                },
                child: const Text('View QR Code'),
              )
            else
              ElevatedButton(
                onPressed: () => _generateQRCode(booking),
                child: const Text('Generate QR Code'),
              ),
            Text(
              'Arrival: ${_formatTimestamp(booking['arrivalTime'])}',
              style: const TextStyle(fontSize: 12),
            ),
            Text(
              'Expires: ${_formatTimestamp(booking['expiryTime'])}',
              style: const TextStyle(fontSize: 12, color: Colors.red),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParkingSection(Map<String, dynamic> parkingData) {
    return Card(
      margin: const EdgeInsets.all(8),
      color: Colors.white.withOpacity(0.9),
      child: ExpansionTile(
        title: Text(
          parkingData['parkingName'],
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        children: (parkingData['bookings'] as List<Map<String, dynamic>>)
            .map((booking) => _buildBookingCard(booking))
            .toList(),
      ),
    );
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'N/A';
    final date = timestamp.toDate(); // Convert Timestamp to DateTime
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute}';
  }

  Future<void> _generateQRCode(Map<String, dynamic> booking) async {
    try {
      final qrScreen = QRCodeScreen(
        spotNumber: booking['spotNumber'],
        parkingId: booking['parkingId'],
        bookingId: booking['bookingId'],
        parkingName: booking['parkingName'],
        arrivalTime: booking['arrivalTime']?.toDate(),
      );

      // Refresh the list after generating QR code
      await Navigator.push(context, MaterialPageRoute(builder: (context) => qrScreen));
      _loadUserQRCodes();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating QR code: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0XFF0079C0),
      extendBody: true,
      appBar: AppBar(
        title: const CustomTitle(
          text: 'QR Code',
          color: Colors.white,
          size: 32,
        ),
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => HomePage()),
          ),
          icon: const Icon(
            Icons.arrow_back,
            color: Colors.white,
          ),
        ),
        toolbarHeight: 100,
        backgroundColor: const Color(0XFF0079C0),
      ),
      body: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(50),
            topRight: Radius.circular(50),
          ),
        ),
        child: RefreshIndicator(
          onRefresh: _loadUserQRCodes,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.black))
              : Container(
                  padding: const EdgeInsets.all(16),
                  child: _userQRCodes.isEmpty
                      ? const Center(
                          child: Text(
                            "No active QR codes found",
                            style: TextStyle(color: Colors.black, fontSize: 16),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _userQRCodes.length,
                          itemBuilder: (context, index) =>
                              _buildParkingSection(_userQRCodes[index]),
                        ),
                ),
        ),
      ),
    );
  }
}
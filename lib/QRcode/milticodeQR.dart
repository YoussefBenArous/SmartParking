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

      // Query only active bookings as per rules
      final bookingsSnapshot = await _firestore
          .collection('bookings')
          .where('userId', isEqualTo: user?.uid)
          .where('status', isEqualTo: 'active')
          .get();

      final parkingBookings = <String, List<Map<String, dynamic>>>{};

      final futures = bookingsSnapshot.docs.map((doc) async {
        final data = doc.data();
        final parkingId = data['parkingId'];

        // User QR codes - matches rule: allow read if request.auth.uid == userId
        final qrDoc = await _firestore
            .collection('users')
            .doc(user?.uid)
            .collection('qrcodes')
            .doc(doc.id)
            .get();

        final parkingDoc = await _firestore.collection('parking').doc(parkingId).get();

        if (parkingDoc.exists) {
          // Convert timestamp if it exists, otherwise use current time
          final timestamp = data['timestamp'] is Timestamp 
              ? data['timestamp'] as Timestamp
              : Timestamp.now();

          parkingBookings.putIfAbsent(parkingId, () => []).add({
            'bookingId': doc.id,
            'spotNumber': data['spotNumber'],
            'parkingName': data['parkingName'],
            'parkingId': parkingId,
            'hasQR': qrDoc.exists,
            'qrData': qrDoc.data(),
            'timestamp': timestamp, // Use the converted timestamp
          });
        }
      }).toList();

      await Future.wait(futures);

      final organizedBookings = parkingBookings.entries.map((entry) {
        return {
          'parkingId': entry.key,
          'parkingName': entry.value.first['parkingName'],
          'bookings': entry.value,
        };
      }).toList();

      if (mounted) {
        setState(() {
          _userQRCodes = organizedBookings;
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

  Widget _buildBookingCard(Map<String, dynamic> booking) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text('Spot ${booking['spotNumber']}'),
            const SizedBox(height: 8),
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
                    ),
                  ),
                );
              },
              child: const Text('View QR Code'),
            ),
            Text(
              'Booked: ${_formatTimestamp(booking['timestamp'])}',
              style: const TextStyle(fontSize: 12),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0XFF0079C0),
      appBar: AppBar(
        title: const CustomTitle(
          text: 'QR Codes',
          color: Colors.white,
          size: 32,
        ),
        centerTitle: true,
        leading: IconButton(
          onPressed: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => HomePage()),
          ),
          icon: const Icon(Icons.arrow_back),
        ),
        toolbarHeight: 100,
        backgroundColor: const Color(0XFF0079C0),
      ),
      body: RefreshIndicator(
        onRefresh: _loadUserQRCodes,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : Container(
                padding: const EdgeInsets.all(16),
                child: _userQRCodes.isEmpty
                    ? const Center(
                        child: Text(
                          "No active QR codes found",
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _userQRCodes.length,
                        itemBuilder: (context, index) =>
                            _buildParkingSection(_userQRCodes[index]),
                      ),
              ),
      ),
    );
  }
}
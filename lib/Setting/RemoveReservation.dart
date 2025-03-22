import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:smart_parking/Setting/Setting.dart';
import 'package:smart_parking/widget/CustomTiltle.dart';

class RemoveReservation extends StatefulWidget {
  const RemoveReservation({super.key});

  @override
  State<RemoveReservation> createState() => _RemoveReservationState();
}

class _RemoveReservationState extends State<RemoveReservation> {
  List<Map<String, dynamic>> _userBookings = [];
  bool _isLoading = true;
  final _firestore = FirebaseFirestore.instance;
  final user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _fetchUserReservations();
  }

  Future<void> _fetchUserReservations() async {
    try {
      if (!mounted) return;
      setState(() => _isLoading = true);

      if (user == null) throw Exception('User must be logged in to view reservations');

      final bookingsSnapshot = await _firestore
          .collection('bookings')
          .where('userId', isEqualTo: user?.uid)
          .where('status', isEqualTo: 'active')
          .get();

      final parkingBookings = <String, List<Map<String, dynamic>>>{};

      final futures = bookingsSnapshot.docs.map((doc) async {
        final data = doc.data();
        final parkingId = data['parkingId'];

        // Get parking details
        final parkingDoc = await _firestore
            .collection('parking')
            .doc(parkingId)
            .get();

        if (parkingDoc.exists) {
          parkingBookings.putIfAbsent(parkingId, () => []).add({
            'bookingId': doc.id,
            'parkingId': parkingId,
            'parkingName': data['parkingName'],
            'spotNumber': data['spotNumber'],
            'spotId': data['spotId'],
            'timestamp': data['timestamp'],
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
          _userBookings = organizedBookings;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching reservations: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _deleteReservation(Map<String, dynamic> booking) async {
    try {
      final batch = _firestore.batch();

      // Follow cancellation flow required by rules
      final bookingRef = _firestore.collection('bookings').doc(booking['bookingId']);
      
      // First mark as cancelled (required by rules)
      await bookingRef.update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'cancelledBy': user?.uid,
      });

      // Then update related documents after status change
      batch.update(
        _firestore
          .collection('parking')
          .doc(booking['parkingId'])
          .collection('spots')
          .doc(booking['spotId']),
        {
          'isAvailable': true,
          'lastUpdated': FieldValue.serverTimestamp(),
          'lastBookingId': booking['bookingId'],
          'lastUserId': user?.uid,
          'lastAction': 'cancelled'
        }
      );

      batch.delete(
        _firestore
          .collection('users')
          .doc(user?.uid)
          .collection('qrcodes')
          .doc(booking['bookingId'])
      );

      batch.delete(
        _firestore
          .collection('parking')
          .doc(booking['parkingId'])
          .collection('qrcodes')
          .doc(booking['bookingId'])
      );

      await batch.commit();

      // Delete booking only after successful cancellation
      await bookingRef.delete();

      await _fetchUserReservations();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reservation cancelled and removed successfully')),
        );
      }
    } catch (e) {
      print('Error cancelling reservation: $e');
      if (mounted) {
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Spot ${booking['spotNumber']}'),
            const SizedBox(height: 8),
            Text('Booked: ${_formatTimestamp(booking['timestamp'])}'),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  onPressed: () => _deleteReservation(booking),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Cancel'),
                ),
              ],
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

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    if (timestamp is Timestamp) {
      final date = timestamp.toDate();
      return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute}';
    }
    return 'Invalid date';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0XFF0079C0),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Color(0XFF0079C0),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => SettingPage()),
          ),
        ),
        title: CustomTitle(
          text: "Reservations",
          color: Colors.white,
          size: 32,
        ),
        centerTitle: true,
        toolbarHeight: 100,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Colors.white))
          : Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: _userBookings.isEmpty
                  ? Center(
                      child: Text(
                        "No active reservations found.",
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _userBookings.length,
                      itemBuilder: (context, index) =>
                          _buildParkingSection(_userBookings[index]),
                    ),
            ),
    );
  }
}

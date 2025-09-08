import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smart_parking/Setting/parkingSetting.dart';
import 'package:smart_parking/widget/CustomTiltle.dart';
import 'package:smart_parking/HomePage/parkingownerPages/userDetaile.dart';

class ModifyReservation extends StatefulWidget {
  final String parkingId;
  final String parkingName;
  final Map<String, dynamic> parkingData;

  const ModifyReservation({
    Key? key,
    required this.parkingId,
    required this.parkingName,
    required this.parkingData,
  }) : super(key: key);

  @override
  State<ModifyReservation> createState() => _ModifyReservationState();
}

class _ModifyReservationState extends State<ModifyReservation> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  List<Map<String, dynamic>> _activeReservations = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadActiveReservations();
  }

  Future<void> _loadActiveReservations() async {
    try {
      setState(() => _isLoading = true);

      // Get all active bookings for this parking
      final bookingsSnapshot = await _firestore
          .collection('bookings')
          .where('parkingId', isEqualTo: widget.parkingId)
          .where('status', isEqualTo: 'active')
          .get();

      List<Map<String, dynamic>> reservations = [];

      for (var doc in bookingsSnapshot.docs) {
        try {
          final bookingData = doc.data();
          final parkingId = bookingData['parkingId'];
          final spotId = bookingData['spotId'];

          // Get user details
          final userDoc = await _firestore
              .collection('users')
              .doc(bookingData['userId'])
              .get();

          // Get spot details from Realtime Database
          final spotSnapshot = await _database
              .child('spots')
              .child(parkingId)
              .child(spotId)
              .get();

          if (!spotSnapshot.exists) continue;
          final spotData = Map<String, dynamic>.from(spotSnapshot.value as Map);

          // Get payment data
          final paymentQuery = await _firestore
              .collection('payments')
              .where('spotId', isEqualTo: spotId)
              .where('userId', isEqualTo: bookingData['userId'])
              .orderBy('timestamp', descending: true)
              .limit(1)
              .get();

          final reservation = {
            'id': doc.id,
            'userId': bookingData['userId'],
            'userName': userDoc.data()?['name'] ?? 'Unknown',
            'parkingId': parkingId,
            'spotId': spotId,
            'spotNumber': bookingData['spotNumber'],
            'entryTime': spotData['occupiedSince'] ?? spotData['lastUpdated'],
            'status': spotData['status'] ?? 'unknown',
            'amount': paymentQuery.docs.isNotEmpty 
                ? paymentQuery.docs.first.data()['amount'] 
                : 0.0,
            'paymentStatus': paymentQuery.docs.isNotEmpty 
                ? paymentQuery.docs.first.data()['status'] 
                : 'pending'
          };

          reservations.add(reservation);
        } catch (e) {
          print('Error processing booking: $e');
        }
      }

      setState(() {
        _activeReservations = reservations;
        _isLoading = false;
      });

    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _navigateToUserDetails(Map<String, dynamic> booking) {
    try {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => UserDetails(
            userId: booking['userId'],
            userName: booking['userName'] ?? 'Unknown',
            spotId: booking['spotId'],
            parkingId: booking['parkingId'],
            spotNumber: booking['spotNumber']?.toString() ?? 'Unknown',
            bookingId: booking['id'],
            status: booking['status'] ?? 'unknown',
          ),
        ),
      );
    } catch (e) {
      print('Error navigating to user details: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  Future<void> _showUserDetails(Map<String, dynamic> reservation) async {
    try {
      // Get user details
      final userDoc = await _firestore
          .collection('users')
          .doc(reservation['userId'])
          .get();

      // Get payment status
      final paymentDoc = await _firestore
          .collection('payments')
          .where('parkingId', isEqualTo: reservation['parkingId'])
          .where('spotId', isEqualTo: reservation['spotId'])
          .where('userId', isEqualTo: reservation['userId'])
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) {
          return Container(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'User Details',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0XFF0079C0),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                Divider(thickness: 1),
                _buildDetailRow(
                  'Name',
                  userDoc.data()?['name'] ?? 'N/A',
                  Icons.person,
                ),
                _buildDetailRow(
                  'Email',
                  userDoc.data()?['email'] ?? 'N/A',
                  Icons.email,
                ),
                _buildDetailRow(
                  'Spot',
                  'SPOT_${reservation['spotNumber']}',
                  Icons.local_parking,
                ),
                _buildDetailRow(
                  'Payment Status',
                  paymentDoc.docs.isNotEmpty ? 
                    paymentDoc.docs.first.data()['status'].toUpperCase() : 
                    'PENDING',
                  Icons.payment,
                  color: paymentDoc.docs.isNotEmpty && 
                         paymentDoc.docs.first.data()['status'] == 'completed' ?
                         Colors.green : Colors.orange,
                ),
                if (paymentDoc.docs.isNotEmpty)
                  _buildDetailRow(
                    'Amount Paid',
                    '${paymentDoc.docs.first.data()['amount']} TND',
                    Icons.attach_money,
                  ),
                _buildDetailRow(
                  'Duration',
                  _calculateDuration(reservation['timestamp']),
                  Icons.timer,
                ),
                SizedBox(height: 20),
                if (paymentDoc.docs.isEmpty)
                  Center(
                    child: ElevatedButton(
                      onPressed: () => _showPaymentReminder(reservation),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                      ),
                      child: Text('Send Payment Reminder'),
                    ),
                  ),
              ],
            ),
          );
        },
      );
    } catch (e) {
      print('Error showing user details: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading user details')),
      );
    }
  }

  Widget _buildDetailRow(String label, String value, IconData icon, {Color? color}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color ?? Colors.grey[600], size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: color ?? Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _calculateDuration(Timestamp timestamp) {
    final now = DateTime.now();
    final start = timestamp.toDate();
    final duration = now.difference(start);

    if (duration.inHours < 1) {
      return '${duration.inMinutes} minutes';
    } else if (duration.inDays < 1) {
      return '${duration.inHours} hours';
    } else {
      return '${duration.inDays} days';
    }
  }

  Future<void> _showPaymentReminder(Map<String, dynamic> reservation) async {
    // Here you would implement the payment reminder functionality
    // For example, sending a notification to the user
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Payment reminder sent to user')),
    );
    Navigator.pop(context);
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    
    try {
      if (timestamp is Timestamp) {
        final date = timestamp.toDate();
        return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute}';
      } else if (timestamp is int) {
        final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
        return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute}';
      }
      return 'Invalid date';
    } catch (e) {
      print('Error formatting timestamp: $e');
      return 'N/A';
    }
  }

  Widget _buildBookingCard(Map<String, dynamic> booking) {
    final entryTimestamp = booking['entryTime'];
    final DateTime? entryTime = entryTimestamp != null 
        ? DateTime.fromMillisecondsSinceEpoch(entryTimestamp)
        : null;

    return Card(
      margin: const EdgeInsets.all(12),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Stack(
        children: [
          // Delete Button
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              icon: Icon(Icons.close, color: Colors.red),
              onPressed: () => _showDeleteConfirmation(booking),
            ),
          ),

          // Entry Time Badge
          if (entryTime != null)
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue),
                ),
                child: Text(
                  'Entry: ${entryTime.hour.toString().padLeft(2, '0')}:${entryTime.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    color: Colors.blue[700],
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),

          // Main Content
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking['userName'] ?? 'Unknown User',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 8),
                Text(
                  'Spot ${booking['spotNumber']}',
                  style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                ),
                SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: booking['status'] == 'occupied' 
                            ? Colors.green.withOpacity(0.1)
                            : Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        booking['status']?.toUpperCase() ?? 'UNKNOWN',
                        style: TextStyle(
                          color: booking['status'] == 'occupied' 
                              ? Colors.green[700]
                              : Colors.orange[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _navigateToUserDetails(booking),
                      icon: Icon(Icons.info_outline),
                      label: Text('Details'),
                      style: TextButton.styleFrom(foregroundColor: Colors.blue),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(Map<String, dynamic> booking) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Reservation'),
        content: Text('Are you sure you want to delete this reservation?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteReservation(booking);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteReservation(Map<String, dynamic> booking) async {
    try {
      // First update booking status to cancelled
      await _firestore
          .collection('bookings')
          .doc(booking['bookingId'])
          .update({
            'status': 'cancelled',
            'cancelledAt': FieldValue.serverTimestamp(),
            'cancelledBy': 'admin'
          });

      // Then update spot availability
      await Future.wait([
        _firestore
            .collection('parking')
            .doc(booking['parkingId'])
            .collection('spots')
            .doc(booking['spotId'])
            .update({
              'isAvailable': true,
              'lastUpdated': FieldValue.serverTimestamp(),
            }),
        
        _database
            .child('spots')
            .child(booking['parkingId'])
            .child(booking['spotId'])
            .update({
              'status': 'available',
              'lastUpdated': ServerValue.timestamp,
            })
      ]);

      // Refresh the list
      await _loadActiveReservations();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting reservation: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0XFF0079C0),
      appBar: AppBar(
        title: CustomTitle(
          text: "Modify Resevation",
          color: Colors.white,
          size: 32,
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back,color: Colors.white,),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const OwnerSetting(),
              ),
            );
          },
        ),
        centerTitle: true,
        backgroundColor: const Color(0XFF0079C0),
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
        child: _isLoading
            ? Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Text(_error!, style: TextStyle(color: Colors.red)))
                : _activeReservations.isEmpty
                    ? Center(child: Text('No active reservations'))
                    : ListView.builder(
                        padding: EdgeInsets.all(16),
                        itemCount: _activeReservations.length,
                        itemBuilder: (context, index) {
                          final reservation = _activeReservations[index];
                          return _buildBookingCard(reservation);
                        },
                      ),
      ),
    );
  }
}

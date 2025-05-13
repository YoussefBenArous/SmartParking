import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:smart_parking/widget/card.dart';

class ParkingOwnerDashboard extends StatefulWidget {
  @override
  _ParkingOwnerDashboardState createState() => _ParkingOwnerDashboardState();
}

class _ParkingOwnerDashboardState extends State<ParkingOwnerDashboard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Map<String, dynamic>? parkingData;
  List<Map<String, dynamic>> _recentTransactions = [];
  Map<String, double> _monthlyStats = {};
  bool _isLoading = true;
  StreamSubscription? _realtimeSubscription;
  StreamSubscription? _firestoreSubscription;
  final _scrollController = ScrollController();
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
    _setupScrollListener();
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (_scrollController.position.pixels <= -100 && !_isRefreshing) {
        _refreshData();
      }
    });
  }

  Future<void> _refreshData() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);

    await Future.wait(
        [_loadParkingData(), _loadTransactions(), _loadMonthlyStats()]);

    setState(() => _isRefreshing = false);
  }

  Future<void> _initializeData() async {
    await _loadParkingData();
    _setupRealtimeUpdates();
    _setupFirestoreUpdates();
  }

  void _setupRealtimeUpdates() {
    final user = _auth.currentUser;
    if (user == null || parkingData == null) return;

    _realtimeSubscription?.cancel();
    _realtimeSubscription =
        _database.ref('spots/${parkingData!['id']}').onValue.listen((event) {
      if (event.snapshot.value != null) {
        _updateRealtimeStats(event.snapshot.value as Map<dynamic, dynamic>);
      }
    });
  }

  void _setupFirestoreUpdates() {
    final user = _auth.currentUser;
    if (user == null || parkingData == null) return;

    _firestoreSubscription?.cancel();
    _firestoreSubscription = _firestore
        .collection('bookings')
        .where('parkingId', isEqualTo: parkingData!['id'])
        .snapshots()
        .listen((snapshot) {
      _updateFirestoreStats(snapshot.docs);
    });
  }

  void _updateRealtimeStats(Map<dynamic, dynamic> spotsData) {
    int occupied = 0;
    int available = 0;

    spotsData.forEach((key, value) {
      if (value['status'] == 'occupied') {
        occupied++;
      } else if (value['status'] == 'available') {
        available++;
      }
    });

    if (mounted) {
      setState(() {
        if (parkingData != null) {
          parkingData!['realtime_occupied'] = occupied;
          parkingData!['realtime_available'] = available;
        }
      });
    }
  }

  void _updateFirestoreStats(List<QueryDocumentSnapshot> bookings) {
    double totalRevenue = 0;
    int activeBookings = 0;

    for (var booking in bookings) {
      final data = booking.data() as Map<String, dynamic>;
      if (data['status'] == 'completed') {
        totalRevenue += double.parse(data['amount'].toString());
      }
      if (data['status'] == 'active') {
        activeBookings++;
      }
    }

    if (mounted) {
      setState(() {
        if (parkingData != null) {
          parkingData!['total_revenue'] = totalRevenue;
          parkingData!['active_bookings'] = activeBookings;
        }
      });
    }
  }

  Future<void> _loadParkingData() async {
    try {
      User? user = _auth.currentUser;
      if (user == null) return;

      QuerySnapshot parkingDocs = await _firestore
          .collection('parking')
          .where('ownerId', isEqualTo: user.uid)
          .get();

      if (parkingDocs.docs.isNotEmpty) {
        setState(() {
          parkingData = parkingDocs.docs.first.data() as Map<String, dynamic>;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading parking data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadTransactions() async {
    try {
      final bookings = await _firestore
          .collection('bookings')
          .where('parkingId', isEqualTo: parkingData?['id'])
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      setState(() {
        _recentTransactions = bookings.docs.map((doc) {
          final data = doc.data();
          return {
            'amount': parkingData?['price'] ?? '0',
            'type': data['status'] == 'completed' ? 'Credit' : 'Pending',
            'date': (data['createdAt'] as Timestamp).toDate(),
          };
        }).toList();
      });
    } catch (e) {
      print('Error loading transactions: $e');
    }
  }

  Future<void> _loadMonthlyStats() async {
    try {
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);

      final bookings = await _firestore
          .collection('bookings')
          .where('parkingId', isEqualTo: parkingData?['id'])
          .where('createdAt', isGreaterThanOrEqualTo: monthStart)
          .get();

      final Map<int, int> dailyBookings = {};

      for (var doc in bookings.docs) {
        final date = (doc.data()['createdAt'] as Timestamp).toDate();
        final day = date.day;
        dailyBookings[day] = (dailyBookings[day] ?? 0) + 1;
      }

      setState(() {
        _monthlyStats = Map.fromEntries(dailyBookings.entries
            .map((e) => MapEntry(e.key.toString(), e.value.toDouble())));
      });
    } catch (e) {
      print('Error loading monthly stats: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0XFF0079C0),
      appBar: _buildAppBar(),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Container(
            height: constraints.maxHeight,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(50),
                topRight: Radius.circular(50),
              ),
            ),
            child: RefreshIndicator(
              onRefresh: _refreshData,
              child: _isLoading
                  ? _buildLoadingView()
                  : SingleChildScrollView(
                      controller: _scrollController,
                      physics: AlwaysScrollableScrollPhysics(),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: _buildDashboard(),
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Color(0XFF0079C0),
      elevation: 0,
      automaticallyImplyLeading:
          false, // to not add the arrow back button automatic
      title: const Text(
        'Dashboard',
        style: TextStyle(
          color: Colors.white,
          fontSize: 30,
          fontStyle: FontStyle.normal,
        ),
      ),
      centerTitle: true,
      toolbarHeight: 100,
    );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: CircularProgressIndicator(
        valueColor:
            AlwaysStoppedAnimation<Color>(Color.fromARGB(255, 164, 52, 0)),
      ),
    );
  }

  Widget _buildDashboard() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 20),
            _buildStatCards(),
            SizedBox(height: 20),
            _buildChartSection(),
            SizedBox(height: 20),
            _buildRecentTransactions(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCards() {
    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.3,
      physics: NeverScrollableScrollPhysics(),
      children: [
        BuildStatCard(
          title: 'Current Occupancy',
          value:
              '${parkingData?['realtime_occupied'] ?? 0}/${parkingData?['capacity'] ?? 0}',
          image: "assets/images/car.png",
        ),
        BuildStatCard(
          title: 'Available Now',
          value: '${parkingData?['realtime_available'] ?? 0}',
          icon: Icons.check_circle_outline,
          color: Colors.green,
        ),
        BuildStatCard(
          title: 'Active Bookings',
          value: '${parkingData?['active_bookings'] ?? 0}',
          icon: Icons.timer,
          color: Colors.orange,
        ),
        BuildStatCard(
          title: 'Today\'s Revenue',
          value: 'TND${_calculateTodayRevenue()}',
          image: "assets/images/TND.png",
          imageheight: 100,
          imagewidth: 100,
          color: Colors.purple,
        ),
      ],
    );
  }

  Widget _buildChartSection() {
    return Card(
      elevation: 4,
      shadowColor: Colors.black26,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Monthly Activity',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20),
            Container(
              height: 200,
              child: _buildActivityChart(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityChart() {
    // Implement your chart here using fl_chart or charts_flutter
    return Center(child: Text('Activity Chart'));
  }

  Widget _buildRecentTransactions() {
    return Card(
      elevation: 4,
      shadowColor: Colors.black26,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Transactions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            ListView.builder(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: _recentTransactions.length,
              itemBuilder: (context, index) {
                final transaction = _recentTransactions[index];
                return _buildTransactionItem(transaction);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionItem(Map<String, dynamic> transaction) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: transaction['type'] == 'Credit'
            ? Colors.green.withOpacity(0.1)
            : Colors.orange.withOpacity(0.1),
        child: Icon(
          transaction['type'] == 'Credit'
              ? Icons.arrow_downward
              : Icons.arrow_upward,
          color: transaction['type'] == 'Credit' ? Colors.green : Colors.orange,
        ),
      ),
      title: Text(
        '\$${transaction['amount']}',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        _formatDate(transaction['date']),
        style: TextStyle(color: Colors.grey),
      ),
      trailing: Text(
        transaction['type'],
        style: TextStyle(
          color: transaction['type'] == 'Credit' ? Colors.green : Colors.orange,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _calculateTodayRevenue() {
    return _recentTransactions
        .where(
            (t) => t['date'].day == DateTime.now().day && t['type'] == 'Credit')
        .fold(0.0, (sum, t) => sum + double.parse(t['amount'].toString()))
        .toStringAsFixed(2);
  }

  @override
  void dispose() {
    _realtimeSubscription?.cancel();
    _firestoreSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }
}

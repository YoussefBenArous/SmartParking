import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:smart_parking/widget/card.dart';
import 'package:smart_parking/widget/drawer.dart';

class ParkingOwnerDashboard extends StatefulWidget {
  @override
  _ParkingOwnerDashboardState createState() => _ParkingOwnerDashboardState();
}

class _ParkingOwnerDashboardState extends State<ParkingOwnerDashboard> {
  // Firebase Services
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Data State
  Map<String, dynamic>? parkingData;
  List<Map<String, dynamic>> _recentTransactions = [];
  Map<String, double> _monthlyStats = {};
  Map<String, dynamic> _dailyStats = {};
  Map<String, dynamic> _occupancyStats = {};
  List<FlSpot> _revenueData = [];
  Map<int, double> _hourlyRevenue = {};
  Map<int, int> _hourlyOccupancy = {};

  // Metrics
  double _todaysTotalRevenue = 0.0;
  int _availableSpots = 0;
  int _occupiedSpots = 0;
  int _parkingCapacity = 0;
  double _maxRevenue = 0;
  double _occupancyRate = 0.0;

  // UI State
  bool _isLoading = true;
  bool _isRefreshing = false;
  final _scrollController = ScrollController();

  // Subscriptions
  StreamSubscription? _realtimeSubscription;
  StreamSubscription? _firestoreSubscription;
  StreamSubscription? _paymentsSubscription;
  StreamSubscription? _availabilitySubscription;
  StreamSubscription? _occupiedSpotsSubscription;
  Timer? _statsTimer;

  @override
  void initState() {
    super.initState();
    _initializeDashboard();
    _setupScrollListener();
  }

  Future<void> _initializeDashboard() async {
    try {
      await _loadParkingData();
      if (parkingData != null) {
        await Future.wait([
          _loadTransactions(),
          _loadMonthlyStats(),
          _loadRevenueData(),
          _loadHourlyData(),
        ]);
        _setupRealtimeListeners();
        _setupRealtimeAnalytics();
      }
    } catch (e) {
      _showErrorSnackbar('Failed to initialize dashboard: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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

    try {
      await _initializeDashboard();
    } catch (e) {
      _showErrorSnackbar('Refresh failed: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  void _setupRealtimeListeners() {
    final parkingId = parkingData?['id'];
    if (parkingId == null) return;

    // Realtime spot availability
    _availabilitySubscription?.cancel();
    _availabilitySubscription = _database.ref('spots/$parkingId').onValue.listen((event) {
      if (event.snapshot.value != null) {
        _processSpotData(event.snapshot.value as Map<dynamic, dynamic>);
      }
    });

    // Realtime payments
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    _paymentsSubscription?.cancel();
    _paymentsSubscription = _firestore
        .collection('payments')
        .where('parkingId', isEqualTo: parkingId)
        .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
        .where('status', isEqualTo: 'completed')
        .snapshots()
        .listen((snapshot) {
      _processPaymentData(snapshot.docs);
    });
  }

  void _processSpotData(Map<dynamic, dynamic> spotsData) {
    int available = 0;
    int occupied = 0;
    Map<int, int> hourlyOccupancy = {};

    spotsData.forEach((key, value) {
      if (value is Map) {
        if (value['status'] == 'available') available++;
        if (value['status'] == 'occupied') occupied++;

        // Track hourly occupancy
        final timestamp = DateTime.fromMillisecondsSinceEpoch(value['lastUpdated']);
        final hour = timestamp.hour;
        hourlyOccupancy[hour] = (hourlyOccupancy[hour] ?? 0) + 1;
      }
    });

    if (mounted) {
      setState(() {
        _availableSpots = available;
        _occupiedSpots = occupied;
        _hourlyOccupancy = hourlyOccupancy;
        _occupancyRate = _parkingCapacity > 0 
            ? (_occupiedSpots / _parkingCapacity) * 100 
            : 0;
      });
    }
  }

  void _processPaymentData(List<QueryDocumentSnapshot> payments) {
    double totalRevenue = 0;
    Map<int, double> hourlyRevenue = {};

    for (var doc in payments) {
      final data = doc.data() as Map<String, dynamic>;
      final amount = (data['amount'] ?? 0.0).toDouble();
      totalRevenue += amount;

      // Track hourly revenue
      final timestamp = (data['timestamp'] as Timestamp).toDate();
      final hour = timestamp.hour;
      hourlyRevenue[hour] = (hourlyRevenue[hour] ?? 0) + amount;
    }

    if (mounted) {
      setState(() {
        _todaysTotalRevenue = totalRevenue;
        _hourlyRevenue = hourlyRevenue;
        _dailyStats = {
          'total_revenue': totalRevenue,
          'completed_payments': payments.length,
          'hourly_revenue': hourlyRevenue,
        };
      });
    }
  }

  void _setupRealtimeAnalytics() {
    _statsTimer?.cancel();
    _statsTimer = Timer.periodic(Duration(minutes: 5), (timer) {
      _updateDashboardMetrics();
    });
  }

  Future<void> _updateDashboardMetrics() async {
    await Future.wait([
      _loadRevenueData(),
      _loadHourlyData(),
    ]);
  }

  Future<void> _loadParkingData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final query = await _firestore
          .collection('parking')
          .where('ownerId', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (query.docs.isEmpty) throw Exception('No parking data found');

      final data = query.docs.first.data();
      if (mounted) {
        setState(() {
          parkingData = data;
          _parkingCapacity = data['capacity'] ?? 0;
        });
      }
    } catch (e) {
      _showErrorSnackbar('Failed to load parking data: ${e.toString()}');
      rethrow;
    }
  }

  Future<void> _loadTransactions() async {
    try {
      final parkingId = parkingData?['id'];
      if (parkingId == null) return;

      final query = await _firestore
          .collection('bookings')
          .where('parkingId', isEqualTo: parkingId)
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      final transactions = query.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'amount': data['amount'] ?? 0.0,
          'status': data['status'] ?? 'unknown',
          'date': (data['createdAt'] as Timestamp).toDate(),
          'vehicleNumber': data['vehicleNumber'] ?? '',
        };
      }).toList();

      if (mounted) {
        setState(() => _recentTransactions = transactions);
      }
    } catch (e) {
      _showErrorSnackbar('Failed to load transactions: ${e.toString()}');
    }
  }

  Future<void> _loadMonthlyStats() async {
    try {
      final parkingId = parkingData?['id'];
      if (parkingId == null) return;

      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);

      final query = await _firestore
          .collection('bookings')
          .where('parkingId', isEqualTo: parkingId)
          .where('createdAt', isGreaterThanOrEqualTo: monthStart)
          .where('status', isEqualTo: 'completed')
          .get();

      final Map<String, double> dailyRevenue = {};
      for (var doc in query.docs) {
        final date = (doc.data()['createdAt'] as Timestamp).toDate();
        final day = date.day.toString();
        final amount = (doc.data()['amount'] ?? 0.0).toDouble();
        dailyRevenue[day] = (dailyRevenue[day] ?? 0) + amount;
      }

      if (mounted) {
        setState(() => _monthlyStats = dailyRevenue);
      }
    } catch (e) {
      _showErrorSnackbar('Failed to load monthly stats: ${e.toString()}');
    }
  }

  Future<void> _loadRevenueData() async {
    try {
      final parkingId = parkingData?['id'];
      if (parkingId == null) return;

      final now = DateTime.now();
      final thirtyDaysAgo = now.subtract(Duration(days: 30));

      final query = await _firestore
          .collection('payments')
          .where('parkingId', isEqualTo: parkingId)
          .where('timestamp', isGreaterThanOrEqualTo: thirtyDaysAgo)
          .where('status', isEqualTo: 'completed')
          .orderBy('timestamp')
          .get();

      final Map<int, double> dailyRevenue = {};
      double maxRev = 0;

      for (var doc in query.docs) {
        final data = doc.data();
        final date = (data['timestamp'] as Timestamp).toDate();
        final day = date.day;
        final amount = (data['amount'] ?? 0.0).toDouble();
        dailyRevenue[day] = (dailyRevenue[day] ?? 0) + amount;
        if (dailyRevenue[day]! > maxRev) maxRev = dailyRevenue[day]!;
      }

      final revenueSpots = dailyRevenue.entries
          .map((e) => FlSpot(e.key.toDouble(), e.value))
          .toList();

      if (mounted) {
        setState(() {
          _revenueData = revenueSpots;
          _maxRevenue = maxRev;
        });
      }
    } catch (e) {
      _showErrorSnackbar('Failed to load revenue data: ${e.toString()}');
    }
  }

  Future<void> _loadHourlyData() async {
    try {
      final parkingId = parkingData?['id'];
      if (parkingId == null) return;

      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      final paymentsQuery = await _firestore
          .collection('payments')
          .where('parkingId', isEqualTo: parkingId)
          .where('timestamp', isGreaterThanOrEqualTo: startOfDay)
          .where('status', isEqualTo: 'completed')
          .get();

      final Map<int, double> hourlyRevenue = {};
      for (var doc in paymentsQuery.docs) {
        final timestamp = (doc.data()['timestamp'] as Timestamp).toDate();
        final hour = timestamp.hour;
        final amount = (doc.data()['amount'] ?? 0.0).toDouble();
        hourlyRevenue[hour] = (hourlyRevenue[hour] ?? 0) + amount;
      }

      if (mounted) {
        setState(() => _hourlyRevenue = hourlyRevenue);
      }
    } catch (e) {
      _showErrorSnackbar('Failed to load hourly data: ${e.toString()}');
    }
  }

  void _showErrorSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0079C0),
      appBar: _buildAppBar(),
      drawer: CustomDrawer(userType: 'Parking Owner'),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Container(
            height: constraints.maxHeight,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(50)),
            ),
            child: RefreshIndicator(
              onRefresh: _refreshData,
              child: _isLoading
                  ? _buildLoadingView()
                  : parkingData == null
                      ? _buildNoDataView()
                      : SingleChildScrollView(
                          controller: _scrollController,
                          physics: AlwaysScrollableScrollPhysics(),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight,
                            ),
                            child: _buildDashboardContent(),
                          ),
                        ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDashboardContent() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCurrentStatsGrid(),
          SizedBox(height: 20),
          _buildRevenueChartSection(),
          SizedBox(height: 20),
          _buildOccupancyChartSection(),
          SizedBox(height: 20),
          _buildRecentTransactionsSection(),
        ],
      ),
    );
  }

  Widget _buildCurrentStatsGrid() {
    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.3,
      physics: NeverScrollableScrollPhysics(),
      children: [
        BuildStatCard(
          title: 'Today\'s Revenue',
          value: 'TND ${_todaysTotalRevenue.toStringAsFixed(2)}',
          icon: Icons.attach_money,
          color: Colors.green,
        ),
        BuildStatCard(
          title: 'Available Spots',
          value: '$_availableSpots/$_parkingCapacity',
          icon: Icons.local_parking,
          color: Colors.blue,
        ),
        BuildStatCard(
          title: 'Occupancy Rate',
          value: '${_occupancyRate.toStringAsFixed(1)}%',
          icon: Icons.pie_chart,
          color: Colors.orange,
        ),
        BuildStatCard(
          title: 'Recent Transactions',
          value: '${_recentTransactions.length}',
          icon: Icons.receipt,
          color: Colors.purple,
        ),
      ],
    );
  }

  Widget _buildRevenueChartSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '30-Day Revenue Trend',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Container(
              height: 200,
              child: _revenueData.isEmpty
                  ? Center(child: Text('No revenue data available'))
                  : LineChart(
                      LineChartData(
                        gridData: FlGridData(show: true),
                        titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: 5,
                              getTitlesWidget: (value, meta) {
                                return Text(value.toInt().toString());
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                return Text(value.toInt().toString());
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: true),
                        minX: 1,
                        maxX: 31,
                        minY: 0,
                        maxY: _maxRevenue * 1.2,
                        lineBarsData: [
                          LineChartBarData(
                            spots: _revenueData,
                            isCurved: true,
                            color: Colors.blue,
                            barWidth: 4,
                            belowBarData: BarAreaData(
                              show: true,
                              color: Colors.blue.withOpacity(0.3),
                            ),
                            dotData: FlDotData(show: false),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOccupancyChartSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hourly Occupancy',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Container(
              height: 200,
              child: _hourlyOccupancy.isEmpty
                  ? Center(child: Text('No occupancy data available'))
                  : BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: _parkingCapacity.toDouble(),
                        barTouchData: BarTouchData(enabled: false),
                        titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Text('${value.toInt()}h'),
                                );
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        barGroups: _hourlyOccupancy.entries.map((entry) {
                          return BarChartGroupData(
                            x: entry.key,
                            barRods: [
                              BarChartRodData(
                                toY: entry.value.toDouble(),
                                color: Colors.blue,
                                width: 16,
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(4)),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentTransactionsSection() {
    if (_recentTransactions.isEmpty) return SizedBox.shrink();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Transactions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            ListView.separated(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              itemCount: _recentTransactions.length,
              separatorBuilder: (context, index) => Divider(height: 16),
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
    final isCompleted = transaction['status'] == 'completed';
    final date = transaction['date'] as DateTime;
    final amount = (transaction['amount'] ?? 0.0).toDouble();

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isCompleted ? Colors.green[50] : Colors.orange[50],
          shape: BoxShape.circle,
        ),
        child: Icon(
          isCompleted ? Icons.check_circle : Icons.pending,
          color: isCompleted ? Colors.green : Colors.orange,
        ),
      ),
      title: Text(
        'TND ${amount.toStringAsFixed(2)}',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        transaction['vehicleNumber'] ?? 'Unknown vehicle',
        style: TextStyle(color: Colors.grey[600]),
      ),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            DateFormat('MMM dd').format(date),
            style: TextStyle(fontSize: 12),
          ),
          Text(
            DateFormat('hh:mm a').format(date),
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Color(0xFF0079C0),
      elevation: 0,
      leading: Builder(
        builder: (context) => IconButton(
          icon: Icon(Icons.menu, color: Colors.white, size: 30),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ),
      title: Text(
        'Dashboard',
        style: TextStyle(color: Colors.white, fontSize: 30),
      ),
      centerTitle: true,
      toolbarHeight: 100,
    );
  }

  Widget _buildLoadingView() {
    return Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0079C0)),
      ),
    );
  }

  Widget _buildNoDataView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 50, color: Colors.grey),
          SizedBox(height: 20),
          Text(
            'No parking data found',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: _refreshData,
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF0079C0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Text('Retry', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _realtimeSubscription?.cancel();
    _firestoreSubscription?.cancel();
    _paymentsSubscription?.cancel();
    _availabilitySubscription?.cancel();
    _occupiedSpotsSubscription?.cancel();
    _statsTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }
}
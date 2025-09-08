import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:smart_parking/PayScreen/PayScreen.dart';
import 'package:smart_parking/widget/CustomTiltle.dart';
import 'package:smart_parking/widget/button.dart';

class CalculeTimeSpend extends StatefulWidget {
  final String parkingId;
  final String spotId;

  const CalculeTimeSpend({
    super.key,
    required this.parkingId,
    required this.spotId,
  });

  @override
  State<CalculeTimeSpend> createState() => _CalculeTimeSpendState();
}

class _CalculeTimeSpendState extends State<CalculeTimeSpend> {
  final DatabaseReference _spotsRef = FirebaseDatabase.instance.ref('spots');
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _tempEntre;    // Add this line
  String? _tempSortie;   // Add this line
  DateTime? _entryTime;
  DateTime? _exitTime;
  double? _pricePerHour;
  double? _totalCost;
  bool _isCalculating = false;
  StreamSubscription? _spotSubscription;

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  @override
  void dispose() {
    _spotSubscription?.cancel();
    super.dispose();
  }

  Future<void> _fetchInitialData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('No authenticated user');
        return;
      }

      // First get the parking price
      final parkingDoc = await _firestore
          .collection('parking')
          .doc(widget.parkingId)
          .get();

      if (parkingDoc.exists && mounted) {
        _pricePerHour = double.tryParse(parkingDoc.data()?['price'] ?? '0');
        print('Price per hour: $_pricePerHour'); // Debug log
      }

      // Get spot data with entry time
      final spotRef = _spotsRef
          .child(widget.parkingId)
          .child(widget.spotId);
          
      final spotSnapshot = await spotRef.get();
      if (!spotSnapshot.exists) {
        print('Spot not found');
        return;
      }

      final spotData = spotSnapshot.value as Map<dynamic, dynamic>;
      
      // Get entry time from occupiedSince field
      final entryTimestamp = spotData['occupiedSince'] ?? spotData['lastUpdated'];
      if (entryTimestamp != null) {
        _entryTime = DateTime.fromMillisecondsSinceEpoch(entryTimestamp);
        if (mounted) {
          setState(() {
            _tempEntre = "${_entryTime!.hour.toString().padLeft(2, '0')}:${_entryTime!.minute.toString().padLeft(2, '0')}";
          });
        }
        print('Entry time: $_entryTime'); // Debug log
      }

      // Setup real-time listener for spot changes
      _spotSubscription = spotRef.onValue.listen((event) {
        if (!event.snapshot.exists || !mounted) return;
        
        final updatedSpotData = event.snapshot.value as Map<dynamic, dynamic>;
        final updatedTimestamp = updatedSpotData['occupiedSince'] ?? updatedSpotData['lastUpdated'];
        
        if (updatedTimestamp != null) {
          setState(() {
            _entryTime = DateTime.fromMillisecondsSinceEpoch(updatedTimestamp);
            _tempEntre = "${_entryTime!.hour.toString().padLeft(2, '0')}:${_entryTime!.minute.toString().padLeft(2, '0')}";
          });
        }
      });

    } catch (e) {
      print("Error fetching data: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }

  void _calculateTotalCost() {
    if (_entryTime == null) {
      print('Entry time is null!'); // Debug log
      return;
    }

    _exitTime = DateTime.now();
    print('Exit time: $_exitTime'); // Debug log

    if (_pricePerHour == null) {
      print('Price per hour is null!'); // Debug log
      return;
    }

    // Calculate duration in minutes
    final duration = _exitTime!.difference(_entryTime!);
    final hours = duration.inMinutes / 60.0;
    
    // Calculate cost with 2 decimal places
    final cost = (hours * _pricePerHour!);
    
    print('Duration: $duration'); // Debug log
    print('Hours: $hours'); // Debug log
    print('Cost before rounding: $cost'); // Debug log

    setState(() {
      _totalCost = double.parse(cost.toStringAsFixed(2));
      _tempSortie = "${_exitTime!.hour.toString().padLeft(2, '0')}:${_exitTime!.minute.toString().padLeft(2, '0')}";
      _isCalculating = true;
    });

    print('Final total cost: $_totalCost'); // Debug log
  }

  void _onPay() {
    if (_entryTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entry time not available')),
      );
      return;
    }

    if (_pricePerHour == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Price information not available')),
      );
      return;
    }

    _calculateTotalCost();

    if (_totalCost == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error calculating cost')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Entry Time: $_tempEntre'),
            Text('Exit Time: $_tempSortie'),
            Text('Rate: $_pricePerHour TND/hour'),
            const SizedBox(height: 8),
            Text('Total amount: $_totalCost TND', 
              style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PayScreen(
                    parkingId: widget.parkingId,
                    spotId: widget.spotId,
                    totalCost: _totalCost ?? 0.0,
                  ),
                ),
              );
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // Prevent back button
      child: Scaffold(
        backgroundColor: const Color(0XFF0079C0),
        extendBody: true,
        appBar: AppBar(
          backgroundColor: const Color(0XFF0079C0),
          title: CustomTitle(
            text: "Time",
            color: Colors.white,
            size: 32,
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () {
              Navigator.pop(context); // Go back to the previous screen
            },
          ),
          centerTitle: true,
          toolbarHeight: 100,
          automaticallyImplyLeading: false, // Remove back button
        ),
        body: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(50),
              topRight: Radius.circular(50),
            ),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildTimeDisplay("Entry Time", _tempEntre ?? "Loading..."),
                  const SizedBox(height: 30),
                  _buildTimeDisplay("Exit Time", _tempSortie ?? "Not Set"),
                  const SizedBox(height: 30),
                  _buildTimeDisplay("TND/Hour", _pricePerHour != null ? "${_pricePerHour} TND" : "Loading..."),
                  const SizedBox(height: 30),
                  _buildTimeDisplay("Result", _totalCost != null ? "${_totalCost} TND" : "Not Calculated"),
                  const SizedBox(height: 50),
                  if (!_isCalculating)
                    button(
                      onPressed: _onPay,
                      text: "Calculate & Pay",
                      fontsize: 16,
                      width: 200,
                      height: 50,
                      radius: 18,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeDisplay(String label, String value) {
    return Container(
      width: double.infinity,
      child: Column(
        children: [
          TimeDisplayWidget(
            label: label,
            value: value,
          ),
          const Divider(
            color: Color(0xff3FA2FF),
            thickness: 0.5,
            endIndent: 25,
            indent: 25,
          ),
        ],
      ),
    );
  }
}

class TimeDisplayWidget extends StatelessWidget {
  final String label;
  final String value;

  const TimeDisplayWidget({
    Key? key,
    required this.label,
    required this.value,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center, // Center the content
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 18, // Slightly larger
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(width: 30),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18, // Slightly larger
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
      ],
    );
  }
}

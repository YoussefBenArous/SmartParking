import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'DeleteandAddSpot.dart';

class AddSpotOnParking extends StatefulWidget {
  final String parkingId;
  final String parkingName;

  const AddSpotOnParking({
    Key? key,
    required this.parkingId,
    required this.parkingName,
  }) : super(key: key);

  @override
  State<AddSpotOnParking> createState() => _AddSpotOnParkingState();
}

class _AddSpotOnParkingState extends State<AddSpotOnParking> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  List<Map<String, dynamic>> _spots = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSpots();
  }

  Future<void> _loadSpots() async {
    try {
      setState(() => _isLoading = true);

      final spotsSnapshot = await _firestore
          .collection('parking')
          .doc(widget.parkingId)
          .collection('spots')
          .orderBy('number')
          .get();

      final spots = spotsSnapshot.docs.map((doc) {
        final data = doc.data();
        final numberStr = data['number'] as String;
        final number = int.tryParse(numberStr.replaceAll('SPOT_', '')) ?? 0;

        return {
          'id': doc.id,
          'number': number,
          'numberStr': numberStr,
          'isAvailable': data['isAvailable'] ?? true,
        };
      }).toList();

      // Sort spots by number
      spots.sort((a, b) => a['number'].compareTo(b['number']));

      setState(() {
        _spots = spots;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading spots: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _addNewSpot() async {
    try {
      final nextNumber = _spots.isEmpty ? 1 : _spots.length + 1;
      final spotNumber = 'SPOT_$nextNumber';

      final batch = _firestore.batch();

      final spotRef = _firestore
          .collection('parking')
          .doc(widget.parkingId)
          .collection('spots')
          .doc();

      final spotData = {
        'number': spotNumber,
        'isAvailable': true,
        'status': 'available',
        'type': 'standard',
        'lastUpdated': FieldValue.serverTimestamp(),
      };

      batch.set(spotRef, spotData);

      batch.update(
        _firestore.collection('parking').doc(widget.parkingId),
        {
          'capacity': FieldValue.increment(1),
          'available': FieldValue.increment(1),
          'lastUpdated': FieldValue.serverTimestamp(),
        },
      );

      await batch.commit();

      await _database
          .child('spots')
          .child(widget.parkingId)
          .child(spotRef.id)
          .set({
        'number': spotNumber,
        'status': 'available',
        'lastUpdated': ServerValue.timestamp,
      });

      await _loadSpots();
    } catch (e) {
      print('Error adding spot: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding spot: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0XFF0079C0),
      appBar: AppBar(
        toolbarHeight: 100,
        backgroundColor: const Color(0XFF0079C0),
        title: Text(
          widget.parkingName,
          style: const TextStyle(
            fontSize: 32,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white,),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(50),
            topRight: Radius.circular(50),
          ),
        ),
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _spots.length + 1,
      itemBuilder: (context, index) {
        if (index == _spots.length) {
          return GestureDetector(
            onTap: _addNewSpot,
            child: DeleteandAddSPOTWidget(
              parkingId: widget.parkingId,
              number: index + 1,
              isAddButton: true,
            ),
          );
        }

        final spot = _spots[index];
        return DeleteandAddSPOTWidget(
          parkingId: widget.parkingId,
          spotId: spot['id'],
          number:
              int.tryParse(spot['number'].toString().replaceAll('SPOT_', '')) ??
                  0,
          onSpotDeleted: _loadSpots,
        );
      },
    );
  }
}

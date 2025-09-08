import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:another_dashed_container/another_dashed_container.dart';

class DeleteandAddSPOTWidget extends StatefulWidget {
  final String parkingId;
  final String? spotId;
  final int number;
  final bool isAddButton;
  final VoidCallback? onSpotAdded;
  final VoidCallback? onSpotDeleted;

  const DeleteandAddSPOTWidget({
    Key? key,
    required this.parkingId,
    this.spotId,
    required this.number,
    this.isAddButton = false,
    this.onSpotAdded,
    this.onSpotDeleted,
  }) : super(key: key);

  @override
  State<DeleteandAddSPOTWidget> createState() => _DeleteandAddSPOTWidgetState();
}

class _DeleteandAddSPOTWidgetState extends State<DeleteandAddSPOTWidget> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  bool _isLoading = false;

  Future<void> _deleteSpot() async {
    if (_isLoading || widget.spotId == null) return;
    
    setState(() => _isLoading = true);
    try {
      // Start a Firestore batch
      final batch = _firestore.batch();
      
      // Delete spot document
      final spotRef = _firestore
          .collection('parking')
          .doc(widget.parkingId)
          .collection('spots')
          .doc(widget.spotId);
      
      batch.delete(spotRef);

      // Update parking capacity
      final parkingRef = _firestore.collection('parking').doc(widget.parkingId);
      batch.update(parkingRef, {
        'capacity': FieldValue.increment(-1),
        'available': FieldValue.increment(-1),
      });

      await batch.commit();

      // Delete from Realtime Database
      await _database
          .child('spots')
          .child(widget.parkingId)
          .child(widget.spotId!)
          .remove();

      if (widget.onSpotDeleted != null) {
        widget.onSpotDeleted!();
      }

    } catch (e) {
      print('Error deleting spot: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting spot: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showDeleteConfirmation() async {
    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete SPOT_${widget.number}'),
          content: const Text('Are you sure you want to delete this Spot?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                _deleteSpot();
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isAddButton) {
      return DashedContainer(
        dashColor: Colors.grey,
        borderRadius: 12.0,
        dashedLength: 10.0,
        blankLength: 5.0,
        strokeWidth: 2.0,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.add_circle_outline,
                size: 40,
                color: Colors.grey[600],
              ),
              Text(
                'Add Spot',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.blue[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue[700]!, width: 2),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'SPOT_${widget.number}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[900],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (widget.spotId != null)
          Positioned(
            top: 4,
            right: 4,
            child: IconButton(
              icon: Icon(Icons.remove_circle, color: Colors.red[700], size: 28),
              onPressed: _isLoading ? null : _showDeleteConfirmation,
            ),
          ),
        if (_isLoading)
          Container(
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(child: CircularProgressIndicator()),
          ),
      ],
    );
  }
}
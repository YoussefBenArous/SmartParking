import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:smart_parking/Setting/Setting.dart';
import 'package:smart_parking/widget/CustomTiltle.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:async';

class FindMySpot extends StatefulWidget {
  const FindMySpot({super.key});
  @override
  State<FindMySpot> createState() => _FindMySpotState();
}

class _FindMySpotState extends State<FindMySpot> {
  final FirebaseDatabase _rtdb = FirebaseDatabase.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  final MapController _mapController = MapController();
  Position? _currentPosition;
  Map<String, dynamic>? _activeSpot;
  bool _isLoading = true;
  List<Marker> _markers = [];
  List<LatLng> _routePoints = [];
  StreamSubscription? _spotStream;
  StreamSubscription? _locationStream;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    try {
      // Request location permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      // Get current location
      _currentPosition = await Geolocator.getCurrentPosition();
      
      // Get user's active booking
      final user = _auth.currentUser;
      if (user != null) {
        final bookingDoc = await _firestore
            .collection('bookings')
            .where('userId', isEqualTo: user.uid)
            .where('status', isEqualTo: 'active')
            .limit(1)
            .get();

        if (bookingDoc.docs.isNotEmpty) {
          final booking = bookingDoc.docs.first.data();
          await _updateSpotLocation(booking['parkingId'], booking['spotNumber']);
        }
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      print('Error initializing location: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateSpotLocation(String parkingId, String spotNumber) async {
    try {
      final parkingDoc = await _firestore
          .collection('parking')
          .doc(parkingId)
          .get();

      if (!parkingDoc.exists) return;

      final location = parkingDoc.data()?['location'] as Map<String, dynamic>;
      if (location == null) return;

      final spotLatLng = LatLng(location['latitude'], location['longitude']);

      if (mounted) {
        setState(() {
          _activeSpot = {
            'parkingId': parkingId,
            'spotNumber': spotNumber,
            'location': spotLatLng,
          };
          _updateMarkers();
          if (_currentPosition != null) {
            _calculateRoute();
          }
        });
      }
    } catch (e) {
      print('Error updating spot location: $e');
    }
  }

  void _updateMarkers() {
    if (_activeSpot == null || !mounted) return;

    setState(() {
      _markers = [
        Marker(
          point: _activeSpot!['location'],
          child: Icon(Icons.local_parking, color: Colors.blue, size: 30),
        ),
        if (_currentPosition != null)
          Marker(
            point: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
            child: Icon(Icons.my_location, color: Colors.red, size: 30),
          ),
      ];
    });
  }

  Future<void> _calculateRoute() async {
    if (_currentPosition == null || _activeSpot == null) return;

    // Here you would implement route calculation
    // For now, drawing straight line between points
    setState(() {
      _routePoints = [
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        _activeSpot!['location'],
      ];
    });
  }

  @override
  void dispose() {
    _spotStream?.cancel();
    _locationStream?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0XFF0079C0),
      extendBody: true,
      appBar: AppBar(
        title: CustomTitle(
          text: "Find My Spot",
          color: Colors.white,
          size: 32,
        ),
        centerTitle: true,
        toolbarHeight: 100,
        backgroundColor: Color(0XFF0079C0),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => SettingPage()),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(50),
            topRight: Radius.circular(50),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(50),
            topRight: Radius.circular(50),
          ),
          child: Stack(
            children: [
              if (_currentPosition != null)
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    center: LatLng(
                      _currentPosition!.latitude,
                      _currentPosition!.longitude,
                    ),
                    zoom: 15,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.app',
                    ),
                    MarkerLayer(markers: _markers),
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _routePoints,
                          strokeWidth: 4.0,
                          color: Colors.blue,
                        ),
                      ],
                    ),
                  ],
                )
              else if (_isLoading)
                Center(child: CircularProgressIndicator())
              else
                Center(child: Text('Unable to get location')),

              if (_activeSpot != null)
                Positioned(
                  bottom: 20,
                  left: 20,
                  right: 20,
                  child: Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Your Spot: ${_activeSpot!['spotNumber']}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          // Add distance and ETA if available
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

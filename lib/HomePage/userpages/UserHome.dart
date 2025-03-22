import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:smart_parking/HomePage/parkingownerPages/ParkingSearchDelegate.dart';
import 'package:smart_parking/Login_and_SignUp/LoginPage.dart';
import 'package:smart_parking/QRcode/QRCodeScreen.dart';
import 'package:smart_parking/QRcode/milticodeQR.dart';
import 'package:smart_parking/Setting/Setting.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smart_parking/parking/SpotSelectScreen.dart';
import 'package:smart_parking/services/auth_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  LatLng? _currentLocation;
  late final MapController _mapController;
  final Location _locationService = Location();
  List<Map<String, dynamic>> _parkingLocations = [];
  List<Map<String, dynamic>> _filteredParkingLocations = [];
  bool _isLoading = true;
  String _errorMessage = '';
  bool _isMapReady = false;
  StreamSubscription<LocationData>? _locationSubscription;
  Timer? _locationUpdateTimer;
  StreamSubscription<QuerySnapshot>? _parkingSubscription;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _mapController = MapController();
    _initializeLocationSettings();
    _initializeApp();
    _loadParkingLocations();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _setupLocationUpdates();
      if (_currentLocation != null && _isMapReady) {
        _mapController.move(_currentLocation!, 15.0);
      }
    }
  }

  Future<void> _initializeLocationSettings() async {
    await _locationService.changeSettings(
      accuracy: LocationAccuracy.high,
      interval: 5000,
      distanceFilter: 5,
    );
  }

  Future<void> _setupLocationUpdates() async {
    try {
      bool serviceEnabled = await _locationService.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _locationService.requestService();
        if (!serviceEnabled) {
          throw Exception('Location services are disabled');
        }
      }

      PermissionStatus permissionGranted =
          await _locationService.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await _locationService.requestPermission();
        if (permissionGranted != PermissionStatus.granted) {
          throw Exception('Location permission denied');
        }
      }

      final locationData = await _locationService.getLocation();
      _updateLocation(locationData);

      _locationSubscription = _locationService.onLocationChanged
          .listen(_updateLocation, onError: (error) {
        setState(() {
          _errorMessage = 'Location update error: $error';
        });
      });

      _locationUpdateTimer = Timer.periodic(Duration(minutes: 1), (timer) {
        _getUserLocation();
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error setting up location: $e';
      });
    }
  }

  void _updateLocation(LocationData locationData) {
    if (locationData.latitude != null &&
        locationData.longitude != null &&
        locationData.accuracy != null &&
        locationData.accuracy! <= 100) {
      setState(() {
        _currentLocation =
            LatLng(locationData.latitude!, locationData.longitude!);
        if (_isMapReady) {
          _mapController.move(_currentLocation!, 15.0);
          _filterParkingNearby();
        }
      });
    }
  }

  Future<void> _loadParkingLocations() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Must be authenticated to view parking locations');
      }

      _parkingSubscription =
          _firestore.collection('parking').snapshots().listen((snapshot) async {
        List<Map<String, dynamic>> parkings = [];

        for (var doc in snapshot.docs) {
          try {
            Map<String, dynamic> data = doc.data();

            await _initializeParkingSpots(doc.id, data['capacity'] ?? 0);

            final spotsSnapshot = await _firestore
                .collection('parking')
                .doc(doc.id)
                .collection('spots')
                .where('isAvailable', isEqualTo: true)
                .get();

            final availableSpots = spotsSnapshot.docs.length;

            await _firestore
                .collection('parking')
                .doc(doc.id)
                .update({'available': availableSpots});

            Map<String, dynamic> processedData = {
              'id': doc.id,
              'name': data['name'] ?? 'Unnamed Parking',
              'location': LatLng(
                (data['location']?['latitude'] ?? 36.8065).toDouble(),
                (data['location']?['longitude'] ?? 10.1815).toDouble(),
              ),
              'capacity': data['capacity'] ?? 0,
              'available': availableSpots,
              'price': data['price'] ?? 'N/A',
              'ownerId': data['ownerId'] ?? '',
              'status': data['status'] ?? 'inactive',
              'address': data['address'] ?? 'No address available',
            };

            if (_validateParkingData(data)) {
              parkings.add(processedData);
            }
          } catch (e) {
            print('Error processing parking doc ${doc.id}: $e');
          }
        }

        if (mounted) {
          setState(() {
            _parkingLocations = parkings;
            _filteredParkingLocations = parkings;
            _isLoading = false;
          });
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading parking locations: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _initializeParkingSpots(String parkingId, int capacity) async {
    try {
      final spotsCollection =
          _firestore.collection('parking').doc(parkingId).collection('spots');

      final existingSpots = await spotsCollection.get();
      if (existingSpots.docs.isEmpty) {
        final batch = _firestore.batch();
        for (int i = 1; i <= capacity; i++) {
          final spotRef = spotsCollection.doc();
          batch.set(spotRef, {
            'number': 'P$i',
            'isAvailable': true,
            'type': 'standard',
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
      }
    } catch (e) {
      print('Error initializing spots for parking $parkingId: $e');
    }
  }

  bool _validateParkingData(Map<String, dynamic> data) {
    try {
      return data.containsKey('name') &&
          data.containsKey('location') &&
          data.containsKey('capacity') &&
          data.containsKey('price') &&
          data.containsKey('available') &&
          data.containsKey('ownerId') &&
          data['location'] is Map &&
          (data['location'] as Map).containsKey('latitude') &&
          (data['location'] as Map).containsKey('longitude') &&
          data['capacity'] is num &&
          data['available'] is num &&
          data['price'] is String &&
          data['available'] <= data['capacity'];
    } catch (e) {
      return false;
    }
  }

  Future<void> _getUserLocation() async {
    try {
      bool serviceEnabled = await _locationService.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _locationService.requestService();
        if (!serviceEnabled) {
          throw Exception('Location services are disabled');
        }
      }

      final locationData = await _locationService.getLocation().timeout(
        Duration(seconds: 10),
        onTimeout: () => throw Exception('Location request timed out'),
      );

      if (locationData.latitude != null && locationData.longitude != null) {
        setState(() {
          _currentLocation = LatLng(locationData.latitude!, locationData.longitude!);
        });
      } else {
        throw Exception('Location data unavailable');
      }
    } catch (e) {
      print('Location error: $e');
      // Show user-friendly error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to get location. Please check permissions.')),
      );
    }
  }

  void _filterParkingNearby() {
    if (_currentLocation == null) return;

    const double radiusInKm = 5.0;
    final Distance distance = Distance();

    setState(() {
      _filteredParkingLocations = _parkingLocations.where((parking) {
        double distanceInKm = distance.as(
          LengthUnit.Kilometer,
          _currentLocation!,
          parking['location'],
        );
        return distanceInKm <= radiusInKm;
      }).toList();
    });
  }

  void _searchParking(String query) {
    setState(() {
      _filteredParkingLocations = _parkingLocations
          .where((parking) =>
              parking['name'].toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage.isNotEmpty) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.red),
              SizedBox(height: 16),
              Text(_errorMessage),
              ElevatedButton(
                onPressed: _initializeApp,
                child: Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () {},
          icon: Icon(
            Icons.account_circle_outlined,
          ),
          iconSize: 45,
        ),
        actions: <Widget>[
          IconButton(
            icon: Icon(Icons.search),
            onPressed: () async {
              final selected = await showSearch(
                context: context,
                delegate: ParkingSearchDelegate(_parkingLocations),
              );
              if (selected != null && _mapController != null && mounted) {
                setState(() {
                  _mapController.move(selected['location'], 15.0);
                });
                _showParkingDetails(selected);
              }
            },
          ),
        ],
      ),
      body: FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _currentLocation ?? LatLng(36.8065, 10.1815),
          initialZoom: 13.0,
          onMapReady: () {
            setState(() {
              _isMapReady = true;
              if (_currentLocation != null) {
                _mapController.move(_currentLocation!, 15.0);
              }
            });
          },
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            tileProvider: CancellableNetworkTileProvider(),
          ),
          if (_currentLocation != null)
            MarkerLayer(
              markers: [
                Marker(
                  point: _currentLocation!,
                  width: 40,
                  height: 40,
                  child: const Icon(
                    Icons.location_pin,
                    size: 40,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          MarkerLayer(
            markers: _filteredParkingLocations.map((parking) {
              bool isAvailable = (parking['available'] ?? 0) > 0;
              String status = parking['status'] ?? 'active';
              Color markerColor = isAvailable && status == 'active'
                  ? Colors.green
                  : status != 'active'
                      ? Colors.grey
                      : Colors.red;

              return Marker(
                point: parking['location'],
                width: 40,
                height: 40,
                child: GestureDetector(
                  onTap: () => _showParkingDetails(parking),
                  child: Container(
                    decoration: BoxDecoration(
                      color: markerColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        'P',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(
          bottom: 40,
        ),
        child: FloatingActionButton(
          shape: CircleBorder(
              side: BorderSide(
            color: Colors.white,
            width: 2,
          )),
          onPressed: _navigateToQRCode, // Updated this line
          child: Icon(
            Icons.qr_code_scanner_rounded,
            color: Colors.white,
            size: 30,
          ),
          backgroundColor: Color(
            0XFF0079C0,
          ),
        ),
      ),
      floatingActionButtonLocation:
          FloatingActionButtonLocation.miniCenterDocked,
      bottomNavigationBar: Container(
        height:
            MediaQuery.of(context).size.height * 0.1, // 10% of screen height
        padding: EdgeInsets.symmetric(horizontal: 16), // Add horizontal padding
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Row(
          mainAxisAlignment:
              MainAxisAlignment.spaceAround, // Distribute space evenly
          children: [
            IconButton(
              onPressed: () async {
                await AuthService().signout(context: context);
              },
              icon: Icon(
                Icons.exit_to_app_outlined,
                color: Color(0XFF767D81),
              ),
              iconSize: MediaQuery.of(context).size.width *
                  0.08, // Responsive icon size
            ),
            IconButton(
              onPressed: () {
                _getUserLocation();
              },
              icon: Icon(
                Icons.location_on_rounded,
                color: Color(0XFF767D81),
              ),
              iconSize: MediaQuery.of(context).size.width *
                  0.08, // Responsive icon size
            ),
            IconButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SettingPage(),
                  ),
                );
              },
              icon: Icon(
                Icons.settings,
                color: Color(0XFF767D81),
              ),
              iconSize: MediaQuery.of(context).size.width *
                  0.08, // Responsive icon size
            ),
          ],
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> _checkExistingBookings(String parkingId) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Must be logged in to view bookings');
      }

      // Check for any active bookings in this specific parking
      final bookingSnapshot = await _firestore
          .collection('bookings')
          .where('userId', isEqualTo: user.uid)
          .where('parkingId', isEqualTo: parkingId)
          .where('status', isEqualTo: 'active')
          .get();

      List<String> spots = [];
      for (var doc in bookingSnapshot.docs) {
        spots.add(doc.data()['spotNumber'].toString());
      }

      return {
        'count': bookingSnapshot.docs.length,
        'spots': spots,
        'hasActiveBooking': bookingSnapshot.docs.isNotEmpty,
      };
    } catch (e) {
      print('Error checking existing bookings: $e');
      return {
        'count': 0, 
        'spots': [], 
        'hasActiveBooking': false
      };
    }
  }

  void _showParkingDetails(Map<String, dynamic> parking) async {
    final capacity = parking['capacity'] ?? 0;
    final available = parking['available'] ?? 0;
    final price = parking['price'] ?? 'N/A';
    final status = parking['status'] ?? 'inactive';
    final parkingId = parking['id'];

    // Check existing bookings first
    final bookings = await _checkExistingBookings(parkingId);
    
    // If user already has a booking in this parking, show error
    if (bookings['hasActiveBooking']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You already have an active booking in this parking'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(parking['name'] ?? 'Unnamed Parking'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Capacity: $capacity spots'),
            Text('Available: $available spots'),
            Text('Price: $price'),
            if (status != 'active')
              Text('Status: $status', 
                  style: TextStyle(color: Colors.red)),
            if (bookings['count'] > 0) ...[
              Text(
                'Your current bookings in this parking:',
                style: TextStyle(color: Colors.orange),
              ),
              Text('Spots: ${bookings['spots'].join(", ")}'),
              Text(
                'Maximum 1 booking allowed per parking',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 12,
                  fontStyle: FontStyle.italic
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
          if (available > 0 && status == 'active')
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SpotSelectionScreen(
                      parkingId: parkingId,
                      parkingName: parking['name'] ?? 'Unnamed Parking',
                      parkingData: parking,
                    ),
                  ),
                );
              },
              child: Text('Select Spot'),
            ),
          if (bookings['hasActiveBooking'])
            TextButton(
              onPressed: null,
              child: Text(
                'Already have a booking',
                style: TextStyle(color: Colors.grey),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _initializeApp() async {
    try {
      await _setupLocationUpdates();
    } catch (e) {
      setState(() {
        _errorMessage = 'Error initializing app: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _bookParking(String parkingId) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Must be logged in to book');
      }

      final bookingData = {
        'parkingId': parkingId,
        'userId': user.uid,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentReference parkingRef =
            FirebaseFirestore.instance.collection('parking').doc(parkingId);
        DocumentSnapshot parkingDoc = await transaction.get(parkingRef);

        if (!parkingDoc.exists) {
          throw Exception('Parking not found');
        }

        Map<String, dynamic> parkingData =
            parkingDoc.data() as Map<String, dynamic>;
        int available = parkingData['available'] ?? 0;

        if (available <= 0) {
          throw Exception('No spots available');
        }

        DocumentReference bookingRef =
            FirebaseFirestore.instance.collection('bookings').doc();
        transaction.set(bookingRef, bookingData);

        transaction.update(parkingRef, {'available': available - 1});
      });

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Booking successful')));
      Navigator.pop(context);
      _loadParkingLocations();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Booking failed: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }

  Future<void> _navigateToQRCode() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('Must be logged in to view QR codes');
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MultiQRCode(),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationSubscription?.cancel();
    _locationUpdateTimer?.cancel();
    _mapController.dispose();
    _parkingSubscription?.cancel();
    super.dispose();
  }
}

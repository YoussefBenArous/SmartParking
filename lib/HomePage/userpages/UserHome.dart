import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:smart_parking/HomePage/parkingownerPages/ParkingSearchDelegate.dart';
import 'package:smart_parking/PayScreen/PaymentSuccessScreen.dart';
import 'package:smart_parking/QRcode/milticodeQR.dart';
import 'package:smart_parking/Setting/Setting.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smart_parking/parking/SpotSelectScreen.dart';
import 'package:smart_parking/services/auth_service.dart';
import 'package:firebase_database/firebase_database.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  LatLng? _currentLocation;
  late final MapController _mapController;
  final Location _locationService = Location();
  final FirebaseDatabase _database = FirebaseDatabase.instance;
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
    _checkPendingPayment();
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
      interval: 10000, // Increased from 5000
      distanceFilter: 10, // Increased from 5
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
      // Check if spots exist in Realtime Database
      final realtimeRef = _database.ref('spots/$parkingId');
      final realtimeSnapshot = await realtimeRef.get();

      if (realtimeSnapshot.value == null) {
        // Create spots in Realtime Database
        Map<String, dynamic> spots = {};
        for (int i = 1; i <= capacity; i++) {
          final spotId = 'spot_$i';
          spots[spotId] = {
            'number': 'P$i',
            'status': 'available',
            'lastUpdated': ServerValue.timestamp,
            'lastBookingId': '',
            'lastUserId': '',
            'ignoreStatusUpdates': false
          };
        }
        await realtimeRef.set(spots);
      }

      // Get spots from Firestore
      final spotsCollection = _firestore
          .collection('parking')
          .doc(parkingId)
          .collection('spots');

      final existingSpots = await spotsCollection.get();
      if (existingSpots.docs.isEmpty) {
        final batch = _firestore.batch();
        for (int i = 1; i <= capacity; i++) {
          final spotRef = spotsCollection.doc('spot_$i');
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
        Duration(seconds: 30), // Increased timeout
        onTimeout: () {
          // Use last known location if available
          if (_currentLocation != null) {
            return LocationData.fromMap({
              'latitude': _currentLocation!.latitude,
              'longitude': _currentLocation!.longitude,
              'accuracy': 0.0,
            });
          }
          throw Exception('Location request timed out');
        },
      );

      if (locationData.latitude != null && locationData.longitude != null) {
        setState(() {
          _currentLocation =
              LatLng(locationData.latitude!, locationData.longitude!);
        });
      } else {
        throw Exception('Location data unavailable');
      }
    } catch (e) {
      print('Location error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Unable to get precise location. Using last known location or default.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
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
    print("DEBUG: Searching for parking with query: $query");
    print("DEBUG: Total parking locations: ${_parkingLocations.length}");
    
    setState(() {
      _filteredParkingLocations = _parkingLocations.where((parking) {
        final name = parking['name']?.toString().toLowerCase() ?? '';
        final searchQuery = query.toLowerCase();
        final matches = name.contains(searchQuery);
        print("DEBUG: Checking parking '${parking['name']}' - Match: $matches");
        return matches;
      }).toList();
      
      print("DEBUG: Found ${_filteredParkingLocations.length} matching locations");
    });
  }

  Future<void> _checkUserBookingLimit() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final activeBookings = await _firestore
          .collection('bookings')
          .where('userId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'active')
          .get();

      if (activeBookings.docs.length >= 3) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'You have reached the maximum limit of 3 active bookings'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error checking booking limit: $e');
    }
  }

  Future<Map<String, dynamic>> _checkParkingAvailability(String parkingId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Must be authenticated');

      // Check user's booking limit first
      final userBookings = await _firestore
          .collection('bookings')
          .where('userId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'active')
          .get();

      if (userBookings.docs.length >= 3) {
        return {
          'realAvailable': 0,
          'reservedCount': 0,
          'hasUserBooking': false,
          'canBook': false,
          'limitReached': true
        };
      }

      // Get real-time counts
      final parkingDoc = await _firestore
          .collection('parking')
          .doc(parkingId)
          .get();

      if (!parkingDoc.exists) throw Exception('Parking not found');

      final data = parkingDoc.data()!;
      final totalCapacity = data['capacity'] ?? 0;

      // Get active bookings count
      final activeBookings = await _firestore
          .collection('bookings')
          .where('parkingId', isEqualTo: parkingId)
          .where('status', isEqualTo: 'active')
          .get();

      final actualAvailable = totalCapacity - activeBookings.docs.length;

      // Update available count in Firestore
      await _firestore
          .collection('parking')
          .doc(parkingId)
          .update({
            'available': actualAvailable,
            'lastUpdated': FieldValue.serverTimestamp()
          });

      return {
        'realAvailable': actualAvailable,
        'reservedCount': activeBookings.docs.length,
        'hasUserBooking': userBookings.docs.any((doc) => doc.data()['parkingId'] == parkingId),
        'canBook': actualAvailable > 0 && userBookings.docs.length < 3,
        'limitReached': userBookings.docs.length >= 3
      };
    } catch (e) {
      print('Error checking availability: $e');
      return {
        'realAvailable': 0,
        'reservedCount': 0,
        'hasUserBooking': false,
        'canBook': false,
        'limitReached': false
      };
    }
  }

  Widget _buildParkingMarker(Map<String, dynamic> parking) {
    return StreamBuilder<DatabaseEvent>(
      stream: _database.ref('spots/${parking['id']}').onValue,
      builder: (context, snapshot) {
        String status = parking['status'] ?? 'inactive';
        Color markerColor = Colors.grey;

        if (snapshot.hasData && snapshot.data?.snapshot.value != null) {
          final spotsData =
              snapshot.data?.snapshot.value as Map<dynamic, dynamic>;
          final availableSpots = spotsData.values
              .where((spot) =>
                  spot is Map &&
                  spot['status'] == 'available' &&
                  !(spot['ignoreStatusUpdates'] ?? false))
              .length;

          if (status == 'active') {
            markerColor = availableSpots > 0 ? Colors.green : Colors.red;
          }
        }

        return GestureDetector(
          onTap: () async {
            final availability = await _checkParkingAvailability(parking['id']);
            if (!availability['canBook']) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(availability['limitReached']
                    ? 'You have reached the maximum limit of 3 active bookings'
                    : availability['hasUserBooking']
                        ? 'You already have an active booking'
                        : 'No spots available at this time'),
                backgroundColor: Colors.red,
              ));
              return;
            }
            _showParkingDetails(parking);
          },
          child: Container(
            width: 40,
            height: 40,
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
        );
      },
    );
  }

  Future<void> _checkPendingPayment() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final pendingPayment = await FirebaseFirestore.instance
          .collection('payments')
          .doc(user.uid)
          .get();

      if (!pendingPayment.exists) return;
      
      final paymentData = pendingPayment.data();
      if (paymentData?['status'] == 'pending') {
        // Redirect to payment screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PaymentSuccessScreen(
              parkingId: paymentData?['parkingId'],
              spotId: paymentData?['spotId'],
              totalCost: paymentData?['amount'],
            ),
          ),
        );
      }
    } catch (e) {
      print('Error checking pending payment: $e');
    }
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
              print("DEBUG: Opening search delegate");
              print("DEBUG: Available parking locations: ${_parkingLocations.length}");
              
              final selected = await showSearch(
                context: context,
                delegate: ParkingSearchDelegate(_parkingLocations),
              );
              
              if (selected != null && _mapController != null && mounted) {
                print("DEBUG: Selected parking: ${selected['name']}");
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
              return Marker(
                point: parking['location'],
                width: 40,
                height: 40,
                child: _buildParkingMarker(parking),
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
          onPressed: _navigateToQRCode,
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
              onPressed: _handleSignOut, // Update this line
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

  void _showParkingDetails(Map<String, dynamic> parking) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Must be authenticated');

      final availability = await _checkParkingAvailability(parking['id']);
      
      // Check for existing booking in this parking
      final existingBooking = await _firestore
          .collection('bookings')
          .where('userId', isEqualTo: user.uid)
          .where('parkingId', isEqualTo: parking['id'])
          .where('status', isEqualTo: 'active')
          .get();

      final hasExistingBooking = existingBooking.docs.isNotEmpty;

      if (!mounted) return;

      String message = '';
      if (availability['limitReached']) {
        message = 'You have reached the maximum limit of 3 active bookings';
      } else if (hasExistingBooking) {
        message = 'You already have an active booking in this parking';
      } else if (availability['realAvailable'] <= 0) {
        message = 'No spots available at this time';
      }

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(parking['name'] ?? 'Unnamed Parking'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total Capacity: ${parking['capacity']} spots'),
              Text(
                'Available: ${availability['realAvailable']} spots',
                style: TextStyle(
                    color: (availability['canBook'] && !hasExistingBooking) 
                           ? Colors.green 
                           : Colors.red,
                    fontWeight: FontWeight.bold),
              ),
              Text('Price: ${parking['price']}'),
              if (parking['status'] != 'active')
                Text('Status: ${parking['status']}',
                    style: TextStyle(color: Colors.red)),
              if (message.isNotEmpty)
                Text(
                  message,
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close'),
            ),
            if (availability['canBook'] && 
                !hasExistingBooking && 
                parking['status'] == 'active')
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SpotSelectionScreen(
                        parkingId: parking['id'],
                        parkingName: parking['name'],
                        parkingData: parking,
                      ),
                    ),
                  );
                },
                child: Text('Select Spot'),
              ),
            if (hasExistingBooking)
              TextButton(
                onPressed: null, // Disabled button
                child: Text(
                  'Already Booked',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
          ],
        ),
      );
    } catch (e) {
      print('Error showing parking details: $e');
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading parking details')));
    }
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

  Future<void> _handleSignOut() async {
    // Show confirmation dialog first
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Sign Out'),
          content: const Text('Are you sure you want to sign out?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: const Text('Sign Out'),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    // If user didn't confirm, return
    if (confirm != true) return;

    try {
      // Cancel all subscriptions first
      _locationSubscription?.cancel();
      _locationUpdateTimer?.cancel();
      _parkingSubscription?.cancel();
      _mapController.dispose();

      // Clean up user session in Firestore
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({
          'lastSignOut': FieldValue.serverTimestamp(),
          'activeSession': false,
        });
      }

      // Sign out from Firebase Auth
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      // Navigate to login and clear all routes
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error signing out: ${e.toString()}'),
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

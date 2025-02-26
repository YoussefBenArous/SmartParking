import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:smart_parking/Login_and_SignUp/LoginPage.dart';
import 'package:smart_parking/Setting/Setting.dart';
import 'dart:async';  // Add this import

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  LatLng? _currentLocation;
  late final MapController _mapController;
  final Location _locationService = Location();
  List<Map<String, dynamic>> _parkingLocations = [];
  List<Map<String, dynamic>> _filteredParkingLocations = [];
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = true;
  String _errorMessage = '';
  bool _isMapReady = false;
  StreamSubscription<LocationData>? _locationSubscription;
  Timer? _locationUpdateTimer;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _initializeLocationSettings();
    _initializeApp();
  }

  Future<void> _initializeLocationSettings() async {
    await _locationService.changeSettings(
      accuracy: LocationAccuracy.high,
      interval: 5000,
      distanceFilter: 5,
    );
  }

  Future<void> _initializeApp() async {
    try {
      _initializeParkingLocations();
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

  Future<void> _setupLocationUpdates() async {
    try {
      bool serviceEnabled = await _locationService.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await _locationService.requestService();
        if (!serviceEnabled) {
          throw Exception('Location services are disabled');
        }
      }

      PermissionStatus permissionGranted = await _locationService.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await _locationService.requestPermission();
        if (permissionGranted != PermissionStatus.granted) {
          throw Exception('Location permission denied');
        }
      }

      // Get initial location
      final locationData = await _locationService.getLocation();
      _updateLocation(locationData);

      // Start location updates
      _locationSubscription?.cancel();
      _locationSubscription = _locationService.onLocationChanged.listen(
        _updateLocation,
        onError: (error) {
          setState(() {
            _errorMessage = 'Location update error: $error';
          });
        }
      );

      // Refresh location every minute as backup
      _locationUpdateTimer?.cancel();
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
        locationData.accuracy! <= 100) { // Only update if accuracy is within 100 meters
      setState(() {
        _currentLocation = LatLng(locationData.latitude!, locationData.longitude!);
        if (_isMapReady) {
          _mapController.move(_currentLocation!, 15.0);
          _filterParkingNearby(); // Update nearby parking spots
        }
      });
    }
  }

  void _initializeParkingLocations() {
    _parkingLocations = [
      {
        'name': 'Parking Lac 1',
        'location': LatLng(36.8317, 10.2292),
        'capacity': 200,
        'available': 45,
        'price': '2 TND/hour'
      },
      {
        'name': 'Parking Tunisia Mall',
        'location': LatLng(36.8468, 10.2744),
        'capacity': 500,
        'available': 120,
        'price': '3 TND/hour'
      },
      {
        'name': 'Parking Carrefour La Marsa',
        'location': LatLng(36.8789, 10.3238),
        'capacity': 300,
        'available': 80,
        'price': '2 TND/hour'
      },
      // Add more parking locations as needed
    ];
    _filteredParkingLocations = _parkingLocations;
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

      PermissionStatus permissionGranted = await _locationService.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await _locationService.requestPermission();
        if (permissionGranted != PermissionStatus.granted) {
          throw Exception('Location permission denied');
        }
      }

      final locationData = await _locationService.getLocation();
      if (locationData.latitude != null && locationData.longitude != null) {
        setState(() {
          _currentLocation = LatLng(locationData.latitude!, locationData.longitude!);
        });
        
        // Only move map if it's ready
        if (_isMapReady) {
          _mapController.move(_currentLocation!, 15.0);
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error getting location: $e';
      });
    }
  }

  void _filterParkingNearby() {
    if (_currentLocation == null) return;

    const double radiusInKm = 5.0; // Search radius in kilometers
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
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => LoginPage(),
              ),
            );
          },
          icon: Icon(
            Icons.account_circle_outlined,
          ),
          iconSize: 45,
        ),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(
              right: 50,
              top: 11,
            ),
            child: SizedBox(
              width: 183,
              height: 42,
              child: TextFormField(
                controller: _searchController,
                onChanged: _searchParking,
                decoration: InputDecoration(
                  suffixIcon: IconButton(
                    onPressed: () {},
                    icon: Icon(
                      Icons.search,
                    ),
                  ),
                  hintText: "Search",
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: Colors.black,
                    fontStyle: FontStyle.normal,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: Color(0XFF9F4949),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: Color(0XFF9F4949),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
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
              // Move to current location if we have it
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
                child: GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(parking['name']),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Capacity: ${parking['capacity']} spots'),
                            Text('Available: ${parking['available']} spots'),
                            Text('Price: ${parking['price']}'),
                          ],
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: Text('Close'),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              // Add booking logic here
                            },
                            child: Text('Book Now'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(20),
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
          onPressed: () {},
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
      floatingActionButtonLocation: FloatingActionButtonLocation.miniCenterDocked,
      bottomNavigationBar: SizedBox(
        height: 70,
        width: double.infinity,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () {},
                icon: Icon(
                  Icons.home_outlined,
                  color: Color(0XFF767D81),
                ),
                iconSize: 40,
              ),
              SizedBox(width: 125),
              IconButton(
                onPressed: () {
                  _getUserLocation();
                },
                icon: Icon(
                  Icons.map_outlined,
                  color: Color(0XFF767D81),
                ),
                iconSize: 40,
              ),
              SizedBox(width: 125),
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
                iconSize: 40,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _locationUpdateTimer?.cancel();
    _mapController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}
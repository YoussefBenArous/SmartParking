import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class ParkingAddPage extends StatefulWidget {
  @override
  _ParkingAddPageState createState() => _ParkingAddPageState();
}

class _ParkingAddPageState extends State<ParkingAddPage> {
  late MapController _mapController;
  LatLng? _selectedLocation;
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _capacityController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  final _searchController = TextEditingController();
  final double _minimumDistanceBetweenParkings = 100; // in meters
  List<Location> _searchResults = [];
  bool _isSearching = false;
  String? _address;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

Future<bool> _isLocationAvailable(LatLng location) async {
  try {
    final parkingSpots = await FirebaseFirestore.instance.collection('parking').get();

    for (var doc in parkingSpots.docs) {
      GeoPoint parkingLocation = doc.data()['location'];
      double distance = Geolocator.distanceBetween(
        location.latitude, location.longitude,
        parkingLocation.latitude, parkingLocation.longitude,
      );

      if (distance < _minimumDistanceBetweenParkings) {
        setState(() {
          _errorMessage = 'A parking already exists within $_minimumDistanceBetweenParkings meters.';
        });
        return false;
      }
    }
    return true;
  } catch (e) {
    setState(() {
      _errorMessage = 'Error checking location: $e';
    });
    return false;
  }
}

Future<void> _getAddressFromLatLng(LatLng position) async {
  try {
    List<Placemark> placemarks = await placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );

    if (placemarks.isNotEmpty) {
      Placemark place = placemarks[0];
      setState(() {
        _address = '${place.street}, ${place.locality}, ${place.country}';
      });
    }
  } catch (e) {
    print('Error getting address: $e');
  }
}

Future<void> _searchLocation(String query) async {
  if (query.isEmpty) return;

  setState(() {
    _isSearching = true;
    _errorMessage = null;
  });

  try {
    List<Location> locations = await locationFromAddress(query);
    if (locations.isNotEmpty) {
      Location firstLocation = locations.first;
      LatLng newPosition = LatLng(firstLocation.latitude, firstLocation.longitude);

      setState(() {
        _searchResults = locations;
        _selectedLocation = newPosition;
      });

      // Move map to searched location
      _mapController.move(newPosition, 15);
    } else {
      setState(() {
        _errorMessage = 'Location not found';
        _searchResults = [];
      });
    }
  } catch (e) {
    setState(() {
      _errorMessage = 'Location not found';
      _searchResults = [];
    });
  } finally {
    setState(() {
      _isSearching = false;
    });
  }
}

Future<void> _saveParkingSpot() async {
  if (!_validateInputs()) return;

  setState(() {
    _isLoading = true;
    _errorMessage = null;
  });

  try {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("User not logged in.");

    // Ensure the user is a Parking Owner
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (userDoc.data()?['userType'] != 'Parking Owner') {
      throw Exception("User is not a Parking Owner.");
    }

    // Start a batch write
    WriteBatch batch = FirebaseFirestore.instance.batch();

    // Create the main parking document
    DocumentReference parkingRef = FirebaseFirestore.instance.collection('parking').doc();
    
    final parkingData = {
      'name': _nameController.text.trim(),
      'location': {
        'latitude': _selectedLocation!.latitude,
        'longitude': _selectedLocation!.longitude,
      },
      'capacity': int.parse(_capacityController.text),
      'available': int.parse(_capacityController.text),
      'price': _priceController.text.trim(),
      'ownerId': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'address': _address ?? 'Need to fix',
      'status': 'active',
    };

    batch.set(parkingRef, parkingData);

    // Add parking reference to owner's parkings collection
    DocumentReference ownerParkingRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('ownedParkings')
        .doc(parkingRef.id);

    batch.set(ownerParkingRef, {
      ...parkingData,
      'parkingId': parkingRef.id,
    });

    // Update user's document to indicate they own parkings
    DocumentReference userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    batch.update(userRef, {
      'hasParking': true,
      'parkingCount': FieldValue.increment(1),
      'lastUpdated': FieldValue.serverTimestamp(),
    });

    // Commit the batch
    await batch.commit();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Parking spot added successfully'))
    );
    Navigator.pop(context);
  } on FirebaseException catch (e) {
    setState(() {
      _errorMessage = 'Firestore Error: ${e.code} - ${e.message}';
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Firestore Error: ${e.message}'), backgroundColor: Colors.red)
    );
  } catch (e) {
    setState(() {
      _errorMessage = e.toString();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red)
    );
  } finally {
    setState(() => _isLoading = false);
  }
}
bool _validateInputs() {
  if (_selectedLocation == null || 
      _nameController.text.trim().isEmpty ||
      _priceController.text.trim().isEmpty || 
      _capacityController.text.trim().isEmpty) {
    setState(() {
      _errorMessage = "Please fill all fields and select a location.";
    });
    return false;
  }

  if (int.tryParse(_capacityController.text) == null) {
    setState(() {
      _errorMessage = "Capacity must be a valid number.";
    });
    return false;
  }

  return true;
}

bool _validateParkingData(Map<String, dynamic> data) {
  return data.containsKey('name') &&
         data.containsKey('location') &&
         data['location'] is Map &&
         data['location']['latitude'] is double &&
         data['location']['longitude'] is double &&
         data.containsKey('capacity') &&
         data.containsKey('available') &&
         data.containsKey('price') &&
         data.containsKey('ownerId') &&
         data['capacity'] is int &&
         data['available'] is int &&
         data['available'] <= data['capacity'] &&
         data['price'] is String;
}

void _onMapTap(TapPosition tapPosition, LatLng latlng) async {
  setState(() {
    _selectedLocation = latlng;
    _isLoading = true;
  });

  await _getAddressFromLatLng(latlng);

  setState(() {
    _isLoading = false;
  });
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Add Parking Spot')),
      body: SingleChildScrollView( // Wrap with SingleChildScrollView
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Search location',
                  suffixIcon: IconButton(
                    icon: Icon(_isSearching ? Icons.hourglass_empty : Icons.search),
                    onPressed: () => _searchLocation(_searchController.text),
                  ),
                  border: OutlineInputBorder(),
                ),
                onSubmitted: _searchLocation,
              ),
              if (_searchResults.isNotEmpty)
                Container(
                  height: 200,
                  child: ListView.builder(
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final location = _searchResults[index];
                      return ListTile(
                        title: Text('${location.latitude}, ${location.longitude}'),
                        onTap: () {
                          setState(() {
                            _selectedLocation = LatLng(
                              location.latitude,
                              location.longitude,
                            );
                            _mapController.move(_selectedLocation!, 15);
                            _searchResults = [];
                            _searchController.clear();
                          });
                        },
                      );
                    },
                  ),
                ),
              if (_address != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text(
                    'Selected Location: $_address',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              SizedBox(height: 10),
              _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : Column(
                      children: [
                        Text('Select Parking Location'),
                        SizedBox(height: 10),
                        SizedBox(
                          height: 300,
                          child: FlutterMap(
                            mapController: _mapController,
                            options: MapOptions(
                              initialCenter: LatLng(36.8065, 10.1815), // Center map (Tunisia)
                              initialZoom: 13.0,
                              onTap: _onMapTap,
                            ),
                            children: [
                              TileLayer(
                                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                tileProvider: CancellableNetworkTileProvider(),
                              ),
                              if (_selectedLocation != null)
                                MarkerLayer(
                                  markers: [
                                    Marker(
                                      point: _selectedLocation!,
                                      width: 40,
                                      height: 40,
                                      child: Icon(Icons.location_pin, size: 40, color: Colors.red),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                        SizedBox(height: 20),
                        TextField(
                          controller: _nameController,
                          decoration: InputDecoration(labelText: 'Parking Name'),
                        ),
                        TextField(
                          controller: _priceController,
                          decoration: InputDecoration(labelText: 'Price per Hour'),
                          keyboardType: TextInputType.number,
                        ),
                        TextField(
                          controller: _capacityController,
                          decoration: InputDecoration(labelText: 'Capacity'),
                          keyboardType: TextInputType.number,
                        ),
                        if (_errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _saveParkingSpot,
                          child: Text('Save Parking Spot'),
                        ),
                      ],
                    ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    _nameController.dispose();
    _priceController.dispose();
    _capacityController.dispose();
    super.dispose();
  }
}

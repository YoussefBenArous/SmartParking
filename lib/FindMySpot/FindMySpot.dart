import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';
import 'package:smart_parking/Setting/Setting.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FindMySpot extends StatefulWidget {
  final String parkingId;
  final String spotId;

  const FindMySpot({
    super.key,
    required this.parkingId,
    required this.spotId,
  });

  @override
  State<FindMySpot> createState() => _FindMySpotState();
}

class _FindMySpotState extends State<FindMySpot> {
  final DatabaseReference _spotsRef = FirebaseDatabase.instance.ref('spots');
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Location and distance variables
  Position? _userPosition;
  Map<String, double>? _spotPosition;
  double? _distance;
  double? _bearing;
  
  // Status variables
  String? _error;
  bool _isLoading = true;
  bool _hasShownArrivalDialog = false;
  
  // Stream subscriptions
  StreamSubscription<DatabaseEvent>? _spotSubscription;
  StreamSubscription<Position>? _locationSubscription;
  Timer? _timeoutTimer;

  @override
  void initState() {
    super.initState();
    _initializeWithTimeout();
  }

  Future<void> _initializeWithTimeout() async {
    // Set timeout for initialization
    _timeoutTimer = Timer(const Duration(seconds: 30), () {
      if (_isLoading && mounted) {
        setState(() {
          _error = 'Initialization timeout. Please check your connection.';
          _isLoading = false;
        });
      }
    });

    try {
      // First get location permissions
      await _requestLocationPermissions();
      
      // Then get spot location from database
      await _getSpotLocation();
      
      // Start location updates
      await _startLocationUpdates();
      
      _timeoutTimer?.cancel();
      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      _timeoutTimer?.cancel();
      if (mounted) {
        setState(() {
          _error = _getReadableError(e);
          _isLoading = false;
        });
        _showErrorDialog(_error!);
      }
    }
  }

  Future<void> _getSpotLocation() async {
    try {
      final snapshot = await _spotsRef
          .child(widget.parkingId)
          .child(widget.spotId)
          .get();

      if (!snapshot.exists) {
        throw Exception('Spot not found in database');
      }
      
      final spotData = snapshot.value as Map<dynamic, dynamic>;
      final location = spotData['location'] as Map<dynamic, dynamic>?;
      
      if (location == null || 
          !location.containsKey('latitude') || 
          !location.containsKey('longitude')) {
        throw Exception('Spot location coordinates not available');
      }
      
      if (mounted) {
        setState(() {
          _spotPosition = {
            'latitude': (location['latitude'] as num).toDouble(),
            'longitude': (location['longitude'] as num).toDouble(),
          };
        });
      }

      // Listen for real-time spot location changes
      _spotSubscription = _spotsRef
          .child(widget.parkingId)
          .child(widget.spotId)
          .onValue
          .listen((event) {
        if (!event.snapshot.exists || !mounted) return;

        final data = event.snapshot.value as Map<dynamic, dynamic>;
        final newLocation = data['location'] as Map<dynamic, dynamic>?;
        
        if (newLocation != null &&
            newLocation.containsKey('latitude') &&
            newLocation.containsKey('longitude')) {
          setState(() {
            _spotPosition = {
              'latitude': (newLocation['latitude'] as num).toDouble(),
              'longitude': (newLocation['longitude'] as num).toDouble(),
            };
          });
          
          // Recalculate distance if user position is available
          if (_userPosition != null) {
            _calculateDistanceAndBearing(
              _userPosition!.latitude,
              _userPosition!.longitude,
              _spotPosition!['latitude']!,
              _spotPosition!['longitude']!,
            );
          }
        }
      });
    } catch (e) {
      throw Exception('Failed to get spot location: ${e.toString()}');
    }
  }

  String _getReadableError(dynamic error) {
    final errorStr = error.toString().toLowerCase();
    
    if (errorStr.contains('permission')) {
      return 'Location permission is required to find your spot';
    } else if (errorStr.contains('service')) {
      return 'Please enable location services';
    } else if (errorStr.contains('spot not found')) {
      return 'Parking spot not found';
    } else if (errorStr.contains('coordinates not available')) {
      return 'Spot location not set by parking owner';
    } else if (errorStr.contains('network') || errorStr.contains('connection')) {
      return 'Network connection issue. Please check your internet';
    } else if (errorStr.contains('timeout')) {
      return 'Request timed out. Please try again';
    }
    
    return 'Unable to find your spot. Please try again';
  }

  Future<void> _requestLocationPermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services must be enabled');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied. Please enable in settings.');
    }
  }

  Future<void> _startLocationUpdates() async {
    try {
      // Get initial position with high accuracy
      final initialPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 15),
      );
      
      _updateUserPosition(initialPosition);

      // Start continuous location updates
      _locationSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 2, // Update every 2 meters
          timeLimit: Duration(seconds: 10),
        ),
      ).listen(
        _updateUserPosition,
        onError: (error) {
          debugPrint('Location stream error: $error');
          // Try to get position manually if stream fails
          _fallbackLocationUpdate();
        },
      );

    } catch (e) {
      debugPrint('Initial location error: $e');
      // Fallback to lower accuracy if high accuracy fails
      await _fallbackLocationUpdate();
    }
  }

  Future<void> _fallbackLocationUpdate() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 10),
      );
      _updateUserPosition(position);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Unable to get your location. Please check GPS settings';
        });
      }
    }
  }

  void _updateUserPosition(Position position) {
    if (!mounted) return;

    setState(() => _userPosition = position);
    
    if (_spotPosition != null) {
      _calculateDistanceAndBearing(
        position.latitude,
        position.longitude,
        _spotPosition!['latitude']!,
        _spotPosition!['longitude']!,
      );
      
      // Show arrival dialog if within 5 meters
      if (_distance != null && _distance! < 5 && !_hasShownArrivalDialog) {
        _hasShownArrivalDialog = true;
        _showArrivalDialog();
      }
    }
  }

  void _calculateDistanceAndBearing(
    double userLat, 
    double userLng, 
    double spotLat, 
    double spotLng,
  ) {
    try {
      final distance = Geolocator.distanceBetween(
        userLat, userLng, spotLat, spotLng,
      );
      
      final bearing = Geolocator.bearingBetween(
        userLat, userLng, spotLat, spotLng,
      );
      
      if (mounted) {
        setState(() {
          _distance = distance;
          _bearing = bearing < 0 ? bearing + 360 : bearing;
        });
      }
    } catch (e) {
      debugPrint('Error calculating distance/bearing: $e');
    }
  }

  String _getDetailedDirection(double bearing) {
    if (bearing >= 337.5 || bearing < 22.5) return 'North ↑';
    if (bearing >= 22.5 && bearing < 67.5) return 'Northeast ↗';
    if (bearing >= 67.5 && bearing < 112.5) return 'East →';
    if (bearing >= 112.5 && bearing < 157.5) return 'Southeast ↘';
    if (bearing >= 157.5 && bearing < 202.5) return 'South ↓';
    if (bearing >= 202.5 && bearing < 247.5) return 'Southwest ↙';
    if (bearing >= 247.5 && bearing < 292.5) return 'West ←';
    if (bearing >= 292.5 && bearing < 337.5) return 'Northwest ↖';
    return 'North ↑';
  }

  String _formatDistance(double distance) {
    if (distance < 1000) {
      return '${distance.toStringAsFixed(0)}m';
    } else {
      return '${(distance / 1000).toStringAsFixed(1)}km';
    }
  }

  void _showArrivalDialog() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 30),
            SizedBox(width: 10),
            Text('You Have Arrived!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.local_parking, color: Colors.blue, size: 60),
            const SizedBox(height: 16),
            Text(
              'You are now ${_formatDistance(_distance ?? 0)} from your parking spot',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 8),
            const Text(
              'Look around for your reserved spot!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const SettingPage()),
              (route) => false,
            ),
            child: const Text('OK', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Row(
          children: [
            Icon(Icons.error, color: Colors.red, size: 30),
            SizedBox(width: 10),
            Text('Error'),
          ],
        ),
        content: Text(message, style: const TextStyle(fontSize: 16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const SettingPage()),
              (route) => false,
            ),
            child: const Text('OK', style: TextStyle(fontSize: 16)),
          ),
          if (message.contains('permission') || message.contains('service'))
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _initializeWithTimeout(); // Retry
              },
              child: const Text('Retry', style: TextStyle(fontSize: 16)),
            ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(
          color: Colors.white,
          strokeWidth: 3,
        ),
        SizedBox(height: 20),
        Text(
          'Finding your spot...',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        SizedBox(height: 10),
        Text(
          'Getting location and spot data...',
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildNavigationState() {
    if (_distance == null || _bearing == null) {
      return const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: Colors.yellow),
          SizedBox(height: 16),
          Text(
            'Calculating distance...',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
        ],
      );
    }

    final hasArrived = _distance! < 5;
    final formattedDistance = _formatDistance(_distance!);
    final detailedDirection = _getDetailedDirection(_bearing!);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Distance display
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          decoration: BoxDecoration(
            color: hasArrived ? Colors.green.withOpacity(0.2) : Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: hasArrived ? Colors.green : Colors.white30,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Text(
                hasArrived ? 'You have arrived!' : formattedDistance,
                style: TextStyle(
                  fontSize: 28,
                  color: hasArrived ? Colors.green : Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (!hasArrived) ...[
                const SizedBox(height: 5),
                Text(
                  'to your parking spot',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              ],
            ],
          ),
        ),
        
        const SizedBox(height: 30),
        
        if (!hasArrived) ...[
          // Compass/Navigation arrow
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.1),
              border: Border.all(color: Colors.white30, width: 2),
            ),
            child: Transform.rotate(
              angle: _bearing! * (math.pi / 180),
              child: const Icon(
                Icons.navigation,
                size: 60,
                color: Colors.yellow,
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Direction text
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Head $detailedDirection',
              style: const TextStyle(
                fontSize: 20,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Spot info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Text(
                  'Spot: ${widget.spotId}',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Parking: ${widget.parkingId}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
        ] else ...[
          const Icon(
            Icons.local_parking,
            size: 80,
            color: Colors.green,
          ),
          const SizedBox(height: 10),
          const Text(
            'Look for your reserved spot nearby!',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.green, width: 1),
            ),
            child: Text(
              'Spot: ${widget.spotId}',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.green,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return _buildLoadingState();
    }

    if (_error != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 60, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            _error!,
            style: const TextStyle(color: Colors.red, fontSize: 18),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _error = null;
                _isLoading = true;
                _hasShownArrivalDialog = false;
              });
              _initializeWithTimeout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF0079C0),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: const Text('Retry'),
          ),
        ],
      );
    }

    return _buildNavigationState();
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _spotSubscription?.cancel();
    _locationSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const SettingPage()),
        );
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0079C0),
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const SettingPage()),
            ),
          ),
          backgroundColor: const Color(0xFF0079C0),
          elevation: 0,
          title: const Text(
            'Find My Spot',
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w600),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated search GIF
                  ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Image.asset(
                      'assets/images/Search1.gif',
                      height: 200,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 200,
                          width: 200,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: const Icon(
                            Icons.search_outlined,
                            size: 80,
                            color: Colors.white,
                          ),
                        );
                      },
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Main content
                  _buildContent(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
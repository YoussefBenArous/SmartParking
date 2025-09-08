import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_parking/FindMySpot/FindMySpot.dart';
import 'package:smart_parking/HomePage/userpages/UserHome.dart';
import 'package:smart_parking/Login_and_SignUp/LoginPage.dart';
import 'package:smart_parking/PayScreen/SelectParkingToPay.dart';
import 'package:smart_parking/Setting/ChangePassword.dart';
import 'package:smart_parking/Setting/RemoveReservation.dart';
import 'package:smart_parking/widget/CustomTiltle.dart';
import 'package:smart_parking/widget/button.dart'; // Ensure it's correctly defined

class SettingPage extends StatefulWidget {
  const SettingPage({super.key});

  @override
  _SettingPageState createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;
  String userName = "Loading..."; // Valeur par défaut

  @override
  void initState() {
    super.initState();
    _loadUserName();
  }

  Future<void> _loadUserName() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedName = prefs.getString("userName");

    if (savedName != null) {
      setState(() {
        userName = savedName;
      });
    } else {
      // Si le nom n'est pas dans SharedPreferences, on va le chercher dans Firestore
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection("users")
            .doc(user.uid)
            .get();

        if (userDoc.exists && userDoc.data() != null) {
          setState(() {
            userName = userDoc["name"] ?? "Guest";
          });

          // Sauvegarde le nom dans SharedPreferences pour la prochaine fois
          await prefs.setString("userName", userName);
        }
      }
    }
  }

  Future<void> _navigateToFindMySpot(BuildContext context) async {
    try {
      print("Starting FindMySpot navigation...");
      
      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print("Location services are disabled");
        showDialog(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: const Text('Location Services Disabled'),
            content: const Text('Please enable location services to use this feature.'),
            actions: [
              TextButton(
                child: const Text('OK'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
        return;
      }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        print("Requesting location permission");
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          print("Location permission denied");
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Location permission is required")),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        print("Location permission permanently denied");
        showDialog(
          context: context,
          builder: (BuildContext context) => AlertDialog(
            title: const Text('Location Permission Required'),
            content: const Text('Please enable location permission in your device settings.'),
            actions: [
              TextButton(
                child: const Text('OK'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
        return;
      }

      // Try to get current position to verify location access
      try {
        await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 5),
        );
      } catch (e) {
        print("Error getting location: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Unable to access location. Please check your settings.")),
        );
        return;
      }

      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("User not authenticated.")),
        );
        return;
      }

      print("Fetching active reservations for user: ${user.uid}");

      final bookingQuery = await FirebaseFirestore.instance
          .collection('bookings')
          .where('userId', isEqualTo: user.uid)
          .where('status', isEqualTo: 'active')
          .get();

      if (bookingQuery.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No active reservations found.")),
        );
        return;
      }

      print("Active reservations found: ${bookingQuery.docs.length}");

      for (var bookingDoc in bookingQuery.docs) {
        final bookingData = bookingDoc.data();
        final String parkingId = bookingData['parkingId'];
        final String spotId = bookingData['spotId'];

        print("Checking spot: parkingId=$parkingId, spotId=$spotId");

        final spotSnapshot = await FirebaseDatabase.instance
            .ref('spots/$parkingId/$spotId')
            .get();

        if (spotSnapshot.exists) {
          final spotData = spotSnapshot.value as Map<dynamic, dynamic>;
          print("DEBUG - Spot Data: $spotData"); // Debug log
          print("DEBUG - Location Data: ${spotData['location']}"); // Debug log

          // Verify location data exists before navigating
          final locationData = spotData['location'] as Map<dynamic, dynamic>?;
          if (locationData == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Spot location data not found")),
            );
            return;
          }

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FindMySpot(
                parkingId: parkingId,
                spotId: spotId,
              ),
            ),
          );
          return;
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No occupied spots found.")),
      );
    } catch (e) {
      print("DEBUG - Error: $e"); // Debug log
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: ${e.toString()}")),
      );
    }
  }

  Future<void> _signOut() async {
    try {
      setState(() => _isLoading = true);
      
      // Don't terminate Firestore here
      await _auth.signOut();
      
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => LoginPage()),
          (route) => false,
        );
      }
    } catch (e) {
      print('Error signing out: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0XFF0079C0),
      appBar: AppBar(
        toolbarHeight: 100,
        backgroundColor: const Color(0XFF0079C0),
        title: Center(
          child: CustomTitle(
            text: "Settings",
            color: Colors.white,
            size: 32,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => HomePage()),
            );
          },
          icon: const Icon(Icons.arrow_back_rounded,
            color: Colors.white,
          ),
          iconSize: 25,
        ),
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
            padding: const EdgeInsets.only(top: 50),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(
                  Icons.account_circle,
                  size: 80,
                  color: Colors.blue,
                ),
                const SizedBox(height: 10),
                Text(
                  userName,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                button(
                  onPressed: () => _navigateToFindMySpot(context),
                  text: "Find My Spot",
                  fontsize: 20,
                  width: 293,
                  height: 45,
                  radius: 18,
                ),
                const SizedBox(height: 20),
                button(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ChangePassword(),
                      ),
                    );
                  },
                  text: "Security",
                  fontsize: 20,
                  width: 293,
                  height: 45,
                  radius: 18,
                ),
                const SizedBox(height: 20),
                button(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => RemoveReservation(),
                      ),
                    );
                  },
                  text: "Cancel Reservation",
                  fontsize: 20,
                  width: 293,
                  height: 45,
                  radius: 18,
                ),
                const SizedBox(height: 20),
                button(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SelectParkingToPay(),
                      ),
                    );
                  },
                  text: "Payment",
                  fontsize: 20,
                  width: 293,
                  height: 45,
                  radius: 18,
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

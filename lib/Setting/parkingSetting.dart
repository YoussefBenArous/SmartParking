import 'package:flutter/material.dart';
import 'package:smart_parking/HomePage/parkingownerPages/AddSpotOnParking.dart';
import 'package:smart_parking/HomePage/parkingownerPages/Modifyreservation.dart';
import 'package:smart_parking/HomePage/parkingownerPages/ParkingOwnerDashboard.dart';
import 'package:smart_parking/Setting/ChangePassword.dart';
import 'package:smart_parking/widget/CustomTiltle.dart';
import 'package:smart_parking/widget/button.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class OwnerSetting extends StatefulWidget {
  const OwnerSetting({super.key});

  @override
  State<OwnerSetting> createState() => _OwnerSettingState();
}

class _OwnerSettingState extends State<OwnerSetting> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? ownerName;
  bool _isLoading = true;

  // Add these properties
  Map<String, dynamic>? parkingData;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadOwnerData();
    _loadParkingData(); // Add this line
  }

  Future<void> _loadOwnerData() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        DocumentSnapshot ownerDoc =
            await _firestore.collection('users').doc(user.uid).get();

        if (ownerDoc.exists) {
          setState(() {
            ownerName = ownerDoc.get('name') ?? 'Owner';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading owner data: $e');
      setState(() => _isLoading = false);
    }
  }

  // Add this method
  Future<void> _loadParkingData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final parkingDoc = await _firestore
          .collection('parking')
          .where('ownerId', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (parkingDoc.docs.isNotEmpty) {
        setState(() {
          parkingData = {
            'id': parkingDoc.docs.first.id,
            ...parkingDoc.docs.first.data(),
          };
        });
      }
    } catch (e) {
      setState(() => errorMessage = e.toString());
      print('Error loading parking data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xff0079C0),
      extendBody: true,
      appBar: _buildAppBar(),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(50),
            topRight: Radius.circular(50),
          ),
        ),
        child: _isLoading
            ? Center(child: CircularProgressIndicator())
            : _buildSettingsContent(),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      leading: IconButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ParkingOwnerDashboard(),
          ),
        ),
        icon: Icon(Icons.arrow_back,color: Colors.white,),
      ),
      title: CustomTitle(
        text: "Settings",
        color: Colors.white,
        size: 32,
      ),
      centerTitle: true,
      backgroundColor: Color(0xff0079C0),
      toolbarHeight: 100,
    );
  }

  Widget _buildSettingsContent() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _buildProfileSection(),
            SizedBox(height: 30),
            _buildSettingsButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileSection() {
    return Column(
      children: [
        const Icon(
                  Icons.account_circle,
                  size: 80,
                  color: Colors.blue,
                ),
        SizedBox(height: 15),
        Text(
          ownerName ?? 'Loading...',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsButtons() {
    return Column(
      children: [
        button(
          onPressed: () async {
            if (parkingData != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddSpotOnParking(
                    parkingId: parkingData!['id'],
                    parkingName: parkingData!['name'] ?? 'Unknown Parking',
                  ),
                ),
              ).then((_) => _loadParkingData()); // Refresh data after return
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Error: Parking data not available'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          text: "Manage Parking",
          fontsize: 20,
          width: 293,
          height: 45,
          radius: 18,
        ),
        SizedBox(height: 20),
        button(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ChangePassword(),
                ),
              );
            },
            text: "Security",
            fontsize: 20,
            width: 293,
            height: 45,
            radius: 18),
        SizedBox(height: 20),
        // Replace the existing AddSpotOnParking button with this
        button(
          onPressed: () async {
            if (parkingData != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ModifyReservation(
                    parkingId: parkingData!['id'],
                    parkingName: parkingData!['name'] ?? 'Unknown Parking',
                    parkingData: parkingData!,
                  ),
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('No parking data available')),
              );
            }
          },
          text: "Modify Reservation",
          fontsize: 20,
          width: 293,
          height: 45,
          radius: 18,
        ),
      ],
    );
  }
}

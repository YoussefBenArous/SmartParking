import 'package:flutter/material.dart';
import 'package:smart_parking/HomePage/parkingownerPages/ParkingOwnerDashboard.dart';
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

  @override
  void initState() {
    super.initState();
    _loadOwnerData();
  }

  Future<void> _loadOwnerData() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        DocumentSnapshot ownerDoc = await _firestore
            .collection('users')
            .doc(user.uid)
            .get();

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
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ParkingOwnerDashboard())),
        icon: Icon(Icons.arrow_back_sharp),
      ),
      title: CustomTitle(
        text: "Paramètres",
        color: Colors.white,
        size: 32,
      ),
      centerTitle: true,
      backgroundColor: Color(0xff0079C0),
      elevation: 0,
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
        CircleAvatar(
          radius: 40,
          backgroundColor: Colors.grey[300],
          child: Icon(
            Icons.account_circle_outlined,
            size: 60,
            color: Colors.black54,
          ),
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
        _buildSettingButton("Modifier Mon Parking", () {
          // TODO: Implement parking modification
        }),
        SizedBox(height: 15),
        _buildSettingButton("Sécurité", () {
          // TODO: Implement security settings
        }),
        SizedBox(height: 15),
        _buildSettingButton("Modifier les Réservations", () {
          // TODO: Implement reservation settings
        }),
      ],
    );
  }

  Widget _buildSettingButton(String text, VoidCallback onPressed) {
    return button(
      onPressed: onPressed,
      text: text,
      fontsize: 20,
      width: MediaQuery.of(context).size.width * 0.8,
      height: 45,
      radius: 18,
    );
  }
}

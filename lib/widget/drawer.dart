import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:smart_parking/HomePage/parkingownerPages/ParkingOwnerDashboard.dart';
import 'package:smart_parking/Setting/parkingSetting.dart';
import 'package:smart_parking/services/auth_service.dart';
class CustomDrawer extends StatefulWidget {
  final String userType;

  const CustomDrawer({
    super.key,
    this.userType = 'User', // Default to regular user
  });

  @override
  State<CustomDrawer> createState() => _CustomDrawerState();
}

class _CustomDrawerState extends State<CustomDrawer> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
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
        DocumentSnapshot ownerDoc =
            await _firestore.collection('users').doc(user.uid).get();

        if (ownerDoc.exists && mounted) {
          setState(() {
            ownerName = ownerDoc.get('name') ?? 'Owner';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading owner data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(50),
          bottomRight: Radius.circular(50),
        ),
      ),
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(
              color: Color(0XFF0079C0),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(
                Icons.account_circle,
                size: 50,
                color: Color(0XFF0079C0),
              ),
            ),
            accountName: Text(
              ownerName ?? 'Loading...',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            accountEmail: Text(
              _auth.currentUser?.email ?? '',
              style: TextStyle(
                fontSize: 20,
                color: Colors.white70,
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildDrawerItem(
                  icon: Icons.person,
                  title: 'Profile',
                  onTap: () {},
                ),
                SizedBox(height: 20,),
                _buildDrawerItem(
                  icon: Icons.settings,
                  title: 'Settings',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => OwnerSetting(),
                      ),
                    );
                  },
                ),
                SizedBox(height: 20,),
                if (widget.userType == 'Parking Owner') ...[
                  _buildDrawerItem(
                    icon: Icons.analytics,
                    title: 'Statistics',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ParkingOwnerDashboard(),
                      ),
                    ),
                  ),
                  SizedBox(height: 20,),
                ],
                Divider(color: Colors.grey.shade300),
                _buildDrawerItem(
                  icon: Icons.logout,
                  title: 'Logout',
                  onTap: () => _showLogoutDialog(context),
                  color: Colors.red,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ListTile(
      leading: Icon(icon, color: color ?? Color(0XFF0079C0)),
      title: Text(
        title,
        style: TextStyle(
          color: color ?? Colors.black87,
          fontSize: 24,
        ),
      ),
      onTap: onTap,
      dense: true,
    );
  }

  Future<void> _showLogoutDialog(BuildContext context) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Logout'),
          content: Text('Are you sure you want to logout?'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text(
                'Logout',
                style: TextStyle(color: Colors.red),
              ),
              onPressed: () async {
                 await AuthService().signOut(context: context);
              },
            ),
          ],
        );
      },
    );
  }
}

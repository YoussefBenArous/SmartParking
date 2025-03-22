import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:smart_parking/Login_and_SignUp/LoginPage.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // Vérifier l'état de connexion
  static Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Vérifier le rôle de l'utilisateur
  static Future<String?> getUserRole() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      return doc.data()?['userType'] as String?;
    } catch (e) {
      print('Erreur lors de la récupération du rôle: $e');
      return null;
    }
  }

  Future<void> signout({required BuildContext context}) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        try {
          // Query only user's own active bookings (matches rules)
          final activeBookings = await _firestore
              .collection('bookings')
              .where('userId', isEqualTo: user.uid)
              .where('status', isEqualTo: 'active')
              .get();

          if (activeBookings.docs.isNotEmpty) {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Active Bookings'),
                content: const Text('You have active bookings. Are you sure you want to sign out?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Cancel'),
                    style: TextButton.styleFrom(foregroundColor: Colors.grey),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('Sign Out'),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                  ),
                ],
              ),
            );

            if (confirm != true) return;
          }
        } catch (e) {
          print('Error checking active bookings: $e');
          // Continue with signout even if checking bookings fails
        }
      }

      await _auth.signOut();
      
      // Show success message in VS Code console
      print('User signed out successfully');

      if (context.mounted) {
        // Show success message in app
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Signed out successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );

        // Navigate to login page
        await Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }
    } on FirebaseException catch (e) {
      print('Firebase Error during sign-out: ${e.code} - ${e.message}');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.message}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('Error during sign-out: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to sign out. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  // Vérifier la permission de localisation
  // static Future<bool> verifyLocationPermission() async {
  //   try {
  //     LocationPermission permission = await Geolocator.checkPermission();
  //     if (permission == LocationPermission.denied) {
  //       permission = await Geolocator.requestPermission();
  //     }
  //     return permission != LocationPermission.denied &&
  //            permission != LocationPermission.deniedForever;
  //   } catch (e) {
  //     print('Erreur de permission de localisation: $e');
  //     return false;
  //   }
  // }
}

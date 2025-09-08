import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Sign Up Method
  Future<UserCredential?> signUpWithEmailAndPassword({
    required String email,
    required String password,
    required String name,
    required String userType,
  }) async {
    try {
      // Email validation
      if (!email.contains('@') || !email.contains('.')) {
        throw FirebaseAuthException(
          code: 'invalid-email',
          message: 'Please enter a valid email address',
        );
      }

      // Password validation
      if (password.length < 6) {
        throw FirebaseAuthException(
          code: 'weak-password',
          message: 'Password should be at least 6 characters',
        );
      }

      // Create user with email and password
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // If user creation successful, store additional info in Firestore
      if (userCredential.user != null) {
        await _firestore.collection('users').doc(userCredential.user!.uid).set({
          'name': name,
          'email': email,
          'userType': userType,
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        // Update user profile
        await userCredential.user!.updateDisplayName(name);
        
        return userCredential;
      }
      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          throw FirebaseAuthException(
            code: e.code,
            message: 'This email is already registered. Please login or use a different email.',
          );
        case 'invalid-email':
          throw FirebaseAuthException(
            code: e.code,
            message: 'Please enter a valid email address.',
          );
        case 'operation-not-allowed':
          throw FirebaseAuthException(
            code: e.code,
            message: 'Email/password accounts are not enabled. Please contact support.',
          );
        case 'weak-password':
          throw FirebaseAuthException(
            code: e.code,
            message: 'Please enter a stronger password.',
          );
        default:
          throw FirebaseAuthException(
            code: 'registration-failed',
            message: 'Registration failed. Please try again later.',
          );
      }
    } catch (e) {
      throw FirebaseAuthException(
        code: 'unknown',
        message: 'An unexpected error occurred. Please try again.',
      );
    }
  }

  // Sign In Method
  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      // First verify if Firestore is available
      await _firestore.collection('users').limit(1).get();

      // Attempt sign in
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update last login
      await _firestore.collection('users').doc(userCredential.user!.uid).update({
        'lastLogin': FieldValue.serverTimestamp(),
      });

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Sign Out Method
  Future<void> signOut({required BuildContext context}) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        // Update last sign out time
        await _firestore.collection('users').doc(user.uid).update({
          'lastSignOut': FieldValue.serverTimestamp(),
          'activeSession': null,
        });
      }

      // Clear all persistent data
      await Future.wait([
        _firestore.terminate(),
        _firestore.clearPersistence(),
      ]);

      // Sign out from Firebase Auth
      await _auth.signOut();
      
      // Initialize a new instance after signout
      await _firestore.enableNetwork();

    } catch (e) {
      print('Sign out error: $e');
      // Ensure user is signed out even if Firestore operations fail
      await _auth.signOut();
    }
  }

  // Helper method to handle auth exceptions
  Exception _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-credential':
        return Exception('Invalid email or password');
      case 'user-disabled':
        return Exception('This account has been disabled');
      case 'user-not-found':
        return Exception('No account found with this email');
      case 'wrong-password':
        return Exception('Incorrect password');
      case 'email-already-in-use':
        return Exception('An account already exists with this email');
      case 'operation-not-allowed':
        return Exception('Operation not allowed');
      case 'weak-password':
        return Exception('Please enter a stronger password');
      default:
        return Exception('Authentication failed: ${e.message}');
    }
  }

  // Helper method to check Firestore connection
  Future<void> ensureFirestoreConnection() async {
    try {
      await _firestore.enableNetwork();
      await _firestore.collection('users').limit(1).get();
    } catch (e) {
      print('Error ensuring Firestore connection: $e');
      // Attempt to reinitialize Firestore
      await _firestore.terminate();
      await _firestore.enableNetwork();
    }
  }
}

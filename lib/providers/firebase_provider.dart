import 'package:flutter/material.dart';
import '../services/firebase_service.dart';

class FirebaseProvider extends InheritedWidget {
  final FirebaseService firebaseService;

  const FirebaseProvider({
    Key? key,
    required this.firebaseService,
    required Widget child,
  }) : super(key: key, child: child);

  static FirebaseProvider of(BuildContext context) {
    final provider = context.dependOnInheritedWidgetOfExactType<FirebaseProvider>();
    assert(provider != null, 'No FirebaseProvider found in context');
    return provider!;
  }

  @override
  bool updateShouldNotify(FirebaseProvider oldWidget) {
    return firebaseService != oldWidget.firebaseService;
  }
}

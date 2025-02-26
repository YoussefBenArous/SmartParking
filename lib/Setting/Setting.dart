import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_parking/HomePage/UserHome.dart';
import 'package:smart_parking/widget/CustomTiltle.dart';
import 'package:smart_parking/widget/button.dart'; // Ensure it's correctly defined

class SettingPage extends StatefulWidget {
  const SettingPage({super.key});

  @override
  _SettingPageState createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0XFF0079C0),
      appBar: AppBar(
        toolbarHeight: 100,
        backgroundColor: const Color(0XFF0079C0),
        centerTitle: true,
        title: const CustomTitle(
          text: "Settings",
          color: Colors.white,
          size: 32,
        ),
        leading: IconButton(
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const HomePage(),
              ),
            );
          },
          icon: const Icon(Icons.arrow_back_rounded),
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
                  Icons.account_circle_outlined,
                  size: 80,
                  color: Colors.black,
                ),
                const SizedBox(height: 10),

                // Affiche le nom de l'utilisateur
                Text(
                  userName,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 20),
                button(
                  onPressed: () {},
                  text: "Find My Place",
                  fontsize: 20,
                  width: 293,
                  height: 45,
                  radius: 18,
                ),
                const SizedBox(height: 20),
                button(
                  onPressed: () {},
                  text: "Security",
                  fontsize: 20,
                  width: 293,
                  height: 45,
                  radius: 18,
                ),
                const SizedBox(height: 20),
                button(
                  onPressed: () {},
                  text: "Cancel Reservation",
                  fontsize: 20,
                  width: 293,
                  height: 45,
                  radius: 18,
                ),
                const SizedBox(height: 20),
                button(
                  onPressed: () {},
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

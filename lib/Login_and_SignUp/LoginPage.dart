import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:smart_parking/HomePage/UserHome.dart';
import 'package:smart_parking/HomePage/ParkingHome.dart';
import 'package:smart_parking/Login_and_SignUp/SignUpPage.dart';
import 'package:smart_parking/widget/button.dart';
import 'package:smart_parking/widget/inputbutton.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscureText = true;
  bool _isLoading = false;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

Future<void> _login() async {
  if (!_formKey.currentState!.validate()) {
    return;
  }

  setState(() {
    _isLoading = true;
  });

  try {
    UserCredential userCredential = await _auth.signInWithEmailAndPassword(
      email: _emailController.text,
      password: _passwordController.text,
    );

    // ✅ Check if authentication was successful
    if (userCredential.user != null) {
      print("✅ Login successful! UID: ${userCredential.user!.uid}");

      // Fetch user data from Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      if (userDoc.exists) {
        print("✅ User document found in Firestore.");
        final userData = userDoc.data();
        final userRole = userData?['userType']; // Make sure it's 'userType'

        if (userRole == 'User') {
          print("✅ Navigating to Home Page.");
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const HomePage()),
          );
        } else if (userRole == 'Parking Owner') {
          print("✅ Navigating to Parking Owner Page.");
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const ParkingOwnerPage()),
          );
        } else {
          print("⚠️ Unrecognized user role: $userRole");
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unrecognized user role.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        print("❌ User document not found in Firestore!");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('User document not found.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  } on FirebaseAuthException catch (e) {
    print("❌ FirebaseAuthException: ${e.code}");
    String errorMessage = 'An error occurred';
    if (e.code == 'user-not-found') {
      errorMessage = 'No user found for that email.';
    } else if (e.code == 'wrong-password') {
      errorMessage = 'Wrong password provided.';
    } else if (e.code == 'invalid-email') {
      errorMessage = 'Invalid email address.';
    } else if (e.code == 'too-many-requests') {
      errorMessage = 'Too many requests. Try again later.';
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
    );
  } catch (e) {
    print("❌ General error: ${e.toString()}");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
    );
  } finally {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Transform.translate(
                offset: const Offset(-125, -40), // Move image left and up
                child: Image.asset(
                  "assets/images/logo1.png",
                  width: 300,
                  height: 250,
                ),
              ),
              const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Welcome Back",
                      style: TextStyle(
                        fontSize: 32,
                        fontStyle: FontStyle.normal,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 1), // Add spacing between the two texts
                    Text(
                      "Login To Your Account",
                      style: TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.normal,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              inputbutton(
                hintText: "Enter Your Email",
                controller: _emailController,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "Please enter your email";
                  }
                  if (!RegExp(
                          r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+")
                      .hasMatch(value)) {
                    return "Please enter a valid email";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),
              inputbutton(
                hintText: "Enter Your Password",
                obscureText: _obscureText,
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() {
                      _obscureText = !_obscureText;
                    });
                  },
                  icon: Icon(
                    _obscureText
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                ),
                controller: _passwordController,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "Please enter your password";
                  }
                  return null;
                },
              ),
              // Use Padding and Row to align the TextButton to the right
              Padding(
                padding:
                    const EdgeInsets.only(right: 20, top: 8), // Adjust padding
                child: Row(
                  mainAxisAlignment:
                      MainAxisAlignment.end, // Align to the right
                  children: [
                    TextButton(
                      onPressed: () {},
                      child: const Text(
                        "Forgot Password ?",
                        style: TextStyle(
                          color: Color(0xff0079C0),
                          fontSize: 11,
                          fontStyle: FontStyle.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(
                height: 10,
              ),
              Center(
                child: button(
                    onPressed: _login,
                    text: _isLoading ? "Logging in..." : "Login",
                    fontsize: 20,
                    width: 215,
                    height: 46,
                    radius: 18),
              ),
              const SizedBox(
                height: 40,
              ),
              const Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Divider(
                        color: Color(0xff3FA2FF),
                        thickness: 0.5,
                        indent: 25,
                        endIndent: 20,
                      ),
                    ),
                    Text(
                      "OR",
                      style: TextStyle(
                          color: Color(0xff424D5B),
                          fontStyle: FontStyle.normal,
                          fontWeight: FontWeight.bold,
                          fontSize: 20),
                    ),
                    Expanded(
                      child: Divider(
                        color: Color(0xff3FA2FF),
                        thickness: 0.5,
                        endIndent: 20,
                        indent: 25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(
                height: 10,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(
                      Icons.facebook,
                      color: Colors.blue,
                      size: 40,
                    ),
                  ),
                  const SizedBox(
                    width: 10,
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(
                      Icons.apple,
                      color: Colors.black,
                    ),
                    iconSize: 40,
                  ),
                  const SizedBox(
                    width: 10,
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: Image.asset("assets/images/google1.png"),
                    iconSize: 30,
                  ),
                ],
              ),
              const SizedBox(
                height: 10,
              ),
              Text.rich(
                TextSpan(
                  children: <TextSpan>[
                    const TextSpan(
                      text: "Don't Have An Account ?   ",
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.normal,
                      ),
                    ),
                    TextSpan(
                      text: "Create Account",
                      style: const TextStyle(
                        color: Color(0xff0079C0),
                        fontSize: 12,
                        fontStyle: FontStyle.normal,
                        decoration: TextDecoration.underline,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (context) => SignUpPage()),
                          );
                        },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

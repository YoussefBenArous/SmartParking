import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:smart_parking/Login_and_SignUp/LoginPage.dart';
import 'package:smart_parking/widget/CustomTiltle.dart';
import 'package:smart_parking/widget/button.dart';
import 'package:smart_parking/widget/inputbutton.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpState();
}

class _SignUpState extends State<SignUpPage> {
  final TextEditingController _nameTextController = TextEditingController();
  final TextEditingController _emailTextController = TextEditingController();
  final TextEditingController _phoneTextController = TextEditingController();
  final TextEditingController _passwordTextController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _ischecked = false;
  bool _obscureText = true;
  String? selectedType;
  bool _isLoading = false;
  bool _hasError = false;
  bool _isPhoneValid = false;

  void _signUp() async {
    if (!_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    if (!_ischecked) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please agree to the terms and conditions")),
      );
      return;
    }

    if (selectedType == null) {
      setState(() {
        _hasError = true; // Show error border
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a user type")),
      );
      return;
    }

    try {
      UserCredential userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailTextController.text.trim(),
        password: _passwordTextController.text.trim(),
      );

      await FirebaseFirestore.instance
          .collection("users")
          .doc(userCredential.user!.uid)
          .set({
        "name": _nameTextController.text.trim(),
        "email": _emailTextController.text.trim(),
        "phone": _phoneTextController.text.trim(),
        "userType": selectedType,
        "createdAt": DateTime.now(),
      });

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }
    } on FirebaseAuthException catch (error) {
      String errorMessage = "An error occurred. Please try again.";
      if (error.code == 'weak-password') {
        errorMessage = "The password provided is too weak.";
      } else if (error.code == 'email-already-in-use') {
        errorMessage = "The account already exists for that email.";
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${error.toString()}")),
        );
      }
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
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Logo and title
              Transform.translate(
                offset: const Offset(-125, -40),
                child: Image.asset(
                  "assets/images/logo1.png",
                  width: 300,
                  height: 250,
                ),
              ),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CustomTitle(
                      text: "Register",
                      color: Colors.black,
                      size: 32,
                    ),
                    const SizedBox(height: 1),
                    Text(
                      _isLoading
                          ? "Creating account..."
                          : "Create your new account",
                      style: const TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.normal,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // Name input
              inputbutton(
                hintText: "Enter Your Name",
                controller: _nameTextController,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "Please enter your name";
                  }
                  return null;
                },
              ),

              const SizedBox(height: 10),

              // Email input
              inputbutton(
                hintText: "Enter Your E-mail",
                controller: _emailTextController,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a valid email';
                  }
                  if (!RegExp(
                          r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+")
                      .hasMatch(value)) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 10),

              // Phone number input
               inputbutton(
                hintText: "Enter Your Phone Number",
                controller: _phoneTextController,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return "Please enter your Phone Number";
                  }
                  return null;
                },
              ),

              const SizedBox(height: 10),

              // Password input
              inputbutton(
                hintText: "Enter Your Password",
                obscureText: _obscureText,
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscureText = !_obscureText),
                  icon: Icon(_obscureText
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined),
                ),
                controller: _passwordTextController,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a password';
                  }
                  if (value.length < 6) {
                    return 'Password must be at least 6 characters long';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 10),

              // Type selector
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: FormField<String>(
                  validator: (value) {
                    if (selectedType == null) {
                      _hasError = true;
                      return 'Please select a user type';
                    }
                    return null;
                  },
                  builder: (FormFieldState<String> state) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 55,
                          decoration: BoxDecoration(
                            border: Border.all(
                              width: 2,
                              color: (_hasError || state.hasError)
                                  ? Colors.red
                                  : const Color(0xff8B8B8B),
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedType,
                              isExpanded: true,
                              hint: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 4),
                                child: Text(
                                  "Select Your Type",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontStyle: FontStyle.normal,
                                    color: Color(0xff8B8B8B),
                                  ),
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              items: const [
                                DropdownMenuItem(
                                  value: "User",
                                  child: Text(
                                    "User",
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontStyle: FontStyle.normal,
                                      color: Color(0xff8B8B8B),
                                    ),
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: "Parking Owner",
                                  child: Text(
                                    "Parking Owner",
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontStyle: FontStyle.normal,
                                      color: Color(0xff8B8B8B),
                                    ),
                                  ),
                                ),
                              ],
                              onChanged: (String? newValue) {
                                setState(() {
                                  selectedType = newValue;
                                  _hasError = false;
                                  state.didChange(newValue);
                                });
                              },
                            ),
                          ),
                        ),
                        if (state.hasError)
                          Padding(
                            padding: const EdgeInsets.only(left: 12, top: 8),
                            child: Text(
                              state.errorText!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),

              const SizedBox(height: 10),
              
              Padding(
                padding: const EdgeInsets.only(left: 30),
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Checkbox(
                        activeColor: Colors.blue,
                        side: const BorderSide(
                          color: Color(0XFF8B8B8B),
                          width: 2,
                        ),
                        value: _ischecked,
                        onChanged: (bool? newValue) {
                          setState(() {
                            _ischecked = newValue!;
                          });
                        },
                      ),
                    ),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: <TextSpan>[
                            const TextSpan(
                              text: "By signing up you agree to our ",
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 12,
                                fontStyle: FontStyle.normal,
                              ),
                            ),
                            TextSpan(
                              text: "Terms & Conditions ",
                              style: const TextStyle(
                                color: Color(0xff0079C0),
                                fontSize: 12,
                                fontStyle: FontStyle.normal,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                              recognizer: TapGestureRecognizer()..onTap = () {},
                            ),
                            const TextSpan(
                              text: "and ",
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 12,
                                fontStyle: FontStyle.normal,
                              ),
                            ),
                            TextSpan(
                              text: "Privacy Policy",
                              style: const TextStyle(
                                color: Color(0xff0079C0),
                                fontSize: 12,
                                fontStyle: FontStyle.normal,
                                decoration: TextDecoration.underline,
                                fontWeight: FontWeight.bold,
                              ),
                              recognizer: TapGestureRecognizer()..onTap = () {},
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              
              Center(
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : button(
                        onPressed: _signUp,
                        text: "Sign Up",
                        fontsize: 20,
                        width: 215,
                        height: 46,
                        radius: 18,
                      ),
              ),
              const SizedBox(height: 40),
              
              Text.rich(
                TextSpan(
                  children: <TextSpan>[
                    const TextSpan(
                      text: "Already have an Account? ",
                      style: TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.normal,
                      ),
                    ),
                    TextSpan(
                      text: "Login",
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
                                builder: (context) => const LoginPage()),
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
    _nameTextController.dispose();
    _emailTextController.dispose();
    _phoneTextController.dispose();
    _passwordTextController.dispose();
    super.dispose();
  }
}
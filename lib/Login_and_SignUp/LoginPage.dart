import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:smart_parking/HomePage/Home.dart';
import 'package:smart_parking/Login_and_SignUp/SignUpPage.dart';
import 'package:smart_parking/widget/inputbutton.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
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
            const inputbutton(hintText: "Enter Your Email"),
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
            ),
            // Use Padding and Row to align the TextButton to the right
            Padding(
              padding:
                  const EdgeInsets.only(right: 20, top: 8), // Adjust padding
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end, // Align to the right
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
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const HomePage(),
                    ),
                  );
                },
                child: const Text(
                  "Login",
                  style: TextStyle(
                    color: Colors.white,
                    fontStyle: FontStyle.normal,
                    fontSize: 20,
                  ),
                ),
                style: ButtonStyle(
                  backgroundColor: const MaterialStatePropertyAll(
                    Color(0xff0079C0),
                  ),
                  minimumSize: const MaterialStatePropertyAll(
                    Size(215, 46),
                  ),
                  shape: MaterialStateProperty.all(
                    ContinuousRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),
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
                          MaterialPageRoute(builder: (context) => SignUpPage()),
                        );
                      },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

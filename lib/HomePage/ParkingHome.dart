import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:smart_parking/Login_and_SignUp/SignUpPage.dart';
import 'package:smart_parking/widget/inputbutton.dart';

class ParkingOwnerPage  extends StatefulWidget {
  const ParkingOwnerPage({super.key});

  @override
  State<ParkingOwnerPage> createState() => _ParkingOwnerPage();
}

class _ParkingOwnerPage extends State<ParkingOwnerPage> {
  bool _obscureText = true;
  bool _agreeToTerms = false;
  String _selectedType = ""; // Initially empty
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            Transform.translate(
              offset: const Offset(-10, 30),
              child: Image.asset(
                "assets/images/First.jpg",
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
                    "WELCOME",
                    style: TextStyle(
                      fontSize: 32,
                      fontStyle: FontStyle.normal,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 1),
                  Text(
                    "Create Your Own Parking",
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
              hintText: "Enter Your Parking Name",
              controller: _nameController,
              
            ),
            const SizedBox(height: 20),
            inputbutton(
              hintText: "Enter Number Of Places",
              controller: _emailController,
              
            ),
            const SizedBox(height: 20),
            inputbutton(
              hintText: "Enter The Adress Of Parking",
              controller: _phoneController,
              
            ),
            const SizedBox(height: 20),
           

            // Custom Dropdown for selecting user type
            GestureDetector(
              onTap: () async {
                // Show Dialog for user type selection
                String? selected = await showDialog<String>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text("Select The Parking Type :"),
                    content: Container(
                      width: 150, // Adjust width as needed
                      height: 150, // Adjust height as needed
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ListTile(
                            title: Text(
                              "a savoir",
                              style: TextStyle(
                                fontSize: 24, // Larger text size
                                fontWeight: FontWeight.bold, // Bold text
                              ),
                            ),
                            onTap: () {
                              Navigator.pop(context, "a savoir");
                            },
                          ),
                          ListTile(
                            title: Text(
                              "a savoir",
                              style: TextStyle(
                                fontSize: 24, // Larger text size
                                fontWeight: FontWeight.bold, // Bold text
                              ),
                            ),
                            onTap: () {
                              Navigator.pop(context, "a savoir");
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                );

                if (selected != null) {
                  setState(() {
                    _selectedType = selected; // Update the selected type
                  });
                }
              },
              child: Container(
                height: 48,
                width: 375,
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.black45, // Lighter gray border
                    width: 2.0, // Consistent border width
                  ),
                  borderRadius: BorderRadius.circular(11.0), // Consistent border radius
                  color: Colors.white12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _selectedType.isEmpty ? "Select The Parking Type" : _selectedType,
                      style: TextStyle(fontSize: 13,  color: Color(0xff8B8B8B)),
                    ),
                    Icon(
                      Icons.arrow_drop_down,
                      color: Colors.black,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Checkbox for terms and conditions
            
            const SizedBox(height: 10),

            // Sign Up Button
            Center(
              child: ElevatedButton(
                onPressed: () {
                  if (_selectedType.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Select The Parking Type :"),
                        backgroundColor: Colors.red,
                      ),
                    );
                  } else {
                    // Proceed with sign-up
                  }
                },
                child: const Text(
                  "Create Your Park",
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
                    Size(170, 50),
                  ),
                  shape: MaterialStateProperty.all(
                    ContinuousRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                ),
              ),
            ),

            // Login Navigation
           
          ],
        ),
      ),
    );
  }
}

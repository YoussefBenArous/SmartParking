import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:smart_parking/PayScreen/PaymentSuccessScreen.dart';
import 'package:smart_parking/PayScreen/entrycreditCard.dart';
import 'package:smart_parking/widget/CustomTiltle.dart';
import 'package:smart_parking/widget/button.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PayScreen extends StatefulWidget {
  final String parkingId;
  final String spotId;
  final double totalCost;

  const PayScreen({
    Key? key,
    required this.parkingId,
    required this.spotId,
    required this.totalCost,
  }) : super(key: key);

  @override
  State<PayScreen> createState() => _PayScreenState();
}

class _PayScreenState extends State<PayScreen> {
  String? _selectedPaymentMethod;

  @override
  void initState() {
    super.initState();
    _savePaymentState();
  }

  Future<void> _savePaymentState() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance.collection('payments').doc(user.uid).set({
        'parkingId': widget.parkingId,
        'spotId': widget.spotId,
        'amount': widget.totalCost,
        'status': 'initiated',
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error saving payment state: $e');
    }
  }

  void _handlePayment() {
    if (_selectedPaymentMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a payment method')),
      );
      return;
    }

    // Check if credit card payment
    if (_selectedPaymentMethod == 'visa') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PaymentScreen(
            parkingId: widget.parkingId,
            spotId: widget.spotId,
            totalCost: widget.totalCost,
          ),
        ),
      );
    } else {
      // Handle D17 or other payment methods
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PaymentSuccessScreen(
            parkingId: widget.parkingId,
            spotId: widget.spotId,
            totalCost: widget.totalCost,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: const Color(0XFF0079C0),
        extendBody: true,
        appBar: AppBar(
          title: CustomTitle(
            text: "Payment",
            color: Colors.white,
            size: 32,
          ),
          centerTitle: true,
          toolbarHeight: 100,
          backgroundColor: const Color(0xff0079C0),
          automaticallyImplyLeading: false,
        ),
        body: Stack(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 60),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(50),
                  topRight: Radius.circular(50),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 80, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 30, bottom: 20),
                      child: Text(
                        "Choose Payment Method",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey[800],
                        ),
                      ),
                    ),
                    _buildPaymentMethod(
                      "D17",
                      "d17",
                      "assets/images/d17.png",
                    ),
                    const SizedBox(height: 15),
                    _buildPaymentMethod(
                      "Visa Card",
                      "visa",
                      "assets/images/visa.png",
                    ),
                    const Spacer(),
                    button(
                      onPressed: _handlePayment,
                      text: 'Confirm Payment',
                      fontsize: 18,
                      width: double.infinity,
                      height: 55,
                      radius: 15,
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            Positioned(
              top: -20,
              left: 20,
              right: 20,
              child: Card(
                elevation: 8,
                shadowColor: Colors.black26,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Container(
                  height: 180,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFE3F2FD),
                        Color(0xFFBBDEFB),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Current Balance',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.blueGrey[800],
                              ),
                            ),
                            Image.asset(
                              'assets/images/cardbancaire.png',
                              height: 40,
                            ),
                          ],
                        ),
                        const Spacer(),
                        const Text(
                          'DT XX.XX',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1565C0),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Available Balance',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.blueGrey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethod(String title, String value, String imagePath) {
    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(
          color: _selectedPaymentMethod == value
              ? const Color(0xFF0079C0)
              : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: () => setState(() {
          _selectedPaymentMethod = value;
          // Add haptic feedback when selecting payment method
          HapticFeedback.lightImpact();
        }),
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Image.asset(
                imagePath,
                height: 35,
              ),
              const SizedBox(width: 15),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Radio(
                value: value,
                groupValue: _selectedPaymentMethod,
                onChanged: (value) => setState(() => _selectedPaymentMethod = value!),
                activeColor: const Color(0xFF0079C0),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

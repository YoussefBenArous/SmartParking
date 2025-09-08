// pubspec.yaml dependencies required:
// flutter_stripe: ^9.4.0
// cloud_functions: ^4.6.5
// cloud_firestore: ^4.9.1
// firebase_core: ^2.30.0
// firebase_auth: ^4.17.4

import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:smart_parking/PayScreen/PaymentSuccessScreen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class PaymentScreen extends StatefulWidget {
  final String parkingId;
  final String spotId;
  final double totalCost;

  const PaymentScreen({
    super.key,
    required this.parkingId,
    required this.spotId,
    required this.totalCost,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _loading = false;
  CardFieldInputDetails? _card;
  final _nameController = TextEditingController();

  Future<void> _makePayment() async {
    if (kIsWeb) {
      // Handle web payments differently
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Credit card payments are not supported on web. Please use our mobile app.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_card == null || !_card!.complete || _nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter full card details.')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final HttpsCallable callable =
          FirebaseFunctions.instance.httpsCallable('createPaymentIntent');
      final response = await callable.call({
        'amount': (widget.totalCost * 100).round(),
        'currency': 'usd',
      });

      final clientSecret = response.data['clientSecret'];

      await Stripe.instance.confirmPayment(
        paymentIntentClientSecret: clientSecret,
        data: PaymentMethodParams.card(
          paymentMethodData: PaymentMethodData(
            billingDetails:
                BillingDetails(name: _nameController.text.trim()),
          ),
        ),
      );

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('payments').add({
          'userId': user.uid,
          'parkingId': widget.parkingId,
          'spotId': widget.spotId,
          'amount': widget.totalCost,
          'timestamp': FieldValue.serverTimestamp(),
          'method': 'credit_card',
          'status': 'completed',
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment successful!')),
        );
        Navigator.pushReplacement(
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment failed: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stripe Payment')),
      body: kIsWeb 
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.warning, size: 64, color: Colors.orange),
                  const SizedBox(height: 16),
                  const Text(
                    'Credit card payments are only available in our mobile app',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Cardholder Name'),
                  ),
                  const SizedBox(height: 20),
                  CardField(
                    onCardChanged: (card) {
                      setState(() {
                        _card = card;
                      });
                    },
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: _loading ? null : _makePayment,
                    child: _loading
                        ? const CircularProgressIndicator()
                        : Text('Pay ${widget.totalCost.toStringAsFixed(2)} TND'),
                  )
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:smart_parking/Setting/Setting.dart';
import 'package:smart_parking/widget/CustomTiltle.dart';
import 'package:smart_parking/widget/button.dart';

class PayScreen extends StatefulWidget {
  const PayScreen({super.key});

  @override
  State<PayScreen> createState() => _PayScreenState();
}

class _PayScreenState extends State<PayScreen> {
  String _selectedPaymentMethod = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
        backgroundColor: Color(0xff0079C0),
        leading: IconButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SettingPage(),
              ),
            );
          },
          icon: Icon(
            Icons.arrow_back,
            color: Colors.black,
          ),
        ),
      ),
      body: Stack(
        children: [
          Container(
            margin: EdgeInsets.only(top: 60),
            decoration: BoxDecoration(
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
                  SizedBox(height: 15),
                  _buildPaymentMethod(
                    "Visa Card",
                    "visa",
                    "assets/images/visa.png",
                  ),
                  Spacer(),
                  button(
                    onPressed: () {},
                    text: 'Confirm Payment',
                    fontsize: 18,
                    width: double.infinity,
                    height: 55,
                    radius: 15,
                  ),
                  SizedBox(height: 20),
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
                  gradient: LinearGradient(
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
                      Spacer(),
                      Text(
                        'DT XX.XX',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1565C0),
                        ),
                      ),
                      SizedBox(height: 5),
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
              ? Color(0xFF0079C0) 
              : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: () => setState(() => _selectedPaymentMethod = value),
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Image.asset(
                imagePath,
                height: 35,
              ),
              SizedBox(width: 15),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Spacer(),
              Radio(
                value: value,
                groupValue: _selectedPaymentMethod,
                onChanged: (value) => setState(() => _selectedPaymentMethod = value!),
                activeColor: Color(0xFF0079C0),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

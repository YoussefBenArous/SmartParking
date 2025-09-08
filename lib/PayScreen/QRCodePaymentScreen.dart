import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:smart_parking/widget/CustomTiltle.dart';
import 'package:smart_parking/services/payment_service.dart';
import 'package:smart_parking/HomePage/userpages/UserHome.dart';

class QRCodePaymentScreen extends StatefulWidget {
  final String bookingId;

  const QRCodePaymentScreen({
    Key? key,
    required this.bookingId,
  }) : super(key: key);

  @override
  State<QRCodePaymentScreen> createState() => _QRCodePaymentScreenState();
}

class _QRCodePaymentScreenState extends State<QRCodePaymentScreen> {
  final PaymentService _paymentService = PaymentService();
  Map<String, dynamic>? bookingDetails;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBookingDetails();
  }

  Future<void> _loadBookingDetails() async {
    try {
      final details = await _paymentService.getBookingDetails(widget.bookingId);
      setState(() {
        bookingDetails = details;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading details: ${e.toString()}')),
      );
    }
  }

  String _generateQRData() {
    if (bookingDetails == null) return '';
    return '''
      BookingID: ${widget.bookingId}
      Parking: ${bookingDetails!['parkingName']}
      Spot: ${bookingDetails!['spotNumber']}
      Duration: ${bookingDetails!['duration']} hours
      Amount: TND ${bookingDetails!['amount']}
    ''';
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => HomePage()),
        );
        return false;
      },
      child: Scaffold(
        backgroundColor: const Color(0XFF0079C0),
        appBar: AppBar(
          title: CustomTitle(
            text: "Payment QR Code",
            color: Colors.white,
            size: 32,
          ),
          centerTitle: true,
          toolbarHeight: 100,
          backgroundColor: Color(0xff0079C0),
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: Icon(Icons.home),
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => HomePage()),
            ),
          ),
        ),
        body: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(50),
              topRight: Radius.circular(50),
            ),
          ),
          child: isLoading
              ? Center(child: CircularProgressIndicator())
              : Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Card(
                        elevation: 5,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            children: [
                              QrImageView(
                                data: _generateQRData(),
                                version: QrVersions.auto,
                                size: 200,
                                backgroundColor: Colors.white,
                              ),
                              SizedBox(height: 20),
                              Text(
                                'Scan this QR code at the parking entrance',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 30),
                      if (bookingDetails != null) ...[
                        _buildDetailItem('Parking', bookingDetails!['parkingName']),
                        _buildDetailItem('Spot', bookingDetails!['spotNumber']),
                        _buildDetailItem('Duration', '${bookingDetails!['duration']} hours'),
                        _buildDetailItem('Amount', 'TND ${bookingDetails!['amount']}'),
                      ],
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

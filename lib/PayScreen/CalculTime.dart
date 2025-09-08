import 'package:flutter/material.dart';
import 'package:smart_parking/PayScreen/QRCodePaymentScreen.dart';
import 'package:smart_parking/QRcode/QRCodeScreen.dart';
import 'package:smart_parking/services/payment_service.dart';
import 'package:smart_parking/widget/CustomTiltle.dart';
import 'package:smart_parking/widget/button.dart';

class CalculateTime extends StatefulWidget {
  final String bookingId;
  final String paymentMethod;

  const CalculateTime({
    Key? key,
    required this.bookingId,
    required this.paymentMethod,
  }) : super(key: key);

  @override
  State<CalculateTime> createState() => _CalculateTimeState();
}

class _CalculateTimeState extends State<CalculateTime> {
  final PaymentService _paymentService = PaymentService();
  bool _isLoading = true;
  Map<String, dynamic>? _bookingDetails;
  int _hours = 1;
  double _amount = 0;
  double _ratePerHour = 2.0; // Default rate per hour
  String _errorMessage = '';
  bool _mounted = true;

  @override
  void initState() {
    super.initState();
    _loadBookingDetails();
  }

  @override
  void dispose() {
    _mounted = false;
    super.dispose();
  }

  Future<void> _loadBookingDetails() async {
    if (!_mounted) return;
    try {
      setState(() => _isLoading = true);

      final details = await _paymentService.getBookingDetails(widget.bookingId);
      if (details == null) {
        throw Exception('Booking details not found');
      }

      final occupancyTime = await _paymentService.getSpotOccupancyTime(
        details['parkingId'],
        details['spotNumber'],
      );

      if (!_mounted) return;

      if (details != null && occupancyTime != null) {
        setState(() {
          _bookingDetails = details;
          _ratePerHour = double.parse(details['price'] ?? '2.0');
          _hours = occupancyTime['duration'];
          if (_hours < 1) _hours = 1;
          _calculateAmount();
        });
      }
    } catch (e) {
      if (_mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _calculateAmount() {
    if (_hours < 1) _hours = 1;
    if (_hours > 24) _hours = 24; // Maximum 24 hours

    setState(() {
      _amount = _hours * _ratePerHour;
      _errorMessage = '';
    });
  }

  Future<void> _confirmPayment() async {
    if (!_mounted) return;

    try {
      setState(() => _isLoading = true);

      if (_bookingDetails == null) throw Exception('Booking details not found');

      // Double check user presence and minimum time
      final isPresent = await _paymentService.verifyUserPresence(
        _bookingDetails!['parkingId'],
        _bookingDetails!['spotNumber'],
      );

      if (!_mounted) return;

      if (!isPresent) {
        throw Exception('Vehicle not detected or has not been parked for minimum required time (5 minutes).');
      }

      // Get actual occupancy time again before payment
      final occupancyDetails = await _paymentService.getSpotOccupancyTime(
        _bookingDetails!['parkingId'],
        _bookingDetails!['spotNumber'],
      );

      if (occupancyDetails == null) {
        throw Exception('Could not verify parking duration.');
      }

      // Ensure payment covers actual time spent
      final actualHours = occupancyDetails['duration'];
      if (_hours < actualHours) {
        setState(() {
          _hours = actualHours;
          _calculateAmount();
          _errorMessage = 'Payment amount adjusted to cover actual parking time.';
        });
        return;
      }

      // Continue with payment
      // Save payment and generate QR in one transaction
      await _paymentService.savePaymentAndGenerateQR(
        bookingId: widget.bookingId,
        amount: _amount,
        paymentMethod: widget.paymentMethod,
        duration: _hours,
      );

      if (!_mounted) return;

      // Get the latest booking details after payment
      final updatedBookingDetails = await _paymentService.getBookingDetails(widget.bookingId);
      if (updatedBookingDetails == null) throw Exception('Could not retrieve updated booking details');

      // Navigate to QR screen with proper data
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => QRCodePaymentScreen(
            bookingId: widget.bookingId,
          ),
        ),
      );
    } catch (e) {
      if (_mounted) {
        setState(() => _errorMessage = e.toString());
      }
    } finally {
      if (_mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0XFF0079C0),
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
          onPressed: () => Navigator.pop(context),
          icon: Icon(
            Icons.arrow_back,
            color: Colors.black,
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
        child: _isLoading
            ? Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    if (_errorMessage.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          _errorMessage,
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    if (_bookingDetails != null) ...[
                      Text(
                        'Parking: ${_bookingDetails!['parkingName']}',
                        style: TextStyle(fontSize: 18),
                      ),
                      Text(
                        'Spot: ${_bookingDetails!['spotNumber']}',
                        style: TextStyle(fontSize: 16),
                      ),
                      SizedBox(height: 20),
                    ],
                    Text(
                      'Select Duration',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: Icon(Icons.remove),
                          onPressed: () {
                            if (_hours > 1) {
                              setState(() {
                                _hours--;
                                _calculateAmount();
                              });
                            }
                          },
                        ),
                        Text(
                          '$_hours hours',
                          style: TextStyle(fontSize: 20),
                        ),
                        IconButton(
                          icon: Icon(Icons.add),
                          onPressed: () {
                            setState(() {
                              _hours++;
                              _calculateAmount();
                            });
                          },
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Rate: TND ${_ratePerHour.toStringAsFixed(2)}/hour',
                      style: TextStyle(fontSize: 16),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Total Amount: TND ${_amount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1565C0),
                      ),
                    ),
                    Spacer(),
                    button(
                      onPressed: _isLoading ? null : _confirmPayment,
                      text: 'Confirm Payment',
                      fontsize: 18,
                      width: double.infinity,
                      height: 55,
                      radius: 15,
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

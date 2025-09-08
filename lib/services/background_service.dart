import 'dart:async';
import 'package:smart_parking/services/payment_service.dart';

class BackgroundService {
  final PaymentService _paymentService = PaymentService();
  Timer? _timer;

  void startPeriodicCheck() {
    // Check every minute (adjust interval as needed)
    _timer = Timer.periodic(Duration(minutes: 1), (timer) async {
      await _paymentService.checkAndCleanupExpiredBookings();
    });
  }

  void stopPeriodicCheck() {
    _timer?.cancel();
    _timer = null;
  }
}

class ParkingBooking {
  final String userId;
  final int spotNumber;
  final String qrCode;
  final DateTime bookingTime;
  final bool isUsed;

  ParkingBooking({
    required this.userId,
    required this.spotNumber,
    required this.qrCode,
    required this.bookingTime,
    this.isUsed = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'spotNumber': spotNumber,
      'qrCode': qrCode,
      'bookingTime': bookingTime.toIso8601String(),
      'isUsed': isUsed,
    };
  }
}

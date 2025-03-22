import 'package:cloud_firestore/cloud_firestore.dart';

class Booking {
  final String id;
  final String userId;
  final String parkingId;
  final int spotNumber;
  final String status;
  final DateTime createdAt;
  final String qrCode;

  Booking({
    required this.id,
    required this.userId,
    required this.parkingId,
    required this.spotNumber,
    required this.status,
    required this.createdAt,
    required this.qrCode,
  });

  factory Booking.fromFirestore(Map<String, dynamic> data, String id) {
    return Booking(
      id: id,
      userId: data['userId'],
      parkingId: data['parkingId'],
      spotNumber: data['spotNumber'],
      status: data['status'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      qrCode: data['qrCode'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'parkingId': parkingId,
      'spotNumber': spotNumber,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'qrCode': qrCode,
    };
  }
}

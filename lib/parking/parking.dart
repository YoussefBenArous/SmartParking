// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:qr_flutter/qr_flutter.dart';
// import 'package:smart_parking/HomePage/UserHome.dart';
// import 'package:smart_parking/QRcode/QRCodeScreen.dart';
// import 'package:smart_parking/models/firebase_service.dart';

// void main() {
//   runApp(const ParkingLotApp());
// }

// class ParkingLotApp extends StatelessWidget {
//   const ParkingLotApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Parking Lot',
//       debugShowCheckedModeBanner: false,
//       theme: ThemeData(
//         primarySwatch: Colors.blue,
//       ),
//       home: const ParkingScreen(),
//     );
//   }
// }

// class ParkingScreen extends StatefulWidget {
//   const ParkingScreen({super.key});

//   @override
//   State<ParkingScreen> createState() => _ParkingScreenState();
// }

// class _ParkingScreenState extends State<ParkingScreen> {
//   int? selectedSpot;
//   bool _isLoading = false;

//   Future<void> _handleSpotSelection(int spotNumber) async {
//     if (_isLoading) return;

//     setState(() => _isLoading = true);
//     try {
//       // Check if spot is available
//       final isAvailable = await FirebaseService.isSpotAvailable(spotNumber);
//       if (!isAvailable) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text('This spot is already occupied')),
//         );
//         return;
//       }

//       // Show confirmation dialog
//       final bool? confirm = await showDialog<bool>(
//         context: context,
//         builder: (context) => AlertDialog(
//           title: Text('Confirm Spot $spotNumber'),
//           content: const Column(
//             mainAxisSize: MainAxisSize.min,
//             children: [
//               Text('Would you like to book this spot?'),
//               SizedBox(height: 10),
//               Text('Price: 2 TND/hour'),
//             ],
//           ),
//           actions: [
//             TextButton(
//               onPressed: () => Navigator.pop(context, false),
//               child: const Text('Cancel'),
//             ),
//             ElevatedButton(
//               onPressed: () => Navigator.pop(context, true),
//               child: const Text('Book Now'),
//             ),
//           ],
//         ),
//       );

//       if (confirm == true) {
//         final bookingId = await FirebaseService.createBooking(spotNumber);
        
//         if (!mounted) return;
//         Navigator.pushReplacement(
//           context,
//           MaterialPageRoute(
//             builder: (context) => QRCodeScreen(
//               spotNumber: spotNumber,
//               parkingId: 'parking_1',
//               bookingId: bookingId,
//             ),
//           ),
//         );
//       }
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text(e.toString())),
//       );
//     } finally {
//       if (mounted) {
//         setState(() => _isLoading = false);
//       }
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Select Parking Spot'),
//         centerTitle: true,
//       ),
//       body: StreamBuilder<QuerySnapshot>(
//         stream: FirebaseService.getSpotStatuses(),
//         builder: (context, snapshot) {
//           if (snapshot.hasError) {
//             return Center(child: Text('Error: ${snapshot.error}'));
//           }

//           if (snapshot.connectionState == ConnectionState.waiting) {
//             return const Center(child: CircularProgressIndicator());
//           }

//           return GridView.builder(
//             padding: const EdgeInsets.all(16),
//             gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//               crossAxisCount: 2,
//               childAspectRatio: 1,
//               crossAxisSpacing: 16,
//               mainAxisSpacing: 16,
//             ),
//             itemCount: 6,
//             itemBuilder: (context, index) {
//               final spotNumber = index + 1;
//               final spotDoc = snapshot.data?.docs
//                   .firstWhere(
//                     (doc) => doc.id == spotNumber.toString(),
//                     orElse: () => ,
//                   );
//               final isOccupied = spotDoc?.get('isOccupied') ?? false;

//               return ParkingSpot(
//                 number: spotNumber,
//                 isOccupied: isOccupied,
//                 isSelected: selectedSpot == spotNumber,
//                 onTap: isOccupied ? null : () => _handleSpotSelection(spotNumber),
//               );
//             },
//           );
//         },
//       ),
//     );
//   }
// }

// class ParkingSpot extends StatelessWidget {
//   final int number;
//   final bool isOccupied;
//   final bool isSelected;
//   final VoidCallback onTap;

//   const ParkingSpot({
//     super.key,
//     required this.number,
//     required this.onTap,
//     this.isOccupied = false,
//     this.isSelected = false,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return GestureDetector(
//       onTap: isOccupied ? null : onTap,
//       child: Container(
//         width: 100,
//         height: 150,
//         decoration: BoxDecoration(
//           color: isOccupied 
//               ? Colors.red[200] 
//               : isSelected 
//                   ? Colors.green[200] 
//                   : Colors.grey[200],
//           border: Border.all(
//             color: isSelected ? Colors.green : Colors.black,
//             width: isSelected ? 3 : 2,
//           ),
//           borderRadius: BorderRadius.circular(10),
//         ),
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           children: [
//             Text(
//               number.toString(),
//               style: TextStyle(
//                 fontSize: 24,
//                 fontWeight: FontWeight.bold,
//                 color: isSelected ? Colors.green[700] : Colors.black,
//               ),
//             ),
//             Text(
//               isOccupied ? 'Occupied' : 'Available',
//               style: TextStyle(
//                 fontSize: 14,
//                 color: isOccupied ? Colors.red : Colors.green,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
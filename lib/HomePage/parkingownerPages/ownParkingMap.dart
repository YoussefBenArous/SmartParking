// import 'package:flutter/material.dart';
// import 'package:flutter_map/flutter_map.dart';
// import 'package:latlong2/latlong.dart';
// import 'package:flutter/services.dart';

// class OwnParkingMap extends StatefulWidget {
//   final double latitude;
//   final double longitude;
//   final String parkingName;
//   final Function(bool) onVerificationComplete;

//   const OwnParkingMap({
//     Key? key, 
//     required this.latitude, 
//     required this.longitude,
//     required this.parkingName,
//     required this.onVerificationComplete,
//   }) : super(key: key);

//   @override
//   State<OwnParkingMap> createState() => _OwnParkingMapState();
// }

// class _OwnParkingMapState extends State<OwnParkingMap> {
//   late final MapController _mapController;
//   bool _isVerifying = false;
//   String? _errorMessage;
//   double _currentZoom = 15.0;
//   bool _isLocationCorrect = false;

//   @override
//   void initState() {
//     super.initState();
//     _mapController = MapController();
//   }

//   Future<void> _verifyLocation() async {
//     setState(() => _isVerifying = true);
    
//     try {
//       // Add your verification logic here
//       await Future.delayed(Duration(seconds: 2)); // Simulated verification
//       setState(() {
//         _isLocationCorrect = true;
//         _errorMessage = null;
//       });
//       widget.onVerificationComplete(true);
      
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text('Location verified successfully!'),
//           backgroundColor: Colors.green,
//         ),
//       );
//     } catch (e) {
//       setState(() {
//         _errorMessage = 'Verification failed: ${e.toString()}';
//         _isLocationCorrect = false;
//       });
//       widget.onVerificationComplete(false);
//     } finally {
//       setState(() => _isVerifying = false);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text("Verify: ${widget.parkingName}"),
//         actions: [
//           IconButton(
//             icon: Icon(Icons.help_outline),
//             onPressed: () => _showHelpDialog(context),
//           ),
//         ],
//       ),
//       body: Stack(
//         children: [
//           FlutterMap(
//             mapController: _mapController,
//             options: MapOptions(
//               initialCenter: LatLng(widget.latitude, widget.longitude),
//               initialZoom: _currentZoom,
//               onMapReady: () {
//                 _mapController.move(
//                   LatLng(widget.latitude, widget.longitude),
//                   _currentZoom,
//                 );
//               },
//             ),
//             children: [
//               TileLayer(
//                 urlTemplate: "https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png",
//                 subdomains: const ['a', 'b', 'c'],
//               ),
//               MarkerLayer(
//                 markers: [
//                   Marker(
//                     width: 80.0,
//                     height: 80.0,
//                     point: LatLng(widget.latitude, widget.longitude),
//                     child: Column(
//                       children: [
//                         Icon(
//                           Icons.location_on,
//                           color: _isLocationCorrect ? Colors.green : Colors.red,
//                           size: 40,
//                         ),
//                         Container(
//                           padding: EdgeInsets.all(4),
//                           decoration: BoxDecoration(
//                             color: Colors.white,
//                             borderRadius: BorderRadius.circular(4),
//                             border: Border.all(color: Colors.blue),
//                           ),
//                           child: Text(
//                             "P",
//                             style: TextStyle(
//                               fontSize: 16,
//                               fontWeight: FontWeight.bold,
//                               color: Colors.blue,
//                             ),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                 ],
//               ),
//             ],
//           ),
//           Positioned(
//             top: 16,
//             right: 16,
//             child: Column(
//               children: [
//                 FloatingActionButton(
//                   heroTag: "zoomIn",
//                   onPressed: () {
//                     setState(() {
//                       _currentZoom = (_currentZoom + 1).clamp(4.0, 18.0);
//                       _mapController.move(
//                         LatLng(widget.latitude, widget.longitude),
//                         _currentZoom,
//                       );
//                     });
//                   },
//                   child: Icon(Icons.add),
//                 ),
//                 SizedBox(height: 8),
//                 FloatingActionButton(
//                   heroTag: "zoomOut",
//                   onPressed: () {
//                     setState(() {
//                       _currentZoom = (_currentZoom - 1).clamp(4.0, 18.0);
//                       _mapController.move(
//                         LatLng(widget.latitude, widget.longitude),
//                         _currentZoom,
//                       );
//                     });
//                   },
//                   child: Icon(Icons.remove),
//                 ),
//               ],
//             ),
//           ),
//           if (_errorMessage != null)
//             Positioned(
//               bottom: 76,
//               left: 16,
//               right: 16,
//               child: Container(
//                 padding: EdgeInsets.all(8),
//                 decoration: BoxDecoration(
//                   color: Colors.red.withOpacity(0.9),
//                   borderRadius: BorderRadius.circular(8),
//                 ),
//                 child: Text(
//                   _errorMessage!,
//                   style: TextStyle(color: Colors.white),
//                 ),
//               ),
//             ),
//         ],
//       ),
//       bottomNavigationBar: Container(
//         padding: EdgeInsets.all(16),
//         child: ElevatedButton(
//           onPressed: _isVerifying ? null : _verifyLocation,
//           style: ElevatedButton.styleFrom(
//             padding: EdgeInsets.symmetric(vertical: 16),
//             backgroundColor: Colors.blue,
//           ),
//           child: _isVerifying
//               ? CircularProgressIndicator(color: Colors.white)
//               : Text(
//                   _isLocationCorrect ? 'Location Verified' : 'Verify Location',
//                   style: TextStyle(fontSize: 16),
//                 ),
//         ),
//       ),
//     );
//   }

//   void _showHelpDialog(BuildContext context) {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: Text('Location Verification Help'),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text('• Verify if your parking location is correctly marked'),
//             Text('• Use zoom controls to check the precise location'),
//             Text('• The marker should be exactly at your parking entrance'),
//             Text('• Click "Verify Location" when you\'re sure it\'s correct'),
//           ],
//         ),
//         actions: [
//           TextButton(
//             onPressed: () => Navigator.pop(context),
//             child: Text('Got it'),
//           ),
//         ],
//       ),
//     );
//   }

//   @override
//   void dispose() {
//     _mapController.dispose();
//     super.dispose();
//   }
// }

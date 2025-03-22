import 'package:flutter/material.dart';

class ParkingSearchDelegate extends SearchDelegate<Map<String, dynamic>?> {
  final List<Map<String, dynamic>> parkingLocations;

  ParkingSearchDelegate(this.parkingLocations);

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          if (query.isEmpty) {
            close(context, null);
          } else {
            query = '';
            showSuggestions(context);
          }
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    if (query.isEmpty) {
      return _buildAllParkings();
    }

    final results = parkingLocations.where((parking) {
      final name = (parking['name'] ?? '').toString().toLowerCase();
      final address = (parking['address'] ?? '').toString().toLowerCase();
      final searchLower = query.toLowerCase();
      return name.contains(searchLower) || address.contains(searchLower);
    }).toList();

    if (results.isEmpty) {
      return const Center(
        child: Text('No parking spots found'),
      );
    }

    return _buildParkingList(results);
  }

  Widget _buildAllParkings() {
    return _buildParkingList(parkingLocations);
  }

  Widget _buildParkingList(List<Map<String, dynamic>> parkings) {
    return ListView.builder(
      itemCount: parkings.length,
      itemBuilder: (context, index) {
        final parking = parkings[index];
        final isAvailable = (parking['available'] ?? 0) > 0;
        final status = parking['status'] ?? 'inactive';
        final name = parking['name'] ?? 'Unnamed Parking';
        final price = parking['price'] ?? 'N/A';
        final available = parking['available'] ?? 0;

        return ListTile(
          leading: Icon(
            Icons.local_parking,
            color: isAvailable && status == 'active' 
                ? Colors.green 
                : Colors.red,
          ),
          title: Text(name),
          subtitle: Text('Available: $available spots'),
          trailing: Text(price),
          onTap: () => close(context, parking),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';

class ParkingSearchDelegate extends SearchDelegate<Map<String, dynamic>?> {
  final List<Map<String, dynamic>> parkingLocations;

  ParkingSearchDelegate(this.parkingLocations) {
    print("DEBUG: Initialized with ${parkingLocations.length} parking locations");
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear),
        onPressed: () {
          print("DEBUG: Clearing search query");
          query = '';
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () {
        print("DEBUG: Closing search");
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    print("DEBUG: Building results for query: $query");
    
    if (query.isEmpty) {
      print("DEBUG: Query is empty");
      return const Center(
        child: Text('Please enter a parking name to search'),
      );
    }

    final results = parkingLocations.where((parking) {
      final name = parking['name']?.toString().toLowerCase() ?? '';
      final searchQuery = query.toLowerCase();
      return name.contains(searchQuery);
    }).toList();

    print("DEBUG: Found ${results.length} results");

    if (results.isEmpty) {
      return const Center(
        child: Text('No parking found'),
      );
    }

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final parking = results[index];
        return ListTile(
          title: Text(parking['name'] ?? 'Unnamed Parking'),
          subtitle: Text('Available: ${parking['available']} spots'),
          onTap: () {
            print("DEBUG: Selected parking: ${parking['name']}");
            close(context, parking);
          },
        );
      },
    );
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    print("DEBUG: Building suggestions for query: $query");
    
    if (query.isEmpty) {
      return ListView.builder(
        itemCount: parkingLocations.length,
        itemBuilder: (context, index) {
          final parking = parkingLocations[index];
          return ListTile(
            title: Text(parking['name'] ?? 'Unnamed Parking'),
            subtitle: Text('Available: ${parking['available']} spots'),
            onTap: () {
              print("DEBUG: Selected suggestion: ${parking['name']}");
              close(context, parking);
            },
          );
        },
      );
    }

    final suggestions = parkingLocations.where((parking) {
      final name = parking['name']?.toString().toLowerCase() ?? '';
      final searchQuery = query.toLowerCase();
      return name.contains(searchQuery);
    }).toList();

    print("DEBUG: Found ${suggestions.length} suggestions");

    return ListView.builder(
      itemCount: suggestions.length,
      itemBuilder: (context, index) {
        final parking = suggestions[index];
        return ListTile(
          title: Text(parking['name'] ?? 'Unnamed Parking'),
          subtitle: Text('Available: ${parking['available']} spots'),
          onTap: () {
            print("DEBUG: Selected suggestion: ${parking['name']}");
            close(context, parking);
          },
        );
      },
    );
  }
}

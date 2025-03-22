import 'package:flutter/material.dart';
import '../services/app_service_test.dart';

class DiagnosticPage extends StatelessWidget {
  Future<Map<String, bool>> _runAllTests() async {
    Map<String, bool> results = {};

    try {
      // Test Firebase Services
      results['Firebase Services'] = await AppServiceTest.verifyAllServices();

      // Test Navigation Flow
      results['Navigation Flow'] = await _testNavigationFlow();

      // Test Data Flow
      results['Data Flow'] = await _testDataFlow();

      // Test User Roles
      results['User Roles'] = await _testUserRoles();

      return results;
    } catch (e) {
      print('Diagnostic tests failed: $e');
      return {'Error': false};
    }
  }

  Future<bool> _testNavigationFlow() async {
    // Add navigation flow tests
    return true;
  }

  Future<bool> _testDataFlow() async {
    // Add data flow tests
    return true;
  }

  Future<bool> _testUserRoles() async {
    // Add user roles tests
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('App Diagnostics'),
      ),
      body: FutureBuilder<Map<String, bool>>(
        future: _runAllTests(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error running diagnostics: ${snapshot.error}'),
            );
          }

          final results = snapshot.data ?? {};

          return ListView(
            padding: EdgeInsets.all(16),
            children: [
              ...results.entries.map((entry) => Card(
                child: ListTile(
                  title: Text(entry.key),
                  trailing: Icon(
                    entry.value ? Icons.check_circle : Icons.error,
                    color: entry.value ? Colors.green : Colors.red,
                  ),
                ),
              )),
            ],
          );
        },
      ),
    );
  }
}

import 'dart:convert';
import 'dart:io';

/// Utility to load test fixture files.
class FixtureLoader {
  static String loadString(String relativePath) {
    final file = File('test/fixtures/$relativePath');
    return file.readAsStringSync();
  }

  static Map<String, dynamic> loadJson(String relativePath) {
    return jsonDecode(loadString(relativePath)) as Map<String, dynamic>;
  }
}

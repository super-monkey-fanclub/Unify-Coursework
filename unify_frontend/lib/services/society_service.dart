import 'dart:convert';

import 'package:http/http.dart' as http;

/// Handles joining societies and managing memberships.
class SocietyService {
  static const String _baseUrl = 'http://127.0.0.1:8000/api/societies';

  /// Join a society for the given user email.
  /// Returns a map with 'success' and 'message'.
  Future<Map<String, dynamic>> joinSociety({
    required String email,
    required String societyName,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/join/'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email,
              'society_name': societyName,
            }),
          )
          .timeout(const Duration(seconds: 10));

      final Map<String, dynamic> body =
          jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'message': body['message'] ?? 'Joined society',
        };
      }

      return {
        'success': false,
        'message': body['error'] ?? 'Could not join society.',
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'Could not connect to the server.',
      };
    }
  }

  /// Fetch the list of societies the given user has joined.
  /// Returns a map with 'success', and on success 'societies' as List<String>.
  Future<Map<String, dynamic>> getMySocieties({
    required String email,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/my/'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email}),
          )
          .timeout(const Duration(seconds: 10));

      final Map<String, dynamic> body =
          jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        final List<dynamic> raw = (body['societies'] as List<dynamic>? ?? []);
        final List<String> names = raw
            .map((e) => (e as Map<String, dynamic>)['name'] as String)
            .toList();
        return {
          'success': true,
          'societies': names,
        };
      }

      return {
        'success': false,
        'message': body['error'] ?? 'Could not load societies.',
      };
    } catch (_) {
      return {
        'success': false,
        'message': 'Could not connect to the server.',
      };
    }
  }
}

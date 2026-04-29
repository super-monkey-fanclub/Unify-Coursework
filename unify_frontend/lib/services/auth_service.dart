import 'dart:convert';

import 'package:http/http.dart' as http;

/// Handles all communication with the Django authentication endpoints.
class AuthService {
  // Change this to your machine's local IP if testing on a physical device.
  static const String _baseUrl = 'http://127.0.0.1:8000/api/auth';

  /// Registers a new user.
  /// Returns a map with 'success' (bool), and either 'user' or 'message'.
  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    String? bootstrapKey,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/register/'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'name': name,
              'email': email,
              'password': password,
              if (bootstrapKey != null && bootstrapKey.isNotEmpty)
                'bootstrap_key': bootstrapKey,
            }),
          )
          .timeout(const Duration(seconds: 10));

      final Map<String, dynamic> body =
          jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 201) {
        return {'success': true, 'user': body['user']};
      }
      return {
        'success': false,
        'message': body['error'] ?? 'Registration failed.',
      };
    } catch (_) {
      return {'success': false, 'message': 'Could not connect to the server.'};
    }
  }

  /// Logs in an existing user.
  /// Returns a map with 'success' (bool), and either 'user' map or 'message'.
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/login/'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 10));

      final Map<String, dynamic> body =
          jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        return {'success': true, 'user': body['user']};
      }
      return {
        'success': false,
        'message': body['error'] ?? 'Login failed.',
      };
    } catch (_) {
      return {'success': false, 'message': 'Could not connect to the server.'};
    }
  }

  /// Ensure a dev account exists using the configured bootstrap key.
  Future<Map<String, dynamic>> ensureDevAccount({
    required String bootstrapKey,
    String? email,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/dev/ensure/'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'bootstrap_key': bootstrapKey,
              if (email != null && email.isNotEmpty) 'email': email,
            }),
          )
          .timeout(const Duration(seconds: 10));

      final Map<String, dynamic> body =
          jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'message': body['message'] ?? 'Developer account ready.',
          'user': body['user'],
          'default_password': body['default_password'],
        };
      }

      return {
        'success': false,
        'message': body['error'] ?? 'Could not bootstrap developer account.',
      };
    } catch (_) {
      return {'success': false, 'message': 'Could not connect to the server.'};
    }
  }

  /// Update a user's account role (dev only).
  Future<Map<String, dynamic>> updateUserRole({
    required String devEmail,
    required String targetEmail,
    required String targetAccountType,
    String? societyName,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/roles/update/'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'dev_email': devEmail,
              'target_email': targetEmail,
              'target_account_type': targetAccountType,
              if (societyName != null && societyName.isNotEmpty)
                'society_name': societyName,
            }),
          )
          .timeout(const Duration(seconds: 10));

      final Map<String, dynamic> body =
          jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'message': body['message'] ?? 'Role updated.',
          'user': body['user'],
        };
      }

      return {
        'success': false,
        'message': body['error'] ?? 'Could not update role.',
      };
    } catch (_) {
      return {'success': false, 'message': 'Could not connect to the server.'};
    }
  }
}

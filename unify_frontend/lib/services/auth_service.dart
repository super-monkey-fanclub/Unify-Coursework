import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';

/// Handles all communication with the Django authentication endpoints.
class AuthService {
  static String get _baseUrl => '${ApiConfig.baseUrl}/api/auth';

  Map<String, dynamic> _connectionError(Object error) {
    return {
      'success': false,
      'message':
          'Could not connect to the server. (${error.runtimeType}: $error)',
    };
  }

  /// Registers a new user.
  /// Returns a map with 'success' (bool), and either 'user' or 'message'.
  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
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
    } catch (error) {
      return _connectionError(error);
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
      return {'success': false, 'message': body['error'] ?? 'Login failed.'};
    } catch (error) {
      return _connectionError(error);
    }
  }
}

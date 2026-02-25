import 'dart:convert';
import 'package:http/http.dart' as http;

/// Handles all communication with the Django authentication endpoints.
class AuthService {
  // Change this to your machine's local IP if testing on a physical device.
  static const String _baseUrl = 'http://127.0.0.1:8000/api/auth';

  /// Registers a new user.
  /// Returns a map with 'success' (bool), and either 'upNumber' or 'message'.
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

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 201) {
        return {'success': true, 'upNumber': body['up_number']};
      }
      return {
        'success': false,
        'message': body['error'] ?? 'Registration failed.',
      };
    } catch (e) {
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

      final body = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        return {'success': true, 'user': body['user']};
      }
      return {'success': false, 'message': body['error'] ?? 'Login failed.'};
    } catch (e) {
      return {'success': false, 'message': 'Could not connect to the server.'};
    }
  }
}

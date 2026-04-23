import 'dart:convert';

import 'package:http/http.dart' as http;

/// Handles all communication with the Django authentication endpoints.
class AuthService {
  // Change this to your machine's local IP if testing on a physical device.
  static const String _baseUrl = 'http://127.0.0.1:8000/api';

  String _extractErrorMessage(String body, String fallback) {
    try {
      final dynamic decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        if (decoded['error'] is String) return decoded['error'] as String;
        if (decoded['detail'] is String) return decoded['detail'] as String;
        for (final value in decoded.values) {
          if (value is List && value.isNotEmpty) {
            final first = value.first;
            if (first is String) return first;
          }
          if (value is Map<String, dynamic>) {
            for (final nested in value.values) {
              if (nested is List && nested.isNotEmpty && nested.first is String) {
                return nested.first as String;
              }
              if (nested is String && nested.isNotEmpty) return nested;
            }
          }
          if (value is String && value.isNotEmpty) return value;
        }
      }
    } catch (_) {
      // Ignore non-JSON responses and fall back to default message.
    }
    return fallback;
  }

  Future<Map<String, dynamic>> _fetchCurrentUser(String accessToken) async {
    final response = await http
        .get(
          Uri.parse('$_baseUrl/me/'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $accessToken',
          },
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      return {
        'success': false,
        'message': _extractErrorMessage(
          response.body,
          'Could not load profile.',
        ),
      };
    }

    final dynamic body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) {
      return {'success': false, 'message': 'Unexpected profile response.'};
    }

    return {'success': true, 'user': body};
  }

  /// Registers a new user.
  /// Returns a map with 'success' (bool), and either 'user' or 'message'.
  Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String upNumber,
    required String password,
    required String passwordConfirmation,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/register/'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'username': username,
              'email': email,
              'up_number': upNumber,
              'password': password,
              'password_confirmation': passwordConfirmation,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final dynamic body = jsonDecode(response.body);
        if (body is Map<String, dynamic>) {
          return {
            'success': true,
            'user': body['user'],
            'access': body['access'],
            'refresh': body['refresh'],
          };
        }
        return {'success': true};
      }

      return {
        'success': false,
        'message': _extractErrorMessage(response.body, 'Registration failed.'),
      };
    } catch (_) {
      return {'success': false, 'message': 'Could not connect to the server.'};
    }
  }

  /// Logs in an existing user.
  /// Returns a map with 'success' (bool), and either 'user' map or 'message'.
  Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/login/'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'username': username, 'password': password}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final dynamic body = jsonDecode(response.body);
        if (body is! Map<String, dynamic> || body['access'] is! String) {
          return {'success': false, 'message': 'Unexpected login response.'};
        }

        final String accessToken = body['access'] as String;
        final meResult = await _fetchCurrentUser(accessToken);
        if (meResult['success'] != true) {
          return meResult;
        }

        return {
          'success': true,
          'user': meResult['user'],
          'access': accessToken,
          'refresh': body['refresh'],
        };
      }

      return {
        'success': false,
        'message': _extractErrorMessage(response.body, 'Login failed.'),
      };
    } catch (_) {
      return {'success': false, 'message': 'Could not connect to the server.'};
    }
  }
}

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
    bool optInEmail = false,
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
              'opt_in_email': optInEmail,
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

  /// Update the authenticated user's account.
  /// `authToken` should be the user's `auth_token` returned at login/register.
  Future<Map<String, dynamic>> updateAccount({
    required String authToken,
    String? email,
    String? currentPassword,
    String? newPassword,
    bool? optInEmail,
  }) async {
    try {
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $authToken',
      };

      final body = <String, dynamic>{};
      if (email != null) body['email'] = email;
      if (currentPassword != null) body['current_password'] = currentPassword;
      if (newPassword != null) body['new_password'] = newPassword;
      if (optInEmail != null) body['opt_in_email'] = optInEmail;

      final response = await http
          .post(
            Uri.parse('$_baseUrl/account/'),
            headers: headers,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      final Map<String, dynamic> resBody =
          jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 200) {
        return {'success': true, 'user': resBody['user']};
      }
      return {
        'success': false,
        'message': resBody['error'] ?? 'Update failed.',
      };
    } catch (error) {
      return _connectionError(error);
    }
  }
}

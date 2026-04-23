import 'dart:convert';

import 'package:http/http.dart' as http;

/// Handles joining societies and managing memberships.
class SocietyService {
  static const String _apiBaseUrl = 'http://127.0.0.1:8000/api';
  static const String _baseUrl = 'http://127.0.0.1:8000/api/societies';

  String _extractErrorMessage(String body, String fallback) {
    try {
      final dynamic decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        if (decoded['error'] is String) return decoded['error'] as String;
        if (decoded['detail'] is String) return decoded['detail'] as String;
        for (final value in decoded.values) {
          if (value is List && value.isNotEmpty && value.first is String) {
            return value.first as String;
          }
          if (value is Map<String, dynamic>) {
            for (final nested in value.values) {
              if (nested is List && nested.isNotEmpty && nested.first is String) {
                return nested.first as String;
              }
              if (nested is String && nested.isNotEmpty) {
                return nested;
              }
            }
          }
          if (value is String && value.isNotEmpty) {
            return value;
          }
        }
      }
    } catch (_) {
      // Ignore parse failures and use fallback.
    }
    return fallback;
  }

  Map<String, String> _jsonHeaders({String? accessToken}) {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (accessToken != null && accessToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $accessToken';
    }
    return headers;
  }

  Future<int?> _resolveSocietyIdByName(String societyName) async {
    try {
      final uri = Uri.parse(
        '$_apiBaseUrl/societies/',
      ).replace(queryParameters: {'search': societyName});
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;

      final dynamic decoded = jsonDecode(response.body);
      final List<dynamic> results = decoded is Map<String, dynamic>
          ? (decoded['results'] as List<dynamic>? ?? <dynamic>[])
          : (decoded as List<dynamic>? ?? <dynamic>[]);

      if (results.isEmpty) return null;

      Map<String, dynamic>? selected;
      for (final item in results) {
        if (item is! Map<String, dynamic>) continue;
        final name = (item['name'] as String? ?? '').toLowerCase();
        if (name == societyName.toLowerCase()) {
          selected = item;
          break;
        }
      }

      selected ??= results.first as Map<String, dynamic>?;
      return selected?['id'] as int?;
    } catch (_) {
      return null;
    }
  }

  Future<int?> _createSociety({
    required String name,
    required String description,
    required String category,
    required String accessToken,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_apiBaseUrl/societies/'),
            headers: _jsonHeaders(accessToken: accessToken),
            body: jsonEncode({
              'name': name,
              'description': description,
              'category': category,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200 && response.statusCode != 201) {
        return null;
      }

      final dynamic decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        return decoded['id'] as int?;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Join a society for the given user email.
  /// Returns a map with 'success' and 'message'.
  Future<Map<String, dynamic>> joinSociety({
    required String email,
    required String societyName,
    String description = '',
    String category = 'General',
    String? accessToken,
  }) async {
    if (accessToken == null || accessToken.isEmpty) {
      return {
        'success': false,
        'message': 'Please log in again before joining a society.',
      };
    }

    try {
      int? societyId = await _resolveSocietyIdByName(societyName);
      societyId ??= await _createSociety(
        name: societyName,
        description: description,
        category: category,
        accessToken: accessToken,
      );
      societyId ??= await _resolveSocietyIdByName(societyName);

      if (societyId == null) {
        return {
          'success': false,
          'message': 'Could not create society record on server.',
        };
      }

      final response = await http
          .post(
            Uri.parse('$_apiBaseUrl/societies/$societyId/join/'),
            headers: _jsonHeaders(accessToken: accessToken),
            body: jsonEncode({}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'message': 'Joined society'};
      }

      return {
        'success': false,
        'message': _extractErrorMessage(
          response.body,
          'Could not join society.',
        ),
      };
    } catch (_) {
      return {'success': false, 'message': 'Could not connect to the server.'};
    }
  }

  /// Fetch the list of societies the given user has joined.
  /// Returns a map with 'success', and on success 'societies' as List<String>.
  Future<Map<String, dynamic>> getMySocieties({
    required String email,
    String? accessToken,
  }) async {
    if (accessToken == null || accessToken.isEmpty) {
      return {'success': true, 'societies': <String>[]};
    }

    try {
      final response = await http
          .get(
            Uri.parse('$_apiBaseUrl/societies/my_societies/'),
            headers: _jsonHeaders(accessToken: accessToken),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        final List<dynamic> raw = decoded is List<dynamic>
            ? decoded
            : (decoded as Map<String, dynamic>)['results'] as List<dynamic>? ??
                  <dynamic>[];
        final List<String> names = raw
            .map((e) => (e as Map<String, dynamic>)['name'] as String)
            .toList();
        return {'success': true, 'societies': names};
      }

      return {
        'success': false,
        'message': _extractErrorMessage(
          response.body,
          'Could not load societies.',
        ),
      };
    } catch (_) {
      return {'success': false, 'message': 'Could not connect to the server.'};
    }
  }

  /// Fetch reviews for a given society name.
  /// Returns a map with 'success', and on success 'reviews' as List<Map>.
  Future<Map<String, dynamic>> getReviews({
    required String societyName,
    String? viewerEmail,
    String sort = 'latest',
    int? minRating,
  }) async {
    try {
      final int? societyId = await _resolveSocietyIdByName(societyName);

      // If this society is only in local seed data and not on the API yet,
      // treat it as an empty state rather than a connectivity failure.
      if (societyId == null) {
        return {
          'success': true,
          'reviews': <Map<String, dynamic>>[],
          'viewer_is_admin': false,
          'can_create_review': false,
          'review_block_reason': null,
          'has_active_review': false,
        };
      }

      final Map<String, String> query = {'society': '$societyId'};
      if (minRating != null) {
        query['rating'] = '$minRating';
      }

      final uri = Uri.parse(
        '$_apiBaseUrl/reviews/',
      ).replace(queryParameters: query);

      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        final List<dynamic> raw = decoded is List<dynamic>
            ? decoded
            : (decoded as Map<String, dynamic>)['results'] as List<dynamic>? ??
                  <dynamic>[];

        final List<Map<String, dynamic>> mapped = raw
            .whereType<Map<String, dynamic>>()
            .map(
              (review) => {
                'id': review['id'],
                'author': review['user_username'] ?? 'Anonymous',
                'author_display_name': review['user_username'] ?? 'Anonymous',
                'rating': review['rating'] ?? 0,
                'comment': review['comment'] ?? '',
                'likes': review['like_count'] ?? 0,
                'dislikes': review['dislike_count'] ?? 0,
                'user_reaction': null,
                'can_react': viewerEmail != null && viewerEmail.isNotEmpty,
                'admin_response': null,
              },
            )
            .toList();

        if (sort == 'rating') {
          mapped.sort(
            (a, b) => (b['rating'] as int).compareTo(a['rating'] as int),
          );
        } else if (sort == 'popularity') {
          mapped.sort((a, b) {
            final aScore = (a['likes'] as int) - (a['dislikes'] as int);
            final bScore = (b['likes'] as int) - (b['dislikes'] as int);
            return bScore.compareTo(aScore);
          });
        }

        return {
          'success': true,
          'reviews': mapped,
          'viewer_is_admin': false,
          'can_create_review': viewerEmail != null && viewerEmail.isNotEmpty,
          'review_block_reason': null,
          'has_active_review': false,
        };
      }

      return {
        'success': false,
        'message': _extractErrorMessage(
          response.body,
          'Could not load reviews.',
        ),
      };
    } catch (_) {
      return {'success': false, 'message': 'Could not connect to the server.'};
    }
  }

  /// Submit a review for a society by a given user.
  /// Returns a map with 'success' and 'message'.
  Future<Map<String, dynamic>> submitReview({
    required String email,
    required String societyName,
    required int rating,
    required String comment,
    String? accessToken,
  }) async {
    if (accessToken == null || accessToken.isEmpty) {
      return {
        'success': false,
        'message': 'Please log in again before submitting a review.',
      };
    }

    try {
      final societyId = await _resolveSocietyIdByName(societyName);
      if (societyId == null) {
        return {
          'success': false,
          'message': 'This society is not available on the server yet.',
        };
      }

      final response = await http
          .post(
            Uri.parse('$_apiBaseUrl/reviews/'),
            headers: _jsonHeaders(accessToken: accessToken),
            body: jsonEncode({
              'society': societyId,
              'rating': rating,
              'comment': comment,
            }),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'message': 'Review submitted.'};
      }

      return {
        'success': false,
        'message': _extractErrorMessage(
          response.body,
          'Could not submit review.',
        ),
      };
    } catch (_) {
      return {'success': false, 'message': 'Could not connect to the server.'};
    }
  }

  /// Submit a one-time reaction (like/dislike) to a review.
  Future<Map<String, dynamic>> reactToReview({
    required String email,
    required int reviewId,
    required String reactionType,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/reviews/react/'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email,
              'review_id': reviewId,
              'reaction_type': reactionType,
            }),
          )
          .timeout(const Duration(seconds: 10));

      final Map<String, dynamic> body =
          jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'message': body['message'] ?? 'Reaction recorded.',
          'likes': body['likes'] ?? 0,
          'dislikes': body['dislikes'] ?? 0,
          'user_reaction': body['user_reaction'],
        };
      }

      return {
        'success': false,
        'message': body['error'] ?? 'Could not react to review.',
      };
    } catch (_) {
      return {'success': false, 'message': 'Could not connect to the server.'};
    }
  }

  /// Delete a review as a society admin.
  Future<Map<String, dynamic>> deleteReviewAsAdmin({
    required String adminEmail,
    required int reviewId,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/reviews/delete/'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'admin_email': adminEmail,
              'review_id': reviewId,
            }),
          )
          .timeout(const Duration(seconds: 10));

      final Map<String, dynamic> body =
          jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'message': body['message'] ?? 'Review deleted.',
        };
      }

      return {
        'success': false,
        'message': body['error'] ?? 'Could not delete review.',
      };
    } catch (_) {
      return {'success': false, 'message': 'Could not connect to the server.'};
    }
  }

  /// Respond to a review as a society admin.
  Future<Map<String, dynamic>> respondToReviewAsAdmin({
    required String adminEmail,
    required int reviewId,
    required String responseText,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/reviews/respond/'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'admin_email': adminEmail,
              'review_id': reviewId,
              'response_text': responseText,
            }),
          )
          .timeout(const Duration(seconds: 10));

      final Map<String, dynamic> body =
          jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'message': body['message'] ?? 'Response saved.',
          'response': body['response'],
        };
      }

      return {
        'success': false,
        'message': body['error'] ?? 'Could not submit response.',
      };
    } catch (_) {
      return {'success': false, 'message': 'Could not connect to the server.'};
    }
  }

  /// Fetch polls for a society.
  Future<Map<String, dynamic>> getPolls({
    required String societyName,
    String? viewerEmail,
  }) async {
    try {
      final Map<String, String> query = {'society': societyName};
      if (viewerEmail != null && viewerEmail.isNotEmpty) {
        query['viewer_email'] = viewerEmail;
      }

      final uri = Uri.parse('$_baseUrl/polls/').replace(queryParameters: query);
      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      final Map<String, dynamic> body =
          jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        final List<dynamic> raw = body['polls'] as List<dynamic>? ?? [];
        final List<dynamic> rawInfo =
            body['info_items'] as List<dynamic>? ?? [];
        return {
          'success': true,
          'polls': raw.cast<Map<String, dynamic>>(),
          'info_items': rawInfo.cast<Map<String, dynamic>>(),
          'viewer_is_member': body['viewer_is_member'] == true,
          'viewer_is_admin': body['viewer_is_admin'] == true,
          'can_create_poll': body['can_create_poll'] == true,
          'can_create_info': body['can_create_info'] == true,
        };
      }

      return {
        'success': false,
        'message': body['error'] ?? 'Could not load polls.',
      };
    } catch (_) {
      return {'success': false, 'message': 'Could not connect to the server.'};
    }
  }

  /// Create a poll as a society admin.
  Future<Map<String, dynamic>> createPoll({
    required String adminEmail,
    required String societyName,
    required String title,
    required String description,
    required List<String> options,
    required int durationMinutes,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/polls/create/'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'admin_email': adminEmail,
              'society_name': societyName,
              'title': title,
              'description': description,
              'options': options,
              'duration_minutes': durationMinutes,
            }),
          )
          .timeout(const Duration(seconds: 10));

      final Map<String, dynamic> body =
          jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'message': body['message'] ?? 'Poll created.',
          'poll': body['poll'],
        };
      }

      return {
        'success': false,
        'message': body['error'] ?? 'Could not create poll.',
      };
    } catch (_) {
      return {'success': false, 'message': 'Could not connect to the server.'};
    }
  }

  /// Create a society information post as an admin.
  Future<Map<String, dynamic>> createInfo({
    required String adminEmail,
    required String societyName,
    required String title,
    required String content,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/polls/info/create/'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'admin_email': adminEmail,
              'society_name': societyName,
              'title': title,
              'content': content,
            }),
          )
          .timeout(const Duration(seconds: 10));

      final Map<String, dynamic> body =
          jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'message': body['message'] ?? 'Information posted.',
          'info': body['info'],
        };
      }

      return {
        'success': false,
        'message': body['error'] ?? 'Could not post information.',
      };
    } catch (_) {
      return {'success': false, 'message': 'Could not connect to the server.'};
    }
  }

  /// Vote on a poll once.
  Future<Map<String, dynamic>> votePoll({
    required String email,
    required int pollId,
    required int optionId,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/polls/vote/'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email,
              'poll_id': pollId,
              'option_id': optionId,
            }),
          )
          .timeout(const Duration(seconds: 10));

      final Map<String, dynamic> body =
          jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'message': body['message'] ?? 'Vote recorded.',
          'poll': body['poll'],
        };
      }

      return {
        'success': false,
        'message': body['error'] ?? 'Could not vote on poll.',
      };
    } catch (_) {
      return {'success': false, 'message': 'Could not connect to the server.'};
    }
  }

  /// Edit a poll by adding or deleting an option.
  Future<Map<String, dynamic>> editPoll({
    required String adminEmail,
    required int pollId,
    required String action,
    String? optionText,
    int? optionId,
  }) async {
    try {
      final Map<String, dynamic> payload = {
        'admin_email': adminEmail,
        'poll_id': pollId,
        'action': action,
      };
      if (optionText != null) {
        payload['option_text'] = optionText;
      }
      if (optionId != null) {
        payload['option_id'] = optionId;
      }

      final response = await http
          .post(
            Uri.parse('$_baseUrl/polls/edit/'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 10));

      final Map<String, dynamic> body =
          jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'message': body['message'] ?? 'Poll updated.',
          'poll': body['poll'],
        };
      }

      return {
        'success': false,
        'message': body['error'] ?? 'Could not update poll.',
      };
    } catch (_) {
      return {'success': false, 'message': 'Could not connect to the server.'};
    }
  }

  /// Delete a poll as an admin.
  Future<Map<String, dynamic>> deletePoll({
    required String adminEmail,
    required int pollId,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/polls/delete/'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'admin_email': adminEmail, 'poll_id': pollId}),
          )
          .timeout(const Duration(seconds: 10));

      final Map<String, dynamic> body =
          jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'message': body['message'] ?? 'Poll deleted.'};
      }

      return {
        'success': false,
        'message': body['error'] ?? 'Could not delete poll.',
      };
    } catch (_) {
      return {'success': false, 'message': 'Could not connect to the server.'};
    }
  }

  /// Delete a society information message as an admin.
  Future<Map<String, dynamic>> deleteInfo({
    required String adminEmail,
    required int infoId,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/polls/info/delete/'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'admin_email': adminEmail, 'info_id': infoId}),
          )
          .timeout(const Duration(seconds: 10));

      final Map<String, dynamic> body =
          jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'message': body['message'] ?? 'Message deleted.',
        };
      }

      return {
        'success': false,
        'message': body['error'] ?? 'Could not delete message.',
      };
    } catch (_) {
      return {'success': false, 'message': 'Could not connect to the server.'};
    }
  }
}

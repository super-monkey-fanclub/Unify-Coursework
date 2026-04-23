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
            body: jsonEncode({'email': email, 'society_name': societyName}),
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
      return {'success': false, 'message': 'Could not connect to the server.'};
    }
  }

  /// Fetch the list of societies the given user has joined.
  /// Returns a map with 'success', and on success 'societies' as List<String>.
  Future<Map<String, dynamic>> getMySocieties({required String email}) async {
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
        return {'success': true, 'societies': names};
      }

      return {
        'success': false,
        'message': body['error'] ?? 'Could not load societies.',
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
      final Map<String, String> query = {'society': societyName, 'sort': sort};
      if (viewerEmail != null && viewerEmail.isNotEmpty) {
        query['viewer_email'] = viewerEmail;
      }
      if (minRating != null) {
        query['min_rating'] = '$minRating';
      }

      final uri = Uri.parse(
        '$_baseUrl/reviews/',
      ).replace(queryParameters: query);

      final response = await http.get(uri).timeout(const Duration(seconds: 10));

      final Map<String, dynamic> body =
          jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        final List<dynamic> raw = body['reviews'] as List<dynamic>? ?? [];
        return {
          'success': true,
          'reviews': raw.cast<Map<String, dynamic>>(),
          'viewer_is_admin': body['viewer_is_admin'] == true,
          'can_create_review': body['can_create_review'] == true,
          'review_block_reason': body['review_block_reason'],
          'has_active_review': body['has_active_review'] == true,
        };
      }

      return {
        'success': false,
        'message': body['error'] ?? 'Could not load reviews.',
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
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/reviews/add/'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'email': email,
              'society_name': societyName,
              'rating': rating,
              'comment': comment,
            }),
          )
          .timeout(const Duration(seconds: 10));

      final Map<String, dynamic> body =
          jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'message': body['message'] ?? 'Review submitted.',
        };
      }

      return {
        'success': false,
        'message': body['error'] ?? 'Could not submit review.',
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
        final List<dynamic> rawInfo = body['info_items'] as List<dynamic>? ?? [];
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
            body: jsonEncode({
              'admin_email': adminEmail,
              'poll_id': pollId,
            }),
          )
          .timeout(const Duration(seconds: 10));

      final Map<String, dynamic> body =
          jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'message': body['message'] ?? 'Poll deleted.',
        };
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
            body: jsonEncode({
              'admin_email': adminEmail,
              'info_id': infoId,
            }),
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

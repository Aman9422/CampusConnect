import 'dart:convert';
import 'package:http/http.dart' as http;

class AIService {
  static const String _cloudFunctionUrl =
      'https://us-central1-campusconnect-firebase-project.cloudfunctions.net/askAI';

  final http.Client _httpClient;

  AIService(this._httpClient);

  factory AIService.instance() {
    return AIService(http.Client());
  }

  /// Send a message to the AI assistant and get a response
  ///
  /// [userId] - The authenticated user's ID
  /// [message] - The user's message to the AI
  ///
  /// Returns the AI's response as a string
  /// Throws an exception if the request fails
  Future<String> sendMessage({
    required String userId,
    required String message,
  }) async {
    try {
      // Validate inputs
      if (userId.isEmpty) {
        throw Exception('User ID is required');
      }

      final trimmedMessage = message.trim();
      if (trimmedMessage.isEmpty) {
        throw Exception('Message cannot be empty');
      }

      if (trimmedMessage.length > 1000) {
        throw Exception('Message too long. Maximum 1000 characters.');
      }

      // Make HTTP POST request to Cloud Function
      final response = await _httpClient
          .post(
            Uri.parse(_cloudFunctionUrl),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'userId': userId, 'message': trimmedMessage}),
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception('Request timed out. Please try again.');
            },
          );

      // Handle response
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final aiResponse = data['response'] as String?;

        if (aiResponse == null || aiResponse.isEmpty) {
          throw Exception('Invalid response from AI service');
        }

        return aiResponse;
      } else if (response.statusCode == 400) {
        final error = json.decode(response.body);
        throw Exception(error['error'] ?? 'Invalid request');
      } else if (response.statusCode == 500) {
        throw Exception('Server error. Please try again later.');
      } else {
        throw Exception(
          'Unexpected error (${response.statusCode}). Please try again.',
        );
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Failed to connect to AI service: $e');
    }
  }

  /// Dispose of resources
  void dispose() {
    _httpClient.close();
  }
}

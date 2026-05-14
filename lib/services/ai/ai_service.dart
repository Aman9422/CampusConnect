import 'dart:convert';
import 'package:campusconnect/models/ai_interaction.dart';
import 'package:http/http.dart' as http;

/// VERSION 4: AI Response Model
/// Contains AI response plus trial and usage metadata
class AIResponse {
  final String message;
  final TrialInfo? trial;
  final UsageInfo? usage;
  final String? warning;
  final int? retryAfter;

  AIResponse({
    required this.message,
    this.trial,
    this.usage,
    this.warning,
    this.retryAfter,
  });

  factory AIResponse.fromJson(Map<String, dynamic> json) {
    return AIResponse(
      message: json['response'] as String? ?? '',
      trial: json['trial'] != null
          ? TrialInfo.fromJson(json['trial'] as Map<String, dynamic>)
          : null,
      usage: json['usage'] != null
          ? UsageInfo.fromJson(json['usage'] as Map<String, dynamic>)
          : null,
      warning: json['warning'] as String?,
      retryAfter: json['retryAfter'] as int?,
    );
  }
}

/// VERSION 4: Trial Information
class TrialInfo {
  final String status; // "active", "expired", or "none"
  final int daysRemaining;
  final String? expiresAt;

  TrialInfo({
    required this.status,
    required this.daysRemaining,
    this.expiresAt,
  });

  factory TrialInfo.fromJson(Map<String, dynamic> json) {
    return TrialInfo(
      status: json['status'] as String? ?? 'none',
      daysRemaining: json['daysRemaining'] as int? ?? 0,
      expiresAt: json['expiresAt'] as String?,
    );
  }

  bool get isActive => status == 'active';
  bool get isExpired => status == 'expired';
}

/// VERSION 4: Usage Information
class UsageInfo {
  final int dailyCount;
  final int dailyLimit;
  final String? lastResetAt;

  UsageInfo({
    required this.dailyCount,
    required this.dailyLimit,
    this.lastResetAt,
  });

  factory UsageInfo.fromJson(Map<String, dynamic> json) {
    return UsageInfo(
      dailyCount: json['dailyCount'] as int? ?? 0,
      dailyLimit: json['dailyLimit'] as int? ?? 50,
      lastResetAt: json['lastResetAt'] as String?,
    );
  }

  double get usagePercentage =>
      dailyLimit > 0 ? (dailyCount / dailyLimit) : 0.0;
  bool get isNearLimit => dailyCount >= (dailyLimit * 0.8);
}

class AIService {
  static const String _cloudFunctionUrl =
      'https://us-central1-campusconnect-firebase-project.cloudfunctions.net/askAI';

  final http.Client _httpClient;

  AIService(this._httpClient);

  factory AIService.instance() {
    return AIService(http.Client());
  }

  /// Send a message to the AI assistant and get a response (VERSION 4)
  ///
  /// [userId] - The authenticated user's ID
  /// [message] - The user's message to the AI
  ///
  /// Returns AIResponse with message, trial info, and usage metadata
  /// Throws an exception if the request fails
  Future<AIResponse> sendMessage({
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
        final data = json.decode(response.body) as Map<String, dynamic>;

        // VERSION 4: Parse enhanced response with trial and usage info
        return AIResponse.fromJson(data);
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

  /// v7.4: Career assistant wrapper with local intent framing.
  ///
  /// Keeps backend contract unchanged while steering the model response style.
  Future<AIResponse> sendCareerAssistantMessage({
    required String userId,
    required String message,
  }) async {
    final intent = detectIntent(message);
    final framedMessage = _withCareerIntentPrefix(intent, message);
    return sendMessage(userId: userId, message: framedMessage);
  }

  /// v7.4: Lightweight intent detection used by AI chat/provider layers.
  AIInteractionIntent detectIntent(String message) {
    final normalized = message.toLowerCase();
    if (_containsAny(normalized, [
      'resume',
      'ats',
      'cv',
      'bullet',
      'rewrite',
    ])) {
      return AIInteractionIntent.resumeImprovement;
    }
    if (_containsAny(normalized, [
      'career path',
      'career',
      'roadmap',
      'next role',
      'future',
    ])) {
      return AIInteractionIntent.careerPath;
    }
    if (_containsAny(normalized, [
      'interview',
      'mock',
      'question',
      'hr round',
      'technical round',
    ])) {
      return AIInteractionIntent.interviewPrep;
    }
    if (_containsAny(normalized, [
      'skill gap',
      'missing skill',
      'what should i learn',
      'upskill',
      'learn next',
    ])) {
      return AIInteractionIntent.skillGap;
    }
    return AIInteractionIntent.general;
  }

  String _withCareerIntentPrefix(AIInteractionIntent intent, String message) {
    switch (intent) {
      case AIInteractionIntent.resumeImprovement:
        return '[Career Assistant: Resume Improvement]\n$message';
      case AIInteractionIntent.careerPath:
        return '[Career Assistant: Career Path Guidance]\n$message';
      case AIInteractionIntent.interviewPrep:
        return '[Career Assistant: Interview Preparation]\n$message';
      case AIInteractionIntent.skillGap:
        return '[Career Assistant: Skill Gap Analysis]\n$message';
      case AIInteractionIntent.general:
        return '[Career Assistant: General Guidance]\n$message';
    }
  }

  bool _containsAny(String source, List<String> needles) {
    return needles.any(source.contains);
  }

  /// Dispose of resources
  void dispose() {
    _httpClient.close();
  }
}

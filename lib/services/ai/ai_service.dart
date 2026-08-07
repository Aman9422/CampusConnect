import 'package:campusconnect/models/ai_interaction.dart';
import 'package:cloud_functions/cloud_functions.dart';

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

/// AIService - AI chat via the `askAI` Cloud Function (callable).
///
/// v8.4.2 (S6b/P3): migrated from a raw HTTPS POST to
/// `FirebaseFunctions#httpsCallable('askAI')`. The authenticated uid is
/// resolved server-side from Firebase Auth (`request.auth.uid`), so a forged
/// `userId` can no longer spend AI quota on another user's account.
class AIService {
  final FirebaseFunctions _functions;

  AIService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance;

  factory AIService.instance() => AIService();

  /// Send a message to the AI assistant and get a response (VERSION 4)
  ///
  /// [userId] - The authenticated user's ID (server derives the identity from
  /// Firebase Auth; kept as a parameter for API compatibility)
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

      // v8.4.2 (S6b/P3): callable call — uid comes from Firebase Auth context
      // on the server; the client no longer transmits `userId`.
      final callable = _functions.httpsCallable('askAI');
      final result = await callable
          .call<Map<String, dynamic>>({'message': trimmedMessage})
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception('Request timed out. Please try again.');
            },
          );

      return AIResponse.fromJson(result.data);
    } on FirebaseFunctionsException catch (e) {
      throw Exception(_mapFunctionError(e));
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

  /// Map a callable error code to a user-friendly message.
  String _mapFunctionError(FirebaseFunctionsException e) {
    switch (e.code) {
      case 'unauthenticated':
        return 'Please log in to use the AI assistant.';
      case 'invalid-argument':
        return e.message ?? 'Invalid request. Please try again.';
      case 'resource-exhausted':
        return e.message ??
            'You have reached the AI message limit. Please try again later.';
      case 'deadline-exceeded':
        return 'The AI assistant took too long to respond. Please try again.';
      case 'internal':
      case 'unavailable':
        return 'The AI assistant is temporarily unavailable. Please try again later.';
      default:
        return e.message ?? 'Failed to connect to AI service.';
    }
  }

  /// Dispose of resources.
  ///
  /// v8.4.2 (S6b/P3): no-op — the callable client owns no HTTP resources.
  void dispose() {}
}

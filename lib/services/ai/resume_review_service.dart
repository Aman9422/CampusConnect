import 'dart:convert';

import 'package:campusconnect/models/resume_review.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// CampusConnect v6.7 - Resume Review Service
///
/// Service for AI-powered resume analysis and ATS optimization.
/// Uses Cloud Functions for processing.
///
/// v8.4.2 (S6b/P3): migrated from raw HTTPS calls to the `reviewResume`
/// callable. The authenticated uid is resolved server-side from Firebase Auth
/// (`request.auth.uid`); the monthly-quota rejection arrives as a
/// `resource-exhausted` HttpsError and is mapped back to
/// [ResumeReviewQuotaException]. Usage checks use the `{checkUsage: true}`
/// callable flag (which replaced the old GET ?checkUsage=true endpoint).
///
/// RULES:
/// - One-shot request only (no conversation memory)
/// - Monthly limit enforced (5 reviews/month)
/// - Resume text NOT stored permanently
/// - Requires authenticated user

class ResumeReviewService {
  final FirebaseFunctions _functions;

  // Character limits for cost control
  static const int maxResumeLength = 5000; // ~1000 words
  static const int minResumeLength = 100; // At least some content

  ResumeReviewService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance;

  factory ResumeReviewService.instance() => ResumeReviewService();

  /// Submit resume for AI review
  ///
  /// [userId] - Authenticated user's ID (server derives the identity from
  /// Firebase Auth; kept as a parameter for API compatibility)
  /// [resumeText] - Resume content as plain text
  /// [targetRole] - Optional target job role for tailored advice
  ///
  /// Returns ResumeReviewResponse with review data and usage info
  /// Throws exception on failure
  Future<ResumeReviewResponse> reviewResume({
    required String userId,
    required String resumeText,
    String? targetRole,
  }) async {
    try {
      // Validate inputs
      if (userId.isEmpty) {
        throw ResumeReviewException('User ID is required');
      }

      final trimmedResume = resumeText.trim();
      if (trimmedResume.length < minResumeLength) {
        throw ResumeReviewException(
          'Resume is too short. Please provide at least 100 characters.',
        );
      }

      if (trimmedResume.length > maxResumeLength) {
        throw ResumeReviewException(
          'Resume is too long. Maximum $maxResumeLength characters allowed.\n'
          'Current: ${trimmedResume.length} characters.',
        );
      }

      debugPrint('ResumeReviewService: Sending review request...');

      // v8.4.2 (S6b/P3): callable call — uid comes from Firebase Auth context
      // on the server; the client no longer transmits `userId`.
      final callable = _functions.httpsCallable(
        'reviewResume',
        options: HttpsCallableOptions(
          timeout: const Duration(seconds: 120),
        ),
      );
      final result = await callable.call<Map<String, dynamic>>({
        'resumeText': trimmedResume,
        'targetRole': targetRole ?? 'General / Entry Level',
        'experienceLevel': 'Student / Fresher',
      });

      // Deep-convert to Map<String, dynamic> — the callable SDK returns nested
      // maps as Map<Object?, Object?> which fails direct casts.
      final data =
          jsonDecode(jsonEncode(result.data)) as Map<String, dynamic>;
      return ResumeReviewResponse.fromJson(data);
    } on FirebaseFunctionsException catch (e) {
      debugPrint('ResumeReviewService: function error ${e.code} - ${e.message}');
      switch (e.code) {
        case 'unauthenticated':
          throw ResumeReviewException('Please log in to review your resume');
        case 'resource-exhausted':
          throw ResumeReviewQuotaException(
            e.message ?? 'Monthly review limit reached',
            usage: _usageFromDetails(e.details),
          );
        case 'invalid-argument':
          throw ResumeReviewException(e.message ?? 'Invalid request');
        case 'internal':
        case 'unavailable':
          throw ResumeReviewException(
            'Server error. Please try again later.',
          );
        case 'deadline-exceeded':
          throw ResumeReviewException(
            'Request timed out. Please try again.',
          );
        default:
          throw ResumeReviewException(
            e.message ?? 'Failed to review resume',
          );
      }
    } on ResumeReviewException {
      rethrow;
    } catch (e) {
      debugPrint('ResumeReviewService error: $e');
      if (e.toString().contains('SocketException') ||
          e.toString().contains('network')) {
        throw ResumeReviewException(
          'No internet connection. Please check your network.',
        );
      }
      throw ResumeReviewException('Failed to review resume: $e');
    }
  }

  /// Check current usage without submitting a review (callable flag).
  Future<ResumeReviewUsage> checkUsage(String userId) async {
    try {
      final callable = _functions.httpsCallable('reviewResume');
      final result = await callable
          .call<Map<String, dynamic>>({'checkUsage': true})
          .timeout(const Duration(seconds: 10));

      final data =
          jsonDecode(jsonEncode(result.data)) as Map<String, dynamic>;
      return ResumeReviewUsage.fromJson(
        data['usage'] as Map<String, dynamic>? ?? {},
      );
    } catch (e) {
      debugPrint('Failed to check usage: $e');
      return const ResumeReviewUsage(monthlyCount: 0, monthlyLimit: 5);
    }
  }

  /// Extract usage from a quota-exceeded callable error's details payload.
  ResumeReviewUsage? _usageFromDetails(Object? details) {
    if (details is! Map) return null;
    try {
      final encoded = jsonEncode(details);
      final map = jsonDecode(encoded) as Map<String, dynamic>;
      return ResumeReviewUsage.fromJson(
        map['usage'] as Map<String, dynamic>? ?? {},
      );
    } catch (e) {
      debugPrint('ResumeReviewService: could not parse quota details: $e');
      return null;
    }
  }

  /// Dispose of resources.
  ///
  /// v8.4.2 (S6b/P3): no-op — the callable client owns no HTTP resources.
  void dispose() {}
}

/// Response wrapper from Cloud Function
class ResumeReviewResponse {
  final ResumeReview review;
  final ResumeReviewUsage usage;
  final String? warning;

  const ResumeReviewResponse({
    required this.review,
    required this.usage,
    this.warning,
  });

  factory ResumeReviewResponse.fromJson(Map<String, dynamic> json) {
    return ResumeReviewResponse(
      review: ResumeReview.fromJson(
        json['review'] as Map<String, dynamic>? ?? json,
      ),
      usage: ResumeReviewUsage.fromJson(
        json['usage'] as Map<String, dynamic>? ?? {},
      ),
      warning: json['warning'] as String?,
    );
  }
}

/// Custom exception for resume review errors
class ResumeReviewException implements Exception {
  final String message;
  ResumeReviewException(this.message);

  @override
  String toString() => message;
}

/// Exception for quota exceeded
class ResumeReviewQuotaException extends ResumeReviewException {
  final ResumeReviewUsage? usage;

  ResumeReviewQuotaException(super.message, {this.usage});
}

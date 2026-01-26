import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:campusconnect/models/resume_review.dart';

/// CampusConnect v6.7 - Resume Review Service
///
/// Service for AI-powered resume analysis and ATS optimization.
/// Uses Cloud Functions for processing.
///
/// RULES:
/// - One-shot request only (no conversation memory)
/// - Monthly limit enforced (2-3 reviews/month)
/// - Resume text NOT stored permanently
/// - Requires authenticated user

class ResumeReviewService {
  static const String _cloudFunctionUrl =
      'https://us-central1-campusconnect-firebase-project.cloudfunctions.net/reviewResume';

  // Character limits for cost control
  static const int maxResumeLength = 5000; // ~1000 words
  static const int minResumeLength = 100; // At least some content

  final http.Client _httpClient;

  ResumeReviewService(this._httpClient);

  factory ResumeReviewService.instance() {
    return ResumeReviewService(http.Client());
  }

  /// Submit resume for AI review
  ///
  /// [userId] - Authenticated user's ID (required)
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

      // Make HTTP POST request to Cloud Function
      final response = await _httpClient
          .post(
            Uri.parse(_cloudFunctionUrl),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'userId': userId,
              'resumeText': trimmedResume,
              'targetRole': targetRole ?? 'General / Entry Level',
              'experienceLevel': 'Student / Fresher',
            }),
          )
          .timeout(
            const Duration(seconds: 60), // Longer timeout for AI processing
            onTimeout: () {
              throw ResumeReviewException(
                'Request timed out. Please try again.',
              );
            },
          );

      // Handle response
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return ResumeReviewResponse.fromJson(data);
      } else if (response.statusCode == 429) {
        // Rate limit / quota exceeded
        final data = json.decode(response.body) as Map<String, dynamic>;
        throw ResumeReviewQuotaException(
          data['error'] as String? ?? 'Monthly review limit reached',
          usage: data['usage'] != null
              ? ResumeReviewUsage.fromJson(
                  data['usage'] as Map<String, dynamic>,
                )
              : null,
        );
      } else if (response.statusCode == 400) {
        final error = json.decode(response.body);
        throw ResumeReviewException(error['error'] ?? 'Invalid request');
      } else if (response.statusCode == 401) {
        throw ResumeReviewException('Please log in to review your resume');
      } else if (response.statusCode == 500) {
        throw ResumeReviewException('Server error. Please try again later.');
      } else {
        throw ResumeReviewException(
          'Unexpected error (${response.statusCode}). Please try again.',
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

  /// Check current usage without submitting a review
  Future<ResumeReviewUsage> checkUsage(String userId) async {
    try {
      final response = await _httpClient
          .get(
            Uri.parse('$_cloudFunctionUrl?userId=$userId&checkUsage=true'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return ResumeReviewUsage.fromJson(
          data['usage'] as Map<String, dynamic>? ?? {},
        );
      }

      // Return default if check fails
      return const ResumeReviewUsage(monthlyCount: 0, monthlyLimit: 3);
    } catch (e) {
      debugPrint('Failed to check usage: $e');
      return const ResumeReviewUsage(monthlyCount: 0, monthlyLimit: 3);
    }
  }

  void dispose() {
    _httpClient.close();
  }
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

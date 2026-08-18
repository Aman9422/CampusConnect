import 'dart:convert';

import 'package:campusconnect/models/career_coach_analysis.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// CampusConnect v9.0 — AI Career Coach Service
///
/// Talks to the `generateCareerCoachAnalysis` Cloud Function (secure
/// backend — no API keys ever reach the client). The server:
///
///   - serves the CACHED analysis when the career-data fingerprint is
///     unchanged (`forceRefresh` absent) — no AI call, no quota
///   - consumes the monthly quota + calls Groq → HuggingFace ONLY when the
///     analysis is missing, stale, or `forceRefresh: true`
///   - stores the result at `users/{uid}/career_coach/summary`
///
/// [summaryStream] live-reads that cached document so the dashboard can
/// render without ever triggering AI.
class CareerCoachService {
  final FirebaseFunctions _functions;
  final FirebaseFirestore _firestore;

  CareerCoachService({
    FirebaseFunctions? functions,
    FirebaseFirestore? firestore,
  }) : _functions = functions ?? FirebaseFunctions.instance,
       _firestore = firestore ?? FirebaseFirestore.instance;

  static final CareerCoachService _instance = CareerCoachService();
  factory CareerCoachService.instance() => _instance;

  /// Request the career-coach analysis.
  ///
  /// [forceRefresh] — when false (default, dashboard refresh), the server
  /// serves the cached analysis if the career data hasn't changed. When true
  /// (the explicit "Re-analyze" button), a fresh AI request is forced and a
  /// monthly credit is consumed.
  Future<CareerCoachResponse> generateAnalysis({
    bool forceRefresh = false,
  }) async {
    try {
      final callable = _functions.httpsCallable(
        'generateCareerCoachAnalysis',
        options: HttpsCallableOptions(
          timeout: const Duration(seconds: 120),
        ),
      );
      final result = await callable.call<Map<String, dynamic>>({
        if (forceRefresh) 'forceRefresh': true,
      });

      // Deep-convert — the callable SDK returns nested maps as
      // Map<Object?, Object?> which fails direct casts.
      final data = jsonDecode(jsonEncode(result.data)) as Map<String, dynamic>;
      return CareerCoachResponse.fromJson(data);
    } on FirebaseFunctionsException catch (e) {
      debugPrint(
        'CareerCoachService: function error ${e.code} - ${e.message}',
      );
      switch (e.code) {
        case 'unauthenticated':
          throw CareerCoachException(
            'Please log in to use the AI Career Coach.',
          );
        case 'resource-exhausted':
          throw CareerCoachQuotaException(
            e.message ?? 'Monthly analysis limit reached',
            usage: _usageFromDetails(e.details),
          );
        case 'not-found':
          throw CareerCoachException(
            'Profile not found. Please complete your profile first.',
          );
        case 'internal':
        case 'unavailable':
          throw CareerCoachUnavailableException(
            'AI Career Coach is temporarily unavailable. Please try again later.',
          );
        case 'deadline-exceeded':
          throw CareerCoachUnavailableException(
            'Request timed out. Please try again.',
          );
        default:
          throw CareerCoachException(
            e.message ?? 'Failed to generate career analysis',
          );
      }
    } on CareerCoachException {
      rethrow;
    } catch (e) {
      debugPrint('CareerCoachService error: $e');
      if (e.toString().contains('SocketException') ||
          e.toString().contains('network')) {
        throw CareerCoachNetworkException(
          'No internet connection. Please check your network.',
        );
      }
      throw CareerCoachException('Failed to generate career analysis: $e');
    }
  }

  /// Read the monthly usage without spending quota (callable flag).
  Future<CareerCoachUsage> checkUsage() async {
    try {
      final callable = _functions.httpsCallable(
        'generateCareerCoachAnalysis',
      );
      final result = await callable
          .call<Map<String, dynamic>>({'checkUsage': true})
          .timeout(const Duration(seconds: 10));

      final data = jsonDecode(jsonEncode(result.data)) as Map<String, dynamic>;
      return CareerCoachUsage.fromJson(
        data['usage'] as Map<String, dynamic>? ?? {},
      );
    } catch (e) {
      debugPrint('CareerCoachService: checkUsage failed: $e');
      return const CareerCoachUsage();
    }
  }

  /// Live stream of the cached `users/{uid}/career_coach/summary` document.
  /// Emits `null` when no analysis exists yet (dashboard shows the empty /
  /// "Generate analysis" state). NEVER triggers an AI request.
  Stream<CareerCoachAnalysis?> summaryStream(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('career_coach')
        .doc('summary')
        .snapshots()
        .map(
          (doc) => doc.exists
              ? CareerCoachAnalysis.fromSummaryDoc(doc.data())
              : null,
        );
  }

  /// One-shot read of the cached summary document (dashboard refresh).
  /// Returns `null` when no analysis exists yet. NEVER triggers an AI
  /// request and never consumes quota.
  Future<CareerCoachAnalysis?> fetchSummaryOnce(String userId) async {
    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('career_coach')
          .doc('summary')
          .get();
      return doc.exists
          ? CareerCoachAnalysis.fromSummaryDoc(doc.data())
          : null;
    } catch (e) {
      debugPrint('CareerCoachService: fetchSummaryOnce failed: $e');
      rethrow;
    }
  }

  CareerCoachUsage? _usageFromDetails(Object? details) {
    if (details is! Map) return null;
    try {
      final map = jsonDecode(jsonEncode(details)) as Map<String, dynamic>;
      return CareerCoachUsage.fromJson(
        map['usage'] as Map<String, dynamic>? ?? {},
      );
    } catch (e) {
      debugPrint('CareerCoachService: could not parse quota details: $e');
      return null;
    }
  }
}

/// Response wrapper from the `generateCareerCoachAnalysis` callable.
class CareerCoachResponse {
  /// True when the server returned the cached analysis (no AI, no quota).
  final bool cached;

  final CareerCoachAnalysis analysis;
  final CareerCoachUsage usage;
  final String? generatedAt;
  final String? providerUsed;

  const CareerCoachResponse({
    required this.cached,
    required this.analysis,
    required this.usage,
    this.generatedAt,
    this.providerUsed,
  });

  factory CareerCoachResponse.fromJson(Map<String, dynamic> json) {
    final analysis = CareerCoachAnalysis.fromJson(
      json['analysis'] as Map<String, dynamic>?,
    );
    final generatedAt = json['generatedAt'] as String?;
    final providerUsed = json['providerUsed'] as String?;

    // The callable carries generatedAt/providerUsed at the TOP level; fold
    // them onto the analysis when the nested map didn't include them.
    final resolvedAnalysis = (generatedAt != null || providerUsed != null) &&
            analysis.generatedAt == null
        ? CareerCoachAnalysis(
            careerReadiness: analysis.careerReadiness,
            careerFocus: analysis.careerFocus,
            recommendations: analysis.recommendations,
            analysisVersion: analysis.analysisVersion,
            generatedAt:
                generatedAt != null ? DateTime.tryParse(generatedAt) : null,
            providerUsed: providerUsed ?? analysis.providerUsed,
          )
        : analysis;

    return CareerCoachResponse(
      cached: json['cached'] as bool? ?? false,
      analysis: resolvedAnalysis,
      usage: CareerCoachUsage.fromJson(
        json['usage'] as Map<String, dynamic>? ?? {},
      ),
      generatedAt: generatedAt,
      providerUsed: providerUsed,
    );
  }
}

/// Custom exception for career-coach errors.
class CareerCoachException implements Exception {
  final String message;
  CareerCoachException(this.message);

  @override
  String toString() => message;
}

/// Exception for quota exceeded.
class CareerCoachQuotaException extends CareerCoachException {
  final CareerCoachUsage? usage;

  CareerCoachQuotaException(super.message, {this.usage});
}

/// v9.0: transient server-side failure (`internal` / `unavailable` /
/// `deadline-exceeded`). Kept separate so a future provider can pause
/// retries instead of burning monthly quota on a dead backend.
class CareerCoachUnavailableException extends CareerCoachException {
  CareerCoachUnavailableException(super.message);
}

/// v9.0: client-side network failure (socket / DNS-level).
class CareerCoachNetworkException extends CareerCoachException {
  CareerCoachNetworkException(super.message);
}

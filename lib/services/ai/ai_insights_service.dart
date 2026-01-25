import 'package:campusconnect/models/ai_placement_insight.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// AIInsightsService - v6.5.1
///
/// Service for fetching and caching AI-generated placement insights.
///
/// CRITICAL RULES:
/// - AI runs ONLY in Cloud Functions
/// - Results are cached in Firestore
/// - App must work WITHOUT AI
/// - Never block UI waiting for AI
class AIInsightsService {
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  static AIInsightsService? _instance;

  AIInsightsService._({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions = functions ?? FirebaseFunctions.instance;

  static AIInsightsService instance() {
    _instance ??= AIInsightsService._();
    return _instance!;
  }

  /// Get cached insight reference
  DocumentReference<Map<String, dynamic>> _getInsightRef(
    String userId,
    String placementId,
  ) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('ai_insights')
        .doc(placementId);
  }

  /// Get cached AI insight (if exists and not expired)
  Future<AIPlacementInsight?> getCachedInsight({
    required String userId,
    required String placementId,
  }) async {
    try {
      final doc = await _getInsightRef(userId, placementId).get();

      if (!doc.exists) return null;

      final insight = AIPlacementInsight.fromFirestore(doc);

      // Return null if expired
      if (insight.isExpired) {
        debugPrint('AI insight for $placementId is expired');
        return null;
      }

      return insight;
    } catch (e) {
      debugPrint('Error fetching cached insight: $e');
      return null;
    }
  }

  /// Get all cached insights for user
  Future<Map<String, AIPlacementInsight>> getAllCachedInsights({
    required String userId,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('ai_insights')
          .get();

      final insights = <String, AIPlacementInsight>{};

      for (final doc in snapshot.docs) {
        final insight = AIPlacementInsight.fromFirestore(doc);
        if (!insight.isExpired) {
          insights[doc.id] = insight;
        }
      }

      return insights;
    } catch (e) {
      debugPrint('Error fetching all cached insights: $e');
      return {};
    }
  }

  /// Request AI insight from Cloud Function
  /// This is non-blocking and should be called in background
  Future<AIPlacementInsight?> requestInsight({
    required String userId,
    required String placementId,
  }) async {
    try {
      // First check cache
      final cached = await getCachedInsight(
        userId: userId,
        placementId: placementId,
      );

      if (cached != null) {
        debugPrint('Using cached AI insight for $placementId');
        return cached;
      }

      // Call Cloud Function
      debugPrint('Requesting AI insight for $placementId');
      final callable = _functions.httpsCallable('generatePlacementInsight');

      final result = await callable.call({
        'uid': userId,
        'placementId': placementId,
      });

      final data = result.data as Map<String, dynamic>?;

      if (data == null || data['success'] != true) {
        debugPrint('AI insight generation failed: ${data?['error']}');
        return null;
      }

      // Parse response
      final insight = AIPlacementInsight.fromFunctionResponse(
        placementId: placementId,
        response: data['insight'] as Map<String, dynamic>,
        modelVersion: data['modelVersion'] as String? ?? 'v1',
      );

      // Cloud Function already caches in Firestore, so just return
      return insight;
    } catch (e) {
      debugPrint('Error requesting AI insight: $e');
      return null;
    }
  }

  /// Request insights for multiple placements (background)
  /// Returns immediately with cached insights, fetches missing ones in background
  Future<Map<String, AIPlacementInsight>> requestInsightsForPlacements({
    required String userId,
    required List<String> placementIds,
    Function(String placementId, AIPlacementInsight insight)? onInsightReady,
  }) async {
    final results = <String, AIPlacementInsight>{};
    final missingIds = <String>[];

    // First, get all cached insights
    final cached = await getAllCachedInsights(userId: userId);

    for (final placementId in placementIds) {
      if (cached.containsKey(placementId)) {
        results[placementId] = cached[placementId]!;
      } else {
        missingIds.add(placementId);
      }
    }

    // Fetch missing ones in background (don't await all)
    for (final placementId in missingIds) {
      // Fire and forget - don't block
      requestInsight(userId: userId, placementId: placementId).then((insight) {
        if (insight != null && onInsightReady != null) {
          onInsightReady(placementId, insight);
        }
      });
    }

    return results;
  }

  /// Clear all cached insights (on logout)
  Future<void> clearCache(String userId) async {
    // Note: We don't actually delete from Firestore on logout
    // The data is user-scoped and will be overwritten on next login
    debugPrint('AI insights cache cleared for user: $userId');
  }
}

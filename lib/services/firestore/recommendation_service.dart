import 'package:campusconnect/models/recommendation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

/// RecommendationService - v7.4 intelligent recommendation layer
///
/// Stores user-specific recommendations in:
/// users/{uid}/recommendations/{recommendationId}
///
/// v8.6 (MED 7): single-writer contract. The Cloud Function
/// `refreshRecommendations` is now the ONLY component that computes/writes
/// recommendation documents — the client previously ran a second, competing
/// scoring model (different weights + limits) that clobbered the server
/// engine's output. [refreshRecommendations] now delegates to that callable
/// and the provider reads the Firestore stream; no recommendation writes
/// happen from the app.
class RecommendationService {
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  RecommendationService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions = functions ?? FirebaseFunctions.instance;

  static final RecommendationService _instance = RecommendationService();
  factory RecommendationService.instance() => _instance;

  CollectionReference<Map<String, dynamic>> _recommendationsRef(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('recommendations');
  }

  Stream<List<Recommendation>> recommendationsStream(
    String userId, {
    int limit = 20,
  }) {
    return _recommendationsRef(userId)
        .where('isActive', isEqualTo: true)
        .orderBy('score', descending: true)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Recommendation.fromFirestore(doc))
              .where((rec) => !rec.isExpired)
              .toList(),
        );
  }

  Future<List<Recommendation>> getRecommendationsOnce(
    String userId, {
    int limit = 20,
  }) async {
    try {
      final query = await _recommendationsRef(userId)
          .where('isActive', isEqualTo: true)
          .orderBy('score', descending: true)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return query.docs
          .map((doc) => Recommendation.fromFirestore(doc))
          .where((rec) => !rec.isExpired)
          .toList();
    } catch (e) {
      debugPrint('RecommendationService.getRecommendationsOnce error: $e');
      return [];
    }
  }

  Future<void> createRecommendation(
    String userId,
    Recommendation recommendation,
  ) async {
    try {
      await _recommendationsRef(userId)
          .doc(recommendation.id)
          .set(recommendation.toFirestore(), SetOptions(merge: true));
    } catch (e) {
      debugPrint('RecommendationService.createRecommendation error: $e');
      rethrow;
    }
  }

  Future<void> markRecommendationInteracted(
    String userId,
    String recommendationId,
  ) async {
    try {
      await _recommendationsRef(userId).doc(recommendationId).set({
        'metadata': {'interactedAt': Timestamp.fromDate(DateTime.now())},
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint(
        'RecommendationService.markRecommendationInteracted error: $e',
      );
    }
  }

  /// Rebuild all recommendations for the user.
  ///
  /// v8.6 (MED 7): delegates to the server-side `refreshRecommendations`
  /// callable, which is the single writer of
  /// `users/{uid}/recommendations/{id}`. The authenticated uid comes from
  /// Firebase Auth on the server — the client never passes a userId and
  /// never writes recommendation documents itself, so the two competing
  /// engines can no longer clobber each other.
  Future<void> refreshRecommendations({
    required String userId,
    required dynamic profile,
  }) async {
    try {
      final callable = _functions.httpsCallable(
        'refreshRecommendations',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 30)),
      );
      await callable.call<Map<String, dynamic>>(<String, dynamic>{});

      debugPrint(
        'RecommendationService: server regenerated recommendations for $userId',
      );
    } catch (e) {
      debugPrint('RecommendationService.refreshRecommendations error: $e');
      rethrow;
    }
  }
}

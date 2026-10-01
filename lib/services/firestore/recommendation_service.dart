import 'package:campusconnect/models/recommendation.dart';
import 'package:campusconnect/services/recommendations/recommendation_fingerprint.dart';
import 'package:campusconnect/utilities/refresh_dedupe.dart';
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

  /// v9.2.2 (§2): end-to-end de-duplication for recommendation regeneration.
  /// Concurrent callers for the same user share ONE in-flight refresh, and a
  /// repeat call for an unchanged profile fingerprint is skipped entirely —
  /// so a fresh set is never regenerated merely because a widget/provider
  /// rebuilt. Reset on logout via [resetRefreshState].
  final RefreshDedupe _refreshGate = RefreshDedupe();

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

  // v9.2 audit (SEC-2): `createRecommendation` was REMOVED — the server
  // `recommendations/engine.js` is the single writer of recommendation
  // documents and `firestore.rules` now denies client create/delete
  // (`allow create, delete: if false`). The method had no callers. Only
  // interaction tracking (`markRecommendationInteracted`) remains, which the
  // rules narrow to the `metadata` key so a client can never forge a score.
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
    bool force = false,
    String reason = 'unspecified',
  }) async {
    // v9.2.2 (§2 — refresh deduplication):
    //  1. CONCURRENCY — if a refresh for this user is already in flight, await
    //     it instead of starting a second server regeneration.
    //  2. FRESHNESS — if this exact profile fingerprint was already refreshed
    //     successfully and is still fresh, skip: an unchanged state must not
    //     be regenerated just because a widget/provider rebuilt. A `force`
    //     (explicit user action) always runs.
    final fingerprint = recommendationFingerprint(profile);

    final inFlight = _refreshGate.inFlightFor(userId);
    if (inFlight != null) {
      debugPrint(
        'RecommendationService: joining in-flight refresh for $userId '
        '(reason=$reason)',
      );
      await inFlight;
      return;
    }

    if (!_refreshGate.shouldRun(userId, fingerprint, force: force)) {
      debugPrint(
        'RecommendationService: refresh deduplicated for $userId '
        '(reason=$reason, fingerprint unchanged — cache hit, no server call)',
      );
      return;
    }

    final future = _invokeRefresh(userId, reason);
    _refreshGate.begin(userId, future);
    try {
      await future;
      _refreshGate.record(userId, fingerprint);
    } catch (e) {
      debugPrint('RecommendationService.refreshRecommendations error: $e');
      rethrow;
    }
  }

  /// Invoke the `refreshRecommendations` callable and log the outcome.
  ///
  /// v8.9.3 (R6): the server callable allows 120 s (AI explanation enrichment
  /// runs the Groq 30 s → HF 60 s fallback chain, up to ~90 s). The previous
  /// 30 s CLIENT timeout could abort the call and surface an error in the UI
  /// while the server kept writing — making a healthy refresh look broken.
  /// Match the server ceiling.
  Future<void> _invokeRefresh(String userId, String reason) async {
    final stopwatch = Stopwatch()..start();
    final callable = _functions.httpsCallable(
      'refreshRecommendations',
      options: HttpsCallableOptions(timeout: const Duration(seconds: 120)),
    );
    await callable.call<Map<String, dynamic>>(<String, dynamic>{});
    stopwatch.stop();

    debugPrint(
      'RecommendationService: server regenerated recommendations for $userId '
      '(${stopwatch.elapsedMilliseconds}ms, reason=$reason)',
    );
  }

  /// v9.2.2 (§2): drop the client refresh de-duplication state on logout so a
  /// new session always refreshes once and an in-flight result can never leak
  /// across accounts.
  void resetRefreshState() => _refreshGate.invalidate();
}

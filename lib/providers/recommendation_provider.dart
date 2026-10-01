import 'dart:async';

import 'package:campusconnect/models/recommendation.dart';
import 'package:campusconnect/models/student_profile.dart';
import 'package:campusconnect/services/firestore/recommendation_service.dart';
import 'package:flutter/foundation.dart';

class RecommendationProvider extends ChangeNotifier {
  final RecommendationService _service;

  RecommendationProvider({RecommendationService? service})
    : _service = service ?? RecommendationService.instance();

  List<Recommendation> _recommendations = [];
  String? _userId;
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _error;
  bool _isDisposed = false;
  StreamSubscription<List<Recommendation>>? _subscription;

  /// v9.2.2 (§2): true while `initWithUser` is still running for `_userId`. A
  /// second call for the SAME user inside that window returns immediately —
  /// preventing a duplicate stream subscription. The server call itself is
  /// additionally collapsed by `RecommendationService`'s `RefreshDedupe` gate.
  bool _initInFlight = false;

  List<Recommendation> get recommendations => _recommendations;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get error => _error;

  List<Recommendation> get mentorRecommendations => _recommendations
      .where((r) => r.type == RecommendationType.mentor)
      .toList();
  List<Recommendation> get jobRecommendations =>
      _recommendations.where((r) => r.type == RecommendationType.job).toList();
  List<Recommendation> get chatRecommendations =>
      _recommendations.where((r) => r.type == RecommendationType.chat).toList();

  Future<void> initWithUser(String userId, StudentProfile profile) async {
    if (_isInitialized && _userId == userId) return;
    // v9.2.2 (§2): a second init for the SAME user while the first is still
    // in flight must not re-subscribe the stream. `_isInitialized` only flips
    // once the first stream snapshot arrives, so without this guard a rebuild
    // in that window re-entered the whole method — the duplicate-refresh
    // window described in the v9.2.2 investigation report.
    if (_initInFlight && _userId == userId) return;

    _initInFlight = true;
    _userId = userId;
    _isDisposed = false;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _subscription?.cancel();
      _subscription = _service
          .recommendationsStream(userId)
          .listen(
            (items) {
              if (_isDisposed) return;
              _recommendations = items;
              _isLoading = false;
              _isInitialized = true;
              _error = null;
              notifyListeners();
            },
            onError: (error) {
              if (_isDisposed) return;
              _error = 'Failed to load recommendations';
              _isLoading = false;
              notifyListeners();
            },
          );

      // v9.2.2 (§2): the refresh is de-duplicated end-to-end inside the service
      // (shared in-flight future + profile-fingerprint skip). `reason` records
      // WHY for the diagnostics.
      await _service.refreshRecommendations(
        userId: userId,
        profile: profile,
        reason: 'init',
      );
    } catch (e) {
      if (_isDisposed) return;
      _isLoading = false;
      _error = 'Failed to initialize recommendations';
      debugPrint('RecommendationProvider.initWithUser error: $e');
      notifyListeners();
    } finally {
      _initInFlight = false;
    }
  }

  Future<void> refresh(StudentProfile profile) async {
    if (_userId == null || _isDisposed) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // v9.2.2 (§2): an EXPLICIT user refresh always runs (`force`) — the
      // deduplication only suppresses implicit duplicates (rebuilds,
      // concurrent callers), never a deliberate tap.
      await _service.refreshRecommendations(
        userId: _userId!,
        profile: profile,
        force: true,
        reason: 'manual',
      );
      _error = null;
    } catch (e) {
      _error = 'Failed to refresh recommendations';
      debugPrint('RecommendationProvider.refresh error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> markInteracted(String recommendationId) async {
    if (_userId == null || _isDisposed) return;
    await _service.markRecommendationInteracted(_userId!, recommendationId);
  }

  void reset() {
    _isDisposed = true;
    _subscription?.cancel();
    _subscription = null;
    _recommendations = [];
    _userId = null;
    _isLoading = false;
    _isInitialized = false;
    _error = null;
    _initInFlight = false;
    // v9.2.2 (§2): clear the client refresh de-duplication state so a
    // re-login always refreshes once and no stale fingerprint survives the
    // session boundary.
    _service.resetRefreshState();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _subscription?.cancel();
    super.dispose();
  }
}

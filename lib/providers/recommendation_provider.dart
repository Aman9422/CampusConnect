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

      await _service.refreshRecommendations(userId: userId, profile: profile);
    } catch (e) {
      if (_isDisposed) return;
      _isLoading = false;
      _error = 'Failed to initialize recommendations';
      debugPrint('RecommendationProvider.initWithUser error: $e');
      notifyListeners();
    }
  }

  Future<void> refresh(StudentProfile profile) async {
    if (_userId == null || _isDisposed) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _service.refreshRecommendations(userId: _userId!, profile: profile);
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
  }

  @override
  void dispose() {
    _isDisposed = true;
    _subscription?.cancel();
    super.dispose();
  }
}

import 'dart:async';

import 'package:campusconnect/models/badge.dart';
import 'package:campusconnect/models/student_profile.dart';
import 'package:campusconnect/models/user_activity.dart';
import 'package:campusconnect/services/firestore/engagement_service.dart';
import 'package:flutter/foundation.dart';

class EngagementProvider extends ChangeNotifier {
  final EngagementService _service;

  EngagementProvider({EngagementService? service})
    : _service = service ?? EngagementService.instance();

  String? _userId;
  StudentProfile? _profile;
  bool _isLoading = false;
  bool _isInitialized = false;
  String? _error;
  bool _isDisposed = false;
  StreamSubscription<Map<String, dynamic>>? _summarySubscription;

  Map<String, dynamic> _summary = {
    'engagementScore': 0,
    'profileStrength': 0,
    'dailyStreak': 0,
    'activityPoints': 0,
    'badges': <Map<String, dynamic>>[],
  };

  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  String? get error => _error;
  int get engagementScore => (_summary['engagementScore'] as num? ?? 0).round();
  int get profileStrength => (_summary['profileStrength'] as num? ?? 0).round();
  int get dailyStreak => (_summary['dailyStreak'] as int? ?? 0);
  int get activityPoints => (_summary['activityPoints'] as int? ?? 0);

  List<Badge> get badges {
    final raw = (_summary['badges'] as List<dynamic>? ?? const <dynamic>[]);
    return raw
        .whereType<Map<String, dynamic>>()
        .map(
          (map) => Badge.fromMap(
            map['id'] as String? ?? map['type'] as String? ?? '',
            map,
          ),
        )
        .toList();
  }

  Future<void> initWithUser(String userId, StudentProfile profile) async {
    if (_isInitialized && _userId == userId) return;

    _userId = userId;
    _profile = profile;
    _isDisposed = false;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _summarySubscription?.cancel();
      _summarySubscription = _service
          .engagementSummaryStream(userId)
          .listen(
            (summary) {
              if (_isDisposed) return;
              _summary = summary;
              _isLoading = false;
              _isInitialized = true;
              _error = null;
              notifyListeners();
            },
            onError: (error) {
              if (_isDisposed) return;
              _error = 'Failed to stream engagement data';
              _isLoading = false;
              notifyListeners();
            },
          );

      await _service.recomputeEngagement(userId: userId, profile: profile);
    } catch (e) {
      if (_isDisposed) return;
      _isLoading = false;
      _error = 'Failed to initialize engagement';
      debugPrint('EngagementProvider.initWithUser error: $e');
      notifyListeners();
    }
  }

  Future<void> refresh({StudentProfile? profile}) async {
    if (_userId == null || _isDisposed) return;

    if (profile != null) {
      _profile = profile;
    }
    if (_profile == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _summary = await _service.recomputeEngagement(
        userId: _userId!,
        profile: _profile!,
      );
      _error = null;
    } catch (e) {
      _error = 'Failed to recompute engagement';
      debugPrint('EngagementProvider.refresh error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> trackActivity({
    required ActivityEventType eventType,
    int points = 1,
    String? sourceId,
    Map<String, dynamic>? metadata,
  }) async {
    if (_userId == null || _isDisposed) return;
    await _service.logActivity(
      userId: _userId!,
      eventType: eventType,
      points: points,
      sourceId: sourceId,
      metadata: metadata,
    );
  }

  void reset() {
    _isDisposed = true;
    _summarySubscription?.cancel();
    _summarySubscription = null;
    _userId = null;
    _profile = null;
    _isLoading = false;
    _isInitialized = false;
    _error = null;
    _summary = {
      'engagementScore': 0,
      'profileStrength': 0,
      'dailyStreak': 0,
      'activityPoints': 0,
      'badges': <Map<String, dynamic>>[],
    };
  }

  @override
  void dispose() {
    _isDisposed = true;
    _summarySubscription?.cancel();
    super.dispose();
  }
}

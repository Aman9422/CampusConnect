import 'dart:async';

import 'package:campusconnect/models/badge.dart';
import 'package:campusconnect/services/firestore/engagement_service.dart';
import 'package:flutter/foundation.dart';

/// v7.4: Engagement provider.
///
/// v9.2 audit (BUG-2): this provider is now a pure READ projection of the
/// server-owned `users/{uid}/engagement_summary/summary` document. It no
/// longer recomputes anything on the client — the server's `logUserActivity`
/// (aggregates) + `recomputeEngagementSummary` (score/badges) are the sole
/// writers, so the score, streak and badges can no longer flicker between two
/// divergent engines and every login no longer costs up to 200 activity reads
/// plus a summary write.
///
/// v9.2 audit (BUG-10): the dead `trackActivity` method (which had no callers
/// and would have been rule-denied for any event other than the removed
/// client `resumeReviewed` write) has been deleted — all activity/points flow
/// through the server's `logUserActivity`.
class EngagementProvider extends ChangeNotifier {
  final EngagementService _service;

  EngagementProvider({EngagementService? service})
    : _service = service ?? EngagementService.instance();

  String? _userId;
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

  /// Start streaming the server-owned engagement summary for [userId].
  Future<void> initWithUser(String userId) async {
    if (_isInitialized && _userId == userId) return;

    _userId = userId;
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
    } catch (e) {
      if (_isDisposed) return;
      _isLoading = false;
      _error = 'Failed to initialize engagement';
      debugPrint('EngagementProvider.initWithUser error: $e');
      notifyListeners();
    }
  }

  /// Pull-to-refresh: take a fresh one-shot read of the server summary.
  ///
  /// The live stream already delivers updates, so this is only a manual
  /// refresh affordance — it performs no computation and writes nothing.
  Future<void> refresh() async {
    final userId = _userId;
    if (userId == null || _isDisposed) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _summary = await _service.getEngagementSummary(userId);
      _error = null;
    } catch (e) {
      _error = 'Failed to refresh engagement';
      debugPrint('EngagementProvider.refresh error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void reset() {
    _isDisposed = true;
    _summarySubscription?.cancel();
    _summarySubscription = null;
    _userId = null;
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

import 'dart:async';

import 'package:campusconnect/services/ai/ai_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// V5.1.1+: Centralized AI usage state with proper lifecycle
/// Tracks trial status, quota, usage, and network connectivity
class AIUsageProvider with ChangeNotifier {
  String? userId; // V5.1.1: Made nullable for logout handling
  final Connectivity _connectivity = Connectivity();
  final FirebaseFirestore _firestore;

  /// v8.8.3 (MED-1): the subscription is retained so it can be cancelled on
  /// reset()/dispose() — the old code leaked it on every init (M5 pattern).
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  AIUsageProvider({
    required AIService aiService,
    this.userId,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  // State
  bool _isInTrial = false;
  int _daysRemainingInTrial = 0;
  int _messagesUsedToday = 0;
  int _dailyLimit = 50;
  bool _isLoading = false;
  String? _error;
  bool _isOnline = true; // V5.1.x: Network state

  // V6.3: Flag to stop operations after logout
  bool _isDisposed = false;

  // Getters
  bool get isInTrial => _isInTrial;
  int get daysRemainingInTrial => _daysRemainingInTrial;
  int get messagesUsedToday => _messagesUsedToday;
  int get dailyLimit => _dailyLimit;
  int get messagesRemaining => dailyLimit - messagesUsedToday;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasReachedLimit => messagesUsedToday >= dailyLimit;
  bool get isOnline => _isOnline; // V5.1.x: Expose network state

  /// V5.1.1: Initialize with user ID (called after login)
  Future<void> initWithUser(String newUserId) async {
    userId = newUserId;
    await init();
  }

  /// V5.1.1: Reset state (called on logout)
  void reset() {
    _isDisposed = true; // V6.3: Mark as disposed first
    // v8.8.3 (MED-1): cancel the connectivity subscription so no listener
    // survives logout (prevents leaks + duplicate notifyListeners on the
    // next login) — M5 pattern.
    _cancelConnectivityMonitoring();
    userId = null;
    _isInTrial = false;
    _daysRemainingInTrial = 0;
    _messagesUsedToday = 0;
    _dailyLimit = 50;
    _isLoading = false;
    _error = null;
    _isOnline = true;
    // Don't notify after dispose
  }

  /// V6.3: Safe notify that checks disposed state
  void _safeNotify() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  /// Initialize: Load AI usage data from Firestore.
  ///
  /// v8.8.3 (MED-2): reads the REAL trial/usage documents instead of the old
  /// hardcoded stub (which always showed "trial active, 5 days, 0/50 used"
  /// until the first message). The `askAI` Cloud Function writes:
  ///   - users/{uid}           → aiTrialStartedAt / aiTrialExpiresAt
  ///   - ai_usage/{uid}        → dailyCount / lastResetAt
  /// (both readable owner-side under firestore.rules). Failures fall back to
  /// neutral defaults without blocking the UI.
  Future<void> init() async {
    if (userId == null) {
      debugPrint('Cannot init AIUsageProvider: userId is null');
      return;
    }

    _isDisposed = false; // V6.3: Reset on init

    // V5.1.x: Start monitoring network connectivity
    _startConnectivityMonitoring();

    _isLoading = true;
    _error = null;
    _safeNotify();

    try {
      final uid = userId!;
      final firestore = _firestore;

      final results = await Future.wait([
        firestore.collection('users').doc(uid).get(),
        firestore.collection('ai_usage').doc(uid).get(),
      ]);

      final userDoc = results[0];
      final usageDoc = results[1];

      // --- Trial state (server-managed via manageUserTrial) ---
      // `aiTrialStartedAt` / `aiTrialExpiresAt` are written by the askAI
      // server path; only the expiry drives the client banner.
      final userData = userDoc.data();
      final trialExpiresAt = _tsMillis(userData?['aiTrialExpiresAt']);
      final nowMillis = DateTime.now().millisecondsSinceEpoch;

      if (trialExpiresAt != null) {
        _isInTrial = trialExpiresAt > nowMillis;
        _daysRemainingInTrial = _isInTrial
            ? ((trialExpiresAt - nowMillis) / Duration.millisecondsPerDay)
                  .ceil()
                  .clamp(0, 365)
            : 0;
      } else {
        // Trial has never started (no server doc yet) → default to active
        // (matches the server's 5-day-on-first-use behavior).
        _isInTrial = true;
        _daysRemainingInTrial = 5;
      }

      // --- Usage (server-managed via trackUsage) ---
      final usageData = usageDoc.data();
      _messagesUsedToday = (usageData?['dailyCount'] as num?)?.toInt() ?? 0;
      _dailyLimit = 50; // DAILY_MESSAGE_LIMIT on the server.
      _error = null;
    } catch (e) {
      _error = 'Failed to load AI usage data';
      debugPrint('AIUsageProvider init error: $e');
    } finally {
      _isLoading = false;
      _safeNotify();
    }
  }

  /// Extract a millisecond timestamp from a Firestore Timestamp / DateTime /
  /// ISO string / num — tolerant of any shape the server may have written.
  int? _tsMillis(Object? value) {
    if (value == null) return null;
    if (value is Timestamp) return value.millisecondsSinceEpoch;
    if (value is DateTime) return value.millisecondsSinceEpoch;
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = DateTime.tryParse(value);
      return parsed?.millisecondsSinceEpoch;
    }
    return null;
  }

  /// V5.1.x: Monitor network connectivity changes
  /// v8.8.3 (MED-1): the subscription is retained so reset()/dispose() can
  /// cancel it; the callback guards with [_isDisposed] so it never notifies
  /// listeners after logout/provider disposal (M5 pattern).
  void _startConnectivityMonitoring() {
    if (_connectivitySubscription != null) return; // Already listening.
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((
      result,
    ) {
      if (_isDisposed) return; // No notify after dispose.
      final wasOnline = _isOnline;
      _isOnline = !result.contains(ConnectivityResult.none);

      if (wasOnline != _isOnline) {
        debugPrint(
          'AIUsageProvider: Network state changed to ${_isOnline ? "online" : "offline"}',
        );
        _safeNotify();
      }
    });
  }

  /// v8.8.3 (MED-1): cancel the connectivity subscription and clear the
  /// reference so it can be re-established on the next [initWithUser].
  void _cancelConnectivityMonitoring() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
  }

  /// Update usage after sending a message
  void incrementUsage() {
    _messagesUsedToday++;
    _safeNotify();
  }

  /// Update trial info from AI response
  void updateTrialInfo({required bool isInTrial, required int daysRemaining}) {
    _isInTrial = isInTrial;
    _daysRemainingInTrial = daysRemaining;
    _safeNotify();
  }

  /// Update usage info from AI response
  void updateUsageInfo({required int messagesUsed, required int dailyLimit}) {
    _messagesUsedToday = messagesUsed;
    _dailyLimit = dailyLimit;
    _safeNotify();
  }

  @override
  void dispose() {
    // v8.8.3 (MED-1): cancel the connectivity subscription to prevent leaks
    // when the provider is disposed (e.g. app teardown) — M5 pattern.
    _isDisposed = true;
    _cancelConnectivityMonitoring();
    super.dispose();
  }
}

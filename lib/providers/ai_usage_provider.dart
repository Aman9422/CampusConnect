import 'package:campusconnect/services/ai/ai_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// V5.1.1+: Centralized AI usage state with proper lifecycle
/// Tracks trial status, quota, usage, and network connectivity
class AIUsageProvider with ChangeNotifier {
  String? userId; // V5.1.1: Made nullable for logout handling
  final Connectivity _connectivity = Connectivity();

  AIUsageProvider({required AIService aiService, this.userId});

  // State
  bool _isInTrial = false;
  int _daysRemainingInTrial = 0;
  int _messagesUsedToday = 0;
  int _dailyLimit = 50;
  bool _isLoading = false;
  String? _error;
  bool _isOnline = true; // V5.1.x: Network state

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

  // V6.3: Flag to stop operations after logout
  bool _isDisposed = false;

  /// V6.3: Safe notify that checks disposed state
  void _safeNotify() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  /// Initialize: Load AI usage data
  /// V5.1.x: Enhanced with network connectivity monitoring
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
      // In V5, we'll fetch usage data from backend
      // For now, set defaults
      _isInTrial = true;
      _daysRemainingInTrial = 5;
      _messagesUsedToday = 0;
      _dailyLimit = 50;
      _error = null;
    } catch (e) {
      _error = 'Failed to load AI usage data';
      debugPrint('AIUsageProvider init error: $e');
    } finally {
      _isLoading = false;
      _safeNotify();
    }
  }

  /// V5.1.x: Monitor network connectivity changes
  void _startConnectivityMonitoring() {
    _connectivity.onConnectivityChanged.listen((result) {
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
}

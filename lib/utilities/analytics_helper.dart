import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';

/// V5.1: Lightweight analytics tracking utility
/// Tracks key events without requiring UI changes
class AnalyticsHelper {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  /// Log placement application success
  static Future<void> logPlacementApplySuccess({
    required String placementId,
    required String company,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'placement_apply_success',
        parameters: {
          'placement_id': placementId,
          'company': company,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      debugPrint('Analytics: placement_apply_success - $placementId');
    } catch (e) {
      debugPrint('Analytics error: $e');
    }
  }

  /// Log placement application failure
  static Future<void> logPlacementApplyFailure({
    required String placementId,
    required String company,
    required String errorReason,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'placement_apply_failure',
        parameters: {
          'placement_id': placementId,
          'company': company,
          'error_reason': errorReason,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      debugPrint('Analytics: placement_apply_failure - $errorReason');
    } catch (e) {
      debugPrint('Analytics error: $e');
    }
  }

  /// Log AI daily limit reached
  static Future<void> logAIDailyLimitReached({
    required String userId,
    required int messagesUsed,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'ai_daily_limit_reached',
        parameters: {
          'user_id': userId,
          'messages_used': messagesUsed,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      debugPrint('Analytics: ai_daily_limit_reached - $messagesUsed messages');
    } catch (e) {
      debugPrint('Analytics error: $e');
    }
  }

  /// Log trial warning shown
  static Future<void> logTrialWarningShown({
    required String userId,
    required int daysRemaining,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'trial_warning_shown',
        parameters: {
          'user_id': userId,
          'days_remaining': daysRemaining,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
      debugPrint('Analytics: trial_warning_shown - $daysRemaining days left');
    } catch (e) {
      debugPrint('Analytics error: $e');
    }
  }

  /// Log offline mode activated
  static Future<void> logOfflineModeActivated() async {
    try {
      await _analytics.logEvent(
        name: 'offline_mode_activated',
        parameters: {'timestamp': DateTime.now().toIso8601String()},
      );
      debugPrint('Analytics: offline_mode_activated');
    } catch (e) {
      debugPrint('Analytics error: $e');
    }
  }

  /// Log screen view
  static Future<void> logScreenView(String screenName) async {
    try {
      await _analytics.logScreenView(screenName: screenName);
      debugPrint('Analytics: screen_view - $screenName');
    } catch (e) {
      debugPrint('Analytics error: $e');
    }
  }
}

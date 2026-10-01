import 'package:campusconnect/enums/user_role.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// EngagementService - v7.4 gamification and engagement scoring
///
/// Data layout:
/// - users/{uid}/activities/{activityId}          (server-written)
/// - users/{uid}/engagement_summary/summary       (server-written)
///
/// v9.2 audit (BUG-2 — "Engagement has two writers with divergent
/// algorithms"): the SERVER is now the single writer of the engagement
/// summary. `functions/helpers/shared.js#logUserActivity` maintains the
/// materialized aggregates (`activityPoints`/`dailyStreak`/
/// `streakLastActiveKey`/`lastActiveAt`) and `recomputeEngagementSummary`
/// (daily scheduler + the profile/resume-review triggers) rewrites the
/// score/badges from those aggregates.
///
/// The client previously ran its own `recomputeEngagement` on every login,
/// summing the newest 200 `activities` docs (double-counting the redundant
/// client `resumeReviewed` write) and bucketing streaks by LOCAL calendar
/// days while the server uses UTC — so the two engines disagreed by ~2×
/// points and ±1 streak, the score/badges flickered between writers, and
/// every login cost up to 200 reads + 1 write. That method (and the
/// client-only `logActivity`) has been removed; this service is now a
/// READ-ONLY projection of the server-owned summary.
class EngagementService {
  final FirebaseFirestore _firestore;

  EngagementService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static final EngagementService _instance = EngagementService();
  factory EngagementService.instance() => _instance;

  /// v8.7.1: role-aware label for the activity badge.
  ///
  /// Alumni see "Active Alumni" — "Active Student" is a Student-flavored title
  /// and mismatched on the Alumni dashboard. Kept as a shared helper for UI
  /// labels; the badge TITLES themselves now come from the server summary.
  static String activeBadgeTitle(UserRole role) {
    return role == UserRole.alumni ? 'Active Alumni' : 'Active Student';
  }

  DocumentReference<Map<String, dynamic>> _summaryRef(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('engagement_summary')
        .doc('summary');
  }

  /// Live stream of the server-owned engagement summary.
  ///
  /// Emits the default (zeroed) summary when the server has not written the
  /// document yet — a brand-new account whose profile trigger has not fired.
  Stream<Map<String, dynamic>> engagementSummaryStream(String userId) {
    return _summaryRef(userId).snapshots().map((doc) {
      final data = doc.data();
      if (data == null) return _defaultSummary();
      return data;
    });
  }

  /// One-shot read of the server-owned engagement summary.
  ///
  /// Used by pull-to-refresh; returns the default summary on any error so the
  /// UI never has to special-case a missing document.
  Future<Map<String, dynamic>> getEngagementSummary(String userId) async {
    try {
      final doc = await _summaryRef(userId).get();
      if (!doc.exists || doc.data() == null) {
        return _defaultSummary();
      }
      return doc.data()!;
    } catch (e) {
      debugPrint('EngagementService.getEngagementSummary error: $e');
      return _defaultSummary();
    }
  }

  Map<String, dynamic> _defaultSummary() {
    return {
      'engagementScore': 0,
      'profileStrength': 0,
      'dailyStreak': 0,
      'activityPoints': 0,
      'badges': const <Map<String, dynamic>>[],
    };
  }
}

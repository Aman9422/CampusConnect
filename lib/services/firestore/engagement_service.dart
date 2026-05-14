import 'dart:math';

import 'package:campusconnect/models/badge.dart';
import 'package:campusconnect/models/student_profile.dart';
import 'package:campusconnect/models/user_activity.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// EngagementService - v7.4 gamification and engagement scoring
///
/// Data layout:
/// - users/{uid}/activities/{activityId}
/// - users/{uid}/engagement_summary/summary
class EngagementService {
  final FirebaseFirestore _firestore;

  EngagementService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static final EngagementService _instance = EngagementService();
  factory EngagementService.instance() => _instance;

  CollectionReference<Map<String, dynamic>> _activitiesRef(String userId) {
    return _firestore.collection('users').doc(userId).collection('activities');
  }

  DocumentReference<Map<String, dynamic>> _summaryRef(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('engagement_summary')
        .doc('summary');
  }

  Future<void> logActivity({
    required String userId,
    required ActivityEventType eventType,
    int points = 1,
    String? sourceId,
    Map<String, dynamic>? metadata,
  }) async {
    final activity = UserActivity(
      id: '',
      userId: userId,
      eventType: eventType,
      points: points,
      sourceId: sourceId,
      occurredAt: DateTime.now(),
      metadata: metadata,
    );

    try {
      await _activitiesRef(userId).add(activity.toFirestore());
    } catch (e) {
      debugPrint('EngagementService.logActivity error: $e');
    }
  }

  Stream<Map<String, dynamic>> engagementSummaryStream(String userId) {
    return _summaryRef(userId).snapshots().map((doc) {
      final data = doc.data();
      if (data == null) return _defaultSummary();
      return data;
    });
  }

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

  Future<Map<String, dynamic>> recomputeEngagement({
    required String userId,
    required StudentProfile profile,
  }) async {
    try {
      final activitiesSnapshot = await _activitiesRef(
        userId,
      ).orderBy('occurredAt', descending: true).limit(200).get();

      final activities = activitiesSnapshot.docs
          .map((doc) => UserActivity.fromFirestore(doc))
          .toList();

      final streakDays = _computeStreak(activities);
      final profileStrength = _computeProfileStrength(profile);
      final activityPoints = activities.fold<int>(
        0,
        (total, event) => total + max(0, event.points),
      );

      final engagementScore =
          (profileStrength * 0.6) +
          min(40, activityPoints * 0.4) +
          min(20, streakDays * 2.5);
      final normalizedScore = engagementScore.clamp(0, 100).round();

      final badges = _buildBadges(
        profileStrength: profileStrength.round(),
        streakDays: streakDays,
        activityPoints: activityPoints,
      );

      final summary = {
        'engagementScore': normalizedScore,
        'profileStrength': profileStrength.round(),
        'dailyStreak': streakDays,
        'activityPoints': activityPoints,
        'lastActiveAt': activities.isEmpty
            ? null
            : Timestamp.fromDate(activities.first.occurredAt),
        'badges': badges.map((b) => b.toMap()).toList(),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      };

      await _summaryRef(userId).set(summary, SetOptions(merge: true));
      return summary;
    } catch (e) {
      debugPrint('EngagementService.recomputeEngagement error: $e');
      rethrow;
    }
  }

  int _computeStreak(List<UserActivity> activities) {
    if (activities.isEmpty) return 0;

    final uniqueDays =
        activities
            .map((activity) {
              final date = activity.occurredAt;
              return DateTime(date.year, date.month, date.day);
            })
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));

    final today = DateTime.now();
    DateTime expected = DateTime(today.year, today.month, today.day);
    int streak = 0;

    for (final day in uniqueDays) {
      if (day == expected) {
        streak++;
        expected = expected.subtract(const Duration(days: 1));
      } else {
        break;
      }
    }

    return streak;
  }

  double _computeProfileStrength(StudentProfile profile) {
    int total = 12;
    int completed = 0;

    if (profile.personal.fullName.trim().isNotEmpty) completed++;
    if (profile.personal.phone.trim().isNotEmpty) completed++;
    if (profile.personal.bio.trim().isNotEmpty) completed++;
    if (profile.academic.college.trim().isNotEmpty) completed++;
    if (profile.academic.program.trim().isNotEmpty) completed++;
    if (profile.academic.year > 0) completed++;
    if (profile.academic.cgpa > 0) completed++;
    if ((profile.skills ?? const <String>[]).isNotEmpty) completed++;
    if ((profile.careerInterest ?? '').trim().isNotEmpty) completed++;
    if ((profile.company ?? '').trim().isNotEmpty) completed++;
    if ((profile.jobRole ?? '').trim().isNotEmpty) completed++;
    if ((profile.linkedinProfile ?? '').trim().isNotEmpty) completed++;

    return (completed / total) * 100;
  }

  List<Badge> _buildBadges({
    required int profileStrength,
    required int streakDays,
    required int activityPoints,
  }) {
    final now = DateTime.now();

    return [
      Badge(
        id: 'profile_pro',
        type: BadgeType.profilePro,
        title: 'Profile Pro',
        description: 'Complete your profile to unlock better recommendations.',
        icon: 'verified',
        progress: profileStrength,
        target: 100,
        earnedAt: profileStrength >= 85 ? now : null,
        isFeatured: true,
      ),
      Badge(
        id: 'consistency_champion',
        type: BadgeType.consistencyChampion,
        title: 'Consistency Champion',
        description: 'Stay active for 7 days.',
        icon: 'local_fire_department',
        progress: streakDays,
        target: 7,
        earnedAt: streakDays >= 7 ? now : null,
        isFeatured: true,
      ),
      Badge(
        id: 'active_student',
        type: BadgeType.activeStudent,
        title: 'Active Student',
        description: 'Earn 50 engagement points.',
        icon: 'school',
        progress: activityPoints,
        target: 50,
        earnedAt: activityPoints >= 50 ? now : null,
      ),
      Badge(
        id: 'networking_pro',
        type: BadgeType.networkingPro,
        title: 'Networking Pro',
        description: 'Build your mentorship and chat activity.',
        icon: 'groups',
        progress: min(100, activityPoints),
        target: 100,
        earnedAt: activityPoints >= 100 ? now : null,
      ),
    ];
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

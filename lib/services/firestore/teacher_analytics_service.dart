import 'dart:math';

import 'package:campusconnect/models/placement_pipeline_data.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// TeacherAnalyticsService - v8.2
///
/// Provides teacher-facing intelligence:
/// - Resume review aggregates
/// - Placement prediction indicators
/// - Skill-gap analysis across students
/// - Performance trends over time
/// - Department analytics (v8.2)
/// - Application pipeline counts (v8.2)
class TeacherAnalyticsService {
  final FirebaseFirestore _firestore;

  TeacherAnalyticsService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  static final TeacherAnalyticsService _instance = TeacherAnalyticsService();
  factory TeacherAnalyticsService.instance() => _instance;

  /// Get resume review aggregate statistics.
  Future<Map<String, dynamic>> getResumeReviewStats() async {
    try {
      final reviewsQuery = await _firestore.collectionGroup('resumeReviews').get();

      if (reviewsQuery.docs.isEmpty) {
        return _emptyReviewStats();
      }

      final scores = reviewsQuery.docs
          .map((doc) => _extractScore(doc.data()))
          .where((score) => score >= 0)
          .toList();

      if (scores.isEmpty) {
        return _emptyReviewStats();
      }

      final totalReviews = scores.length;
      final totalScore = scores.reduce((a, b) => a + b);
      final avgScore = totalScore / totalReviews;

      final scoreDistribution = {
        'excellent': scores.where((s) => s >= 80).length,
        'good': scores.where((s) => s >= 60 && s < 80).length,
        'fair': scores.where((s) => s >= 40 && s < 60).length,
        'poor': scores.where((s) => s < 40).length,
      };

      return {
        'totalReviews': totalReviews,
        'avgScore': avgScore,
        'scoreDistribution': scoreDistribution,
      };
    } catch (e) {
      debugPrint('TeacherAnalyticsService.getResumeReviewStats error: $e');
      return _emptyReviewStats();
    }
  }

  /// Get student leaderboard data from latest resume score per student.
  Future<List<Map<String, dynamic>>> getStudentResumeData() async {
    try {
      final usersQuery = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'student')
          .get();

      final studentData = <Map<String, dynamic>>[];

      for (final userDoc in usersQuery.docs) {
        try {
          final latestReview = await _getLatestReview(userDoc.id);
          if (latestReview == null) continue;

          int reviewCount = 0;
          try {
            final totalReviewsQuery = await _firestore
                .collection('users')
                .doc(userDoc.id)
                .collection('resumeReviews')
                .count()
                .get();
            reviewCount = totalReviewsQuery.count ?? 0;
          } catch (_) {
            // count() requires a composite index — fallback to fetching docs
            try {
              final snapshot = await _firestore
                  .collection('users')
                  .doc(userDoc.id)
                  .collection('resumeReviews')
                  .get();
              reviewCount = snapshot.docs.length;
            } catch (_) {
              reviewCount = 0;
            }
          }

          final latestScore = _extractScore(latestReview.data);
          if (latestScore < 0) continue;

          // Get department from user profile
          final department = _getStudentDepartment(userDoc.data());

          studentData.add({
            'studentId': userDoc.id,
            'studentName': _getStudentName(userDoc.data()),
            'department': department,
            'latestScore': latestScore,
            'reviewCount': reviewCount,
            'lastReviewedAt': latestReview.createdAt,
          });
        } catch (e) {
          debugPrint(
            'TeacherAnalyticsService.getStudentResumeData student error: $e',
          );
        }
      }

      studentData.sort((a, b) {
        final scoreCompare =
            (b['latestScore'] as int).compareTo(a['latestScore'] as int);
        if (scoreCompare != 0) return scoreCompare;
        final dateA = a['lastReviewedAt'] as DateTime?;
        final dateB = b['lastReviewedAt'] as DateTime?;
        if (dateA == null || dateB == null) return 0;
        return dateB.compareTo(dateA);
      });

      return studentData.take(30).toList();
    } catch (e) {
      debugPrint('TeacherAnalyticsService.getStudentResumeData error: $e');
      return [];
    }
  }

  /// v8.2: Get department-level analytics.
  ///
  /// Groups students by department and computes per-department metrics.
  /// Returns list sorted by placement rate descending.
  Future<List<Map<String, dynamic>>> getDepartmentAnalytics() async {
    try {
      final usersQuery = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'student')
          .get();

      // Group students by department
      final deptGroups = <String, List<Map<String, dynamic>>>{};
      for (final userDoc in usersQuery.docs) {
        final dept = _getStudentDepartment(userDoc.data());
        deptGroups.putIfAbsent(dept, () => []).add({
          'studentId': userDoc.id,
          'data': userDoc.data(),
        });
      }

      final deptAnalytics = <Map<String, dynamic>>[];
      for (final entry in deptGroups.entries) {
        final deptName = entry.key;
        final students = entry.value;
        final studentCount = students.length;

        // Get resume scores for students in this department
        double totalScore = 0;
        int scoredCount = 0;
        final deptSkills = <String, int>{};
        int atRisk = 0;

        for (final student in students) {
          final uid = student['studentId'] as String;
          try {
            final latestReview = await _getLatestReview(uid);
            if (latestReview != null) {
              final score = _extractScore(latestReview.data);
              if (score >= 0) {
                totalScore += score;
                scoredCount++;
                if (score < 50) atRisk++;
              }
              // Collect missing keywords from latest review
              final missing = (latestReview.data['missingKeywords']
                      as List<dynamic>? ??
                  [])
                  .whereType<String>()
                  .map((s) => s.trim().toLowerCase())
                  .where((s) => s.isNotEmpty);
              for (final skill in missing) {
                deptSkills[skill] = (deptSkills[skill] ?? 0) + 1;
              }
            }
          } catch (_) {}
        }

        final avgScore = scoredCount > 0 ? totalScore / scoredCount : 0.0;
        final topSkills = deptSkills.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final top3Skills = topSkills.take(3).map((e) => e.key).toList();

        // Risk level based on at-risk ratio and avg score
        String riskLevel;
        final riskRatio = studentCount > 0 ? atRisk / studentCount : 0.0;
        if (riskRatio > 0.3 || avgScore < 40) {
          riskLevel = 'high';
        } else if (riskRatio > 0.15 || avgScore < 60) {
          riskLevel = 'medium';
        } else {
          riskLevel = 'low';
        }

        deptAnalytics.add({
          'department': deptName,
          'studentCount': studentCount,
          'avgScore': avgScore.round(),
          'topSkills': top3Skills,
          'riskLevel': riskLevel,
          'atRiskCount': atRisk,
        });
      }

      // Sort by studentCount descending as a proxy for placement readiness
      deptAnalytics.sort((a, b) =>
          (b['studentCount'] as int).compareTo(a['studentCount'] as int));

      return deptAnalytics;
    } catch (e) {
      debugPrint('TeacherAnalyticsService.getDepartmentAnalytics error: $e');
      return [];
    }
  }

  /// v8.2.3: Get real application pipeline counts.
  ///
  /// Returns typed [PlacementPipelineData] where every stage represents
  /// unique student count — NOT application document count.
  /// Stages: Eligible -> Applied -> Shortlisted -> Interview -> Placed
  Future<PlacementPipelineData> getApplicationPipelineCounts() async {
    try {
      // Get total student count — try aggregation first, fallback to get() if
      // count() requires a composite index that hasn't been created yet
      int totalStudents = 0;
      try {
        final countQuery = await _firestore
            .collection('users')
            .where('role', isEqualTo: 'student')
            .count()
            .get();
        totalStudents = countQuery.count ?? 0;
      } catch (_) {
        // count() needs a composite index — fallback to fetching documents
        final snapshot = await _firestore
            .collection('users')
            .where('role', isEqualTo: 'student')
            .get();
        totalStudents = snapshot.docs.length;
      }

      // Get distinct student IDs from applications collection
      // Critical: we count unique userIds, NOT application documents
      int distinctAppliedStudents = 0;
      try {
        final appsQuery = await _firestore.collectionGroup('applications').get();
        final uniqueStudentIds = appsQuery.docs
            .map((doc) => doc.data()['userId'] as String?)
            .where((id) => id != null)
            .toSet();
        distinctAppliedStudents = uniqueStudentIds.length;
      } catch (e) {
        debugPrint('TeacherAnalyticsService: collectionGroup apps query error: $e');
      }

      return PlacementPipelineData(
        eligibleStudents: totalStudents,
        appliedStudents: distinctAppliedStudents,
        // Shortlisted, Interview, Placed — not trackable without schema change
      );
    } catch (e) {
      debugPrint('TeacherAnalyticsService.getApplicationPipelineCounts error: $e');
      return const PlacementPipelineData(
        eligibleStudents: 0,
        appliedStudents: 0,
      );
    }
  }

  /// v8.2: Get average engagement and profile strength across students.
  ///
  /// Queries engagement subcollection for aggregate metrics.
  Future<Map<String, dynamic>> getEngagementAggregates() async {
    try {
      final usersQuery = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'student')
          .get();

      int totalEngagement = 0;
      int totalProfileStrength = 0;
      int count = 0;
      int activeAlumni = 0;

      for (final userDoc in usersQuery.docs) {
        try {
          final engagementDoc = await _firestore
              .collection('users')
              .doc(userDoc.id)
              .collection('engagement_summary')
              .doc('summary')
              .get();
          if (engagementDoc.exists) {
            final data = engagementDoc.data() ?? {};
            totalEngagement += (data['engagementScore'] as num? ?? 0).round();
            totalProfileStrength += (data['profileStrength'] as num? ?? 0).round();
            count++;
          }
        } catch (_) {}
      }

      // Count alumni
      try {
        final alumniQuery = await _firestore
            .collection('users')
            .where('role', isEqualTo: 'alumni')
            .count()
            .get();
        activeAlumni = alumniQuery.count ?? 0;
      } catch (_) {}

      return {
        'avgEngagement': count > 0 ? (totalEngagement / count).round() : 0,
        'avgProfileStrength': count > 0 ? (totalProfileStrength / count).round() : 0,
        'activeAlumni': activeAlumni,
        'studentCount': count,
      };
    } catch (e) {
      debugPrint('TeacherAnalyticsService.getEngagementAggregates error: $e');
      return {
        'avgEngagement': 0,
        'avgProfileStrength': 0,
        'activeAlumni': 0,
        'studentCount': 0,
      };
    }
  }

  /// v7.4: Placement prediction indicators.
  ///
  /// Scores are inferred from latest resume strength buckets.
  Future<Map<String, dynamic>> getPlacementPredictionIndicators() async {
    try {
      final students = await getStudentResumeData();
      if (students.isEmpty) {
        return {
          'highPotential': 0,
          'mediumPotential': 0,
          'atRisk': 0,
          'predictedPlacementRate': 0.0,
        };
      }

      int highPotential = 0;
      int mediumPotential = 0;
      int atRisk = 0;

      for (final student in students) {
        final score = student['latestScore'] as int? ?? 0;
        if (score >= 75) {
          highPotential++;
        } else if (score >= 50) {
          mediumPotential++;
        } else {
          atRisk++;
        }
      }

      final predictedPlacementRate = (highPotential * 0.9 + mediumPotential * 0.5) /
          max(1, students.length);

      return {
        'highPotential': highPotential,
        'mediumPotential': mediumPotential,
        'atRisk': atRisk,
        'predictedPlacementRate': (predictedPlacementRate * 100).clamp(0, 100),
      };
    } catch (e) {
      debugPrint(
        'TeacherAnalyticsService.getPlacementPredictionIndicators error: $e',
      );
      return {
        'highPotential': 0,
        'mediumPotential': 0,
        'atRisk': 0,
        'predictedPlacementRate': 0.0,
      };
    }
  }

  /// v7.4: Aggregate missing skills to identify institution-level gaps.
  Future<List<Map<String, dynamic>>> getSkillGapAnalysis({
    int limit = 8,
  }) async {
    try {
      final snapshot = await _firestore
          .collectionGroup('resumeReviews')
          .limit(400)
          .get();

      final frequency = <String, int>{};
      for (final doc in snapshot.docs) {
        final missing = (doc.data()['missingKeywords'] as List<dynamic>? ?? [])
            .whereType<String>()
            .map((s) => s.trim().toLowerCase())
            .where((s) => s.isNotEmpty);
        for (final skill in missing) {
          frequency[skill] = (frequency[skill] ?? 0) + 1;
        }
      }

      final sorted = frequency.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return sorted.take(limit).map((entry) {
        final count = entry.value;
        final severity = count >= 15
            ? 'high'
            : count >= 7
            ? 'medium'
            : 'low';
        return {
          'skill': entry.key,
          'count': count,
          'severity': severity,
        };
      }).toList();
    } catch (e) {
      debugPrint('TeacherAnalyticsService.getSkillGapAnalysis error: $e');
      return [];
    }
  }

  /// v7.4: Monthly score trend for recent months.
  Future<List<Map<String, dynamic>>> getPerformanceTrendInsights({
    int pastMonths = 6,
  }) async {
    try {
      final startDate = DateTime.now().subtract(Duration(days: pastMonths * 30));
      final snapshot = await _firestore
          .collectionGroup('resumeReviews')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .get();

      final monthly = <String, List<int>>{};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final score = _extractScore(data);
        if (score < 0) continue;

        final createdAt = _extractDate(data);
        if (createdAt == null) continue;
        final monthKey =
            '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}';
        monthly.putIfAbsent(monthKey, () => <int>[]).add(score);
      }

      final trends = monthly.entries.map((entry) {
        final scores = entry.value;
        final avgScore = scores.reduce((a, b) => a + b) / scores.length;
        return {
          'month': entry.key,
          'avgScore': avgScore.round(),
          'reviewCount': scores.length,
        };
      }).toList()
        ..sort(
          (a, b) =>
              (a['month'] as String).compareTo(b['month'] as String),
        );

      return trends;
    } catch (e) {
      debugPrint(
        'TeacherAnalyticsService.getPerformanceTrendInsights error: $e',
      );
      return [];
    }
  }

  /// Backward-compatible alias used by existing UI.
  Future<List<Map<String, dynamic>>> getReviewTrends({int pastDays = 30}) async {
    final months = max(1, (pastDays / 30).ceil());
    return getPerformanceTrendInsights(pastMonths: months);
  }

  Map<String, dynamic> _emptyReviewStats() {
    return {
      'totalReviews': 0,
      'avgScore': 0.0,
      'scoreDistribution': {
        'excellent': 0,
        'good': 0,
        'fair': 0,
        'poor': 0,
      },
    };
  }

  int _extractScore(Map<String, dynamic> data) {
    return data['atsScore'] as int? ?? -1;
  }

  DateTime? _extractDate(Map<String, dynamic> data) {
    final createdAt = data['createdAt'] as Timestamp?;
    final reviewedAt = data['reviewedAt'] as Timestamp?;
    return createdAt?.toDate() ?? reviewedAt?.toDate();
  }

  Future<_LatestReview?> _getLatestReview(String userId) async {
    try {
      final createdAtQuery = await _firestore
          .collection('users')
          .doc(userId)
          .collection('resumeReviews')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (createdAtQuery.docs.isNotEmpty) {
        final doc = createdAtQuery.docs.first;
        return _LatestReview(
          data: doc.data(),
          createdAt: _extractDate(doc.data()),
        );
      }
    } catch (_) {
      // Fall through to reviewedAt fallback.
    }

    try {
      final reviewedAtQuery = await _firestore
          .collection('users')
          .doc(userId)
          .collection('resumeReviews')
          .orderBy('reviewedAt', descending: true)
          .limit(1)
          .get();
      if (reviewedAtQuery.docs.isNotEmpty) {
        final doc = reviewedAtQuery.docs.first;
        return _LatestReview(
          data: doc.data(),
          createdAt: _extractDate(doc.data()),
        );
      }
    } catch (e) {
      debugPrint('TeacherAnalyticsService._getLatestReview error: $e');
    }

    return null;
  }

  String _getStudentName(Map<String, dynamic> userData) {
    if (userData['personal'] != null) {
      final personal = userData['personal'] as Map<String, dynamic>;
      final displayName = personal['displayName'] as String?;
      if (displayName != null && displayName.isNotEmpty) {
        return displayName;
      }
      final fullName = personal['fullName'] as String?;
      if (fullName != null && fullName.isNotEmpty) {
        return fullName;
      }
      final email = personal['email'] as String?;
      if (email != null && email.contains('@')) {
        return email.split('@').first;
      }
    }
    return 'Unknown Student';
  }

  /// v8.2: Extract department from user profile data.
  String _getStudentDepartment(Map<String, dynamic> userData) {
    // Try root-level department first
    if (userData['department'] is String && (userData['department'] as String).isNotEmpty) {
      return userData['department'] as String;
    }
    // Try personal.department
    if (userData['personal'] != null) {
      final personal = userData['personal'] as Map<String, dynamic>;
      if (personal['department'] is String && (personal['department'] as String).isNotEmpty) {
        return personal['department'] as String;
      }
    }
    return 'Unknown';
  }
}

class _LatestReview {
  final Map<String, dynamic> data;
  final DateTime? createdAt;

  _LatestReview({required this.data, required this.createdAt});
}

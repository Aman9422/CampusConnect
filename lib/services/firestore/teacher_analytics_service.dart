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

  // ──────────────────────────────────────────────────────────────────────
  // v9.2 (P1): load-scoped read cache.
  //
  // One `loadAnalytics()` cycle previously issued the SAME expensive queries
  // several times:
  //   • users(role == student)          — 4 separate full roster scans
  //   • collectionGroup(resumeReviews)  — 3 separate scans
  //   • per-student review count        — 1 count() read PER student
  //   • getStudentResumeData()          — run twice (direct + prediction)
  //
  // [beginLoad] (called once by TeacherAnalyticsProvider at the start of a
  // cycle) clears every cache below; each underlying query is then issued AT
  // MOST ONCE and its result reused across the aggregate methods. Computed
  // values are unchanged — only duplicate reads are removed.
  // ──────────────────────────────────────────────────────────────────────
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>? _studentsFuture;
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>?
  _resumeReviewsFuture;
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>?
  _applicationsFuture;
  Future<Map<String, int>>? _reviewCountsFuture;
  Future<List<Map<String, dynamic>>>? _studentDataFuture;
  Future<int>? _alumniCountFuture;
  Future<Map<String, Map<String, dynamic>>>? _latestReviewByUserFuture;

  /// v9.2 (P1): begin a fresh load cycle — drop every cached read so the next
  /// `loadAnalytics()` fetches current data exactly once.
  void beginLoad() {
    _studentsFuture = null;
    _resumeReviewsFuture = null;
    _applicationsFuture = null;
    _reviewCountsFuture = null;
    _studentDataFuture = null;
    _alumniCountFuture = null;
    _latestReviewByUserFuture = null;
  }

  /// Shared `users(role == student)` roster — fetched once per load cycle.
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _studentDocs() {
    return _studentsFuture ??= _firestore
        .collection('users')
        .where('role', isEqualTo: 'student')
        .get()
        .then((snapshot) => snapshot.docs);
  }

  /// Shared `collectionGroup(resumeReviews)` result — fetched once per load
  /// cycle and reused by the stats, skill-gap and trend aggregations. Kept
  /// exact (unbounded) deliberately: capping it would under-count reviews, and
  /// the v9.2 brief is explicit that correctness is not traded for fewer reads.
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  _resumeReviewDocs() {
    return _resumeReviewsFuture ??= _firestore
        .collectionGroup('resumeReviews')
        .get()
        .then((snapshot) => snapshot.docs);
  }

  /// Shared `collectionGroup(applications)` result — fetched once per cycle.
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _applicationDocs() {
    return _applicationsFuture ??= _firestore
        .collectionGroup('applications')
        .get()
        .then((snapshot) => snapshot.docs);
  }

  /// Latest review for a student — derived from the shared `resumeReviews`
  /// scan (v9.2 P1).
  ///
  /// Previously this issued a per-student `orderBy('createdAt')` query (plus a
  /// `reviewedAt` fallback query) for EVERY student — an N+1 read pattern that
  /// dominated the load cost. The shared `collectionGroup('resumeReviews')`
  /// scan already contains every review, so the per-student latest is now
  /// computed in memory by [pickLatestReviewPerUser] with the SAME selection
  /// rule (newest `createdAt`, else newest `reviewedAt`). No extra reads.
  Future<_LatestReview?> _latestReviewFor(String userId) async {
    final byUser = await (_latestReviewByUserFuture ??= _resumeReviewDocs()
        .then(
          (docs) => pickLatestReviewPerUser(
            docs.map(
              (doc) => (
                uid: doc.reference.parent.parent?.id ?? '',
                data: doc.data(),
              ),
            ),
          ),
        ));

    final data = byUser[userId];
    if (data == null) return null;
    return _LatestReview(data: data, createdAt: _extractDate(data));
  }

  /// Per-student review count derived from the shared `resumeReviews` scan —
  /// removes the previous count() read (with a full-get fallback) per student.
  Future<int> _reviewCountFor(String userId) async {
    final counts = await (_reviewCountsFuture ??= _resumeReviewDocs().then((
      docs,
    ) {
      final byUser = <String, int>{};
      for (final doc in docs) {
        final uid = doc.reference.parent.parent?.id;
        if (uid == null) continue;
        byUser[uid] = (byUser[uid] ?? 0) + 1;
      }
      return byUser;
    }));
    return counts[userId] ?? 0;
  }

  /// Get resume review aggregate statistics.
  Future<Map<String, dynamic>> getResumeReviewStats() async {
    try {
      final reviewDocs = await _resumeReviewDocs();

      if (reviewDocs.isEmpty) {
        return _emptyReviewStats();
      }

      final scores = reviewDocs
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
  ///
  /// v9.2 (P1): cached per load cycle so `getPlacementPredictionIndicators`
  /// (which derives from this same data) reuses it instead of scanning the
  /// roster a second time.
  Future<List<Map<String, dynamic>>> getStudentResumeData() {
    return _studentDataFuture ??= _buildStudentResumeData();
  }

  Future<List<Map<String, dynamic>>> _buildStudentResumeData() async {
    try {
      final userDocs = await _studentDocs();

      final studentData = <Map<String, dynamic>>[];

      for (final userDoc in userDocs) {
        try {
          final latestReview = await _latestReviewFor(userDoc.id);
          // v9.2 (P1): derived from the shared resumeReviews scan — no
          // per-student count() read (nor its full-get fallback).
          final reviewCount = await _reviewCountFor(userDoc.id);

          // Every student enters the leaderboard, WITH or WITHOUT resume
          // reviews. A student who has never submitted a review is still a
          // student — including them keeps `studentData` consistent with the
          // pipeline / department / engagement counts (previously the device
          // log showed "0 students" while pipeline/dept/engagement found 1),
          // and lets at-risk detection flag them via the "No resume reviews"
          // signal. A missing or malformed atsScore degrades to 0.
          final rawScore = latestReview == null
              ? 0
              : _extractScore(latestReview.data);
          final latestScore = rawScore < 0 ? 0 : rawScore;

          // Get department from user profile
          final department = _getStudentDepartment(userDoc.data());

          studentData.add({
            'studentId': userDoc.id,
            'studentName': _getStudentName(userDoc.data()),
            'department': department,
            'latestScore': latestScore,
            'reviewCount': reviewCount,
            'lastReviewedAt': latestReview?.createdAt,
          });
        } catch (e) {
          debugPrint(
            'TeacherAnalyticsService.getStudentResumeData student error: $e',
          );
        }
      }

      studentData.sort((a, b) {
        final scoreCompare = (b['latestScore'] as int).compareTo(
          a['latestScore'] as int,
        );
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
      // v9.2 (P1): reuse the shared roster scan (was a second full scan).
      final userDocs = await _studentDocs();

      // Group students by department
      final deptGroups = <String, List<Map<String, dynamic>>>{};
      for (final userDoc in userDocs) {
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
            // v9.2 (P1): shared with the leaderboard — at most one read.
            final latestReview = await _latestReviewFor(uid);
            if (latestReview != null) {
              final score = _extractScore(latestReview.data);
              if (score >= 0) {
                totalScore += score;
                scoredCount++;
                if (score < 50) atRisk++;
              }
              // Collect missing keywords from latest review
              final missing =
                  (latestReview.data['missingKeywords'] as List<dynamic>? ?? [])
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
      deptAnalytics.sort(
        (a, b) =>
            (b['studentCount'] as int).compareTo(a['studentCount'] as int),
      );

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
      // v9.2 (P1): reuse the shared roster scan instead of a separate count()
      // query. The roster was already fetched in full for the leaderboard /
      // department / engagement aggregates, so this removes a duplicate scan
      // (and the composite-index fallback path) with an identical count.
      final totalStudents = (await _studentDocs()).length;

      // v9.1: bucket application STATUS into per-stage DISTINCT-student
      // counts. The collectionGroup matches BOTH mirrors (canonical
      // `applications/{uid}_{placementId}` + mirror
      // `placements/{placementId}/applications/{uid}`) and a student can
      // apply to multiple placements with different statuses, so we collect
      // each student's ENTIRE status set and count them at their HIGHEST
      // reached stage:
      //   - placed: any doc with status 'placed'
      //   - interviewed: any doc with 'interviewed' (or placed — cumulative)
      //   - shortlisted: any doc with 'shortlisted' (or interviewed/placed)
      //   - applied: any application doc at all
      final studentStatuses = <String, Set<String>>{};
      try {
        // v9.2 (P1): shared `collectionGroup(applications)` scan — one read
        // for the whole load cycle.
        final appDocs = await _applicationDocs();
        for (final doc in appDocs) {
          final data = doc.data();
          final studentId =
              data['userId'] as String? ?? data['studentId'] as String?;
          if (studentId == null) continue;
          final status = data['status'] as String? ?? 'applied';
          studentStatuses.putIfAbsent(studentId, () => <String>{}).add(status);
        }
      } catch (e) {
        debugPrint(
          'TeacherAnalyticsService: collectionGroup apps query error: $e',
        );
      }

      int shortlisted = 0;
      int interviewed = 0;
      int placed = 0;
      for (final statuses in studentStatuses.values) {
        if (statuses.contains('placed')) {
          placed++;
          interviewed++;
          shortlisted++;
        } else if (statuses.contains('interviewed')) {
          interviewed++;
          shortlisted++;
        } else if (statuses.contains('shortlisted')) {
          shortlisted++;
        }
      }

      return PlacementPipelineData(
        eligibleStudents: totalStudents,
        appliedStudents: studentStatuses.length,
        shortlistedStudents: shortlisted,
        interviewedStudents: interviewed,
        placedStudents: placed,
      );
    } catch (e) {
      debugPrint(
        'TeacherAnalyticsService.getApplicationPipelineCounts error: $e',
      );
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
      // v9.2 (P1): reuse the shared roster scan (was a 4th full student scan).
      final userDocs = await _studentDocs();

      int totalEngagement = 0;
      int totalProfileStrength = 0;
      int count = 0;

      // v9.2 audit (PERF-1): the per-student `engagement_summary/summary`
      // read was an N+1 — one dedicated document read PER student, awaited
      // SERIALLY inside the loop (≈N serial round trips on every teacher
      // dashboard load, the single largest per-load latency line). The reads
      // are now issued CONCURRENTLY in bounded chunks, so the whole fan-out
      // costs a few waves of latency instead of N back-to-back round trips.
      // Same documents, same aggregate values.
      //
      // NOTE: cloud_firestore 6.x does not expose `FirebaseFirestore.getAll`
      // (removed from the public API), so this uses `Future.wait` over
      // chunked refs — the batching primitive this SDK version provides. The
      // chunk bound caps in-flight requests; each read is individually
      // error-tolerant so one failed document never drops the whole chunk
      // (the previous per-item `catch` semantics are preserved).
      const int engagementBatchSize = 50;
      for (var i = 0; i < userDocs.length; i += engagementBatchSize) {
        final end = (i + engagementBatchSize) < userDocs.length
            ? (i + engagementBatchSize)
            : userDocs.length;
        final chunk = userDocs.sublist(i, end);
        if (chunk.isEmpty) continue;

        try {
          final snapshots = await Future.wait(
            chunk.map((userDoc) async {
              try {
                return await _firestore
                    .collection('users')
                    .doc(userDoc.id)
                    .collection('engagement_summary')
                    .doc('summary')
                    .get();
              } catch (e) {
                debugPrint(
                  'TeacherAnalyticsService: engagement_summary read failed '
                  'for ${userDoc.id}: $e',
                );
                return null;
              }
            }),
          );
          for (final engagementDoc in snapshots) {
            if (engagementDoc == null || !engagementDoc.exists) continue;
            final data = engagementDoc.data() ?? {};
            totalEngagement += (data['engagementScore'] as num? ?? 0).round();
            totalProfileStrength += (data['profileStrength'] as num? ?? 0)
                .round();
            count++;
          }
        } catch (e) {
          debugPrint(
            'TeacherAnalyticsService.getEngagementAggregates batch error: $e',
          );
        }
      }

      // Count alumni — cached per load cycle, read at most once.
      int activeAlumni = 0;
      try {
        activeAlumni = await (_alumniCountFuture ??= _firestore
            .collection('users')
            .where('role', isEqualTo: 'alumni')
            .count()
            .get()
            .then((snapshot) => snapshot.count ?? 0));
      } catch (_) {}

      return {
        'avgEngagement': count > 0 ? (totalEngagement / count).round() : 0,
        'avgProfileStrength': count > 0
            ? (totalProfileStrength / count).round()
            : 0,
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

      final predictedPlacementRate =
          (highPotential * 0.9 + mediumPotential * 0.5) /
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

  /// v8.9 (Phase 8): Recommendation intelligence aggregates.
  ///
  /// Queries the `recommendations` collectionGroup (teachers granted read via
  /// firestore.rules) and aggregates ONLY engine fields — career goals,
  /// target roles, skill gaps (skillsMissing on role/placement cards),
  /// placement match tiers, and strong-match / skill-gap student counts. No
  /// private resume text or full student profiles are ever read or returned.
  Future<Map<String, dynamic>> getRecommendationAggregates() async {
    try {
      final snapshot = await _firestore
          .collectionGroup('recommendations')
          .limit(800)
          .get();

      final careerGoals = <String, int>{};
      final targetRoles = <String, int>{};
      final skillGaps = <String, int>{};
      final placementTiers = <String, int>{};
      final strongStudents = <String>{};
      final gapStudents = <String>{};

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final type = data['type'] as String? ?? '';
        final studentId =
            data['studentId'] as String? ?? data['userId'] as String? ?? '';

        // Career goal distribution: only `role` recommendations carry
        // career-goal signals. `skill` cards were removed in v9.0 — the
        // AI Career Coach owns career reasoning now.
        final title = (data['title'] as String? ?? '').trim();
        if (type == 'role' && title.isNotEmpty) {
          final label = title.replaceFirst('Career match: ', '');
          careerGoals[label] = (careerGoals[label] ?? 0) + 1;
        }

        // Target role distribution.
        final targetRole = data['targetRole'] as String?;
        if (targetRole != null && targetRole.isNotEmpty) {
          final label = targetRole.replaceAll('_', ' ');
          targetRoles[label] = (targetRoles[label] ?? 0) + 1;
        }

        // Skill gaps: skillsMissing on role/placement/skill recs.
        final missing = (data['skillsMissing'] as List<dynamic>? ?? [])
            .whereType<String>()
            .map((s) => s.trim().toLowerCase())
            .where((s) => s.isNotEmpty)
            .toList();
        for (final skill in missing) {
          skillGaps[skill] = (skillGaps[skill] ?? 0) + 1;
        }

        // Placement match tier distribution.
        final metadata = data['metadata'] as Map<String, dynamic>? ?? {};
        final tier = metadata['matchTier'] as String?;
        if (tier != null && tier.isNotEmpty) {
          placementTiers[tier] = (placementTiers[tier] ?? 0) + 1;
          if (studentId.isNotEmpty && tier == 'strong') {
            strongStudents.add(studentId);
          }
        }

        // Students with target-role skill gaps.
        if (type == 'role' && missing.isNotEmpty && studentId.isNotEmpty) {
          gapStudents.add(studentId);
        }
      }

      List<Map<String, dynamic>> toCountedList(
        Map<String, int> map, {
        int? limitCount,
      }) {
        final entries = map.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final list = entries
            .map((e) => {'label': e.key, 'count': e.value})
            .toList();
        return limitCount != null ? list.take(limitCount).toList() : list;
      }

      return {
        'careerGoals': toCountedList(careerGoals, limitCount: 10),
        'targetRoles': toCountedList(targetRoles, limitCount: 10),
        'topSkillGaps': toCountedList(skillGaps, limitCount: 8),
        'placementTiers': placementTiers,
        'strongMatchStudents': strongStudents.length,
        'significantGapStudents': gapStudents.length,
      };
    } catch (e) {
      debugPrint(
        'TeacherAnalyticsService.getRecommendationAggregates error: $e',
      );
      return {
        'careerGoals': <Map<String, dynamic>>[],
        'targetRoles': <Map<String, dynamic>>[],
        'topSkillGaps': <Map<String, dynamic>>[],
        'placementTiers': <String, int>{},
        'strongMatchStudents': 0,
        'significantGapStudents': 0,
      };
    }
  }

  /// v7.4: Aggregate missing skills to identify institution-level gaps.
  Future<List<Map<String, dynamic>>> getSkillGapAnalysis({
    int limit = 8,
  }) async {
    try {
      // v9.2 (P1): reuse the shared resumeReviews scan (exact — previously
      // capped at 400 docs). One collectionGroup read for the whole cycle.
      final reviewDocs = await _resumeReviewDocs();

      final frequency = <String, int>{};
      for (final doc in reviewDocs) {
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
        return {'skill': entry.key, 'count': count, 'severity': severity};
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
      final startDate = DateTime.now().subtract(
        Duration(days: pastMonths * 30),
      );

      // v9.2 (P1): reuse the shared resumeReviews scan and apply the date
      // window client-side — same result as the previous where() query, but
      // no second collectionGroup read. The window is applied to `createdAt`
      // only (Timestamp or ISO string), matching the server-side filter.
      final reviewDocs = await _resumeReviewDocs();

      final monthly = <String, List<int>>{};
      for (final doc in reviewDocs) {
        final data = doc.data();
        final score = _extractScore(data);
        if (score < 0) continue;

        final rawCreatedAt = data['createdAt'];
        DateTime? createdAt;
        if (rawCreatedAt is Timestamp) {
          createdAt = rawCreatedAt.toDate();
        } else if (rawCreatedAt is String) {
          createdAt = DateTime.tryParse(rawCreatedAt);
        }
        if (createdAt == null) continue;
        if (createdAt.isBefore(startDate)) continue;
        final monthKey =
            '${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}';
        monthly.putIfAbsent(monthKey, () => <int>[]).add(score);
      }

      final trends =
          monthly.entries.map((entry) {
            final scores = entry.value;
            final avgScore = scores.reduce((a, b) => a + b) / scores.length;
            return {
              'month': entry.key,
              'avgScore': avgScore.round(),
              'reviewCount': scores.length,
            };
          }).toList()..sort(
            (a, b) => (a['month'] as String).compareTo(b['month'] as String),
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
  Future<List<Map<String, dynamic>>> getReviewTrends({
    int pastDays = 30,
  }) async {
    final months = max(1, (pastDays / 30).ceil());
    return getPerformanceTrendInsights(pastMonths: months);
  }

  Map<String, dynamic> _emptyReviewStats() {
    return {
      'totalReviews': 0,
      'avgScore': 0.0,
      'scoreDistribution': {'excellent': 0, 'good': 0, 'fair': 0, 'poor': 0},
    };
  }

  int _extractScore(Map<String, dynamic> data) {
    final atsScore = data['atsScore'];
    if (atsScore is int && atsScore >= 0 && atsScore <= 100) {
      return atsScore;
    }
    // Tolerant of numbers / non-int literals.
    if (atsScore is num) {
      return atsScore.toInt().clamp(0, 100);
    }
    // Legacy/external writers may use a string or the snake_case field name.
    final scoreString = data['ats_score'];
    if (scoreString is String) {
      final parsed = int.tryParse(scoreString);
      if (parsed != null) return parsed.clamp(0, 100);
    }
    return -1;
  }

  DateTime? _extractDate(Map<String, dynamic> data) {
    // Current Timestamp fields first.
    final createdAt = data['createdAt'];
    if (createdAt is Timestamp) return createdAt.toDate();
    final reviewedAt = data['reviewedAt'];
    if (reviewedAt is Timestamp) return reviewedAt.toDate();

    // Legacy writers may store ISO-8601 strings instead of Timestamps.
    if (createdAt is String) return DateTime.tryParse(createdAt);
    if (reviewedAt is String) return DateTime.tryParse(reviewedAt);

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
    if (userData['department'] is String &&
        (userData['department'] as String).isNotEmpty) {
      return userData['department'] as String;
    }
    // Try personal.department
    if (userData['personal'] != null) {
      final personal = userData['personal'] as Map<String, dynamic>;
      if (personal['department'] is String &&
          (personal['department'] as String).isNotEmpty) {
        return personal['department'] as String;
      }
    }
    return 'Unknown';
  }
}

/// v9.2 (P1): pure selection of the latest review per student from the shared
/// `resumeReviews` scan — replaces the previous per-student N+1 query.
///
/// Preserves the former query semantics exactly: prefer the doc with the
/// newest `createdAt`; if a student has NO review carrying `createdAt`, fall
/// back to the newest `reviewedAt`. A doc missing both fields is ignored (a
/// Firestore `orderBy` would have excluded it too).
///
/// Extracted as a pure function so it is unit-testable without Firestore.
@visibleForTesting
Map<String, Map<String, dynamic>> pickLatestReviewPerUser(
  Iterable<({String uid, Map<String, dynamic> data})> entries,
) {
  final byCreatedAt = <String, Map<String, dynamic>>{};
  final createdAtMs = <String, int>{};
  final byReviewedAt = <String, Map<String, dynamic>>{};
  final reviewedAtMs = <String, int>{};

  for (final entry in entries) {
    if (entry.uid.isEmpty) continue;

    final createdMs = _fieldMillis(entry.data['createdAt']);
    if (createdMs != null) {
      if (createdAtMs[entry.uid] == null ||
          createdMs > createdAtMs[entry.uid]!) {
        createdAtMs[entry.uid] = createdMs;
        byCreatedAt[entry.uid] = entry.data;
      }
      continue;
    }

    final reviewedMs = _fieldMillis(entry.data['reviewedAt']);
    if (reviewedMs != null) {
      if (reviewedAtMs[entry.uid] == null ||
          reviewedMs > reviewedAtMs[entry.uid]!) {
        reviewedAtMs[entry.uid] = reviewedMs;
        byReviewedAt[entry.uid] = entry.data;
      }
    }
  }

  final result = <String, Map<String, dynamic>>{};
  for (final uid in {...byCreatedAt.keys, ...byReviewedAt.keys}) {
    result[uid] = byCreatedAt[uid] ?? byReviewedAt[uid]!;
  }
  return result;
}

/// Millisecond value of a Firestore/Timestamp/date field, tolerant of the
/// legacy ISO-string writers. Returns null when the field is absent/unusable.
int? _fieldMillis(Object? raw) {
  if (raw is Timestamp) return raw.millisecondsSinceEpoch;
  if (raw is DateTime) return raw.millisecondsSinceEpoch;
  if (raw is String) return DateTime.tryParse(raw)?.millisecondsSinceEpoch;
  if (raw is num) return raw.toInt();
  return null;
}

class _LatestReview {
  final Map<String, dynamic> data;
  final DateTime? createdAt;

  _LatestReview({required this.data, required this.createdAt});
}

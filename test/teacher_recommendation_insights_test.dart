import 'package:flutter_test/flutter_test.dart';

/// CampusConnect v8.9 — Teacher-Facing Recommendation Insights contract tests.
///
/// Mirrors the aggregate logic in
/// `TeacherAnalyticsService.getRecommendationAggregates`
/// (lib/services/firestore/teacher_analytics_service.dart):
///   - Reads ONLY the engine fields of recommendation docs (never resume
///     text / full student profiles).
///   - Builds career-goal, target-role, skill-gap and placement-tier
///     distributions.
///   - Counts strong-match students and significant-gap students.
///   - Tolerates legacy doc shapes (missing new fields degrade to empty).
///
/// Pure-Dart mirror — no Firestore, no API keys.

/// Mirrors getRecommendationAggregates' aggregation over the raw docs.
Map<String, dynamic> aggregateRecommendations(List<Map<String, dynamic>> docs) {
  final careerGoals = <String, int>{};
  final targetRoles = <String, int>{};
  final skillGaps = <String, int>{};
  final placementTiers = <String, int>{};
  final strongStudents = <String>{};
  final gapStudents = <String>{};

  for (final data in docs) {
    final type = data['type'] as String? ?? '';
    final studentId =
        data['studentId'] as String? ?? data['userId'] as String? ?? '';

    // v9.0: only `role` docs produce career-goal signals. `skill` cards
    // were removed — the AI Career Coach owns career reasoning now.
    final title = (data['title'] as String? ?? '').trim();
    if (type == 'role' && title.isNotEmpty) {
      final label = title.replaceFirst('Career match: ', '');
      careerGoals[label] = (careerGoals[label] ?? 0) + 1;
    }

    final targetRole = data['targetRole'] as String?;
    if (targetRole != null && targetRole.isNotEmpty) {
      final label = targetRole.replaceAll('_', ' ');
      targetRoles[label] = (targetRoles[label] ?? 0) + 1;
    }

    final missing = (data['skillsMissing'] as List<dynamic>? ?? [])
        .whereType<String>()
        .map((s) => s.trim().toLowerCase())
        .where((s) => s.isNotEmpty)
        .toList();
    for (final skill in missing) {
      skillGaps[skill] = (skillGaps[skill] ?? 0) + 1;
    }

    final metadata = data['metadata'] as Map<String, dynamic>? ?? {};
    final tier = metadata['matchTier'] as String?;
    if (tier != null && tier.isNotEmpty) {
      placementTiers[tier] = (placementTiers[tier] ?? 0) + 1;
      if (studentId.isNotEmpty && tier == 'strong') {
        strongStudents.add(studentId);
      }
    }

    if (type == 'role' && missing.isNotEmpty && studentId.isNotEmpty) {
      gapStudents.add(studentId);
    }
  }

  List<Map<String, dynamic>> toCountedList(
    Map<String, int> map, {
    required int limit,
  }) {
    final entries = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries
        .take(limit)
        .map((e) => {'label': e.key, 'count': e.value})
        .toList();
  }

  return {
    'careerGoals': toCountedList(careerGoals, limit: 10),
    'targetRoles': toCountedList(targetRoles, limit: 10),
    'topSkillGaps': toCountedList(skillGaps, limit: 8),
    'placementTiers': placementTiers,
    'strongMatchStudents': strongStudents.length,
    'significantGapStudents': gapStudents.length,
  };
}

void main() {
  group('aggregate distributions', () {
    test('builds career-goal, target-role, skill-gap and tier aggregates', () {
      final result = aggregateRecommendations([
        {
          'type': 'role',
          'title': 'Career match: Mobile Developer',
          'targetRole': 'mobile_developer',
          'skillsMissing': ['Docker', 'Firebase'],
          'userId': 'u1',
        },
        {
          'type': 'placement',
          'title': 'Flutter Dev at X',
          'metadata': {'matchTier': 'strong'},
          'skillsMissing': ['Docker'],
          'userId': 'u1',
        },
        {
          'type': 'role',
          'title': 'Career match: Backend Engineer',
          'targetRole': 'backend_engineer',
          'skillsMissing': ['Docker', 'Kubernetes'],
          'userId': 'u2',
        },
      ]);

      // v9.0: only `role` docs produce career-goal signals.
      expect(
        result['careerGoals'],
        containsAll([
          {'label': 'Mobile Developer', 'count': 1},
          {'label': 'Backend Engineer', 'count': 1},
        ]),
      );
      // Raw `contains(mapLiteral)` produces _MapContains (matches a Map
      // actual, never a List) — wrap in equals for deep element matching.
      expect(
        result['targetRoles'],
        containsAll([
          equals({'label': 'mobile developer', 'count': 1}),
          equals({'label': 'backend engineer', 'count': 1}),
        ]),
      );
      // Docker appears in role (1) + placement (1) + role (1) → 3.
      expect(
        (result['topSkillGaps'] as List).firstWhere(
          (e) => e['label'] == 'docker',
        )['count'],
        3,
      );
      expect(result['placementTiers'], {'strong': 1});
      expect(result['strongMatchStudents'], 1);
      // u1 has role rec with missing skills + u2 has role rec with missing
      // skills → both are gap students.
      expect(result['significantGapStudents'], 2);
    });

    test('skill-gap aggregation normalizes case and trims', () {
      final result = aggregateRecommendations([
        {
          'type': 'role',
          'title': 'Career match: X',
          'skillsMissing': ['  Docker ', 'docker', 'AWS'],
          'userId': 'u9',
        },
      ]);

      final dockerEntries = (result['topSkillGaps'] as List)
          .where((e) => e['label'] == 'docker')
          .toList();
      expect(dockerEntries.single['count'], 2);
    });
  });

  group('privacy — aggregate only, no resume text', () {
    test('resume text in a doc is NEVER read or returned', () {
      final docs = [
        {
          'type': 'placement',
          'title': 'SDE at A',
          'metadata': {'matchTier': 'strong'},
          'userId': 'u1',
          // A malicious/mis-shaped doc with resume text — the aggregate
          // layer only reads engine fields and never surfaces this.
          'resumeText': 'PRIVATE_RESUME_CONTENT',
          'skillsMissing': ['Kotlin'],
        },
      ];

      final result = aggregateRecommendations(docs);
      final serialized = result.toString();

      expect(serialized, isNot(contains('PRIVATE_RESUME_CONTENT')));
      expect(result['strongMatchStudents'], 1);
    });
  });

  group('legacy tolerance', () {
    test('docs missing all v8.9 fields degrade to empty aggregates', () {
      final result = aggregateRecommendations([
        {'type': 'chat', 'title': 'Use AI Career Assistant', 'userId': 'u1'},
      ]);

      expect(result['careerGoals'], isEmpty);
      expect(result['targetRoles'], isEmpty);
      expect(result['topSkillGaps'], isEmpty);
      expect(result['placementTiers'], isEmpty);
      expect(result['strongMatchStudents'], 0);
      expect(result['significantGapStudents'], 0);
    });

    test('studentId falls back to userId for legacy docs', () {
      final result = aggregateRecommendations([
        {
          'type': 'placement',
          'title': 'SDE at A',
          'metadata': {'matchTier': 'strong'},
          'userId': 'u_legacy',
        },
      ]);

      expect(result['strongMatchStudents'], 1);
    });
  });

  group('ranking of distributions', () {
    test('career goals and skill gaps sort by count descending', () {
      final result = aggregateRecommendations([
        for (var i = 0; i < 3; i++)
          {'type': 'role', 'title': 'Career match: A', 'userId': 'u$i'},
        for (var i = 0; i < 2; i++)
          {'type': 'role', 'title': 'Career match: B', 'userId': 'u${i + 10}'},
        {'type': 'role', 'title': 'Career match: C', 'userId': 'u99'},
      ]);

      final goals = result['careerGoals'] as List;
      expect(goals.first['label'], 'A');
      expect(goals.first['count'], 3);
      expect(goals.last['label'], 'C');
    });
  });
}

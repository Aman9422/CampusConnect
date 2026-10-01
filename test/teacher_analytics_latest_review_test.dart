import 'package:campusconnect/services/firestore/teacher_analytics_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

/// CampusConnect v9.2 (P1) — Teacher Analytics "latest review per student".
///
/// Regression cover for the fix that removed the per-student N+1 read in
/// `TeacherAnalyticsService`: instead of issuing
/// `users/{uid}/resumeReviews orderBy(createdAt).limit(1)` (plus a
/// `reviewedAt` fallback) for EVERY student, the latest review is derived in
/// memory from the ONE shared `collectionGroup('resumeReviews')` scan via
/// [pickLatestReviewPerUser].
///
/// The selection rule must be IDENTICAL to the previous Firestore queries:
///   • prefer the doc with the newest `createdAt`;
///   • only if a student has NO review carrying `createdAt`, use the newest
///     `reviewedAt`;
///   • a doc with neither field is ignored (an `orderBy` would exclude it too).
void main() {
  ({String uid, Map<String, dynamic> data}) entry(
    String uid,
    Map<String, dynamic> data,
  ) => (uid: uid, data: data);

  group('pickLatestReviewPerUser — createdAt ordering', () {
    test('picks the newest createdAt for a single student', () {
      final older = entry('u1', {'atsScore': 40, 'createdAt': _ts(2024, 1, 1)});
      final newer = entry('u1', {'atsScore': 80, 'createdAt': _ts(2024, 6, 1)});
      final middle = entry('u1', {
        'atsScore': 60,
        'createdAt': _ts(2024, 3, 1),
      });

      final result = pickLatestReviewPerUser([older, newer, middle]);

      expect(result.keys, ['u1']);
      expect(result['u1']!['atsScore'], 80);
    });

    test('keeps each student independent', () {
      final result = pickLatestReviewPerUser([
        entry('u1', {'atsScore': 10, 'createdAt': _ts(2024, 1, 1)}),
        entry('u2', {'atsScore': 20, 'createdAt': _ts(2024, 1, 1)}),
        entry('u1', {'atsScore': 90, 'createdAt': _ts(2024, 5, 1)}),
        entry('u2', {'atsScore': 50, 'createdAt': _ts(2024, 9, 1)}),
      ]);

      expect(result['u1']!['atsScore'], 90);
      expect(result['u2']!['atsScore'], 50);
    });

    test('accepts an ISO-8601 string createdAt (legacy writer)', () {
      final result = pickLatestReviewPerUser([
        entry('u1', {'atsScore': 30, 'createdAt': '2024-01-01T00:00:00.000Z'}),
        entry('u1', {'atsScore': 70, 'createdAt': '2024-08-01T00:00:00.000Z'}),
      ]);

      expect(result['u1']!['atsScore'], 70);
    });
  });

  group('pickLatestReviewPerUser — reviewedAt fallback', () {
    test('uses reviewedAt when no review carries createdAt', () {
      final result = pickLatestReviewPerUser([
        entry('u1', {'atsScore': 25, 'reviewedAt': _ts(2024, 2, 1)}),
        entry('u1', {'atsScore': 75, 'reviewedAt': _ts(2024, 7, 1)}),
      ]);

      expect(result['u1']!['atsScore'], 75);
    });

    test('createdAt wins over reviewedAt for the same student', () {
      // reviewedAt is NEWER, but createdAt is present → createdAt branch wins,
      // exactly as the previous `orderBy(createdAt)` query would have returned.
      final result = pickLatestReviewPerUser([
        entry('u1', {
          'atsScore': 55,
          'createdAt': _ts(2024, 3, 1),
          'reviewedAt': _ts(2024, 12, 1),
        }),
      ]);

      expect(result['u1']!['atsScore'], 55);
    });

    test('a createdAt-bearing review wins even if a reviewedAt-only one is '
        'newer in wall-clock time', () {
      final withCreatedAt = entry('u1', {
        'atsScore': 88,
        'createdAt': _ts(2023, 1, 1),
        'reviewedAt': _ts(2023, 1, 1),
      });
      final reviewedAtOnly = entry('u1', {
        'atsScore': 12,
        'reviewedAt': _ts(2026, 1, 1),
      });

      final result = pickLatestReviewPerUser([withCreatedAt, reviewedAtOnly]);

      expect(
        result['u1']!['atsScore'],
        88,
        reason:
            'the doc that carries createdAt is preferred, matching '
            'orderBy(createdAt).limit(1)',
      );
    });
  });

  group('pickLatestReviewPerUser — exclusions', () {
    test('ignores entries with an empty uid', () {
      final result = pickLatestReviewPerUser([
        entry('', {'atsScore': 99, 'createdAt': _ts(2024, 1, 1)}),
        entry('u1', {'atsScore': 40, 'createdAt': _ts(2024, 1, 1)}),
      ]);

      expect(result.keys, ['u1']);
    });

    test('ignores a doc with neither createdAt nor reviewedAt', () {
      final result = pickLatestReviewPerUser([
        entry('u1', {'atsScore': 99}),
        entry('u2', {'atsScore': 10, 'createdAt': _ts(2024, 1, 1)}),
      ]);

      expect(result.containsKey('u1'), isFalse);
      expect(result['u2']!['atsScore'], 10);
    });

    test('returns an empty map for no entries', () {
      expect(pickLatestReviewPerUser(const []), isEmpty);
    });
  });
}

Timestamp _ts(int year, int month, int day) =>
    Timestamp.fromDate(DateTime.utc(year, month, day));

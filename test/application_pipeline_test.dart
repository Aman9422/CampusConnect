import 'package:flutter_test/flutter_test.dart';

/// CampusConnect v9.1 — Application pipeline bucket tests.
///
/// Mirrors `TeacherAnalyticsService.getApplicationPipelineCounts`
/// (lib/services/firestore/teacher_analytics_service.dart) as a pure
/// function so the status-bucketing logic can be unit-tested without
/// Firebase — same convention as `test/security_rules_mirror_test.dart`.
///
/// Under test:
///   - a student's ENTIRE status set is collected across BOTH mirrors
///     (canonical `applications/{uid}_{placementId}` + mirror
///     `placements/{placementId}/applications/{uid}`) and deduped by userId
///   - each student is counted at their HIGHEST reached stage (cumulative):
///     placed = has 'placed'; interviewed = 'interviewed' OR 'placed';
///     shortlisted = 'shortlisted' OR 'interviewed' OR 'placed';
///     applied = any application doc at all
///   - docs with no userId/studentId are skipped; missing status defaults
///     to 'applied'

/// Minimal raw application doc — only the fields the bucket logic reads.
typedef AppDoc = ({String? userId, String? studentId, String? status});

/// Result of bucketing — all values are DISTINCT-student counts.
typedef PipelineCounts = ({
  int applied,
  int shortlisted,
  int interviewed,
  int placed,
});

/// Mirror of `TeacherAnalyticsService.getApplicationPipelineCounts`.
PipelineCounts bucketPipeline(Iterable<AppDoc> docs) {
  final studentStatuses = <String, Set<String>>{};
  for (final doc in docs) {
    final studentId = doc.userId ?? doc.studentId;
    if (studentId == null) continue;
    final status = doc.status ?? 'applied';
    studentStatuses.putIfAbsent(studentId, () => <String>{}).add(status);
  }

  var shortlisted = 0;
  var interviewed = 0;
  var placed = 0;
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

  return (
    applied: studentStatuses.length,
    shortlisted: shortlisted,
    interviewed: interviewed,
    placed: placed,
  );
}

AppDoc doc(String? userId, {String? studentId, String? status}) => (
  userId: userId,
  studentId: studentId,
  status: status,
);

void main() {
  group('bucketPipeline — distinct-student counts', () {
    test('counts each student once even when BOTH mirrors exist', () {
      // u1 canonical + mirror with different statuses (mirror stale).
      final counts = bucketPipeline([
        doc('u1', status: 'applied'),
        doc('u1', studentId: 'u1', status: 'shortlisted'),
        doc('u2', status: 'applied'),
        doc('u3', status: 'placed'),
      ]);
      expect(counts.applied, 3);
      expect(counts.shortlisted, 2); // u1 (shortlisted) + u3 (placed)
      expect(counts.interviewed, 1); // u3 only
      expect(counts.placed, 1);
    });

    test('cumulative stages — a placed student is in every upstream stage', () {
      final counts = bucketPipeline([
        doc('u1', status: 'placed'),
        doc('u2', status: 'interviewed'),
        doc('u3', status: 'shortlisted'),
        doc('u4', status: 'applied'),
      ]);
      expect(counts.applied, 4);
      expect(counts.shortlisted, 3); // u1 + u2 + u3
      expect(counts.interviewed, 2); // u1 + u2
      expect(counts.placed, 1);
    });

    test('interviewed student is counted as shortlisted too', () {
      final counts = bucketPipeline([
        doc('u1', status: 'interviewed'),
        doc('u2', status: 'shortlisted'),
      ]);
      expect(counts.applied, 2);
      expect(counts.shortlisted, 2);
      expect(counts.interviewed, 1);
      expect(counts.placed, 0);
    });

    test('rejected applications still count as applied but advance nothing', () {
      final counts = bucketPipeline([
        doc('u1', status: 'rejected'),
        doc('u2', status: 'applied'),
      ]);
      expect(counts.applied, 2);
      expect(counts.shortlisted, 0);
      expect(counts.interviewed, 0);
      expect(counts.placed, 0);
    });

    test('missing status defaults to applied', () {
      final counts = bucketPipeline([doc('u1')]);
      expect(counts.applied, 1);
      expect(counts.shortlisted, 0);
    });

    test('docs without userId/studentId are skipped', () {
      final counts = bucketPipeline([
        doc(null, studentId: null, status: 'placed'),
        doc('u1', status: 'applied'),
      ]);
      expect(counts.applied, 1);
      expect(counts.placed, 0);
    });

    test('empty input produces all zeros', () {
      final counts = bucketPipeline(const []);
      expect(counts.applied, 0);
      expect(counts.shortlisted, 0);
      expect(counts.interviewed, 0);
      expect(counts.placed, 0);
    });

    test('a student with multiple placements across statuses reaches the top stage once', () {
      // u1 applied to p1 (shortlisted) and p2 (interviewed) — counts once
      // at interviewed, never twice.
      final counts = bucketPipeline([
        doc('u1', status: 'shortlisted'),
        doc('u1', status: 'interviewed'),
      ]);
      expect(counts.applied, 1);
      expect(counts.shortlisted, 1);
      expect(counts.interviewed, 1);
      expect(counts.placed, 0);
    });

    test('userId wins when present; studentId only fills in for legacy docs', () {
      // Canonical doc carries userId; a legacy mirror may carry ONLY
      // studentId. Both resolve to the same user via userId ?? studentId.
      final counts = bucketPipeline([
        doc('u1', status: 'placed'),
        doc(null, studentId: 'u1', status: 'applied'),
      ]);
      expect(counts.applied, 1);
      expect(counts.placed, 1);
    });

    test('a userId is never shadowed by a differing studentId alias', () {
      // u1's doc carries a studentId alias that is NOT used for identity.
      // A separate doc whose USERNAME happens to match that alias is a
      // distinct student — identity always comes from userId ?? studentId.
      final counts = bucketPipeline([
        doc('realUid', studentId: 'aliasUid', status: 'placed'),
        doc('aliasUid', status: 'applied'),
      ]);
      expect(counts.applied, 2);
      expect(counts.placed, 1);
    });
  });
}

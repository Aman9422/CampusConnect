import 'package:flutter_test/flutter_test.dart';

/// CampusConnect v9.1 — Application applicant dedupe tests.
///
/// Mirrors `PlacementsService.getApplicationsForPlacement`
/// (lib/services/firestore/placements_service.dart) as a pure function so
/// the dedupe logic can be unit-tested without Firebase — same convention
/// as `test/security_rules_mirror_test.dart`.
///
/// Under test:
///   - a collectionGroup query on `applications` matches BOTH mirrors:
///     canonical `applications/{uid}_{placementId}` (field `resumeUrl`) and
///     mirror `placements/{placementId}/applications/{uid}` (field `resume`)
///   - each student is deduped by userId; docs with no userId/studentId are
///     skipped
///   - the canonical doc is preferred because it carries `resumeUrl` — a
///     mirror is kept only when no canonical doc arrived
///   - result is sorted by appliedAt descending
///   - when kept doc is a mirror-only record, `resume` falls back into the
///     resume link (Application.fromFirestore behavior)

/// Minimal raw application doc — only the fields the dedupe logic reads.
typedef ApplicantDoc = ({
  String? userId,
  String? studentId,
  String? placementId,
  String? resumeUrl,
  String? resume,
  String? status,
  DateTime appliedAt,
});

/// A deduped applicant as surfaced to the UI.
typedef DedupedApplicant = ({
  String userId,
  String resumeUrl,
  DateTime appliedAt,
  String status,
});

/// Mirror of `PlacementsService.getApplicationsForPlacement`'s dedupe loop.
///
/// The service first runs `collectionGroup('applications')
/// .where('placementId', isEqualTo: placementId)`; placement filtering is
/// done by the Firestore query, so this function only mirrors the in-memory
/// dedupe + sort that follows the query.
List<DedupedApplicant> dedupeApplicants(Iterable<ApplicantDoc> docs) {
  final byUser = <String, ApplicantDoc>{};
  final hadResumeUrl = <String, bool>{};

  for (final doc in docs) {
    final userId = doc.userId ?? doc.studentId;
    if (userId == null) continue;

    final carriesResumeUrl = doc.resumeUrl != null;
    final current = byUser[userId];
    final currentCarriesResumeUrl = hadResumeUrl[userId] ?? false;

    // Keep first match; replace only when the new doc is canonical
    // (`resumeUrl`) and the kept doc was only a mirror (`resume`).
    if (current == null || (carriesResumeUrl && !currentCarriesResumeUrl)) {
      byUser[userId] = doc;
      hadResumeUrl[userId] = carriesResumeUrl;
    }
  }

  final documents = byUser.values.toList()
    ..sort((a, b) => b.appliedAt.compareTo(a.appliedAt));

  return documents
      .map(
        (doc) => (
          userId: doc.userId ?? doc.studentId!,
          resumeUrl: doc.resumeUrl ?? doc.resume ?? '',
          appliedAt: doc.appliedAt,
          status: doc.status ?? 'applied',
        ),
      )
      .toList();
}

ApplicantDoc app(
  String? userId, {
  String? studentId,
  String? placementId = 'p1',
  String? resumeUrl,
  String? resume,
  String status = 'applied',
  DateTime? appliedAt,
}) =>
    (
      userId: userId,
      studentId: studentId,
      placementId: placementId,
      resumeUrl: resumeUrl,
      resume: resume,
      status: status,
      appliedAt: appliedAt ?? DateTime(2026, 8, 1),
    );

void main() {
  group('dedupeApplicants — canonical-over-mirror preference', () {
    test('canonical doc preferred even when the mirror is seen first', () {
      final applicants = dedupeApplicants([
        app('u1', resume: 'mirror-resume-s3://u1.pdf', appliedAt: DateTime(2026, 8, 1)),
        app('u1', resumeUrl: 'canonical-s3://u1.pdf', appliedAt: DateTime(2026, 8, 2)),
      ]);
      expect(applicants, hasLength(1));
      expect(applicants.single.userId, 'u1');
      expect(applicants.single.resumeUrl, 'canonical-s3://u1.pdf');
    });

    test('canonical first then mirror — canonical is kept', () {
      final applicants = dedupeApplicants([
        app('u1', resumeUrl: 'canonical-s3://u1.pdf', appliedAt: DateTime(2026, 8, 2)),
        app('u1', resume: 'mirror-resume-s3://u1.pdf', appliedAt: DateTime(2026, 8, 1)),
      ]);
      expect(applicants, hasLength(1));
      expect(applicants.single.resumeUrl, 'canonical-s3://u1.pdf');
    });

    test('two canonicals — first one wins (no replacement churn)', () {
      final applicants = dedupeApplicants([
        app('u1', resumeUrl: 'canonical-A.pdf', appliedAt: DateTime(2026, 8, 1)),
        app('u1', resumeUrl: 'canonical-B.pdf', appliedAt: DateTime(2026, 8, 3)),
      ]);
      expect(applicants, hasLength(1));
      expect(applicants.single.resumeUrl, 'canonical-A.pdf');
    });

    test('two mirrors only (no canonical at all) — first mirror kept', () {
      final applicants = dedupeApplicants([
        app('u1', resume: 'mirror-A.pdf', appliedAt: DateTime(2026, 8, 1)),
        app('u1', resume: 'mirror-B.pdf', appliedAt: DateTime(2026, 8, 2)),
      ]);
      expect(applicants, hasLength(1));
      expect(applicants.single.resumeUrl, 'mirror-A.pdf');
    });

    test('mirror-only record falls back to the resume field as the link', () {
      final applicants = dedupeApplicants([
        app('u1', resume: 'placements/p1/applications/u1/resume.pdf'),
      ]);
      expect(applicants.single.resumeUrl,
          'placements/p1/applications/u1/resume.pdf');
    });
  });

  group('dedupeApplicants — identity & ordering', () {
    test('distinct students are all kept, sorted by appliedAt descending', () {
      final applicants = dedupeApplicants([
        app('u1', resumeUrl: 'r1.pdf', appliedAt: DateTime(2026, 8, 1)),
        app('u2', resumeUrl: 'r2.pdf', appliedAt: DateTime(2026, 8, 5)),
        app('u3', resumeUrl: 'r3.pdf', appliedAt: DateTime(2026, 8, 3)),
      ]);
      expect(applicants.map((a) => a.userId).toList(), ['u2', 'u3', 'u1']);
    });

    test('userId takes precedence over the studentId alias', () {
      final applicants = dedupeApplicants([
        app('realUid', studentId: 'aliasUid', resumeUrl: 'r.pdf', appliedAt: DateTime(2026, 8, 2)),
        app('realUid', studentId: 'aliasUid', resume: 'm.pdf', appliedAt: DateTime(2026, 8, 1)),
      ]);
      expect(applicants, hasLength(1));
      expect(applicants.single.userId, 'realUid');
    });

    test('studentId-only docs are deduped by the alias', () {
      final applicants = dedupeApplicants([
        app(null, studentId: 'u1', resumeUrl: 'r1.pdf'),
        app(null, studentId: 'u1', resume: 'm1.pdf'),
        app(null, studentId: 'u2', resume: 'm2.pdf'),
      ]);
      expect(applicants, hasLength(2));
      expect(applicants.map((a) => a.userId).toSet(), {'u1', 'u2'});
    });

    test('docs with neither userId nor studentId are skipped', () {
      final applicants = dedupeApplicants([
        app(null, studentId: null, resumeUrl: 'orphan.pdf'),
        app('u1', resumeUrl: 'r1.pdf'),
      ]);
      expect(applicants, hasLength(1));
      expect(applicants.single.userId, 'u1');
    });

    test('empty input produces an empty list', () {
      expect(dedupeApplicants(const []), isEmpty);
    });
  });
}

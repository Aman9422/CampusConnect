import 'package:campusconnect/models/application.dart';
import 'package:campusconnect/models/placement.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

/// CampusConnect v9.1 — Model tolerance tests (BUG-B / BUG-G / SEC-1 DoS
/// defense-in-depth).
///
/// Pins the tolerant-parse contract introduced/extended by the v9.1 audit:
///   - `Application.fromFirestore` (BUG-B): a legacy mirror-only doc carrying
///     only `studentId` — or missing identity fields entirely — must parse
///     without throwing; the old null-unsafe `data['userId'] as String` cast
///     crashed the whole applicants query for that placement.
///   - `Application.isTextResume` (BUG-G): pasted-text applications (the
///     fallback path stores the raw text in `resumeUrl`) are detected so the
///     UI shows a text dialog instead of calling `launchUrl` on arbitrary
///     text (which threw a `FormatException`).
///   - `Placement.fromFirestore` (SEC-1 defense-in-depth): a malformed
///     placement doc (deadline as a String, postedAt missing, non-map
///     requirements) must degrade to sane fallbacks instead of crashing
///     every client rendering the placements list.
///
/// Uses the same `FakeDocumentSnapshot` pattern as `test/application_test.dart`.

void main() {
  group('Application.fromFirestore — BUG-B tolerant identity', () {
    test('legacy mirror-only doc with studentId (no userId) parses', () {
      final app = Application.fromFirestore(
        FakeDocumentSnapshot({
          'studentId': 'u1',
          'placementId': 'p1',
          'resume': 'https://storage.googleapis.com/legacy.pdf',
          'appliedAt': Timestamp.fromDate(DateTime(2026, 7, 1)),
          'status': 'applied',
        }),
      );
      expect(app.userId, 'u1');
      expect(app.placementId, 'p1');
      // Mirror-only docs carry `resume`, which falls back into resumeUrl.
      expect(
        app.resumeUrl,
        'https://storage.googleapis.com/legacy.pdf',
      );
      expect(app.status, 'applied');
    });

    test('doc with NEITHER userId nor studentId parses to empty (no crash)', () {
      final app = Application.fromFirestore(
        FakeDocumentSnapshot({
          'placementId': 'p1',
          'resumeUrl': 'https://x.pdf',
          'appliedAt': Timestamp.fromDate(DateTime(2026, 7, 1)),
        }),
      );
      expect(app.userId, '');
      expect(app.appliedAt, DateTime(2026, 7, 1));
    });

    test('missing appliedAt falls back to now instead of throwing', () {
      final before = DateTime.now();
      final app = Application.fromFirestore(
        FakeDocumentSnapshot({
          'userId': 'u1',
          'placementId': 'p1',
          'resumeUrl': '',
        }),
      );
      final after = DateTime.now();
      expect(
        app.appliedAt.isBefore(before) || app.appliedAt.isAfter(after),
        isFalse,
      );
    });

    test('missing status defaults to applied', () {
      final app = Application.fromFirestore(
        FakeDocumentSnapshot({
          'userId': 'u1',
          'placementId': 'p1',
          'resumeUrl': 'https://x.pdf',
          'appliedAt': Timestamp.fromDate(DateTime(2026, 7, 1)),
        }),
      );
      expect(app.status, 'applied');
    });
  });

  group('Application.isTextResume — BUG-G text-paste detection', () {
    test('a real https download URL is linkable, not a text resume', () {
      final app = _appWithResume(
        'https://firebasestorage.googleapis.com/v0/b/cc.appspot.com/o/'
        'resumes%2Fu1%2Fsnapshots%2Fapp.pdf?alt=media',
      );
      expect(app.isTextResume, isFalse);
    });

    test('an http link is linkable', () {
      expect(_appWithResume('http://example.com/resume.pdf').isTextResume, isFalse);
    });

    test('a gs:// GCS path is linkable', () {
      expect(_appWithResume('gs://bucket/resumes/u1/latest.pdf').isTextResume, isFalse);
    });

    test('a legacy resumes/ storage path is linkable', () {
      expect(_appWithResume('resumes/u1/latest.pdf').isTextResume, isFalse);
    });

    test('pasted plain text is a text resume', () {
      expect(
        _appWithResume(
          'B.Tech CSE, 8.2 CGPA\nWorked on Flutter apps at ABC Startup.',
        ).isTextResume,
        isTrue,
      );
    });

    test('empty resume is NOT a text resume (no resume at all)', () {
      expect(_appWithResume('').isTextResume, isFalse);
    });
  });

  group('Placement.fromFirestore — SEC-1 malformed-data tolerance', () {
    test('well-formed placement parses normally', () {
      final placement = Placement.fromFirestore(
        FakePlacementSnapshot({
          'company': 'Google',
          'role': 'SDE',
          'description': 'desc',
          'eligibility': 'CSE',
          'salary': '30 LPA',
          'deadline': Timestamp.fromDate(DateTime(2026, 12, 31)),
          'postedAt': Timestamp.fromDate(DateTime(2026, 8, 1)),
          'isActive': true,
        }),
      );
      expect(placement.company, 'Google');
      expect(placement.deadline, DateTime(2026, 12, 31));
      expect(placement.postedAt, DateTime(2026, 8, 1));
      expect(placement.isActive, isTrue);
    });

    test('deadline stored as a String degrades to a future fallback', () {
      final placement = Placement.fromFirestore(
        FakePlacementSnapshot({
          'company': 'Google',
          'deadline': '2026-12-31', // malformed — not a Timestamp
          'postedAt': Timestamp.fromDate(DateTime(2026, 8, 1)),
        }),
      );
      // Sanity: the fallback is a future date (now + 30 days), not a crash.
      expect(placement.deadline.isAfter(DateTime.now()), isTrue);
    });

    test('missing postedAt degrades to now instead of throwing', () {
      final placement = Placement.fromFirestore(
        FakePlacementSnapshot({
          'company': 'Google',
          'deadline': Timestamp.fromDate(DateTime(2026, 12, 31)),
        }),
      );
      expect(
        placement.postedAt.difference(DateTime.now()).inSeconds.abs(),
        lessThan(5),
      );
    });

    test('missing optional fields produce empty/fallback strings', () {
      final placement = Placement.fromFirestore(
        FakePlacementSnapshot({
          'company': 'Google',
          'deadline': Timestamp.fromDate(DateTime(2026, 12, 31)),
          'postedAt': Timestamp.fromDate(DateTime(2026, 8, 1)),
        }),
      );
      expect(placement.role, '');
      expect(placement.description, '');
      expect(placement.eligibility, '');
      expect(placement.salary, 'Not Specified');
      expect(placement.isActive, isTrue); // defaults to true
    });

    test('non-map requirements degrade to an open-to-all empty parser', () {
      final placement = Placement.fromFirestore(
        FakePlacementSnapshot({
          'company': 'Google',
          'requirements': 'not-a-map', // malformed
          'deadline': Timestamp.fromDate(DateTime(2026, 12, 31)),
          'postedAt': Timestamp.fromDate(DateTime(2026, 8, 1)),
        }),
      );
      expect(placement.requirements.isOpenToAll, isTrue);
    });

    test('completely empty doc renders a non-crashing placement', () {
      final placement = Placement.fromFirestore(FakePlacementSnapshot({}));
      expect(placement.id, 'p_empty');
      expect(placement.company, '');
      expect(placement.isDeadlinePassed, isFalse);
    });
  });
}

Application _appWithResume(String resumeUrl) => Application(
  id: 'a1',
  userId: 'u1',
  placementId: 'p1',
  resumeUrl: resumeUrl,
  appliedAt: DateTime(2026, 7, 1),
  status: 'applied',
);

// ignore: subtype_of_sealed_class
/// Minimal DocumentSnapshot stand-in (same pattern as test/application_test.dart).
class FakeDocumentSnapshot implements DocumentSnapshot<Map<String, dynamic>> {
  final Map<String, dynamic> _data;

  FakeDocumentSnapshot(this._data);

  @override
  String get id => 'app_a1';

  @override
  Map<String, dynamic> data() => _data;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ignore: subtype_of_sealed_class
/// Placement variant of the DocumentSnapshot stand-in (id `p_empty` for the
/// empty-doc test).
class FakePlacementSnapshot implements DocumentSnapshot<Map<String, dynamic>> {
  final Map<String, dynamic> _data;

  FakePlacementSnapshot(this._data);

  @override
  String get id => 'p_empty';

  @override
  Map<String, dynamic> data() => _data;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

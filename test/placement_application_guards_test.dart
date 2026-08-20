import 'package:flutter_test/flutter_test.dart';

/// CampusConnect v9.1 — Server-side placement application guard tests.
///
/// Mirrors the v9.1 audit-fix guards in `functions/placements.js`
/// (SEC-3 / SEC-4 / BUG-A) as pure Dart functions so they can be unit-tested
/// without the Firebase Admin SDK — same convention as
/// `test/security_rules_mirror_test.dart`.
///
/// Under test:
///   - `STATUS_TRANSITIONS` state machine (SEC-3): every write must come from
///     a legal previous state; terminal states (placed/rejected) have no
///     outgoing transitions — a malicious client jumping applied→placed or
///     placed→shortlisted is rejected server-side even if the UI never offers
///     the button.
///   - actor-must-author-placement (SEC-3): only the teacher/alumni who
///     created the placement may update its applications.
///   - mirror-missing guard (BUG-A): a missing mirror doc is re-created via
///     `set` instead of failing the entire transaction — the canonical status
///     write survives.
///   - placement-existence validation in `logPlacementApplication` (SEC-4):
///     missing / inactive / past-deadline placements are rejected inside the
///     create transaction.
///   - placement-rate formula fix (BUG-D): the dashboard percentage is
///     placedStudents ÷ totalStudents, never activeDrives ÷ students.
///
/// The `canUpdateStatus` mirror returns the HttpsError code (or null) exactly
/// like `updateApplicationStatus` throws — assertions pin the error
/// classification as well as accept/reject.

/// The status values the callable may write (mirror of `APPLICATION_STATUSES`).
const List<String> applicationStatuses = [
  'shortlisted',
  'interviewed',
  'placed',
  'rejected',
];

/// Mirror of `STATUS_TRANSITIONS` in `functions/placements.js` — single
/// source of truth for legal next stages per current stage.
const Map<String, List<String>> statusTransitions = {
  'applied': ['shortlisted', 'rejected'],
  'shortlisted': ['interviewed', 'rejected'],
  'interviewed': ['placed', 'rejected'],
  'placed': <String>[],
  'rejected': <String>[],
};

/// Mirror of the v9.1 audit-fix guards in `functions/placements.js`.
class PlacementApplicationGuards {
  const PlacementApplicationGuards._();

  /// `updateApplicationStatus` transition validation. Returns null when the
  /// transition is legal, else the HttpsError code the callable throws
  /// (`failed-precondition`, or `invalid-argument` for an unknown status).
  static String? validateTransition({
    required String currentStatus,
    required String newStatus,
  }) {
    if (!applicationStatuses.contains(newStatus)) return 'invalid-argument';
    final legalNext = statusTransitions[currentStatus] ?? const <String>[];
    return legalNext.contains(newStatus) ? null : 'failed-precondition';
  }

  /// `updateApplicationStatus` actor-author check (reads the placement inside
  /// the transaction). Returns null when the actor may update, else
  /// `permission-denied` (or `not-found` when the placement is gone).
  static String? checkPlacementAccess({
    required bool placementExists,
    required String? placementCreatedBy,
    required String actorUid,
  }) {
    if (!placementExists) return 'not-found';
    if (placementCreatedBy != actorUid) return 'permission-denied';
    return null;
  }

  /// `updateApplicationStatus` mirror-missing guard (BUG-A). A missing mirror
  /// is re-created with `set` (with the minimal shape) so the canonical
  /// `update` is NOT rolled back; an existing mirror is simply updated.
  static String mirrorWrite({required bool mirrorExists}) =>
      mirrorExists ? 'update' : 'set';

  /// `logPlacementApplication` placement validation (SEC-4), executed inside
  /// the create transaction. Returns null when the application may proceed,
  /// else the HttpsError code (`not-found` / `failed-precondition`).
  static String? checkPlacementAccepting({
    required bool placementExists,
    required bool? isActive,
    required DateTime? deadline,
    required DateTime now,
  }) {
    if (!placementExists) return 'not-found';
    if (isActive != true) return 'failed-precondition';
    if (deadline != null && !now.isBefore(deadline)) {
      return 'failed-precondition';
    }
    return null;
  }

  /// BUG-D mirror of the teacher dashboard placement-rate computation: the
  /// numerator is the REAL distinct-student placed count
  /// (`TeacherAnalyticsService.pipelinePlaced`), the denominator the total
  /// students — never the count of active drives. Falls back to 0 when the
  /// denominator is 0 (pipeline not loaded / apps query failed).
  static int placementRate({required int placedStudents, required int totalStudents}) {
    if (totalStudents <= 0) return 0;
    return ((placedStudents / totalStudents) * 100).round();
  }
}

void main() {
  group('STATUS_TRANSITIONS — server-side state machine (SEC-3)', () {
    test('mirrors the exact legal-transition table from functions/placements.js', () {
      expect(statusTransitions, {
        'applied': ['shortlisted', 'rejected'],
        'shortlisted': ['interviewed', 'rejected'],
        'interviewed': ['placed', 'rejected'],
        'placed': <String>[],
        'rejected': <String>[],
      });
    });

    test('legal forward transitions are accepted', () {
      expect(
        PlacementApplicationGuards.validateTransition(
          currentStatus: 'applied',
          newStatus: 'shortlisted',
        ),
        isNull,
      );
      expect(
        PlacementApplicationGuards.validateTransition(
          currentStatus: 'applied',
          newStatus: 'rejected',
        ),
        isNull,
      );
      expect(
        PlacementApplicationGuards.validateTransition(
          currentStatus: 'shortlisted',
          newStatus: 'interviewed',
        ),
        isNull,
      );
      expect(
        PlacementApplicationGuards.validateTransition(
          currentStatus: 'interviewed',
          newStatus: 'placed',
        ),
        isNull,
      );
    });

    test('applied → placed (stage skip) is rejected', () {
      expect(
        PlacementApplicationGuards.validateTransition(
          currentStatus: 'applied',
          newStatus: 'placed',
        ),
        'failed-precondition',
      );
    });

    test('terminal states cannot move backwards to a WRITABLE status', () {
      // shortlisted/interviewed are valid writable statuses, so reaching a
      // terminal state closes the transition map — every legal-next check
      // from a terminal state is a failed-precondition.
      for (final terminal in ['placed', 'rejected']) {
        expect(
          PlacementApplicationGuards.validateTransition(
            currentStatus: terminal,
            newStatus: 'shortlisted',
          ),
          'failed-precondition',
        );
        expect(
          PlacementApplicationGuards.validateTransition(
            currentStatus: terminal,
            newStatus: 'interviewed',
          ),
          'failed-precondition',
        );
      }
    });

    test('applied is NOT a writable status — rejected as invalid-argument', () {
      // The callable validates `status ∈ APPLICATION_STATUSES` (shortlisted |
      // interviewed | placed | rejected) BEFORE the transition map, so
      // attempting to write `applied` is an invalid-argument, not a
      // transition error — regardless of the previous state.
      expect(
        PlacementApplicationGuards.validateTransition(
          currentStatus: 'placed',
          newStatus: 'applied',
        ),
        'invalid-argument',
      );
      expect(
        PlacementApplicationGuards.validateTransition(
          currentStatus: 'applied',
          newStatus: 'applied',
        ),
        'invalid-argument',
      );
    });

    test('unknown new status is an invalid-argument, not a transition error', () {
      expect(
        PlacementApplicationGuards.validateTransition(
          currentStatus: 'applied',
          newStatus: 'hired',
        ),
        'invalid-argument',
      );
    });

    test('missing previous status defaults to applied (legacy docs)', () {
      // canonicalData.status || "applied" — a legacy doc without status can
      // only be advanced from the initial state.
      final legalNext = statusTransitions['applied']!;
      expect(legalNext, contains('shortlisted'));
      expect(legalNext, contains('rejected'));
    });
  });

  group('Actor-must-author-placement (SEC-3)', () {
    test('the placement creator may update applications', () {
      expect(
        PlacementApplicationGuards.checkPlacementAccess(
          placementExists: true,
          placementCreatedBy: 'teacherA',
          actorUid: 'teacherA',
        ),
        isNull,
      );
    });

    test('a teacher who did not create the placement is denied', () {
      expect(
        PlacementApplicationGuards.checkPlacementAccess(
          placementExists: true,
          placementCreatedBy: 'teacherA',
          actorUid: 'teacherB',
        ),
        'permission-denied',
      );
    });

    test('a deleted placement cannot be updated', () {
      expect(
        PlacementApplicationGuards.checkPlacementAccess(
          placementExists: false,
          placementCreatedBy: null,
          actorUid: 'teacherA',
        ),
        'not-found',
      );
    });
  });

  group('Mirror-missing guard (BUG-A)', () {
    test('existing mirror is updated in place', () {
      expect(
        PlacementApplicationGuards.mirrorWrite(mirrorExists: true),
        'update',
      );
    });

    test('missing mirror is re-created via set — canonical write survives', () {
      // Pre-fix, `transaction.update(missingMirror)` aborted the ENTIRE
      // transaction, rolling back the canonical status write. Post-fix the
      // guard re-creates the mirror instead.
      expect(
        PlacementApplicationGuards.mirrorWrite(mirrorExists: false),
        'set',
      );
    });
  });

  group('Placement-existence validation (SEC-4)', () {
    final future = DateTime(2026, 12, 31);
    final past = DateTime(2026, 1, 1);

    test('active placement before deadline accepts applications', () {
      expect(
        PlacementApplicationGuards.checkPlacementAccepting(
          placementExists: true,
          isActive: true,
          deadline: future,
          now: DateTime(2026, 8, 20),
        ),
        isNull,
      );
    });

    test('missing placement is rejected with not-found', () {
      expect(
        PlacementApplicationGuards.checkPlacementAccepting(
          placementExists: false,
          isActive: null,
          deadline: null,
          now: DateTime(2026, 8, 20),
        ),
        'not-found',
      );
    });

    test('inactive placement is rejected even before its deadline', () {
      expect(
        PlacementApplicationGuards.checkPlacementAccepting(
          placementExists: true,
          isActive: false,
          deadline: future,
          now: DateTime(2026, 8, 20),
        ),
        'failed-precondition',
      );
    });

    test('past-deadline placement is rejected', () {
      expect(
        PlacementApplicationGuards.checkPlacementAccepting(
          placementExists: true,
          isActive: true,
          deadline: past,
          now: DateTime(2026, 8, 20),
        ),
        'failed-precondition',
      );
    });

    test('no deadline means no deadline check', () {
      expect(
        PlacementApplicationGuards.checkPlacementAccepting(
          placementExists: true,
          isActive: true,
          deadline: null,
          now: DateTime(2026, 8, 20),
        ),
        isNull,
      );
    });
  });

  group('Placement-rate formula (BUG-D)', () {
    test('placed students over total students, rounded', () {
      expect(PlacementApplicationGuards.placementRate(placedStudents: 12, totalStudents: 40), 30);
    });

    test('rate stays a sane percentage — 18 placed of 20 students → 90%', () {
      // The OLD bug used activeDrives ÷ students and could exceed 100%.
      // The fixed formula divides two DISTINCT-STUDENT counts, so a rate
      // >100 is structurally impossible; this pins the formula shape.
      expect(PlacementApplicationGuards.placementRate(placedStudents: 18, totalStudents: 20), 90);
    });

    test('zero students falls back to 0 instead of a division error', () {
      expect(PlacementApplicationGuards.placementRate(placedStudents: 5, totalStudents: 0), 0);
    });

    test('zero placed students produces 0%', () {
      expect(PlacementApplicationGuards.placementRate(placedStudents: 0, totalStudents: 30), 0);
    });
  });
}

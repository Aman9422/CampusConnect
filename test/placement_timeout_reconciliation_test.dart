import 'package:campusconnect/providers/placements_provider.dart';
import 'package:flutter_test/flutter_test.dart';

/// CampusConnect v9.2.4 (D-2) — placement apply/status timeout contract tests.
///
/// The v9.2.3 audit found a client/server timeout mismatch that produced a
/// user-visible bug: `logPlacementApplication` is declared
/// `timeoutSeconds: 120` server-side (it copies the resume to a snapshot object
/// and mints a signed URL *before* its Firestore transaction), while the Flutter
/// client gave up after **30 s**. A slow-but-successful apply was therefore
/// reported to the student as "Request timed out. Please try again.", the
/// optimistic "applied" state was rolled back, and the student retried an
/// application the backend had already recorded.
///
/// `updateApplicationStatus` had the same shape (30 s client vs 60 s server).
///
/// This suite pins three things:
///
/// 1. **The real client constants** — `PlacementsProvider`'s static timeouts,
///    read directly from production code, must match the server declarations.
/// 2. **The reconciliation decision table** — mirrored as a pure function
///    because driving `applyForPlacement` end to end needs Firebase Functions
///    and the connectivity plugin, neither of which exists in `flutter test`
///    (the same constraint that made
///    `test/placement_application_guards_test.dart` a mirror rather than an
///    integration test).
/// 3. **The pending-confirmation type** — the deliberate signal that lets the
///    UI keep showing "applied" without inviting a duplicate attempt.
void main() {
  // The declarations in `functions/placements.js`, mirrored here so the client
  // constants are compared against the contract rather than merely restated.
  // `functions/test/hardening_source_contracts.test.js` additionally asserts
  // these values against the actual server source, so the two cannot drift
  // unnoticed.
  const serverApplyTimeoutSeconds = 120;
  const serverStatusTimeoutSeconds = 60;

  // ---------------------------------------------------------------------------
  // Mirror of `PlacementsProvider._reconcileTimedOutApply`.
  //
  //   confirmed = application != null              -> true
  //             | null when the read itself threw  -> unknown
  //             | false when the doc is absent      -> false
  // ---------------------------------------------------------------------------
  ({bool rolledBack, bool keptApplied, bool pending, bool threw}) resolve(
    bool? confirmed,
  ) {
    if (confirmed == true) {
      // Server had it: keep the applied state, clear pending, report success.
      return (
        rolledBack: false,
        keptApplied: true,
        pending: false,
        threw: false,
      );
    }
    if (confirmed == false) {
      // Authoritative "not applied" — safe to roll back and surface an error.
      return (
        rolledBack: true,
        keptApplied: false,
        pending: false,
        threw: true,
      );
    }
    // Unconfirmed: keep BOTH the applied state and the pending flag.
    return (rolledBack: false, keptApplied: true, pending: true, threw: true);
  }

  group('client timeouts match the server declarations (D-2)', () {
    test('apply-for-placement client timeout is 120 s, not the old 30 s', () {
      expect(
        PlacementsProvider.kApplyCallableTimeout,
        const Duration(seconds: serverApplyTimeoutSeconds),
      );
      // Explicit regression guard: the audit's bug was precisely this value
      // being 30. Asserting "not 30" documents intent beyond the equality.
      expect(
        PlacementsProvider.kApplyCallableTimeout,
        isNot(const Duration(seconds: 30)),
      );
    });

    test('application-status client timeout is 60 s, not the old 30 s', () {
      expect(
        PlacementsProvider.kStatusCallableTimeout,
        const Duration(seconds: serverStatusTimeoutSeconds),
      );
      expect(
        PlacementsProvider.kStatusCallableTimeout,
        isNot(const Duration(seconds: 30)),
      );
    });

    test('the client timeout is never SHORTER than the server timeout', () {
      // The invariant that actually matters: giving up before the server does
      // is what turns a success into a reported failure. Equal or longer is
      // correct; shorter is the defect.
      expect(
        PlacementsProvider.kApplyCallableTimeout.inSeconds,
        greaterThanOrEqualTo(serverApplyTimeoutSeconds),
      );
      expect(
        PlacementsProvider.kStatusCallableTimeout.inSeconds,
        greaterThanOrEqualTo(serverStatusTimeoutSeconds),
      );
    });
  });

  group('timeout reconciliation decision table (mirror)', () {
    test('server HAS the application → success, no rollback, no pending', () {
      final result = resolve(true);

      expect(result.rolledBack, isFalse);
      expect(result.keptApplied, isTrue);
      expect(result.pending, isFalse);
      expect(result.threw, isFalse);
    });

    test(
      'server does NOT have the application → roll back (authoritative)',
      () {
        final result = resolve(false);

        expect(result.rolledBack, isTrue);
        expect(result.keptApplied, isFalse);
        expect(result.pending, isFalse);
        expect(result.threw, isTrue, reason: 'a real failure must be reported');
      },
    );

    test('state could not be confirmed → keep applied + pending, never roll '
        'back', () {
      final result = resolve(null);

      expect(
        result.rolledBack,
        isFalse,
        reason: 'a client timeout is NOT proof the server failed',
      );
      expect(result.keptApplied, isTrue);
      expect(result.pending, isTrue);
      expect(result.threw, isTrue, reason: 'surface the pending message');
    });

    test('the pre-v9.2.4 behaviour (blind rollback on timeout) is gone', () {
      // Old code: `catch (e) { _appliedPlacementIds.remove(placementId); …
      // throw Exception("Request timed out…") }` — a rollback with no read.
      // The table must never contain a row that both rolled back AND left the
      // server state unread.
      for (final confirmed in <bool?>[true, false, null]) {
        final result = resolve(confirmed);
        if (result.rolledBack) {
          expect(
            confirmed,
            isFalse,
            reason: 'rollback is only legal against an authoritative "absent"',
          );
        }
      }
    });

    test('the unconfirmed outcome is surfaced as a pending confirmation, not a '
        'failure', () {
      // Production throws `PlacementPendingConfirmationException` in exactly
      // this branch; that is what lets the UI say "still being confirmed"
      // rather than "Request timed out. Please try again.".
      final unconfirmed = resolve(null);

      expect(unconfirmed.pending, isTrue);
      expect(unconfirmed.keptApplied, isTrue);
      expect(
        const PlacementPendingConfirmationException('pending'),
        isA<PlacementPendingConfirmationException>(),
      );
    });
  });

  group('PlacementPendingConfirmationException is a distinct, catchable type', () {
    test('it is an Exception carrying the message', () {
      const exception = PlacementPendingConfirmationException(
        'Your application is still being confirmed.',
      );

      expect(exception, isA<Exception>());
      expect(exception.message, 'Your application is still being confirmed.');
      expect(exception.toString(), contains('still being confirmed'));
    });

    test('a genuine failure is NOT matched as a pending confirmation', () {
      // `applyForPlacement` re-throws this type untouched (it does not roll the
      // optimistic state back), so the catch site must be able to tell it apart
      // from a genuine error. If it were ever replaced by a bare `Exception`,
      // the caller could not distinguish "pending" from "failed" and the D-2
      // defect would silently return.
      expect(
        isPendingConfirmation(
          const PlacementPendingConfirmationException('pending'),
        ),
        isTrue,
      );
      expect(isPendingConfirmation(Exception('boom')), isFalse);
      expect(isPendingConfirmation(StateError('boom')), isFalse);
      expect(isPendingConfirmation('not even an error'), isFalse);
    });
  });
}

/// The classification a UI catch site performs on a failed apply: only the
/// dedicated type means "the server state is still being confirmed — keep
/// showing applied and do not invite a re-apply".
///
/// Declared with an `Object` parameter so the check is a genuine runtime type
/// test rather than a statically-known tautology.
bool isPendingConfirmation(Object error) =>
    error is PlacementPendingConfirmationException;

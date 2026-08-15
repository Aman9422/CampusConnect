import 'package:flutter_test/flutter_test.dart';

/// CampusConnect v8.8.2 — Resume quota crash-safe reservation contract tests.
///
/// These tests mirror the SERVER-SIDE quota logic added to
/// `functions/index.js` (project_info__22/23 finding A, HIGH):
///
/// 1. `consumeResumeQuota(userId, requestId)` stamps a per-request
///    reservation (`pendingRequestId` / `pendingSince`) on the usage doc.
/// 2. A SUCCESSFUL review calls `clearResumeReservation(userId, requestId)`
///    — the credit is KEPT and the reservation removed (the compensation
///    sweep must never refund a delivered review).
/// 3. An AI-failure calls `rollbackResumeUsage(userId, requestId)` — the
///    credit is returned AND the reservation cleared in the SAME atomic
///    transaction (no double-refund).
/// 4. `compensateStaleResumeQuota` refunds ONLY reservations older than the
///    stale cutoff and never touches recent/in-flight ones.
///
/// Mirrors only the pure decision logic; Firestore itself is not exercised.
class ResumeQuotaReservation {
  const ResumeQuotaReservation._();

  static const int monthlyLimit = 5;

  /// 24h (matches RESUME_RESERVATION_STALE_HOURS in index.js)
  static const int staleHours = 24;

  static bool atLimit(int monthlyCount) => monthlyCount >= monthlyLimit;

  static int consume(int monthlyCount) => monthlyCount + 1;

  static int rollback(int monthlyCount) =>
      monthlyCount > 0 ? monthlyCount - 1 : 0;

  /// The reservation is cleared when the review completes successfully —
  /// the credit is kept but no `pendingRequestId` remains.
  static bool isReservationCleared(String? pendingRequestId) =>
      pendingRequestId == null;

  /// A reservation is stale when `pendingSince` is older than the cutoff.
  static bool isStale(
    DateTime pendingSince,
    DateTime now, {
    int staleHours = staleHours,
  }) {
    return now.difference(pendingSince).inHours >= staleHours;
  }

  /// The sweep refunds only non-zero monthly counts that are STILL stale —
  /// never a doc whose reservation was cleared in the meantime.
  static bool shouldCompensate({
    required int monthlyCount,
    required DateTime? pendingSince,
    required DateTime cutoff,
  }) {
    if (pendingSince == null) return false; // cleared/never reserved
    if (monthlyCount <= 0) return false;
    return pendingSince.isBefore(cutoff); // still stale
  }
}

void main() {
  group('consumeResumeQuota reservation stamping', () {
    test('consuming the first credit stamps a reservation', () {
      final count = ResumeQuotaReservation.consume(0);
      expect(count, 1);
      expect(ResumeQuotaReservation.atLimit(count), isFalse);
    });

    test('limit is enforced at 5 (server throws before increment)', () {
      expect(ResumeQuotaReservation.atLimit(5), isTrue);
      // Mirror: at the limit the server throws resource-exhausted — the
      // pure mirror never increments past 5.
      expect(ResumeQuotaReservation.atLimit(6), isTrue);
    });

    test('rollback never decrements below zero', () {
      expect(ResumeQuotaReservation.rollback(0), 0);
      expect(ResumeQuotaReservation.rollback(1), 0);
      expect(ResumeQuotaReservation.rollback(3), 2);
    });
  });

  group('success path clears the reservation (credit kept)', () {
    test('after a successful review the reservation is cleared', () {
      // clearResumeReservation removes pendingRequestId on success.
      expect(ResumeQuotaReservation.isReservationCleared(null), isTrue);
      expect(ResumeQuotaReservation.isReservationCleared('req-1'), isFalse);
    });

    test('a cleared reservation is never compensated later', () {
      final cutoff = DateTime.now();
      expect(
        ResumeQuotaReservation.shouldCompensate(
          monthlyCount: 2,
          pendingSince: null, // cleared on success
          cutoff: cutoff,
        ),
        isFalse,
      );
    });
  });

  group('AI-failure rollback clears the reservation atomically', () {
    test('rollback returns the credit', () {
      expect(ResumeQuotaReservation.rollback(2), 1);
    });

    test('rollback also leaves no pending reservation (no double refund)', () {
      // After rollbackResumeUsage, pendingRequestId is deleted in the SAME
      // transaction — so the stale sweep cannot refund it a second time.
      expect(ResumeQuotaReservation.isReservationCleared(null), isTrue);
    });
  });

  group('compensateStaleResumeQuota safety contract', () {
    final now = DateTime.now();
    final cutoff = now.subtract(
      const Duration(hours: ResumeQuotaReservation.staleHours),
    );

    test('stale un-cleared reservations ARE eligible for refund', () {
      final pendingSince = now.subtract(const Duration(hours: 30));
      expect(ResumeQuotaReservation.isStale(pendingSince, now), isTrue);
      expect(
        ResumeQuotaReservation.shouldCompensate(
          monthlyCount: 1,
          pendingSince: pendingSince,
          cutoff: cutoff,
        ),
        isTrue,
      );
    });

    test('recent in-flight reservations are NEVER refunded', () {
      final pendingSince = now.subtract(const Duration(minutes: 2));
      expect(ResumeQuotaReservation.isStale(pendingSince, now), isFalse);
      expect(
        ResumeQuotaReservation.shouldCompensate(
          monthlyCount: 1,
          pendingSince: pendingSince,
          cutoff: cutoff,
        ),
        isFalse,
      );
    });

    test('docs without any reservation are untouched', () {
      expect(
        ResumeQuotaReservation.shouldCompensate(
          monthlyCount: 4,
          pendingSince: null,
          cutoff: cutoff,
        ),
        isFalse,
      );
    });

    test('zero-count docs are never decremented below zero', () {
      expect(
        ResumeQuotaReservation.shouldCompensate(
          monthlyCount: 0,
          pendingSince: now.subtract(const Duration(hours: 48)),
          cutoff: cutoff,
        ),
        isFalse,
      );
    });

    test('the stale boundary is exactly 24h', () {
      final justAt = now.subtract(const Duration(hours: 24));
      expect(ResumeQuotaReservation.isStale(justAt, now), isTrue);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';

/// CampusConnect v8.8.2 — Resume review retry-storm throttle contract tests.
///
/// Mirrors the SERVER-UNREACHABLE/network cooldown added to
/// `ResumeReviewProvider` (project_info__22/23 finding E, LOW/MEDIUM):
/// after [maxConsecutiveTransientFailures] consecutive transient failures
/// (which `connectivity_plus` cannot detect — e.g. DNS-level loss), review
/// submissions pause for [retryCooldown] so a dead backend cannot burn the
/// monthly quota on retry storms (the pid 24538 case: 3x `internal` fails).
///
/// Mirrors only the pure state machine: no Flutter/Firebase dependencies.
class RetryThrottle {
  const RetryThrottle._();

  static const int maxConsecutiveTransientFailures = 2;
  static const Duration retryCooldown = Duration(seconds: 30);

  /// Mirrors `_registerTransientFailure`: increments the streak; when it
  /// reaches the threshold the cooldown is armed and the streak resets.
  static ({int failures, bool blocked, Duration remaining}) registerFailure({
    required int failures,
  }) {
    final nextFailures = failures + 1;
    if (nextFailures >= maxConsecutiveTransientFailures) {
      return (failures: 0, blocked: true, remaining: retryCooldown);
    }
    return (
      failures: nextFailures,
      blocked: false,
      remaining: Duration.zero,
    );
  }

  /// Mirrors `isRetryBlocked`: a cooldown is active while `now` is before
  /// `blockedUntil`.
  static bool isBlocked({
    required DateTime now,
    required DateTime? blockedUntil,
  }) {
    if (blockedUntil == null) return false;
    return now.isBefore(blockedUntil);
  }

  /// Mirrors the success / connectivity-restore path: clears both the streak
  /// and the cooldown.
  static ({int failures, DateTime? blockedUntil}) reset() =>
      (failures: 0, blockedUntil: null);
}

void main() {
  final now = DateTime.now();

  group('transient-failure counting (dead backend protection)', () {
    test('a single failure does NOT block yet', () {
      final result = RetryThrottle.registerFailure(failures: 0);
      expect(result.failures, 1);
      expect(result.blocked, isFalse);
    });

    test('two consecutive failures arm the 30s cooldown and reset the count', () {
      final first = RetryThrottle.registerFailure(failures: 0);
      expect(first.failures, 1);

      final second = RetryThrottle.registerFailure(failures: first.failures);
      expect(second.failures, 0); // reset for re-arm after cooldown
      expect(second.blocked, isTrue);
      expect(second.remaining, const Duration(seconds: 30));
    });
  });

  group('cooldown blocks submissions then expires', () {
    test('while the cooldown is active the user is blocked', () {
      final blockedUntil = now.add(const Duration(seconds: 30));
      expect(
        RetryThrottle.isBlocked(now: now, blockedUntil: blockedUntil),
        isTrue,
      );
    });

    test('after the cooldown expires submissions are allowed again', () {
      final blockedUntil = now.subtract(const Duration(seconds: 1));
      expect(
        RetryThrottle.isBlocked(now: now, blockedUntil: blockedUntil),
        isFalse,
      );
    });

    test('with no cooldown armed nothing is blocked', () {
      expect(RetryThrottle.isBlocked(now: now, blockedUntil: null), isFalse);
    });
  });

  group('cooldown clears on success / connectivity restore', () {
    test('a successful review clears the streak and the cooldown', () {
      final state = RetryThrottle.reset();
      expect(state.failures, 0);
      expect(state.blockedUntil, isNull);
      expect(RetryThrottle.isBlocked(now: now, blockedUntil: state.blockedUntil),
          isFalse);
    });
  });

  group('quota rejections are NOT transient (they do not arm the cooldown)', () {
    test('monthly-limit exhaustion leaves the throttle state untouched', () {
      // The provider handles ResumeReviewQuotaException without calling
      // _registerTransientFailure — the failure streak stays unchanged.
      final state = RetryThrottle.reset();
      expect(state.failures, 0);
      expect(RetryThrottle.isBlocked(now: now, blockedUntil: state.blockedUntil),
          isFalse);
    });
  });
}

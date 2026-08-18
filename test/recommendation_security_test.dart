import 'package:flutter_test/flutter_test.dart';

/// CampusConnect v8.9 — Recommendation Security contract tests.
///
/// Mirrors the security model in `firestore.rules` + `functions/index.js`:
///   - Students own their recommendations: owner read, `write: false` for
///     all clients (single writer is the server engine).
///   - Students can never modify another student's recommendations.
///   - Teachers may READ the `recommendations` collectionGroup for aggregate
///     intelligence only — and only when authenticated as role=teacher.
///   - The refresh callable requires `request.auth.uid`.
///   - Eligibility is deterministic server-side — AI can never override.
///
/// Pure-Dart mirror pattern — no Firebase, no API keys.

/// Mirrors `users/{userId}/recommendations/{recommendationId}` rules:
/// `allow read: if isOwner(userId); allow write: if false;`
class RecommendationRules {
  const RecommendationRules._();

  static bool canRead({
    required bool isAuthenticated,
    required String resourceUserId,
    required String authUid,
  }) => isAuthenticated && resourceUserId == authUid;

  static bool canWrite() => false; // Cloud Functions are the single writer.
}

/// Mirrors `match /{path=**}/recommendations/{id} { allow read: if isTeacher(); }`.
class RecommendationTeacherReadRules {
  const RecommendationTeacherReadRules._();

  static bool canTeacherRead({
    required bool isAuthenticated,
    required String? userRole,
  }) => isAuthenticated && userRole == 'teacher';
}

/// Mirrors the callable gate: `request.auth?.uid` must exist.
class RefreshCallableAuth {
  const RefreshCallableAuth._();

  static bool isAuthorized({required String? authUid}) =>
      authUid != null && authUid.isNotEmpty;
}

/// Mirrors `checkMandatoryEligibility` — deterministic, AI never consulted.
class DeterministicEligibility {
  const DeterministicEligibility._();

  static bool allowsRecommendation({
    required bool isActive,
    required bool alreadyApplied,
    required bool deadlinePassed,
  }) {
    if (!isActive) return false;
    if (alreadyApplied) return false;
    if (deadlinePassed) return false;
    return true;
  }
}

void main() {
  group('recommendation ownership — owner read, write:false', () {
    test('the owner can read their own recommendations', () {
      expect(
        RecommendationRules.canRead(
          isAuthenticated: true,
          resourceUserId: 'u1',
          authUid: 'u1',
        ),
        isTrue,
      );
    });

    test('Student A can never read Student B\'s recommendations', () {
      expect(
        RecommendationRules.canRead(
          isAuthenticated: true,
          resourceUserId: 'u2',
          authUid: 'u1',
        ),
        isFalse,
      );
    });

    test('unauthenticated read is denied even with a matching uid string', () {
      expect(
        RecommendationRules.canRead(
          isAuthenticated: false,
          resourceUserId: 'u1',
          authUid: 'u1',
        ),
        isFalse,
      );
    });

    test(
      'client write is denied for everyone — server is the single writer',
      () {
        expect(RecommendationRules.canWrite(), isFalse);
      },
    );
  });

  group('teacher aggregate read — collectionGroup only', () {
    test('a teacher can read recommendation docs for aggregates', () {
      expect(
        RecommendationTeacherReadRules.canTeacherRead(
          isAuthenticated: true,
          userRole: 'teacher',
        ),
        isTrue,
      );
    });

    test('students and alumni cannot read the collectionGroup', () {
      expect(
        RecommendationTeacherReadRules.canTeacherRead(
          isAuthenticated: true,
          userRole: 'student',
        ),
        isFalse,
      );
      expect(
        RecommendationTeacherReadRules.canTeacherRead(
          isAuthenticated: true,
          userRole: 'alumni',
        ),
        isFalse,
      );
    });

    test('unauthenticated users cannot read the collectionGroup', () {
      expect(
        RecommendationTeacherReadRules.canTeacherRead(
          isAuthenticated: false,
          userRole: null,
        ),
        isFalse,
      );
    });
  });

  group('callable authentication — refresh path', () {
    test('a signed-in uid can trigger a refresh', () {
      expect(RefreshCallableAuth.isAuthorized(authUid: 'u1'), isTrue);
    });

    test('unauthenticated callable requests are rejected', () {
      expect(RefreshCallableAuth.isAuthorized(authUid: null), isFalse);
      expect(RefreshCallableAuth.isAuthorized(authUid: ''), isFalse);
    });
  });

  group('deterministic eligibility — AI can never override', () {
    test('eligible opportunities are recommended', () {
      expect(
        DeterministicEligibility.allowsRecommendation(
          isActive: true,
          alreadyApplied: false,
          deadlinePassed: false,
        ),
        isTrue,
      );
    });

    test('inactive, already-applied and deadline-passed are all rejected', () {
      expect(
        DeterministicEligibility.allowsRecommendation(
          isActive: false,
          alreadyApplied: false,
          deadlinePassed: false,
        ),
        isFalse,
      );
      expect(
        DeterministicEligibility.allowsRecommendation(
          isActive: true,
          alreadyApplied: true,
          deadlinePassed: false,
        ),
        isFalse,
      );
      expect(
        DeterministicEligibility.allowsRecommendation(
          isActive: true,
          alreadyApplied: false,
          deadlinePassed: true,
        ),
        isFalse,
      );
    });
  });
}

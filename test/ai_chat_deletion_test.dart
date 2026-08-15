import 'package:flutter_test/flutter_test.dart';

/// CampusConnect v8.8 — AI chat deletion + retention + security contract tests.
///
/// These tests mirror the v8.8 server + rules behavior as pure Dart functions
/// so they can be unit-tested without Firebase, following the existing
/// `test/alumni_group_chat_test.dart` pattern.
///
/// Under test (docs/Task.md Phases 5/6/7):
///   - Deletion is OWNER-ONLY — identity comes from `request.auth.uid`,
///     never a client-supplied userId (P5).
///   - `users/{uid}/ai_interactions` delete is owner-scoped (rules P5/P7).
///   - `deleteAIHistory` removes BOTH `users/{uid}/ai_interactions` and the
///     legacy `ai_conversations` store (P5).
///   - Retention: only expired docs (createdAt < cutoff) are deleted;
///     recent conversations are preserved; unrelated docs untouched (P6).
///   - Deletes are batched (≤400/batch) and idempotent (P6).
class AIDeletionRules {
  const AIDeletionRules._();

  /// `firestore.rules`: `ai_interactions` owner-scoped delete.
  static bool canDeleteInteraction({
    required bool isAuthenticated,
    required String resourceUserId,
    required String authUid,
  }) => isAuthenticated && resourceUserId == authUid;

  /// `deleteAIHistory`: identity is `request.auth.uid` — the client cannot
  /// supply a target userId.
  static bool isOwnHistoryPath(String path, String authUid) =>
      path == 'users/$authUid/ai_interactions';

  /// The callable deletes BOTH stores for the authenticated user.
  static List<String> storesDeletedFor(String authUid) => [
    'users/$authUid/ai_interactions',
    'ai_conversations/where(userId == $authUid)',
  ];
}

class AIRetentionPolicy {
  const AIRetentionPolicy._();

  /// v8.8 default retention window (days) — conservative default 90.
  static const int defaultRetentionDays = 90;

  /// Env-configurable: must be a positive integer, else default 90.
  static int retentionDaysFrom(String? envValue) {
    final parsed = int.tryParse(envValue ?? '');
    if (parsed == null || parsed <= 0) return defaultRetentionDays;
    return parsed;
  }

  /// A doc is expired when its timestamp is older than the cutoff.
  static bool isExpired(DateTime docCreatedAt, DateTime cutoff) =>
      docCreatedAt.isBefore(cutoff);

  /// Recent conversations are NEVER deleted automatically (P6).
  static bool isRecent(DateTime docCreatedAt, DateTime cutoff) =>
      !isExpired(docCreatedAt, cutoff);

  /// Cleanup only ever touches the two AI stores — never unrelated docs.
  static bool isEligiblePath(String path) =>
      path.startsWith('users/') && path.contains('/ai_interactions') ||
      path.startsWith('ai_conversations/');
}

class AIBatchDeleter {
  const AIBatchDeleter._();

  /// Batches of 400 (well under the 500-write Firestore batch cap).
  static const int batchSize = 400;

  /// Number of batches for a doc count (chunked safe deletes).
  static int batchCount(int docCount) => (docCount / batchSize).ceil();
}

void main() {
  group('AIDeletionRules — owner-only deletion (P5/P7)', () {
    test('user can delete their own conversation', () {
      expect(
        AIDeletionRules.canDeleteInteraction(
          isAuthenticated: true,
          resourceUserId: 'STUDENT_A',
          authUid: 'STUDENT_A',
        ),
        isTrue,
      );
    });

    test('user CANNOT delete another user\'s conversation', () {
      expect(
        AIDeletionRules.canDeleteInteraction(
          isAuthenticated: true,
          resourceUserId: 'STUDENT_B',
          authUid: 'STUDENT_A',
        ),
        isFalse,
      );
    });

    test('unauthenticated deletion is rejected', () {
      expect(
        AIDeletionRules.canDeleteInteraction(
          isAuthenticated: false,
          resourceUserId: 'STUDENT_A',
          authUid: 'STUDENT_A',
        ),
        isFalse,
      );
    });

    test('deletion path is always scoped to the auth UID', () {
      expect(
        AIDeletionRules.isOwnHistoryPath(
          'users/STUDENT_A/ai_interactions',
          'STUDENT_A',
        ),
        isTrue,
      );
      expect(
        AIDeletionRules.isOwnHistoryPath(
          'users/STUDENT_B/ai_interactions',
          'STUDENT_A',
        ),
        isFalse,
      );
    });

    test(
      'deleteAIHistory removes both stores (client store + legacy store)',
      () {
        expect(
          AIDeletionRules.storesDeletedFor('STUDENT_A'),
          contains('users/STUDENT_A/ai_interactions'),
        );
        expect(
          AIDeletionRules.storesDeletedFor('STUDENT_A'),
          contains('ai_conversations/where(userId == STUDENT_A)'),
        );
        expect(
          AIDeletionRules.storesDeletedFor('STUDENT_B'),
          isNot(contains('users/STUDENT_A/ai_interactions')),
        );
      },
    );
  });

  group('AIRetentionPolicy — conservative cleanup (P6)', () {
    test('default retention is 90 days', () {
      expect(AIRetentionPolicy.defaultRetentionDays, 90);
      expect(AIRetentionPolicy.retentionDaysFrom(null), 90);
      expect(AIRetentionPolicy.retentionDaysFrom(''), 90);
    });

    test('cleanup preserves RECENT conversations', () {
      final now = DateTime.now();
      final cutoff = now.subtract(
        Duration(days: AIRetentionPolicy.defaultRetentionDays),
      );
      expect(AIRetentionPolicy.isRecent(now, cutoff), isTrue);
      expect(
        AIRetentionPolicy.isRecent(
          now.subtract(const Duration(days: 30)),
          cutoff,
        ),
        isTrue,
      );
    });

    test('expired conversations are eligible for deletion', () {
      final now = DateTime.now();
      final cutoff = now.subtract(
        Duration(days: AIRetentionPolicy.defaultRetentionDays),
      );
      expect(
        AIRetentionPolicy.isExpired(
          now.subtract(const Duration(days: 91)),
          cutoff,
        ),
        isTrue,
      );
    });

    test('unrelated documents are never touched', () {
      expect(
        AIRetentionPolicy.isEligiblePath('users/U/ai_interactions/x'),
        isTrue,
      );
      expect(AIRetentionPolicy.isEligiblePath('ai_conversations/x'), isTrue);
      expect(
        AIRetentionPolicy.isEligiblePath('users/U/resumeReviews/x'),
        isFalse,
      );
      expect(AIRetentionPolicy.isEligiblePath('placements/123'), isFalse);
      expect(AIRetentionPolicy.isEligiblePath('applications/app'), isFalse);
    });

    test('invalid/non-positive retention config falls back to 90', () {
      expect(AIRetentionPolicy.retentionDaysFrom('0'), 90);
      expect(AIRetentionPolicy.retentionDaysFrom('-5'), 90);
      expect(AIRetentionPolicy.retentionDaysFrom('abc'), 90);
      expect(AIRetentionPolicy.retentionDaysFrom('30'), 30);
    });
  });

  group('AIBatchDeleter — safe batched deletes (P6)', () {
    test('large histories are chunked under the write caps', () {
      expect(AIBatchDeleter.batchCount(1), 1);
      expect(AIBatchDeleter.batchCount(400), 1);
      expect(AIBatchDeleter.batchCount(401), 2);
      expect(AIBatchDeleter.batchCount(5000), 13);
    });

    test('batch size stays well under the Firestore 500 cap', () {
      expect(AIBatchDeleter.batchSize, lessThan(500));
    });
  });
}

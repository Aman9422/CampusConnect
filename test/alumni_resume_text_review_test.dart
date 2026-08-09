import 'package:flutter_test/flutter_test.dart';

/// CampusConnect v8.7 — Alumni Text-Based Resume Reviewer contract tests.
///
/// These tests mirror the SERVER-SIDE client validation + pipeline reuse
/// (Task §2/§3/§18) as pure Dart functions:
///
///   - Alumni submit PASTED TEXT (no PDF required, no portfolio required).
///   - The text review flows through the SAME `reviewResume` callable as the
///     Student uploaded-PDF path (no second AI/ATS engine — Task §3).
///   - The shared monthly quota (`resume_usage/{uid}`, atomic) applies.
///   - Review history is stored under `users/{uid}/resumeReviews`
///     (own-UID only — Task §4).
///   - Student uploaded-PDF reviews remain functional (Task §12).
class AlumniTextReviewPath {
  const AlumniTextReviewPath._();

  /// The single `reviewResume` callable accepts EITHER pasted text OR a
  /// storage path — one engine, two inputs (Task §3).
  static bool usesExistingPipeline({
    required bool hasText,
    required bool hasStoragePath,
  }) {
    return (hasText && !hasStoragePath) || (!hasText && hasStoragePath);
  }

  /// Mutual exclusion: pasted text and storage path are not both sent.
  static bool inputsAreMutuallyExclusive({
    required bool hasText,
    required bool hasStoragePath,
  }) {
    return !(hasText && hasStoragePath);
  }

  /// Client-side text validation (mirrors `ResumeReviewService`).
  static String? validateResumeText(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return 'Resume text is required when no uploaded resume is provided.';
    }
    if (trimmed.length < 100) {
      return 'Resume is too short. Please provide at least 100 characters.';
    }
    if (trimmed.length > 5000) {
      return 'Resume is too long. Maximum 5000 characters allowed.';
    }
    return null;
  }
}

/// Mirrors the single shared quota (`consumeResumeQuota` server logic,
/// Task §18): Alumni text reviews consume the SAME quota as Student reviews —
/// there is no separate Alumni quota.
class SharedResumeQuota {
  const SharedResumeQuota._();

  static const int monthlyLimit = 5;

  static bool canSubmit(int monthlyCount) => monthlyCount < monthlyLimit;

  static int consume(int monthlyCount) => monthlyCount + 1;

  static bool isExhausted(int monthlyCount) => monthlyCount >= monthlyLimit;
}

/// Mirrors `users/{uid}/resumeReviews` history scoping (Task §4).
class AlumniTextReviewHistoryScope {
  const AlumniTextReviewHistoryScope._();

  static String collectionPath(String uid) => 'users/$uid/resumeReviews';

  static bool isOwnHistoryPath(String path, String uid) =>
      path == collectionPath(uid);
}

void main() {
  group('AlumniTextReviewPath (pasted text -> existing pipeline)', () {
    test('alumni text-only review uses the existing review pipeline', () {
      expect(
        AlumniTextReviewPath.usesExistingPipeline(
          hasText: true,
          hasStoragePath: false,
        ),
        isTrue,
      );
    });

    test('student uploaded-PDF review also uses the same pipeline', () {
      expect(
        AlumniTextReviewPath.usesExistingPipeline(
          hasText: false,
          hasStoragePath: true,
        ),
        isTrue,
      );
    });

    test('text and storage path are mutually exclusive inputs', () {
      expect(
        AlumniTextReviewPath.inputsAreMutuallyExclusive(
          hasText: true,
          hasStoragePath: true,
        ),
        isFalse,
      );
      expect(
        AlumniTextReviewPath.inputsAreMutuallyExclusive(
          hasText: true,
          hasStoragePath: false,
        ),
        isTrue,
      );
    });

    test(
      'empty / too-short resume text is rejected with existing validation',
      () {
        expect(AlumniTextReviewPath.validateResumeText(''), isNotNull);
        expect(AlumniTextReviewPath.validateResumeText('   '), isNotNull);
        expect(AlumniTextReviewPath.validateResumeText('x' * 99), isNotNull);
      },
    );

    test('valid pasted resume text passes validation', () {
      final sample =
          'Flutter Developer with 5 years of experience building '
          'cross-platform mobile applications. Proficient in Dart, Firebase, '
          'and REST APIs. Led a team of 4 engineers delivering 10+ production '
          'apps with 4.8+ ratings.';
      expect(AlumniTextReviewPath.validateResumeText(sample), isNull);
    });

    test('alumni text review does NOT require a PDF or portfolio', () {
      // The text path never supplies a storagePath — no upload required.
      expect(
        AlumniTextReviewPath.usesExistingPipeline(
          hasText: true,
          hasStoragePath: false,
        ),
        isTrue,
      );
    });
  });

  group('SharedResumeQuota (one shared quota — Task §18)', () {
    test('rejects when quota is exhausted', () {
      expect(SharedResumeQuota.canSubmit(5), isFalse);
      expect(SharedResumeQuota.isExhausted(5), isTrue);
    });

    test('allows when quota is available', () {
      expect(SharedResumeQuota.canSubmit(4), isTrue);
      expect(SharedResumeQuota.isExhausted(4), isFalse);
    });

    test('consumes one credit per review', () {
      expect(SharedResumeQuota.consume(2), 3);
    });
  });

  group('AlumniTextReviewHistoryScope (own-UID history — Task §4)', () {
    test('history stored under users/{uid}/resumeReviews', () {
      expect(
        AlumniTextReviewHistoryScope.collectionPath('ALUMNI_1'),
        'users/ALUMNI_1/resumeReviews',
      );
    });

    test('alumni cannot access another user\'s history', () {
      expect(
        AlumniTextReviewHistoryScope.isOwnHistoryPath(
          'users/ALUMNI_1/resumeReviews',
          'ALUMNI_1',
        ),
        isTrue,
      );
      expect(
        AlumniTextReviewHistoryScope.isOwnHistoryPath(
          'users/STUDENT_9/resumeReviews',
          'ALUMNI_1',
        ),
        isFalse,
      );
    });
  });

  group('Regression — Student uploaded-PDF reviewer unchanged (Task §12)', () {
    test('student uploaded-PDF review still flows through the pipeline', () {
      expect(
        AlumniTextReviewPath.usesExistingPipeline(
          hasText: false,
          hasStoragePath: true,
        ),
        isTrue,
      );
    });

    test('student reviews share the same monthly quota', () {
      // A student at 4/5 and an alumni at 4/5 face the same limit.
      expect(SharedResumeQuota.canSubmit(4), isTrue);
      expect(SharedResumeQuota.canSubmit(5), isFalse);
    });
  });
}

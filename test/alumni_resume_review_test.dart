import 'package:flutter_test/flutter_test.dart';

/// CampusConnect v8.5.2 (A5) — Alumni Resume Reviewer & Portfolio Integration
/// contract tests.
///
/// These tests mirror the SERVER-SIDE decision logic in `functions/index.js`
/// (`onResumeReviewCreatedRefreshMatches` + `resumeTextFromStorage`) as pure
/// Dart functions so they can be unit-tested without Firebase, exactly like
/// the existing `test/resume_review_storage_path_test.dart` pattern.
///
/// The v8.5.2 behavior under test:
///  1. The ATS → `portfolio.resume` merge runs for ANY role (student OR
///     alumni) — Alumni reviews must persist
///     `latestATSScore` / `reviewCount` / `lastReviewAt` / `updatedAt`.
///  2. Student-only AI enrichment (recommendations, engagement recompute)
///     stays gated to `role == 'student'`.
///  3. The reviewer is strictly personal: an Alumni's review can only use
///     their OWN storage path (`resumes/{uid}/latest.pdf`).
///  4. Review history lives under `users/{uid}/resumeReviews` — isolated per
///     authenticated UID.

/// Mirrors the ATS-merge gate from `onResumeReviewCreatedRefreshMatches`.
///
/// Returns the `portfolio.resume` merge that the trigger applies for a review
/// author. The merge itself is role-agnostic; only the student-only
/// enrichment (recommendations) is gated.
class AlumniReviewPortfolioSync {
  const AlumniReviewPortfolioSync._();

  static Map<String, dynamic> atsMergeFields({int? atsScore, int increment = 1}) {
    return {
      'reviewCount': increment,
      'lastReviewAt': 'now',
      'updatedAt': 'now',
      if (atsScore != null) 'latestATSScore': atsScore,
    };
  }

  /// True when the review author should also have their student
  /// recommendations refreshed (role == 'student' only).
  static bool shouldRefreshStudentRecommendations(String? role) =>
      role == 'student';

  /// True when the ATS → portfolio merge should run. Post-v8.5.2 this is
  /// TRUE for every role — Students AND Alumni share the same source of truth.
  static bool shouldMergeAtsIntoPortfolio(String? role) => role != null;
}

/// Mirrors `resumeTextFromStorage`'s exact-match ownership rule.
/// Reuses the same contract as `ResumeReviewStoragePathValidator`.
class AlumniOwnResumePath {
  const AlumniOwnResumePath._();

  static bool isValid(String? storagePath, String uid) {
    if (storagePath == null || storagePath.isEmpty || uid.isEmpty) {
      return false;
    }
    return storagePath == 'resumes/$uid/latest.pdf';
  }
}

/// Mirrors `ResumeHistoryService`'s collection scoping:
/// `users/{uid}/resumeReviews` — a history request can only ever address the
/// authenticated user's own subcollection.
class AlumniReviewHistoryScope {
  const AlumniReviewHistoryScope._();

  static String collectionPath(String uid) => 'users/$uid/resumeReviews';

  static bool isOwnHistoryPath(String path, String uid) =>
      path == collectionPath(uid);
}

void main() {
  group('AlumniReviewPortfolioSync (ATS metadata merge for any role)', () {
    test('Alumni review merges ATS fields into portfolio.resume', () {
      final merge = AlumniReviewPortfolioSync.atsMergeFields(atsScore: 82);
      expect(merge['reviewCount'], 1);
      expect(merge['lastReviewAt'], 'now');
      expect(merge['updatedAt'], 'now');
      expect(merge['latestATSScore'], 82);
    });

    test('ATS merge runs for Alumni (root cause fix)', () {
      // v8.5.2 A2: previously `role !== "student"` early-returned and Alumni
      // reviews never persisted ATS. The gate must now pass for alumni.
      expect(AlumniReviewPortfolioSync.shouldMergeAtsIntoPortfolio('alumni'),
          isTrue);
      expect(AlumniReviewPortfolioSync.shouldMergeAtsIntoPortfolio('student'),
          isTrue);
    });

    test('student-only recommendations stay gated', () {
      expect(
        AlumniReviewPortfolioSync.shouldRefreshStudentRecommendations(
            'student'),
        isTrue,
      );
      expect(
        AlumniReviewPortfolioSync.shouldRefreshStudentRecommendations(
            'alumni'),
        isFalse,
      );
    });

    test('ATS merge drops the score when the review carried no integer', () {
      final merge = AlumniReviewPortfolioSync.atsMergeFields();
      expect(merge.containsKey('latestATSScore'), isFalse);
      expect(merge['reviewCount'], 1);
    });
  });

  group('AlumniOwnResumePath (review uses the alumni\'s own storage path)', () {
    test('accepts the alumni\'s own canonical resume path', () {
      expect(
        AlumniOwnResumePath.isValid('resumes/ALUMNI123/latest.pdf', 'ALUMNI123'),
        isTrue,
      );
    });

    test('rejects another user\'s resume path', () {
      expect(
        AlumniOwnResumePath.isValid(
            'resumes/STUDENT999/latest.pdf', 'ALUMNI123'),
        isFalse,
      );
    });

    test('rejects snapshot / history paths (only latest.pdf is reviewable)', () {
      expect(
        AlumniOwnResumePath.isValid(
            'resumes/ALUMNI123/snapshots/app_xyz.pdf', 'ALUMNI123'),
        isFalse,
      );
      expect(
        AlumniOwnResumePath.isValid(
            'resumes/ALUMNI123/history/v1.pdf', 'ALUMNI123'),
        isFalse,
      );
    });

    test('rejects null / empty path without throwing', () {
      expect(AlumniOwnResumePath.isValid(null, 'ALUMNI123'), isFalse);
      expect(AlumniOwnResumePath.isValid('', 'ALUMNI123'), isFalse);
    });
  });

  group('AlumniReviewHistoryScope (history isolated to the owning uid)', () {
    test('paths resolve under users/{uid}/resumeReviews', () {
      expect(
        AlumniReviewHistoryScope.collectionPath('ALUMNI123'),
        'users/ALUMNI123/resumeReviews',
      );
    });

    test('an alumni can only address their own history subcollection', () {
      expect(
        AlumniReviewHistoryScope.isOwnHistoryPath(
            'users/ALUMNI123/resumeReviews', 'ALUMNI123'),
        isTrue,
      );
      expect(
        AlumniReviewHistoryScope.isOwnHistoryPath(
            'users/STUDENT999/resumeReviews', 'ALUMNI123'),
        isFalse,
      );
    });
  });

  group('Regression — Student behavior remains unchanged', () {
    test('student review still merges ATS metadata', () {
      expect(AlumniReviewPortfolioSync.shouldMergeAtsIntoPortfolio('student'),
          isTrue);
      final merge = AlumniReviewPortfolioSync.atsMergeFields(atsScore: 91);
      expect(merge['latestATSScore'], 91);
    });

    test('student review still refreshes recommendations', () {
      expect(
        AlumniReviewPortfolioSync.shouldRefreshStudentRecommendations(
            'student'),
        isTrue,
      );
    });
  });
}

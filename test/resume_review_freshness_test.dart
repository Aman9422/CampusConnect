// CampusConnect v9.3 — resume-review freshness.
//
// WHY THIS SUITE EXISTS
// ---------------------
// `ResumeReviewProvider` is app-level, so a review it holds outlives the
// screen. The reviewer shows results instead of the input form whenever
// `hasReview` is true, so after a student replaced their resume in the
// portfolio and came back they were shown the PREVIOUS result — the same
// number, every time, whatever they uploaded. (The other half of the "it always
// says 68" report was the score itself; see `functions/test/ats_score.test.js`.)
//
// These tests pin the rule that decides when a held review no longer describes
// the resume the student has now.
//
// Pure Dart — no Firebase, no widget tree.
//
// Run: flutter test test/resume_review_freshness_test.dart

import 'package:campusconnect/services/ai/resume_review_freshness.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const path = 'resumes/uid-123/latest.pdf';

  group('uploadedResumeKey', () {
    test('composes the storage path and the resume version', () {
      expect(
        ResumeReviewFreshness.uploadedResumeKey(
          storagePath: path,
          version: 3,
        ),
        'resumes/uid-123/latest.pdf#v3',
      );
    });

    test('the separator cannot collide with a real storage path', () {
      // A path never contains "#", which is what makes the split unambiguous.
      expect(path.contains(ResumeReviewFreshness.versionSeparator), isFalse);
      expect(
        ResumeReviewFreshness.uploadedResumeKey(
          storagePath: path,
          version: 1,
        )!.split(ResumeReviewFreshness.versionSeparator),
        [path, '1'],
      );
    });

    test('different versions produce different keys', () {
      final v1 = ResumeReviewFreshness.uploadedResumeKey(
        storagePath: path,
        version: 1,
      );
      final v2 = ResumeReviewFreshness.uploadedResumeKey(
        storagePath: path,
        version: 2,
      );
      expect(v1, isNot(equals(v2)));
    });

    test('identity is stable across calls — a review is not "stale" at rest',
        () {
      expect(
        ResumeReviewFreshness.uploadedResumeKey(
          storagePath: path,
          version: 4,
        ),
        ResumeReviewFreshness.uploadedResumeKey(
          storagePath: path,
          version: 4,
        ),
      );
    });

    test('a missing or empty path has no identity', () {
      expect(
        ResumeReviewFreshness.uploadedResumeKey(storagePath: null, version: 1),
        isNull,
      );
      expect(
        ResumeReviewFreshness.uploadedResumeKey(storagePath: '', version: 1),
        isNull,
      );
    });

    test('a missing or nonsensical version degrades to the first revision',
        () {
      for (final version in [null, 0, -5]) {
        expect(
          ResumeReviewFreshness.uploadedResumeKey(
            storagePath: path,
            version: version,
          ),
          'resumes/uid-123/latest.pdf#v1',
          reason: 'version $version should read as the first upload',
        );
      }
    });
  });

  group('isStale', () {
    final v1Key = ResumeReviewFreshness.uploadedResumeKey(
      storagePath: path,
      version: 1,
    );
    final v2Key = ResumeReviewFreshness.uploadedResumeKey(
      storagePath: path,
      version: 2,
    );

    test('an unchanged resume is not stale — re-opening keeps the review', () {
      expect(
        ResumeReviewFreshness.isStale(
          reviewedResumeKey: v1Key,
          currentResumeKey: v1Key,
        ),
        isFalse,
      );
    });

    test('a REPLACED resume is stale — this is the reported bug', () {
      expect(
        ResumeReviewFreshness.isStale(
          reviewedResumeKey: v1Key,
          currentResumeKey: v2Key,
        ),
        isTrue,
      );
    });

    test('a REMOVED resume is stale — the reviewed document is gone', () {
      expect(
        ResumeReviewFreshness.isStale(
          reviewedResumeKey: v1Key,
          currentResumeKey: null,
        ),
        isTrue,
      );
    });

    test('a pasted-text review is never stale', () {
      // No document binding. Otherwise a student with an uploaded resume who
      // chose to paste text would be bounced off their own fresh result.
      expect(
        ResumeReviewFreshness.isStale(
          reviewedResumeKey: null,
          currentResumeKey: v1Key,
        ),
        isFalse,
      );
      expect(
        ResumeReviewFreshness.isStale(
          reviewedResumeKey: '',
          currentResumeKey: v1Key,
        ),
        isFalse,
      );
      expect(
        ResumeReviewFreshness.isStale(
          reviewedResumeKey: null,
          currentResumeKey: null,
        ),
        isFalse,
      );
    });
  });

  group('the reported scenario, end to end', () {
    test('replacing the resume invalidates the score held for the old one',
        () {
      // 1. Student reviews the uploaded resume (version 1).
      const versionAtReview = 1;
      final keyAtReview = ResumeReviewFreshness.uploadedResumeKey(
        storagePath: path,
        version: versionAtReview,
      );

      // While nothing changes, the result stays valid on every return visit.
      expect(
        ResumeReviewFreshness.isStale(
          reviewedResumeKey: keyAtReview,
          currentResumeKey: ResumeReviewFreshness.uploadedResumeKey(
            storagePath: path,
            version: versionAtReview,
          ),
        ),
        isFalse,
      );

      // 2. They replace the resume in the portfolio — same storage path, but
      //    `ResumeMetadata.version` is bumped, so the document differs.
      const versionAfterReplace = versionAtReview + 1;
      final currentKey = ResumeReviewFreshness.uploadedResumeKey(
        storagePath: path,
        version: versionAfterReplace,
      );

      // 3. The held review must now be treated as stale, so the screen shows
      //    the form and a FRESH score is produced for the new file, instead of
      //    re-presenting the old number as if it described the new resume.
      expect(
        ResumeReviewFreshness.isStale(
          reviewedResumeKey: keyAtReview,
          currentResumeKey: currentKey,
        ),
        isTrue,
      );
    });
  });
}

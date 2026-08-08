import 'package:flutter_test/flutter_test.dart';

/// CampusConnect v8.5 (R9) — Resume-review storage-path security contract.
///
/// Mirrors the server-side validation in `functions/index.js`
/// (`resumeTextFromStorage`): a review may ONLY be issued for the
/// authenticated user's own canonical resume at `resumes/{uid}/latest.pdf`.
/// The same rule is enforced on the client so a UI-bound storage path can be
/// validated before it leaves the device; the Cloud Function re-validates
/// with `request.auth.uid` as the authoritative identity.
///
/// [ResumeReviewStoragePathValidator.isOwnerResumePath] is a pure function so
/// it can be unit-tested without Firebase.
class ResumeReviewStoragePathValidator {
  const ResumeReviewStoragePathValidator._();

  /// Exact-match rule from v8.5.1: `resumes/{uid}/latest.pdf`.
  ///
  /// Rejects:
  ///  - another user's path (`resumes/OTHERUSER/latest.pdf`)
  ///  - a different layout (`users/{uid}/resume.pdf`)
  ///  - any file other than `latest.pdf` (`resumes/{uid}/other.pdf`)
  ///  - non-string / empty input (never throws)
  static bool isOwnerResumePath(String? storagePath, String uid) {
    if (storagePath == null || storagePath.isEmpty || uid.isEmpty) {
      return false;
    }
    return storagePath == 'resumes/$uid/latest.pdf';
  }
}

void main() {
  group('ResumeReviewStoragePathValidator.isOwnerResumePath', () {
    test('accepts the canonical own-resume path', () {
      expect(
        ResumeReviewStoragePathValidator.isOwnerResumePath(
          'resumes/USER123/latest.pdf',
          'USER123',
        ),
        isTrue,
      );
    });

    test('rejects another user\'s resume path', () {
      expect(
        ResumeReviewStoragePathValidator.isOwnerResumePath(
          'resumes/OTHERUSER/latest.pdf',
          'USER123',
        ),
        isFalse,
      );
    });

    test('rejects a non-resume storage layout', () {
      expect(
        ResumeReviewStoragePathValidator.isOwnerResumePath(
          'users/USER123/resume.pdf',
          'USER123',
        ),
        isFalse,
      );
    });

    test('rejects a non-latest file in the own resumes folder', () {
      expect(
        ResumeReviewStoragePathValidator.isOwnerResumePath(
          'resumes/USER123/other.pdf',
          'USER123',
        ),
        isFalse,
      );
    });

    test('rejects history snapshots (only latest.pdf is reviewable)', () {
      expect(
        ResumeReviewStoragePathValidator.isOwnerResumePath(
          'resumes/USER123/history/v1.pdf',
          'USER123',
        ),
        isFalse,
      );
    });

    test('rejects null / empty values without throwing', () {
      expect(
        ResumeReviewStoragePathValidator.isOwnerResumePath(null, 'USER123'),
        isFalse,
      );
      expect(
        ResumeReviewStoragePathValidator.isOwnerResumePath('', 'USER123'),
        isFalse,
      );
      expect(
        ResumeReviewStoragePathValidator.isOwnerResumePath(
          'resumes/USER123/latest.pdf',
          '',
        ),
        isFalse,
      );
    });
  });
}

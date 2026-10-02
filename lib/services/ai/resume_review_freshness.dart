/// CampusConnect v9.3 — resume-review freshness.
///
/// WHAT THIS FIXES
/// ---------------
/// `ResumeReviewProvider` is an app-level provider: once a review has been
/// produced, `currentReview` stays set for the whole session. The review screen
/// shows those results INSTEAD of the input form (`hasReview` short-circuits the
/// body), so after a student swapped their resume in the portfolio and came back
/// to the reviewer they were shown the PREVIOUS result — the same number, every
/// time, no matter what they uploaded. That is one of the two causes of the
/// "the score is always 68" report.
///
/// A review is a statement about a specific document. This module binds a review
/// to the resume it was computed from and answers one question: *does the review
/// I am holding still describe the resume the student has now?*
///
/// The rule is deliberately conservative about pasted text. A pasted review has
/// no document binding at all (`reviewedResumeKey` is null) and is NEVER stale on
/// its own — otherwise a student with an uploaded resume who chooses to paste
/// text would be bounced off their own fresh result.
///
/// Pure and deterministic — no Firebase, no Flutter, unit-testable.
library;

class ResumeReviewFreshness {
  const ResumeReviewFreshness._();

  /// Separator between the storage path and the resume version.
  ///
  /// `resumes/{uid}/latest.pdf` is OVERWRITTEN on every replace, so the path
  /// alone cannot tell two different resumes apart. `ResumeMetadata.version` is
  /// incremented on each upload, so path + version identifies the exact
  /// document a review was run against.
  static const String versionSeparator = '#v';

  /// Key identifying one uploaded resume revision.
  ///
  /// @param storagePath - e.g. `resumes/{uid}/latest.pdf`
  /// @param version - `ResumeMetadata.version` (>= 1)
  /// @returns A stable key, or null when there is no usable path.
  static String? uploadedResumeKey({
    String? storagePath,
    int? version,
  }) {
    if (storagePath == null || storagePath.isEmpty) return null;
    final revision = (version == null || version < 1) ? 1 : version;
    return '$storagePath$versionSeparator$revision';
  }

  /// True when the held review no longer describes the current resume.
  ///
  /// [reviewedResumeKey] is the key captured when the review was produced
  /// (null for a pasted-text review). [currentResumeKey] is the key of the
  /// resume the student has right now (null when they have no uploaded resume).
  ///
  /// @returns false when no review is bound to a document (nothing can be
  ///   stale), true when the bound document has been replaced or removed.
  static bool isStale({
    required String? reviewedResumeKey,
    required String? currentResumeKey,
  }) {
    // A pasted-text review is not bound to any document.
    if (reviewedResumeKey == null || reviewedResumeKey.isEmpty) return false;
    // The reviewed document is gone (resume removed).
    if (currentResumeKey == null || currentResumeKey.isEmpty) return true;
    // Replaced, or unchanged.
    return reviewedResumeKey != currentResumeKey;
  }
}

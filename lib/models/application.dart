import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for placement application
/// V5: Normalized application data structure
///
/// v8.4.1 (T5): Resume snapshot fields (`resumeVersion`,
/// `resumeStoragePath`, `atsScoreAtApplication`) preserve the exact resume
/// used when applying — later uploads never change this record
/// (docs/Task.md Phase 8).
class Application {
  final String id;
  final String userId;
  final String placementId;
  final String resumeUrl;
  final DateTime appliedAt;
  // v9.1 (BUG-H): full pipeline — applied | shortlisted | interviewed |
  // placed | rejected. The stale pre-v9.1 comment (`applied | shortlisted |
  // rejected`) is fixed; `applied` is the initial state and `rejected` is a
  // terminal state alongside `placed`.
  final String status;

  /// v8.4.1 (T5): Resume version at the time of application.
  final int? resumeVersion;

  /// v8.4.1 (T5): Durable Storage path (`resumes/{uid}/latest.pdf`) at apply time.
  final String? resumeStoragePath;

  /// v8.4.1 (T5): Latest ATS score at the time of application.
  final int? atsScoreAtApplication;

  Application({
    required this.id,
    required this.userId,
    required this.placementId,
    required this.resumeUrl,
    required this.appliedAt,
    required this.status,
    this.resumeVersion,
    this.resumeStoragePath,
    this.atsScoreAtApplication,
  });

  factory Application.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    // v9.1: mirror docs (`placements/{id}/applications/{uid}`) store the
    // snapshot under `resume`, canonical docs under `resumeUrl`. Fall back so
    // a mirror-only legacy record still yields a usable resume link.
    final resumeUrl = data['resumeUrl'] as String? ?? data['resume'] as String?;
    // v9.1 audit (BUG-B): a legacy mirror-only doc may only carry
    // `studentId` (predates the `userId` field) — the old null-unsafe cast
    // `data['userId'] as String` threw a TypeError that crashed the entire
    // applicants query for that placement. Fall through to `studentId`, then
    // `''` so one legacy doc can never take down the whole screen.
    final userId = data['userId'] as String? ??
        data['studentId'] as String? ??
        '';
    return Application(
      id: doc.id,
      userId: userId,
      placementId: data['placementId'] as String,
      resumeUrl: resumeUrl ?? '',
      appliedAt: (data['appliedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] as String? ?? 'applied',
      resumeVersion: data['resumeVersion'] as int?,
      resumeStoragePath: data['resumeStoragePath'] as String?,
      atsScoreAtApplication: data['atsScoreAtApplication'] as int?,
    );
  }

  /// v9.1 audit (BUG-G): true when the resume value is NOT a link/path —
  /// the student pasted text instead of uploading a PDF (`resumeUrl` holds
  /// the pasted text). The applicants view shows a "Text resume" state
  /// instead of a dead "Resume" button that would try to `launchUrl` on
  /// arbitrary text and throw a `FormatException`.
  bool get isTextResume => resumeUrl.isNotEmpty && !_isResumeLink(resumeUrl);

  /// Whether the resume value looks like a real link or storage path.
  ///
  /// Covers Firebase signed URLs (`https://firebasestorage.googleapis.com/…`),
  /// plain `http(s)` links, `gs://` GCS paths, and legacy `resumes/…`
  /// storage paths. Anything else (e.g. pasted background text) is not a
  /// link — it is a text resume.
  static bool _isResumeLink(String value) {
    final lower = value.trim().toLowerCase();
    return lower.startsWith('http://') ||
        lower.startsWith('https://') ||
        lower.startsWith('gs://') ||
        lower.startsWith('resumes/');
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      // Spec Phase 8 calls it "studentId" — stored for forward compatibility
      // with Teacher Analytics 2.0 while `userId` remains canonical.
      'studentId': userId,
      'placementId': placementId,
      'resumeUrl': resumeUrl,
      if (resumeVersion != null) 'resumeVersion': resumeVersion,
      if (resumeStoragePath != null) 'resumeStoragePath': resumeStoragePath,
      if (atsScoreAtApplication != null)
        'atsScoreAtApplication': atsScoreAtApplication,
      'appliedAt': Timestamp.fromDate(appliedAt),
      'status': status,
    };
  }
}

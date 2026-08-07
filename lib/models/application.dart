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
  final String status; // applied | shortlisted | rejected

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
    return Application(
      id: doc.id,
      userId: data['userId'] as String,
      placementId: data['placementId'] as String,
      resumeUrl: data['resumeUrl'] as String? ?? '',
      appliedAt: (data['appliedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: data['status'] as String? ?? 'applied',
      resumeVersion: data['resumeVersion'] as int?,
      resumeStoragePath: data['resumeStoragePath'] as String?,
      atsScoreAtApplication: data['atsScoreAtApplication'] as int?,
    );
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

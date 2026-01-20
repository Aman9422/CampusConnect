import 'package:cloud_firestore/cloud_firestore.dart';

/// Model for placement application
/// V5: Normalized application data structure
class Application {
  final String id;
  final String userId;
  final String placementId;
  final String resumeUrl;
  final DateTime appliedAt;
  final String status; // applied | shortlisted | rejected

  Application({
    required this.id,
    required this.userId,
    required this.placementId,
    required this.resumeUrl,
    required this.appliedAt,
    required this.status,
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
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'placementId': placementId,
      'resumeUrl': resumeUrl,
      'appliedAt': Timestamp.fromDate(appliedAt),
      'status': status,
    };
  }
}

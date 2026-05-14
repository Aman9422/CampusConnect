import 'package:cloud_firestore/cloud_firestore.dart';

enum ActivityEventType {
  login,
  profileUpdated,
  resumeReviewed,
  mentorshipRequested,
  chatMessageSent,
  opportunityViewed,
  recommendationClicked,
}

class UserActivity {
  final String id;
  final String userId;
  final ActivityEventType eventType;
  final String? sourceId;
  final int points;
  final DateTime occurredAt;
  final Map<String, dynamic>? metadata;

  const UserActivity({
    required this.id,
    required this.userId,
    required this.eventType,
    required this.points,
    required this.occurredAt,
    this.sourceId,
    this.metadata,
  });

  factory UserActivity.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserActivity(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      eventType: _parseEventType(data['eventType'] as String?),
      sourceId: data['sourceId'] as String?,
      points: data['points'] as int? ?? 0,
      occurredAt:
          (data['occurredAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'eventType': eventType.name,
      'sourceId': sourceId,
      'points': points,
      'occurredAt': Timestamp.fromDate(occurredAt),
      'metadata': metadata ?? <String, dynamic>{},
    };
  }

  static ActivityEventType _parseEventType(String? value) {
    switch (value) {
      case 'login':
        return ActivityEventType.login;
      case 'profileUpdated':
        return ActivityEventType.profileUpdated;
      case 'resumeReviewed':
        return ActivityEventType.resumeReviewed;
      case 'mentorshipRequested':
        return ActivityEventType.mentorshipRequested;
      case 'chatMessageSent':
        return ActivityEventType.chatMessageSent;
      case 'opportunityViewed':
        return ActivityEventType.opportunityViewed;
      case 'recommendationClicked':
        return ActivityEventType.recommendationClicked;
      default:
        return ActivityEventType.login;
    }
  }
}

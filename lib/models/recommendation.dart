import 'package:cloud_firestore/cloud_firestore.dart';

enum RecommendationType { mentor, job, chat, mentorship, skill }

enum RecommendationPriority { high, medium, low }

class Recommendation {
  final String id;
  final String userId;
  final RecommendationType type;
  final RecommendationPriority priority;
  final String title;
  final String description;
  final double score;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final bool isActive;
  final Map<String, dynamic>? metadata;

  const Recommendation({
    required this.id,
    required this.userId,
    required this.type,
    required this.priority,
    required this.title,
    required this.description,
    required this.score,
    required this.createdAt,
    this.expiresAt,
    this.isActive = true,
    this.metadata,
  });

  factory Recommendation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Recommendation(
      id: doc.id,
      userId: data['userId'] as String? ?? '',
      type: _parseRecommendationType(data['type'] as String?),
      priority: _parsePriority(data['priority'] as String?),
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      score: (data['score'] as num?)?.toDouble() ?? 0.0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
      isActive: data['isActive'] as bool? ?? true,
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'type': type.name,
      'priority': priority.name,
      'title': title,
      'description': description,
      'score': score,
      'createdAt': Timestamp.fromDate(createdAt),
      'isActive': isActive,
      'metadata': metadata ?? <String, dynamic>{},
      if (expiresAt != null) 'expiresAt': Timestamp.fromDate(expiresAt!),
    };
  }

  Recommendation copyWith({
    RecommendationType? type,
    RecommendationPriority? priority,
    String? title,
    String? description,
    double? score,
    DateTime? expiresAt,
    bool? isActive,
    Map<String, dynamic>? metadata,
  }) {
    return Recommendation(
      id: id,
      userId: userId,
      type: type ?? this.type,
      priority: priority ?? this.priority,
      title: title ?? this.title,
      description: description ?? this.description,
      score: score ?? this.score,
      createdAt: createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      isActive: isActive ?? this.isActive,
      metadata: metadata ?? this.metadata,
    );
  }

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  static RecommendationType _parseRecommendationType(String? value) {
    switch (value) {
      case 'mentor':
        return RecommendationType.mentor;
      case 'job':
        return RecommendationType.job;
      case 'chat':
        return RecommendationType.chat;
      case 'mentorship':
        return RecommendationType.mentorship;
      case 'skill':
        return RecommendationType.skill;
      default:
        return RecommendationType.chat;
    }
  }

  static RecommendationPriority _parsePriority(String? value) {
    switch (value) {
      case 'high':
        return RecommendationPriority.high;
      case 'medium':
        return RecommendationPriority.medium;
      case 'low':
        return RecommendationPriority.low;
      default:
        return RecommendationPriority.medium;
    }
  }
}

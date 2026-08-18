import 'package:cloud_firestore/cloud_firestore.dart';

/// v8.9: `role` (career-role match) and `placement` (placement match) are
/// new recommendation types produced by the server engine
/// (functions/recommendations/engine.js). The legacy types are preserved.
/// v8.9.1: `portfolio` — portfolio-first gate card ("Complete your portfolio
/// first") surfaced when the student has no portfolio content yet.
enum RecommendationType {
  mentor,
  job,
  chat,
  mentorship,
  skill,
  role,
  placement,
  portfolio,
}

enum RecommendationPriority { high, medium, low }

/// Tolerant read: every new v8.9 field (`source`, `targetRole`,
/// `opportunityId`, `reason`, `skillsMatched`, `skillsMissing`,
/// `isRead`, `isDismissed`, `aiExplanation`, `suggestedAction`) defaults
/// safely so older recommendation documents and newer engine output both
/// parse. The server is the single writer — this model is read-only for
/// display plus the existing interaction marker.
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

  // v8.9 fields — engineered recommendations explain themselves.
  final String? source;
  final String? targetRole;
  final String? opportunityId;
  final String? reason;
  final List<String> skillsMatched;
  final List<String> skillsMissing;
  final bool isRead;
  final bool isDismissed;
  final String? aiExplanation;
  final String? suggestedAction;

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
    this.source,
    this.targetRole,
    this.opportunityId,
    this.reason,
    this.skillsMatched = const [],
    this.skillsMissing = const [],
    this.isRead = false,
    this.isDismissed = false,
    this.aiExplanation,
    this.suggestedAction,
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
      // v8.9 tolerant reads — all optional with safe defaults.
      source: data['source'] as String?,
      targetRole: data['targetRole'] as String?,
      opportunityId: data['opportunityId'] as String?,
      reason: data['reason'] as String?,
      skillsMatched: _stringList(data['skillsMatched']),
      skillsMissing: _stringList(data['skillsMissing']),
      isRead: data['isRead'] as bool? ?? false,
      isDismissed: data['isDismissed'] as bool? ?? false,
      aiExplanation: data['aiExplanation'] as String?,
      suggestedAction:
          (data['metadata'] as Map<String, dynamic>?)?['suggestedAction']
              as String? ??
          data['suggestedAction'] as String?,
    );
  }

  static List<String> _stringList(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<String>()
        .where((item) => item.trim().isNotEmpty)
        .toList();
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
      // v8.9 — written only when present (backward compatible).
      if (source != null) 'source': source,
      if (targetRole != null) 'targetRole': targetRole,
      if (opportunityId != null) 'opportunityId': opportunityId,
      if (reason != null) 'reason': reason,
      if (skillsMatched.isNotEmpty) 'skillsMatched': skillsMatched,
      if (skillsMissing.isNotEmpty) 'skillsMissing': skillsMissing,
      if (isRead) 'isRead': isRead,
      if (isDismissed) 'isDismissed': isDismissed,
      if (aiExplanation != null) 'aiExplanation': aiExplanation,
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
    String? source,
    String? targetRole,
    String? opportunityId,
    String? reason,
    List<String>? skillsMatched,
    List<String>? skillsMissing,
    bool? isRead,
    bool? isDismissed,
    String? aiExplanation,
    String? suggestedAction,
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
      source: source ?? this.source,
      targetRole: targetRole ?? this.targetRole,
      opportunityId: opportunityId ?? this.opportunityId,
      reason: reason ?? this.reason,
      skillsMatched: skillsMatched ?? this.skillsMatched,
      skillsMissing: skillsMissing ?? this.skillsMissing,
      isRead: isRead ?? this.isRead,
      isDismissed: isDismissed ?? this.isDismissed,
      aiExplanation: aiExplanation ?? this.aiExplanation,
      suggestedAction: suggestedAction ?? this.suggestedAction,
    );
  }

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  /// v8.9: match tier label for placement recommendations.
  String? get matchTierLabel =>
      (metadata?['matchTier'] as String?)?.replaceAll('_', ' ');

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
      case 'role':
        return RecommendationType.role;
      case 'placement':
        return RecommendationType.placement;
      case 'portfolio':
        return RecommendationType.portfolio;
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

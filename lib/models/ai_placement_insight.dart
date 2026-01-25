import 'package:cloud_firestore/cloud_firestore.dart';

/// AIPlacementInsight - v6.5.1
///
/// AI-generated insights for placement matching.
/// Cached in Firestore at users/{uid}/ai_insights/{placementId}
///
/// IMPORTANT: AI insights are OPTIONAL enhancements.
/// Rule-based eligibility ALWAYS takes precedence.
class AIPlacementInsight {
  final String placementId;
  final int matchScore; // 0-100
  final List<String> reasons; // Why it's a good match
  final List<String> missing; // Gaps/missing requirements
  final DateTime generatedAt;
  final String modelVersion;
  final DateTime? expiresAt;

  const AIPlacementInsight({
    required this.placementId,
    required this.matchScore,
    required this.reasons,
    required this.missing,
    required this.generatedAt,
    required this.modelVersion,
    this.expiresAt,
  });

  /// Check if insight is expired (default 24h cache)
  bool get isExpired {
    if (expiresAt != null) {
      return DateTime.now().isAfter(expiresAt!);
    }
    // Default 24h expiry
    return DateTime.now().difference(generatedAt).inHours > 24;
  }

  /// Get match level for UI display
  MatchLevel get matchLevel {
    if (matchScore >= 80) return MatchLevel.excellent;
    if (matchScore >= 60) return MatchLevel.good;
    if (matchScore >= 40) return MatchLevel.fair;
    return MatchLevel.low;
  }

  /// Get color hint for match score
  String get colorHint {
    switch (matchLevel) {
      case MatchLevel.excellent:
        return 'green';
      case MatchLevel.good:
        return 'blue';
      case MatchLevel.fair:
        return 'orange';
      case MatchLevel.low:
        return 'red';
    }
  }

  factory AIPlacementInsight.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AIPlacementInsight(
      placementId: doc.id,
      matchScore: data['matchScore'] as int? ?? 0,
      reasons: List<String>.from(data['reasons'] ?? []),
      missing: List<String>.from(data['missing'] ?? []),
      generatedAt:
          (data['generatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      modelVersion: data['modelVersion'] as String? ?? 'unknown',
      expiresAt: (data['expiresAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'matchScore': matchScore,
      'reasons': reasons,
      'missing': missing,
      'generatedAt': Timestamp.fromDate(generatedAt),
      'modelVersion': modelVersion,
      if (expiresAt != null) 'expiresAt': Timestamp.fromDate(expiresAt!),
    };
  }

  /// Create from Cloud Function response
  factory AIPlacementInsight.fromFunctionResponse({
    required String placementId,
    required Map<String, dynamic> response,
    required String modelVersion,
  }) {
    return AIPlacementInsight(
      placementId: placementId,
      matchScore: response['matchScore'] as int? ?? 0,
      reasons: List<String>.from(response['reasons'] ?? []),
      missing: List<String>.from(response['missing'] ?? []),
      generatedAt: DateTime.now(),
      modelVersion: modelVersion,
      expiresAt: DateTime.now().add(const Duration(hours: 24)),
    );
  }

  /// Create empty/unavailable insight
  factory AIPlacementInsight.unavailable(String placementId) {
    return AIPlacementInsight(
      placementId: placementId,
      matchScore: 0,
      reasons: [],
      missing: [],
      generatedAt: DateTime.now(),
      modelVersion: 'unavailable',
    );
  }

  @override
  String toString() {
    return 'AIPlacementInsight(placementId: $placementId, matchScore: $matchScore, '
        'reasons: $reasons, missing: $missing)';
  }
}

/// Match level for UI display
enum MatchLevel {
  excellent, // 80-100
  good, // 60-79
  fair, // 40-59
  low, // 0-39
}

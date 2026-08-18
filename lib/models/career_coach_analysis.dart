//CampusConnect v9.0 — AI Career Coach models


enum CareerCoachPriority { high, medium, low }

enum CareerCoachRecType {
  skill,
  portfolio,
  resume,
  project,
  experience,
  certification,
  achievement,
  profile,
  interview,
  jobSearch,
}

/// Career readiness level — `strong | solid | developing | sparse`.
enum CareerReadinessLevel {
  strong,
  solid,
  developing,
  sparse,
}

/// Career readiness assessment (level + honest summary).
class CareerReadiness {
  final CareerReadinessLevel level;
  final String summary;

  const CareerReadiness({
    this.level = CareerReadinessLevel.developing,
    this.summary = '',
  });

  factory CareerReadiness.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const CareerReadiness();
    return CareerReadiness(
      level: _parseReadinessLevel(json['level'] as String?),
      summary: (json['summary'] as String?)?.trim() ?? '',
    );
  }

  static CareerReadinessLevel _parseReadinessLevel(String? value) {
    switch (value?.toLowerCase()) {
      case 'strong':
        return CareerReadinessLevel.strong;
      case 'solid':
        return CareerReadinessLevel.solid;
      case 'developing':
        return CareerReadinessLevel.developing;
      case 'sparse':
        return CareerReadinessLevel.sparse;
      default:
        return CareerReadinessLevel.developing;
    }
  }

  bool get hasContent => summary.isNotEmpty;

  Map<String, dynamic> toJson() => {
    'level': level.name,
    'summary': summary,
  };
}

/// A single AI career recommendation.
class CareerCoachRecommendation {
  final CareerCoachRecType type;
  final CareerCoachPriority priority;
  final String title;
  final String reason;
  final String action;
  final String? whyItMatters;
  final String? estimatedEffort;

  const CareerCoachRecommendation({
    required this.type,
    required this.priority,
    required this.title,
    required this.reason,
    required this.action,
    this.whyItMatters,
    this.estimatedEffort,
  });

  /// Tolerant parse — invalid types/priorities/required-fields are rejected
  /// by returning `null` (the caller skips the item). Unknown recommendation
  /// types also produce a fallback with empty title so `isValid` is false
  /// and the caller filters it out.
  factory CareerCoachRecommendation.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const CareerCoachRecommendation(
      type: CareerCoachRecType.profile,
      priority: CareerCoachPriority.medium,
      title: '',
      reason: '',
      action: '',
    );
    }

    final type = _parseType(json['type'] as String?);
    if (type == null) {
      // Unknown type — return an invalid rec that the caller will filter out.
      return const CareerCoachRecommendation(
        type: CareerCoachRecType.profile,
        priority: CareerCoachPriority.medium,
        title: '',
        reason: '',
        action: '',
      );
    }
    final priority = _parsePriority(json['priority'] as String?);
    final title = (json['title'] as String?)?.trim() ?? '';
    final reason = (json['reason'] as String?)?.trim() ?? '';
    final action = (json['action'] as String?)?.trim() ?? '';

    return CareerCoachRecommendation(
      type: type,
      priority: priority,
      title: title,
      reason: reason,
      action: action,
      whyItMatters: (json['whyItMatters'] as String?)?.trim(),
      estimatedEffort: (json['estimatedEffort'] as String?)?.trim(),
    );
  }

  bool get isValid => title.isNotEmpty && reason.isNotEmpty && action.isNotEmpty;

  /// Returns `null` for unknown types so callers can filter them out.
  static CareerCoachRecType? _parseType(String? value) {
    switch (value?.toLowerCase()) {
      case 'skill':
        return CareerCoachRecType.skill;
      case 'portfolio':
        return CareerCoachRecType.portfolio;
      case 'resume':
        return CareerCoachRecType.resume;
      case 'project':
        return CareerCoachRecType.project;
      case 'experience':
        return CareerCoachRecType.experience;
      case 'certification':
        return CareerCoachRecType.certification;
      case 'achievement':
        return CareerCoachRecType.achievement;
      case 'profile':
        return CareerCoachRecType.profile;
      case 'interview':
        return CareerCoachRecType.interview;
      case 'jobsearch':
        return CareerCoachRecType.jobSearch;
      default:
        return null;
    }
  }

  static CareerCoachPriority _parsePriority(String? value) {
    switch (value?.toLowerCase()) {
      case 'high':
        return CareerCoachPriority.high;
      case 'medium':
        return CareerCoachPriority.medium;
      case 'low':
        return CareerCoachPriority.low;
      default:
        return CareerCoachPriority.medium;
    }
  }

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'priority': priority.name,
    'title': title,
    'reason': reason,
    'action': action,
    'whyItMatters': whyItMatters,
    'estimatedEffort': estimatedEffort,
  };
}

/// The complete AI Career Coach analysis.
class CareerCoachAnalysis {
  final CareerReadiness careerReadiness;
  final String? careerFocus;
  final List<CareerCoachRecommendation> recommendations;

  /// Server pipeline version — cached analyses with a different version are
  /// stale and trigger regeneration by the callable.
  final int analysisVersion;

  /// When the analysis was generated (client local time conversion).
  final DateTime? generatedAt;

  /// Which provider produced it (groq | huggingface).
  final String? providerUsed;

  /// v9.0 IMP-14: Career-data fingerprint stored by the server. When the
  /// profile trigger invalidates the cache (IMP-13), this is set to `""`.
  /// The provider uses this to detect staleness and show a "re-analyze"
  /// nudge without making a server call.
  final String? profileDataVersion;

  const CareerCoachAnalysis({
    this.careerReadiness = const CareerReadiness(),
    this.careerFocus,
    this.recommendations = const [],
    this.analysisVersion = 0,
    this.generatedAt,
    this.providerUsed,
    this.profileDataVersion,
  });

  /// Parse from the callable response `analysis` map OR the cached Firestore
  /// `analysis` field (both share the same shape).
  factory CareerCoachAnalysis.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const CareerCoachAnalysis();

    final rawRecs = json['recommendations'];
    final recommendations = <CareerCoachRecommendation>[];
    if (rawRecs is List) {
      for (final raw in rawRecs) {
        if (raw is! Map) continue;
        final rec = CareerCoachRecommendation.fromJson(
          Map<String, dynamic>.from(raw),
        );
        if (rec.isValid && !recommendations.any((r) => r.type == rec.type)) {
          recommendations.add(rec);
        }
        if (recommendations.length >= 5) break; // server cap
      }
    }

    return CareerCoachAnalysis(
      careerReadiness: CareerReadiness.fromJson(
        json['careerReadiness'] is Map
            ? Map<String, dynamic>.from(json['careerReadiness'] as Map)
            : null,
      ),
      careerFocus: (json['careerFocus'] as String?)?.trim(),
      recommendations: recommendations,
      analysisVersion: (json['analysisVersion'] as num?)?.toInt() ?? 0,
      generatedAt: _parseTimestamp(json['generatedAt']),
      providerUsed: json['providerUsed'] as String?,
    );
  }

  /// Parse from the Firestore `users/{uid}/career_coach/summary` document —
  /// the analysis lives under `analysis` and metadata at the top level.
  factory CareerCoachAnalysis.fromSummaryDoc(
    Map<String, dynamic>? data,
  ) {
    if (data == null) return const CareerCoachAnalysis();
    final analysis = CareerCoachAnalysis.fromJson(
      data['analysis'] is Map
          ? Map<String, dynamic>.from(data['analysis'] as Map)
          : null,
    );
    return CareerCoachAnalysis(
      careerReadiness: analysis.careerReadiness,
      careerFocus: analysis.careerFocus,
      recommendations: analysis.recommendations,
      analysisVersion:
          (data['analysisVersion'] as num?)?.toInt() ??
          analysis.analysisVersion,
      generatedAt: analysis.generatedAt ?? _parseTimestamp(data['generatedAt']),
      providerUsed: (data['providerUsed'] as String?) ?? analysis.providerUsed,
      profileDataVersion: data['profileDataVersion'] as String?,
    );
  }

  bool get hasContent =>
      careerReadiness.hasContent ||
      (careerFocus?.isNotEmpty ?? false) ||
      recommendations.isNotEmpty;

  /// Does the cached analysis carry a DIFFERENT pipeline version than the
  /// current app? (Server treats mismatches as stale; this surfaces the
  /// same check to the UI when offline.)
  bool isStaleForVersion(int currentVersion) =>
      analysisVersion != 0 && analysisVersion != currentVersion;

  /// v9.0 IMP-14: True when the server has invalidated the cache by clearing
  /// the `profileDataVersion` field (empty string). The dashboard can show a
  /// "Your career plan may be outdated — re-analyze?" nudge without making
  /// a server call.
  bool get isStaleProfile =>
      hasContent && (profileDataVersion == null || profileDataVersion!.isEmpty);

  Map<String, dynamic> toJson() => {
    'careerReadiness': careerReadiness.toJson(),
    'careerFocus': careerFocus,
    'recommendations': recommendations.map((r) => r.toJson()).toList(),
    'analysisVersion': analysisVersion,
    'generatedAt': generatedAt?.toIso8601String(),
    'providerUsed': providerUsed,
  };

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    // ISO string from the callable response.
    if (value is String) return DateTime.tryParse(value);
    // Firestore Timestamp (and anything else exposing toDateTime()) —
    // duck-typed so the model needs no Firestore dependency in tests.
    try {
      final toDateTime = (value as dynamic).toDateTime;
      if (toDateTime is Function) {
        final converted = toDateTime();
        if (converted is DateTime) return converted;
      }
    } catch (_) {
      // Not a timestamp-like object — fall through.
    }
    return null;
  }
}

/// Career Coach monthly usage — mirrors `ResumeReviewUsage`.
class CareerCoachUsage {
  final int monthlyCount;
  final int monthlyLimit;
  final String? lastResetMonth;

  const CareerCoachUsage({
    this.monthlyCount = 0,
    this.monthlyLimit = 3,
    this.lastResetMonth,
  });

  factory CareerCoachUsage.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const CareerCoachUsage();
    return CareerCoachUsage(
      monthlyCount: (json['monthlyCount'] as num?)?.toInt() ?? 0,
      monthlyLimit: (json['monthlyLimit'] as num?)?.toInt() ?? 3,
      lastResetMonth: json['lastResetMonth'] as String?,
    );
  }

  int get analysesRemaining => (monthlyLimit - monthlyCount).clamp(0, monthlyLimit);
  bool get hasReachedLimit => monthlyCount >= monthlyLimit;
  double get usagePercentage =>
      monthlyLimit > 0 ? (monthlyCount / monthlyLimit) : 0.0;

  Map<String, dynamic> toJson() => {
    'monthlyCount': monthlyCount,
    'monthlyLimit': monthlyLimit,
    'lastResetMonth': lastResetMonth,
  };
}

// CampusConnect v6.7 - Resume Review Model
//
// Represents the AI-generated resume review response.

/// Represents a single bullet point improvement suggestion
class BulletImprovement {
  final String original;
  final String improved;
  final String reason;

  const BulletImprovement({
    required this.original,
    required this.improved,
    required this.reason,
  });

  factory BulletImprovement.fromJson(Map<String, dynamic> json) {
    return BulletImprovement(
      original: json['original'] as String? ?? '',
      improved: json['improved'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'original': original,
    'improved': improved,
    'reason': reason,
  };
}

/// Section-specific advice for resume sections
class SectionAdvice {
  final String? summary;
  final String? skills;
  final String? projects;
  final String? experience;
  final String? education;

  const SectionAdvice({
    this.summary,
    this.skills,
    this.projects,
    this.experience,
    this.education,
  });

  factory SectionAdvice.fromJson(Map<String, dynamic> json) {
    return SectionAdvice(
      summary: json['summary'] as String?,
      skills: json['skills'] as String?,
      projects: json['projects'] as String?,
      experience: json['experience'] as String?,
      education: json['education'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'summary': summary,
    'skills': skills,
    'projects': projects,
    'experience': experience,
    'education': education,
  };

  /// Get non-null sections as a map for iteration
  Map<String, String> get nonNullSections {
    final sections = <String, String>{};
    if (summary != null && summary!.isNotEmpty) sections['Summary'] = summary!;
    if (skills != null && skills!.isNotEmpty) sections['Skills'] = skills!;
    if (projects != null && projects!.isNotEmpty) {
      sections['Projects'] = projects!;
    }
    if (experience != null && experience!.isNotEmpty) {
      sections['Experience'] = experience!;
    }
    if (education != null && education!.isNotEmpty) {
      sections['Education'] = education!;
    }
    return sections;
  }
}

/// Complete resume review result from AI
class ResumeReview {
  /// ATS compatibility score (0-100)
  final int atsScore;

  /// List of resume strengths
  final List<String> strengths;

  /// Keywords missing for ATS optimization
  final List<String> missingKeywords;

  /// Formatting issues detected
  final List<String> formatIssues;

  /// Before/after bullet point improvements
  final List<BulletImprovement> bulletImprovements;

  /// Section-by-section advice
  final SectionAdvice sectionAdvice;

  /// Overall actionable advice
  final String overallAdvice;

  /// Hiring likelihood verdict
  final String hireabilityVerdict;

  /// Timestamp when review was generated
  final DateTime reviewedAt;

  const ResumeReview({
    required this.atsScore,
    required this.strengths,
    required this.missingKeywords,
    required this.formatIssues,
    required this.bulletImprovements,
    required this.sectionAdvice,
    required this.overallAdvice,
    required this.hireabilityVerdict,
    required this.reviewedAt,
  });

  factory ResumeReview.fromJson(Map<String, dynamic> json) {
    return ResumeReview(
      atsScore: json['atsScore'] as int? ?? 0,
      strengths:
          (json['strengths'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      missingKeywords:
          (json['missingKeywords'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      formatIssues:
          (json['formatIssues'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      bulletImprovements:
          (json['bulletImprovements'] as List<dynamic>?)
              ?.map(
                (e) => BulletImprovement.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
      sectionAdvice: json['sectionAdvice'] != null
          ? SectionAdvice.fromJson(
              json['sectionAdvice'] as Map<String, dynamic>,
            )
          : const SectionAdvice(),
      overallAdvice: json['overallAdvice'] as String? ?? '',
      hireabilityVerdict: json['hireabilityVerdict'] as String? ?? '',
      reviewedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'atsScore': atsScore,
    'strengths': strengths,
    'missingKeywords': missingKeywords,
    'formatIssues': formatImprovements,
    'bulletImprovements': bulletImprovements.map((b) => b.toJson()).toList(),
    'sectionAdvice': sectionAdvice.toJson(),
    'overallAdvice': overallAdvice,
    'hireabilityVerdict': hireabilityVerdict,
  };

  /// Get score color based on ATS score
  String get scoreLevel {
    if (atsScore >= 80) return 'excellent';
    if (atsScore >= 60) return 'good';
    if (atsScore >= 40) return 'fair';
    return 'needsWork';
  }

  /// Check if review has any issues to address
  bool get hasIssues =>
      missingKeywords.isNotEmpty ||
      formatIssues.isNotEmpty ||
      bulletImprovements.isNotEmpty;
}

/// Alias for formatting issues (typo fix)
extension ResumeReviewExtension on ResumeReview {
  List<String> get formatImprovements => formatIssues;
}

/// v6.8: Stored resume review history item
class ResumeReviewHistory {
  final String id;
  final String userId;
  final int atsScore;
  final List<String> strengths;
  final List<String> missingKeywords;
  final List<String> formatIssues;
  final List<BulletImprovement> bulletImprovements;
  final SectionAdvice sectionAdvice;
  final String overallAdvice;
  final String hireabilityVerdict;
  final String? targetRole;
  final DateTime createdAt;
  final String monthKey; // Format: "YYYY-MM"

  const ResumeReviewHistory({
    required this.id,
    required this.userId,
    required this.atsScore,
    required this.strengths,
    required this.missingKeywords,
    required this.formatIssues,
    required this.bulletImprovements,
    required this.sectionAdvice,
    required this.overallAdvice,
    required this.hireabilityVerdict,
    this.targetRole,
    required this.createdAt,
    required this.monthKey,
  });

  factory ResumeReviewHistory.fromFirestore(
    String docId,
    Map<String, dynamic> data,
  ) {
    return ResumeReviewHistory(
      id: docId,
      userId: data['userId'] as String? ?? '',
      atsScore: data['atsScore'] as int? ?? 0,
      strengths:
          (data['strengths'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      missingKeywords:
          (data['missingKeywords'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      formatIssues:
          (data['formatIssues'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      bulletImprovements:
          (data['bulletImprovements'] as List<dynamic>?)
              ?.map(
                (e) => BulletImprovement.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          [],
      sectionAdvice: data['sectionAdvice'] != null
          ? SectionAdvice.fromJson(
              data['sectionAdvice'] as Map<String, dynamic>,
            )
          : const SectionAdvice(),
      overallAdvice: data['overallAdvice'] as String? ?? '',
      hireabilityVerdict: data['hireabilityVerdict'] as String? ?? '',
      targetRole: data['targetRole'] as String?,
      createdAt: (data['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
      monthKey: data['monthKey'] as String? ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
    'userId': userId,
    'atsScore': atsScore,
    'strengths': strengths,
    'missingKeywords': missingKeywords,
    'formatIssues': formatIssues,
    'bulletImprovements': bulletImprovements.map((b) => b.toJson()).toList(),
    'sectionAdvice': sectionAdvice.toJson(),
    'overallAdvice': overallAdvice,
    'hireabilityVerdict': hireabilityVerdict,
    'targetRole': targetRole,
    'createdAt': createdAt,
    'monthKey': monthKey,
  };

  /// Convert to ResumeReview for display
  ResumeReview toResumeReview() {
    return ResumeReview(
      atsScore: atsScore,
      strengths: strengths,
      missingKeywords: missingKeywords,
      formatIssues: formatIssues,
      bulletImprovements: bulletImprovements,
      sectionAdvice: sectionAdvice,
      overallAdvice: overallAdvice,
      hireabilityVerdict: hireabilityVerdict,
      reviewedAt: createdAt,
    );
  }

  /// Get score color based on ATS score
  String get scoreLevel {
    if (atsScore >= 80) return 'excellent';
    if (atsScore >= 60) return 'good';
    if (atsScore >= 40) return 'fair';
    return 'needsWork';
  }
}

/// Usage tracking for resume reviews (monthly limit)
class ResumeReviewUsage {
  final int monthlyCount;
  final int monthlyLimit;
  final DateTime? lastReviewAt;
  final String? lastResetMonth; // Format: "2026-01"

  const ResumeReviewUsage({
    required this.monthlyCount,
    required this.monthlyLimit,
    this.lastReviewAt,
    this.lastResetMonth,
  });

  factory ResumeReviewUsage.fromJson(Map<String, dynamic> json) {
    return ResumeReviewUsage(
      monthlyCount: json['monthlyCount'] as int? ?? 0,
      monthlyLimit: json['monthlyLimit'] as int? ?? 3,
      lastReviewAt: json['lastReviewAt'] != null
          ? DateTime.tryParse(json['lastReviewAt'] as String)
          : null,
      lastResetMonth: json['lastResetMonth'] as String?,
    );
  }

  int get reviewsRemaining =>
      (monthlyLimit - monthlyCount).clamp(0, monthlyLimit);
  bool get hasReachedLimit => monthlyCount >= monthlyLimit;
  double get usagePercentage =>
      monthlyLimit > 0 ? (monthlyCount / monthlyLimit) : 0.0;
}

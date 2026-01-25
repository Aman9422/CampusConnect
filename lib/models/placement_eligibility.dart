/// PlacementEligibility - v6.5
///
/// Rule-based eligibility result for a placement.
/// This is the MANDATORY layer that runs before any AI scoring.
class PlacementEligibility {
  final String placementId;
  final bool isEligible;
  final List<String> passedChecks;
  final List<String> failedChecks;
  final EligibilityStatus status;

  const PlacementEligibility({
    required this.placementId,
    required this.isEligible,
    required this.passedChecks,
    required this.failedChecks,
    required this.status,
  });

  /// Quick check if user can apply
  bool get canApply => isEligible && status == EligibilityStatus.eligible;

  /// Get summary message for UI
  String get summaryMessage {
    switch (status) {
      case EligibilityStatus.eligible:
        return 'You meet all requirements';
      case EligibilityStatus.notEligible:
        return failedChecks.isNotEmpty
            ? failedChecks.first
            : 'You don\'t meet the requirements';
      case EligibilityStatus.deadlinePassed:
        return 'Application deadline has passed';
      case EligibilityStatus.alreadyApplied:
        return 'You have already applied';
      case EligibilityStatus.unknown:
        return 'Eligibility could not be determined';
    }
  }

  /// Create eligible result
  factory PlacementEligibility.eligible({
    required String placementId,
    required List<String> passedChecks,
  }) {
    return PlacementEligibility(
      placementId: placementId,
      isEligible: true,
      passedChecks: passedChecks,
      failedChecks: [],
      status: EligibilityStatus.eligible,
    );
  }

  /// Create not eligible result
  factory PlacementEligibility.notEligible({
    required String placementId,
    required List<String> passedChecks,
    required List<String> failedChecks,
  }) {
    return PlacementEligibility(
      placementId: placementId,
      isEligible: false,
      passedChecks: passedChecks,
      failedChecks: failedChecks,
      status: EligibilityStatus.notEligible,
    );
  }

  /// Create deadline passed result
  factory PlacementEligibility.deadlinePassed({required String placementId}) {
    return PlacementEligibility(
      placementId: placementId,
      isEligible: false,
      passedChecks: [],
      failedChecks: ['Application deadline has passed'],
      status: EligibilityStatus.deadlinePassed,
    );
  }

  /// Create already applied result
  factory PlacementEligibility.alreadyApplied({required String placementId}) {
    return PlacementEligibility(
      placementId: placementId,
      isEligible: false,
      passedChecks: [],
      failedChecks: [],
      status: EligibilityStatus.alreadyApplied,
    );
  }

  /// Convert to JSON for caching
  Map<String, dynamic> toJson() {
    return {
      'placementId': placementId,
      'isEligible': isEligible,
      'passedChecks': passedChecks,
      'failedChecks': failedChecks,
      'status': status.name,
    };
  }

  /// Create from JSON
  factory PlacementEligibility.fromJson(Map<String, dynamic> json) {
    return PlacementEligibility(
      placementId: json['placementId'] as String,
      isEligible: json['isEligible'] as bool,
      passedChecks: List<String>.from(json['passedChecks'] ?? []),
      failedChecks: List<String>.from(json['failedChecks'] ?? []),
      status: EligibilityStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => EligibilityStatus.unknown,
      ),
    );
  }
}

/// Eligibility status enum
enum EligibilityStatus {
  eligible,
  notEligible,
  deadlinePassed,
  alreadyApplied,
  unknown,
}

/// Placement requirements model
/// Added to placements collection for eligibility checking
class PlacementRequirements {
  final double? minCgpa;
  final List<int> allowedYears;
  final List<String> programs;
  final List<String> skills;
  final List<String> branches;

  const PlacementRequirements({
    this.minCgpa,
    this.allowedYears = const [],
    this.programs = const [],
    this.skills = const [],
    this.branches = const [],
  });

  /// Check if requirements are empty (open to all)
  bool get isOpenToAll =>
      minCgpa == null &&
      allowedYears.isEmpty &&
      programs.isEmpty &&
      branches.isEmpty;

  factory PlacementRequirements.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const PlacementRequirements();

    return PlacementRequirements(
      minCgpa: (map['minCgpa'] as num?)?.toDouble(),
      allowedYears: List<int>.from(map['allowedYears'] ?? []),
      programs: List<String>.from(map['programs'] ?? []),
      skills: List<String>.from(map['skills'] ?? []),
      branches: List<String>.from(map['branches'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (minCgpa != null) 'minCgpa': minCgpa,
      if (allowedYears.isNotEmpty) 'allowedYears': allowedYears,
      if (programs.isNotEmpty) 'programs': programs,
      if (skills.isNotEmpty) 'skills': skills,
      if (branches.isNotEmpty) 'branches': branches,
    };
  }
}

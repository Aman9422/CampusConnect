import 'package:campusconnect/models/portfolio/portfolio_parse.dart';

/// CampusConnect v8.4 — Career preferences for the student portfolio.
///
/// Stored under `users/{uid}/portfolio.preferences`.
class CareerPreferences {
  final List<String> preferredRoles;
  final List<String> preferredLocations;
  final String? expectedSalary;

  /// v8.4.1 (T3): Career objective displayed on the portfolio (docs/Task.md
  /// Phase 3 "Career Objective").
  final String? careerObjective;
  final String remotePreference; // Yes | No | Hybrid
  final String relocationPreference; // Yes | No | Open

  const CareerPreferences({
    this.preferredRoles = const [],
    this.preferredLocations = const [],
    this.expectedSalary,
    this.careerObjective,
    this.remotePreference = 'Hybrid',
    this.relocationPreference = 'Open',
  });

  factory CareerPreferences.empty() => const CareerPreferences();

  factory CareerPreferences.fromMap(Map<String, dynamic> map) {
    // v8.4.7: tolerant reads — lists may contain non-strings; never throws;
    // bad fields degrade to defaults.
    return CareerPreferences(
      preferredRoles: parseStringList(map['preferredRoles']),
      preferredLocations: parseStringList(map['preferredLocations']),
      expectedSalary: asString(map['expectedSalary']),
      careerObjective: asString(map['careerObjective']),
      remotePreference: asString(map['remotePreference']) ?? 'Hybrid',
      relocationPreference: asString(map['relocationPreference']) ?? 'Open',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'preferredRoles': preferredRoles,
      'preferredLocations': preferredLocations,
      'expectedSalary': expectedSalary,
      'careerObjective': careerObjective,
      'remotePreference': remotePreference,
      'relocationPreference': relocationPreference,
    };
  }

  /// NOTE (N5, v8.4.2): `copyWith` uses `x ?? this.x`, so it CANNOT clear a
  /// field back to null — passing `careerObjective: null` keeps the existing
  /// value. To null a field, construct a fresh object (or use a sentinel).
  /// Matters when wiring the P1 ATS merge (latestATSScore/lastReviewAt).
  CareerPreferences copyWith({
    List<String>? preferredRoles,
    List<String>? preferredLocations,
    String? expectedSalary,
    String? careerObjective,
    String? remotePreference,
    String? relocationPreference,
  }) {
    return CareerPreferences(
      preferredRoles: preferredRoles ?? this.preferredRoles,
      preferredLocations: preferredLocations ?? this.preferredLocations,
      expectedSalary: expectedSalary ?? this.expectedSalary,
      careerObjective: careerObjective ?? this.careerObjective,
      remotePreference: remotePreference ?? this.remotePreference,
      relocationPreference: relocationPreference ?? this.relocationPreference,
    );
  }

  /// True when no role/location/salary/career-objective has been recorded AND
  /// the remote/relocation preferences are still at their defaults.
  /// A student who picked a non-default remote/relocation (e.g. `Remote`,
  /// `No`) or wrote a career objective has preference content — the UI must
  /// show the section (M4/L1 + v8.4.1 T3).
  bool get isEmpty =>
      preferredRoles.isEmpty &&
      preferredLocations.isEmpty &&
      (expectedSalary == null || expectedSalary!.trim().isEmpty) &&
      (careerObjective == null || careerObjective!.trim().isEmpty) &&
      remotePreference == 'Hybrid' &&
      relocationPreference == 'Open';

  static const List<String> remoteOptions = ['Yes', 'No', 'Hybrid'];
  static const List<String> relocationOptions = ['Yes', 'No', 'Open'];
}

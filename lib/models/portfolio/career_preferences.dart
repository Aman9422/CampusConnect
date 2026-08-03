/// CampusConnect v8.4 — Career preferences for the student portfolio.
///
/// Stored under `users/{uid}/portfolio.preferences`.
class CareerPreferences {
  final List<String> preferredRoles;
  final List<String> preferredLocations;
  final String? expectedSalary;
  final String remotePreference; // Yes | No | Hybrid
  final String relocationPreference; // Yes | No | Open

  const CareerPreferences({
    this.preferredRoles = const [],
    this.preferredLocations = const [],
    this.expectedSalary,
    this.remotePreference = 'Hybrid',
    this.relocationPreference = 'Open',
  });

  factory CareerPreferences.empty() => const CareerPreferences();

  factory CareerPreferences.fromMap(Map<String, dynamic> map) {
    return CareerPreferences(
      preferredRoles:
          (map['preferredRoles'] as List<dynamic>?)?.cast<String>() ??
          const [],
      preferredLocations:
          (map['preferredLocations'] as List<dynamic>?)?.cast<String>() ??
          const [],
      expectedSalary: map['expectedSalary'] as String?,
      remotePreference: map['remotePreference'] as String? ?? 'Hybrid',
      relocationPreference: map['relocationPreference'] as String? ?? 'Open',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'preferredRoles': preferredRoles,
      'preferredLocations': preferredLocations,
      'expectedSalary': expectedSalary,
      'remotePreference': remotePreference,
      'relocationPreference': relocationPreference,
    };
  }

  CareerPreferences copyWith({
    List<String>? preferredRoles,
    List<String>? preferredLocations,
    String? expectedSalary,
    String? remotePreference,
    String? relocationPreference,
  }) {
    return CareerPreferences(
      preferredRoles: preferredRoles ?? this.preferredRoles,
      preferredLocations: preferredLocations ?? this.preferredLocations,
      expectedSalary: expectedSalary ?? this.expectedSalary,
      remotePreference: remotePreference ?? this.remotePreference,
      relocationPreference: relocationPreference ?? this.relocationPreference,
    );
  }

  /// True when no role/location/salary has been recorded AND the
  /// remote/relocation preferences are still at their defaults.
  /// A student who picked a non-default remote/relocation (e.g. `Remote`,
  /// `No`) has preference content — the UI must show the section (M4/L1).
  bool get isEmpty =>
      preferredRoles.isEmpty &&
      preferredLocations.isEmpty &&
      (expectedSalary == null || expectedSalary!.trim().isEmpty) &&
      remotePreference == 'Hybrid' &&
      relocationPreference == 'Open';

  static const List<String> remoteOptions = ['Yes', 'No', 'Hybrid'];
  static const List<String> relocationOptions = ['Yes', 'No', 'Open'];
}

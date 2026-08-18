import 'package:campusconnect/models/placement.dart';
import 'package:campusconnect/models/placement_eligibility.dart';
import 'package:campusconnect/models/student_profile.dart';

/// EligibilityEngine - v6.5
///
/// Rule-based eligibility checker for placements.
/// This is the MANDATORY layer that runs BEFORE any AI scoring.
///
/// Rules are deterministic and must always work without AI.
///
/// ARCH-3: These rules are mirrored server-side in
/// `functions/recommendations/engine.js` → `checkMandatoryEligibility()`.
/// Both implementations MUST stay in sync. See `docs/eligibility_rules.md`
/// for the canonical rule set and sync policy.
class EligibilityEngine {
  /// Check eligibility for a single placement
  static PlacementEligibility checkEligibility({
    required Placement placement,
    required StudentProfile profile,
    required bool hasApplied,
  }) {
    final passedChecks = <String>[];
    final failedChecks = <String>[];

    // Rule 1: Check deadline
    if (placement.isDeadlinePassed) {
      return PlacementEligibility.deadlinePassed(placementId: placement.id);
    }

    // Rule 2: Check if already applied
    if (hasApplied) {
      return PlacementEligibility.alreadyApplied(placementId: placement.id);
    }

    final requirements = placement.requirements;

    // If no structured requirements, user is eligible
    if (requirements.isOpenToAll) {
      return PlacementEligibility.eligible(
        placementId: placement.id,
        passedChecks: ['Open to all students'],
      );
    }

    // Rule 3: Check CGPA requirement
    if (requirements.minCgpa != null) {
      final userCgpa = profile.academic.cgpa;
      if (userCgpa >= requirements.minCgpa!) {
        passedChecks.add(
          'CGPA ${userCgpa.toStringAsFixed(2)} meets minimum ${requirements.minCgpa}',
        );
      } else {
        failedChecks.add(
          'CGPA ${userCgpa.toStringAsFixed(2)} below required ${requirements.minCgpa}',
        );
      }
    }

    // Rule 4: Check year requirement
    if (requirements.allowedYears.isNotEmpty) {
      final userYear = profile.academic.year;
      if (requirements.allowedYears.contains(userYear)) {
        passedChecks.add('Year $userYear is eligible');
      } else {
        failedChecks.add(
          'Year $userYear not eligible (requires ${_formatYears(requirements.allowedYears)})',
        );
      }
    }

    // Rule 5: Check program/branch requirement
    if (requirements.programs.isNotEmpty) {
      final userProgram = profile.academic.program.toUpperCase();
      final matchesProgram = requirements.programs.any(
        (p) => p.toUpperCase() == userProgram,
      );
      if (matchesProgram) {
        passedChecks.add('Program $userProgram is eligible');
      } else {
        failedChecks.add(
          'Program $userProgram not eligible (requires ${requirements.programs.join(", ")})',
        );
      }
    }

    // Rule 6: Check branch requirement (if different from program)
    if (requirements.branches.isNotEmpty) {
      final userBranch = profile.academic.program.toUpperCase();
      final matchesBranch = requirements.branches.any(
        (b) => b.toUpperCase() == userBranch,
      );
      if (matchesBranch) {
        passedChecks.add('Branch eligible');
      } else {
        failedChecks.add(
          'Branch not eligible (requires ${requirements.branches.join(", ")})',
        );
      }
    }

    // Determine final eligibility
    if (failedChecks.isEmpty) {
      return PlacementEligibility.eligible(
        placementId: placement.id,
        passedChecks: passedChecks,
      );
    } else {
      return PlacementEligibility.notEligible(
        placementId: placement.id,
        passedChecks: passedChecks,
        failedChecks: failedChecks,
      );
    }
  }

  /// Check eligibility for multiple placements
  static Map<String, PlacementEligibility> checkAllEligibility({
    required List<Placement> placements,
    required StudentProfile profile,
    required Set<String> appliedPlacementIds,
  }) {
    final results = <String, PlacementEligibility>{};

    for (final placement in placements) {
      results[placement.id] = checkEligibility(
        placement: placement,
        profile: profile,
        hasApplied: appliedPlacementIds.contains(placement.id),
      );
    }

    return results;
  }

  /// Get eligible placements only
  static List<Placement> getEligiblePlacements({
    required List<Placement> placements,
    required StudentProfile profile,
    required Set<String> appliedPlacementIds,
  }) {
    return placements.where((placement) {
      final eligibility = checkEligibility(
        placement: placement,
        profile: profile,
        hasApplied: appliedPlacementIds.contains(placement.id),
      );
      return eligibility.isEligible;
    }).toList();
  }

  /// Sort placements by eligibility (eligible first, then by deadline)
  static List<Placement> sortByEligibility({
    required List<Placement> placements,
    required Map<String, PlacementEligibility> eligibilityMap,
  }) {
    final sorted = List<Placement>.from(placements);

    sorted.sort((a, b) {
      final eligA = eligibilityMap[a.id];
      final eligB = eligibilityMap[b.id];

      // Eligible placements first
      if (eligA?.isEligible == true && eligB?.isEligible != true) return -1;
      if (eligB?.isEligible == true && eligA?.isEligible != true) return 1;

      // Then sort by deadline (soonest first)
      return a.deadline.compareTo(b.deadline);
    });

    return sorted;
  }

  /// Format years list for display
  static String _formatYears(List<int> years) {
    if (years.isEmpty) return '';
    if (years.length == 1) return 'Year ${years.first}';
    return 'Years ${years.join(", ")}';
  }
}

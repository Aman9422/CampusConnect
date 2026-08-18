import 'package:flutter_test/flutter_test.dart';

/// CampusConnect v8.9 — Placement Recommendation Matching contract tests.
///
/// Mirrors the deterministic placement logic in
/// `functions/recommendations/engine.js`:
///   - `checkMandatoryEligibility` (deadline, already-applied, CGPA, year,
///     program/branch) — hard gates that AI can NEVER override (Phase 7).
///   - `classifyPlacementMatch` → Strong Match / Potential Match / Skill Gap.
///   - `scorePlacement` → 0-100 with skill overlap + preference + ATS blend.
///
/// Pure-Dart mirror pattern (like test/security_rules_mirror_test.dart) so
/// the contract is testable without Firebase or API keys.

({bool eligible, String? reason}) checkMandatoryEligibilityMirror({
  required bool isActive,
  required DateTime? deadline,
  required bool alreadyApplied,
  required double? minCgpa,
  required List<int> allowedYears,
  required List<String> programs,
  required List<String> branches,
  required double studentCgpa,
  required int studentYear,
  required String studentProgram,
  DateTime? now,
}) {
  if (!isActive) {
    return (eligible: false, reason: null);
  }
  final current = now ?? DateTime.now();
  if (deadline != null && deadline.isBefore(current)) {
    return (eligible: false, reason: 'Application deadline has passed');
  }
  if (alreadyApplied) {
    return (eligible: false, reason: 'You have already applied');
  }
  final failures = <String>[];
  if (minCgpa != null && studentCgpa < minCgpa) {
    failures.add('CGPA $studentCgpa below required $minCgpa');
  }
  if (allowedYears.isNotEmpty && !allowedYears.contains(studentYear)) {
    failures.add('Year $studentYear not eligible');
  }
  if (programs.isNotEmpty) {
    final upperPrograms = programs.map((p) => p.toUpperCase()).toList();
    if (!upperPrograms.contains(studentProgram.toUpperCase())) {
      failures.add('Program ${studentProgram.toUpperCase()} not eligible');
    }
  } else if (branches.isNotEmpty) {
    final upperBranches = branches.map((b) => b.toUpperCase()).toList();
    if (!upperBranches.contains(studentProgram.toUpperCase())) {
      failures.add('Branch not eligible');
    }
  }
  if (failures.isNotEmpty) return (eligible: false, reason: failures.first);
  return (eligible: true, reason: null);
}

/// Mirrors normalizeTokens (split on , space /, lowercase, drop 1-char).
Set<String> tokensOf(List<String> values) {
  return values
      .expand((value) => value.split(RegExp(r'[,\s/]+')))
      .map((token) => token.trim().toLowerCase())
      .where((token) => token.length > 1)
      .toSet();
}

int intersectionCount(Set<String> a, Set<String> b) {
  var count = 0;
  for (final value in a) {
    if (b.contains(value)) count++;
  }
  return count;
}

({String tier, double overlap, int preferenceBonus, List<String> matched, List<String> missing})
classifyPlacementMatchMirror({
  required List<String> requirementSkills,
  required List<String> freeTextSkills,
  required String role,
  required String company,
  required Set<String> studentSkills,
  required Set<String> careerSignals,
}) {
  final allReqSkills = {...requirementSkills, ...freeTextSkills}.toList();
  final reqTokens = tokensOf(allReqSkills);

  var overlap = 0.0;
  if (reqTokens.isNotEmpty) {
    overlap = intersectionCount(studentSkills, reqTokens) / reqTokens.length;
  }

  final roleSignals = tokensOf([role, company]);
  final preferenceBonus = intersectionCount(careerSignals, roleSignals);

  String tier;
  if (overlap >= 0.6 || (overlap >= 0.4 && preferenceBonus > 0)) {
    tier = 'strong';
  } else if (overlap >= 0.3 || preferenceBonus > 0) {
    tier = 'potential';
  } else {
    tier = 'skill_gap';
  }

  final matched = allReqSkills
      .where((skill) => studentSkills.contains(skill.toLowerCase()))
      .toList();
  final missing = allReqSkills
      .where((skill) => !studentSkills.contains(skill.toLowerCase()))
      .toList();

  return (
    tier: tier,
    overlap: overlap,
    preferenceBonus: preferenceBonus,
    matched: matched,
    missing: missing,
  );
}

int scorePlacementMirror({
  required String tier,
  required double overlap,
  required int? atsScore,
}) {
  var score = 35;
  score += (overlap * 40).round().clamp(0, 40).toInt();
  if (tier == 'strong') score += 8;
  if (tier == 'potential') score += 4;
  if (atsScore != null) score += (atsScore / 10).round().clamp(0, 10).toInt();
  return score.clamp(0, 100).toInt();
}

/// Mirrors buildPlacementRecommendations: portfolio-first gate → eligibility
/// gate → classify → relevance gate → score → strong/potential/skill_gap
/// label; max 4, sorted desc.
///
/// v8.9.1 portfolio-first contract: placement matching requires demonstrable
/// evidence (skills, project technologies, or an ATS-scored resume). Stated
/// intent alone (career interest) is NOT enough — the mirror returns an
/// empty list and the engine emits the portfolio gate card instead.
///
/// v8.9.1 relevance gate: an eligible placement with ZERO skill overlap AND
/// ZERO career-alignment is irrelevant noise (the "Security Operations at
/// TCS" report) and is always skipped.
List<({String role, String company, String tier, int score})>
buildPlacementRecommendationsMirror({
  required List<
    ({
      String id,
      String role,
      String company,
      List<String> requirementSkills,
      List<String> freeTextSkills,
      DateTime? deadline,
      bool isActive,
      double? minCgpa,
      List<int> allowedYears,
      List<String> programs,
      List<String> branches,
    })
  >
  placements,
  required Set<String> studentSkills,
  required Set<String> careerSignals,
  required double studentCgpa,
  required int studentYear,
  required String studentProgram,
  required Set<String> appliedIds,
  required int? atsScore,
  bool hasProjectTokens = false,
}) {
  // v8.9.1 portfolio-first gate (mirror of hasMeaningfulPortfolioContent):
  // real skills OR project technologies OR an ATS-scored resume. Career
  // interest / preferred roles are stated intent, NOT evidence.
  final hasMeaningfulPortfolioContent =
      studentSkills.isNotEmpty || hasProjectTokens || atsScore != null;
  if (!hasMeaningfulPortfolioContent) {
    return [];
  }

  final results = <({String role, String company, String tier, int score})>[];
  for (final placement in placements) {
    final eligibility = checkMandatoryEligibilityMirror(
      isActive: placement.isActive,
      deadline: placement.deadline,
      alreadyApplied: appliedIds.contains(placement.id),
      minCgpa: placement.minCgpa,
      allowedYears: placement.allowedYears,
      programs: placement.programs,
      branches: placement.branches,
      studentCgpa: studentCgpa,
      studentYear: studentYear,
      studentProgram: studentProgram,
    );
    if (!eligibility.eligible) continue;

    final match = classifyPlacementMatchMirror(
      requirementSkills: placement.requirementSkills,
      freeTextSkills: placement.freeTextSkills,
      role: placement.role,
      company: placement.company,
      studentSkills: studentSkills,
      careerSignals: careerSignals,
    );

    // v8.9.1 relevance gate: zero skill overlap AND zero career alignment →
    // irrelevant for this student (e.g. Security Operations at TCS for an
    // app-development-focused student). Never recommend it.
    if (match.overlap == 0 && match.preferenceBonus == 0) {
      continue;
    }

    final score = scorePlacementMirror(
      tier: match.tier,
      overlap: match.overlap,
      atsScore: atsScore,
    );
    results.add((
      role: placement.role,
      company: placement.company,
      tier: match.tier,
      score: score,
    ));
  }
  results.sort((a, b) => b.score.compareTo(a.score));
  return results.take(4).toList();
}

void main() {
  group('checkMandatoryEligibility — hard gates (deterministic)', () {
    test('eligible student passes when all gates clear', () {
      final result = checkMandatoryEligibilityMirror(
        isActive: true,
        deadline: DateTime.now().add(const Duration(days: 7)),
        alreadyApplied: false,
        minCgpa: 7.0,
        allowedYears: [3, 4],
        programs: ['CSE'],
        branches: [],
        studentCgpa: 8.2,
        studentYear: 3,
        studentProgram: 'CSE',
      );
      expect(result.eligible, isTrue);
      expect(result.reason, isNull);
    });

    test('CGPA below the requirement is rejected', () {
      final result = checkMandatoryEligibilityMirror(
        isActive: true,
        deadline: DateTime.now().add(const Duration(days: 7)),
        alreadyApplied: false,
        minCgpa: 7.0,
        allowedYears: [],
        programs: [],
        branches: [],
        studentCgpa: 6.5,
        studentYear: 3,
        studentProgram: 'CSE',
      );
      expect(result.eligible, isFalse);
      expect(result.reason, contains('CGPA'));
    });

    test('wrong year is rejected', () {
      final result = checkMandatoryEligibilityMirror(
        isActive: true,
        deadline: DateTime.now().add(const Duration(days: 7)),
        alreadyApplied: false,
        minCgpa: null,
        allowedYears: [4],
        programs: [],
        branches: [],
        studentCgpa: 8.0,
        studentYear: 2,
        studentProgram: 'CSE',
      );
      expect(result.eligible, isFalse);
      expect(result.reason, contains('Year'));
    });

    test('wrong program/branch is rejected', () {
      final result = checkMandatoryEligibilityMirror(
        isActive: true,
        deadline: DateTime.now().add(const Duration(days: 7)),
        alreadyApplied: false,
        minCgpa: null,
        allowedYears: [],
        programs: ['CSE'],
        branches: [],
        studentCgpa: 8.0,
        studentYear: 3,
        studentProgram: 'ECE',
      );
      expect(result.eligible, isFalse);
      expect(result.reason, contains('Program'));
    });

    test('a passed deadline rejects regardless of other gates', () {
      final result = checkMandatoryEligibilityMirror(
        isActive: true,
        deadline: DateTime.now().subtract(const Duration(days: 1)),
        alreadyApplied: false,
        minCgpa: null,
        allowedYears: [],
        programs: [],
        branches: [],
        studentCgpa: 9.0,
        studentYear: 4,
        studentProgram: 'CSE',
      );
      expect(result.eligible, isFalse);
      expect(result.reason, contains('deadline'));
    });

    test('already-applied placements are never re-recommended', () {
      final result = checkMandatoryEligibilityMirror(
        isActive: true,
        deadline: DateTime.now().add(const Duration(days: 7)),
        alreadyApplied: true,
        minCgpa: null,
        allowedYears: [],
        programs: [],
        branches: [],
        studentCgpa: 9.0,
        studentYear: 4,
        studentProgram: 'CSE',
      );
      expect(result.eligible, isFalse);
      expect(result.reason, contains('already applied'));
    });

    test('no gates configured → everything eligible (skills not a gate)', () {
      final result = checkMandatoryEligibilityMirror(
        isActive: true,
        deadline: null,
        alreadyApplied: false,
        minCgpa: null,
        allowedYears: [],
        programs: [],
        branches: [],
        studentCgpa: 0,
        studentYear: 1,
        studentProgram: '',
      );
      expect(result.eligible, isTrue);
    });
  });

  group('classifyPlacementMatch — tiers', () {
    test('high skill overlap → Strong Match', () {
      final match = classifyPlacementMatchMirror(
        requirementSkills: ['Flutter', 'Dart', 'Firebase'],
        freeTextSkills: [],
        role: 'Flutter Developer',
        company: 'TechCorp',
        studentSkills: {'flutter', 'dart', 'firebase', 'git'},
        careerSignals: {},
      );
      expect(match.tier, 'strong');
      expect(match.overlap, greaterThanOrEqualTo(0.6));
    });

    test('partial overlap with career preference → Strong Match', () {
      final match = classifyPlacementMatchMirror(
        requirementSkills: ['Flutter', 'Dart', 'Firebase'],
        freeTextSkills: [],
        role: 'Flutter Developer',
        company: 'TechCorp',
        studentSkills: {'flutter', 'dart', 'git'},
        careerSignals: {'flutter', 'developer'},
      );
      expect(match.tier, 'strong');
    });

    test('low overlap with sparse preference → Potential Match', () {
      final match = classifyPlacementMatchMirror(
        requirementSkills: ['Flutter', 'Dart', 'Firebase', 'Kotlin'],
        freeTextSkills: [],
        role: 'Mobile Developer',
        company: 'TechCorp',
        studentSkills: {'flutter', 'git'},
        careerSignals: {'mobile'},
      );
      expect(match.tier, 'potential');
    });

    test('no overlap / no preference → Skill Gap', () {
      final match = classifyPlacementMatchMirror(
        requirementSkills: ['Flutter', 'Dart', 'Firebase'],
        freeTextSkills: [],
        role: 'Flutter Developer',
        company: 'TechCorp',
        studentSkills: {'python', 'django', 'sql'},
        careerSignals: {'data'},
      );
      expect(match.tier, 'skill_gap');
      expect(match.matched, isEmpty);
      expect(match.missing, containsAll(['Flutter', 'Dart']));
    });
  });

  group('buildPlacementRecommendations — eligibility rejection + ranking', () {
    test('mandatory-ineligible placements are never recommended', () {
      final results = buildPlacementRecommendationsMirror(
        placements: [
          (
            id: 'p1',
            role: 'SDE',
            company: 'A',
            requirementSkills: ['Java'],
            freeTextSkills: [],
            deadline: DateTime.now().add(const Duration(days: 7)),
            isActive: true,
            minCgpa: 8.0,
            allowedYears: [4],
            programs: [],
            branches: [],
          ),
          (
            id: 'p2',
            role: 'Analyst',
            company: 'B',
            requirementSkills: ['SQL', 'Python'],
            freeTextSkills: [],
            deadline: DateTime.now().add(const Duration(days: 7)),
            isActive: true,
            minCgpa: null,
            allowedYears: [],
            programs: [],
            branches: [],
          ),
        ],
        studentSkills: {'sql', 'python', 'java'},
        careerSignals: {},
        studentCgpa: 6.5, // fails p1's 8.0 CGPA gate
        studentYear: 3, // fails p1's year-4 gate
        studentProgram: 'CSE',
        appliedIds: {},
        atsScore: 70,
      );

      expect(results.any((r) => r.role == 'SDE'), isFalse);
      expect(results.any((r) => r.role == 'Analyst'), isTrue);
    });

    test('eligible placements sort by score descending (max 4)', () {
      final results = buildPlacementRecommendationsMirror(
        placements: List.generate(
          6,
          (i) => (
            id: 'p$i',
            role: 'Role $i',
            company: 'C$i',
            requirementSkills: ['Dart', 'Flutter', 'Firebase'],
            freeTextSkills: [],
            deadline: DateTime.now().add(const Duration(days: 7)),
            isActive: true,
            minCgpa: null,
            allowedYears: [],
            programs: [],
            branches: [],
          ),
        ),
        studentSkills: {'dart', 'flutter', 'firebase'},
        careerSignals: {},
        studentCgpa: 8.0,
        studentYear: 4,
        studentProgram: 'CSE',
        appliedIds: {},
        atsScore: 80,
      );

      expect(results.length, lessThanOrEqualTo(4));
      for (var i = 1; i < results.length; i++) {
        expect(results[i].score, lessThanOrEqualTo(results[i - 1].score));
      }
    });

    test('applied placements are excluded from the recommendation list', () {
      final results = buildPlacementRecommendationsMirror(
        placements: [
          (
            id: 'p_applied',
            role: 'SDE',
            company: 'A',
            requirementSkills: ['Java'],
            freeTextSkills: [],
            deadline: DateTime.now().add(const Duration(days: 7)),
            isActive: true,
            minCgpa: null,
            allowedYears: [],
            programs: [],
            branches: [],
          ),
        ],
        studentSkills: {'java', 'git'},
        careerSignals: {},
        studentCgpa: 8.0,
        studentYear: 4,
        studentProgram: 'CSE',
        appliedIds: {'p_applied'},
        atsScore: 75,
      );

      expect(results, isEmpty);
    });

    test(
      'a student with NO skills/interests/ATS data gets no generic placements',
      () {
        // Regression: new students with an empty profile doc (no portfolio,
        // no careerInterest, no ATS) received every eligible placement at the
        // 35 baseline — e.g. a security-focused SOC role for an app-focused
        // student. The engine now requires at least one student signal to
        // emit placement matches.
        final results = buildPlacementRecommendationsMirror(
          placements: [
            (
              id: 'soc_1',
              role: 'Security Operations Intern',
              company: 'TCS',
              requirementSkills: ['SIEM', 'Linux', 'Networking'],
              freeTextSkills: [],
              deadline: DateTime.now().add(const Duration(days: 7)),
              isActive: true,
              minCgpa: null,
              allowedYears: [],
              programs: [],
              branches: [],
            ),
            (
              id: 'swe_1',
              role: 'Software Engineering Intern',
              company: 'Google',
              requirementSkills: ['Java', 'Algorithms'],
              freeTextSkills: [],
              deadline: DateTime.now().add(const Duration(days: 7)),
              isActive: true,
              minCgpa: null,
              allowedYears: [],
              programs: [],
              branches: [],
            ),
          ],
          studentSkills: {}, // profile doc had no skills
          careerSignals: {}, // no career interest/preferences stored
          studentCgpa: 0, // academic fields also absent
          studentYear: 0,
          studentProgram: '',
          appliedIds: {},
          atsScore: null, // no resume/ATS yet
        );

        expect(results, isEmpty);
      },
    );

    test(
      'an intent-only student (career interest, no portfolio evidence) gets '
      'NO placement recs — the portfolio gate card handles them',
      () {
        // v8.9.1 portfolio-first regression: a student with ONLY a stated
        // career interest (the REQUIRED setup field) but no skills, projects
        // or ATS-scored resume must not receive placement matches. The
        // engine emits the "Complete your portfolio first" gate card instead.
        final results = buildPlacementRecommendationsMirror(
          placements: [
            (
              id: 'app_dev',
              role: 'App Developer Intern',
              company: 'TechCo',
              requirementSkills: ['Flutter'],
              freeTextSkills: [],
              deadline: DateTime.now().add(const Duration(days: 7)),
              isActive: true,
              minCgpa: null,
              allowedYears: [],
              programs: [],
              branches: [],
            ),
          ],
          studentSkills: {}, // no skills recorded
          careerSignals: {'app', 'developer', 'flutter'}, // intent only
          studentCgpa: 8.0,
          studentYear: 3,
          studentProgram: 'CSE',
          appliedIds: {},
          atsScore: null, // no resume/ATS yet
        );

        expect(results, isEmpty);
      },
    );

    test(
      'the TCS SOC case: eligible but zero skill overlap AND zero career '
      'alignment is never recommended',
      () {
        // Regression from the user report: an app-development-focused
        // student kept seeing "Security Operations at TCS". The placement is
        // mandatory-eligible (open, CGPA/year fine) but has zero skill
        // overlap and zero career-signal alignment — the v8.9.1 relevance
        // gate must skip it, even though the student has portfolio evidence.
        final results = buildPlacementRecommendationsMirror(
          placements: [
            (
              id: 'soc_1',
              role: 'Security Operations Intern',
              company: 'TCS',
              requirementSkills: ['SIEM', 'Linux', 'Network Security', 'Firewall'],
              freeTextSkills: [],
              deadline: DateTime.now().add(const Duration(days: 7)),
              isActive: true,
              minCgpa: null,
              allowedYears: [],
              programs: [],
              branches: [],
            ),
            (
              id: 'app_dev_1',
              role: 'Flutter Developer Intern',
              company: 'TechCo',
              requirementSkills: ['Flutter', 'Dart'],
              freeTextSkills: [],
              deadline: DateTime.now().add(const Duration(days: 7)),
              isActive: true,
              minCgpa: null,
              allowedYears: [],
              programs: [],
              branches: [],
            ),
          ],
          studentSkills: {'flutter', 'dart', 'firebase', 'git'},
          careerSignals: {'flutter', 'mobile', 'developer'},
          studentCgpa: 8.2,
          studentYear: 3,
          studentProgram: 'CSE',
          appliedIds: {},
          atsScore: 78,
        );

        // The irrelevant SOC-at-TCS row is gone; only the relevant app-dev
        // placement survives.
        expect(
          results.any((r) => r.role == 'Security Operations Intern'),
          isFalse,
          reason: 'SOC at TCS has zero skill overlap and zero career '
              'alignment — must be filtered by the relevance gate',
        );
        expect(
          results.any((r) => r.role == 'Flutter Developer Intern'),
          isTrue,
          reason: 'the Flutter placement overlaps the student skills ',
        );
      },
    );

    test(
      'a student WITH portfolio evidence (skills) but an intent-only signal '
      'still unlocks placement matching',
      () {
        // Portfolio-first gate passes because real skills are present; the
        // career signal is the alignment bonus, not the gate.
        final results = buildPlacementRecommendationsMirror(
          placements: [
            (
              id: 'app_dev',
              role: 'App Developer Intern',
              company: 'TechCo',
              requirementSkills: ['Flutter', 'Dart'],
              freeTextSkills: [],
              deadline: DateTime.now().add(const Duration(days: 7)),
              isActive: true,
              minCgpa: null,
              allowedYears: [],
              programs: [],
              branches: [],
            ),
          ],
          studentSkills: {'flutter', 'dart'},
          careerSignals: {'app', 'developer', 'flutter'},
          studentCgpa: 8.0,
          studentYear: 3,
          studentProgram: 'CSE',
          appliedIds: {},
          atsScore: null,
        );

        expect(results, isNotEmpty);
      },
    );
  });
}

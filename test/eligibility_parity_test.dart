import 'package:campusconnect/models/placement.dart';
import 'package:campusconnect/models/placement_eligibility.dart';
import 'package:campusconnect/models/student_profile.dart';
import 'package:campusconnect/services/eligibility_engine.dart';
import 'package:flutter_test/flutter_test.dart';

/// CampusConnect v9.2.4 (D-3) — client/server eligibility PARITY tests.
///
/// The v9.2.3 audit found that `lib/services/eligibility_engine.dart` and
/// `functions/recommendations/engine.js::checkMandatoryEligibility` disagreed
/// on placements that specify BOTH `programs` and `branches`:
///
///   * the server treats them as ALTERNATIVES — `branches` is consulted only
///     when `programs` is empty (`if (programs.length > 0) {…} else if
///     (branches.length > 0) {…}`);
///   * the client treated them as two INDEPENDENT requirements, so both had to
///     pass.
///
/// The consequence was visible to the student: the eligibility badge on the
/// placements list contradicted the placement recommendation card the engine
/// emitted for the very same placement and student, because the badge is the
/// student's only pre-apply signal.
///
/// These tests drive the **real** client engine and compare its verdict against
/// a pure mirror of the server's rule, case for case. The mirror is duplicated
/// from `test/placement_match_test.dart` on purpose: each suite is
/// self-contained and must fail independently if the semantics drift again.
///
/// `docs/eligibility_rules.md` documents the same canonical rule. Client badge,
/// server engine and documented rule are now required to agree.
void main() {
  // ---------------------------------------------------------------------------
  // Mirror of the SERVER rule (functions/recommendations/engine.js).
  //
  // Kept structurally identical to the JS: the programs gate is evaluated
  // first and, when it applies, `branches` is never looked at.
  // ---------------------------------------------------------------------------
  ({bool eligible, String? reason}) checkMandatoryEligibilityServer({
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
    if (!isActive) return (eligible: false, reason: null);

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

    // The D-3 rule, verbatim: programs first, branches ONLY if programs is
    // empty. Both lists are compared against the student's PROGRAM.
    if (programs.isNotEmpty) {
      if (!programs.contains(studentProgram)) {
        failures.add('Program ${studentProgram.toUpperCase()} not eligible');
      }
    } else if (branches.isNotEmpty) {
      if (!branches.contains(studentProgram)) {
        failures.add('Branch not eligible');
      }
    }

    if (failures.isNotEmpty) return (eligible: false, reason: failures.first);
    return (eligible: true, reason: null);
  }

  Placement buildPlacement({
    required List<String> programs,
    required List<String> branches,
    double? minCgpa,
    List<int> allowedYears = const [],
    DateTime? deadline,
    bool isActive = true,
  }) {
    return Placement(
      id: 'placement_1',
      company: 'Acme Corp',
      role: 'Software Engineer',
      description: 'Build things',
      eligibility: 'Legacy free-text eligibility',
      salary: '12 LPA',
      deadline: deadline ?? DateTime.now().add(const Duration(days: 30)),
      postedAt: DateTime.now(),
      isActive: isActive,
      requirements: PlacementRequirements(
        minCgpa: minCgpa,
        allowedYears: allowedYears,
        programs: programs,
        branches: branches,
      ),
    );
  }

  StudentProfile buildProfile({
    required String program,
    double cgpa = 8.0,
    int year = 3,
  }) {
    return StudentProfile(
      uid: 'student_1',
      personal: PersonalInfo(
        fullName: 'Test Student',
        email: 'student@example.com',
        phone: '',
        avatarUrl: '',
      ),
      academic: AcademicInfo(
        college: 'Test College',
        program: program,
        year: year,
        cgpa: cgpa,
      ),
      career: CareerInfo(interests: const [], preferredRoles: const []),
      metadata: ProfileMetadata(
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
  }

  /// Asserts the REAL client engine and the SERVER mirror agree for one case.
  void expectParity({
    required String name,
    required List<String> programs,
    required List<String> branches,
    required String studentProgram,
    required bool expectedEligible,
    double cgpa = 8.0,
    int year = 3,
    double? minCgpa,
    List<int> allowedYears = const [],
  }) {
    final placement = buildPlacement(
      programs: programs,
      branches: branches,
      minCgpa: minCgpa,
      allowedYears: allowedYears,
    );
    final profile = buildProfile(
      program: studentProgram,
      cgpa: cgpa,
      year: year,
    );

    final client = EligibilityEngine.checkEligibility(
      placement: placement,
      profile: profile,
      hasApplied: false,
    );

    final server = checkMandatoryEligibilityServer(
      isActive: placement.isActive,
      deadline: placement.deadline,
      alreadyApplied: false,
      minCgpa: minCgpa,
      allowedYears: allowedYears,
      programs: programs,
      branches: branches,
      studentCgpa: cgpa,
      studentYear: year,
      studentProgram: studentProgram,
    );

    expect(
      client.isEligible,
      expectedEligible,
      reason: '[client] $name — failed: ${client.failedChecks}',
    );
    expect(
      server.eligible,
      expectedEligible,
      reason: '[server mirror] $name — failed: ${server.reason}',
    );
    expect(
      client.isEligible,
      server.eligible,
      reason: 'client and server disagree for: $name',
    );
  }

  // ---------------------------------------------------------------------------
  // The table the Task requires: programs only · branches only · both ·
  // matching program · matching branch · non-matching program ·
  // non-matching branch · missing student program.
  // ---------------------------------------------------------------------------
  group('programs / branches parity — table-driven (D-3)', () {
    test('programs only, matching program → eligible', () {
      expectParity(
        name: 'programs only · match',
        programs: ['CSE'],
        branches: [],
        studentProgram: 'CSE',
        expectedEligible: true,
      );
    });

    test('programs only, non-matching program → not eligible', () {
      expectParity(
        name: 'programs only · no match',
        programs: ['CSE'],
        branches: [],
        studentProgram: 'ECE',
        expectedEligible: false,
      );
    });

    test('branches only, matching branch → eligible', () {
      expectParity(
        name: 'branches only · match',
        programs: [],
        branches: ['CSE'],
        studentProgram: 'CSE',
        expectedEligible: true,
      );
    });

    test('branches only, non-matching branch → not eligible', () {
      expectParity(
        name: 'branches only · no match',
        programs: [],
        branches: ['CSE'],
        studentProgram: 'ECE',
        expectedEligible: false,
      );
    });

    test('BOTH lists — program matches, branch does NOT → ELIGIBLE '
        '(server semantics: branches ignored when programs is set)', () {
      expectParity(
        name: 'both · program match + branch mismatch',
        programs: ['CSE'],
        branches: ['IT'],
        studentProgram: 'CSE',
        expectedEligible: true,
      );
    });

    test('BOTH lists — program does NOT match, branch DOES → NOT eligible '
        '(the pre-v9.2.4 client wrongly returned eligible here)', () {
      expectParity(
        name: 'both · program mismatch + branch match',
        programs: ['CSE'],
        branches: ['IT'],
        studentProgram: 'IT',
        expectedEligible: false,
      );
    });

    test('BOTH lists — neither matches → not eligible', () {
      expectParity(
        name: 'both · neither matches',
        programs: ['CSE'],
        branches: ['IT'],
        studentProgram: 'MECH',
        expectedEligible: false,
      );
    });

    test('BOTH lists — program matches and branch also matches → eligible', () {
      expectParity(
        name: 'both · both match',
        programs: ['CSE'],
        branches: ['CSE'],
        studentProgram: 'CSE',
        expectedEligible: true,
      );
    });

    test('missing student program + programs required → not eligible', () {
      expectParity(
        name: 'missing program · programs required',
        programs: ['CSE'],
        branches: [],
        studentProgram: '',
        expectedEligible: false,
      );
    });

    test('missing student program + branches required → not eligible', () {
      expectParity(
        name: 'missing program · branches required',
        programs: [],
        branches: ['CSE'],
        studentProgram: '',
        expectedEligible: false,
      );
    });

    test('missing student program, no program/branch gate → eligible', () {
      expectParity(
        name: 'missing program · no gate',
        programs: [],
        branches: [],
        studentProgram: '',
        expectedEligible: true,
      );
    });

    test('multi-entry lists behave like the server (any-of semantics)', () {
      expectParity(
        name: 'multi-entry programs · match',
        programs: ['CSE', 'IT', 'ECE'],
        branches: [],
        studentProgram: 'IT',
        expectedEligible: true,
      );
      expectParity(
        name: 'multi-entry branches · match',
        programs: [],
        branches: ['CSE', 'IT', 'ECE'],
        studentProgram: 'ECE',
        expectedEligible: true,
      );
      expectParity(
        name: 'multi-entry programs · no match',
        programs: ['CSE', 'IT', 'ECE'],
        branches: [],
        studentProgram: 'MECH',
        expectedEligible: false,
      );
    });
  });

  group('the other gates stay in parity', () {
    test('CGPA gate', () {
      expectParity(
        name: 'cgpa below minimum',
        programs: [],
        branches: [],
        studentProgram: 'CSE',
        expectedEligible: false,
        cgpa: 6.5,
        minCgpa: 7.0,
      );
      expectParity(
        name: 'cgpa meets minimum',
        programs: [],
        branches: [],
        studentProgram: 'CSE',
        expectedEligible: true,
        cgpa: 7.5,
        minCgpa: 7.0,
      );
    });

    test('year gate', () {
      expectParity(
        name: 'year not allowed',
        programs: [],
        branches: [],
        studentProgram: 'CSE',
        expectedEligible: false,
        year: 2,
        allowedYears: [3, 4],
      );
      expectParity(
        name: 'year allowed',
        programs: [],
        branches: [],
        studentProgram: 'CSE',
        expectedEligible: true,
        year: 4,
        allowedYears: [3, 4],
      );
    });

    test('a program gate and a CGPA gate are both enforced (AND)', () {
      // The programs/branches pair is an OR-ish alternative, but every OTHER
      // gate is still an independent AND — the fix must not have loosened that.
      expectParity(
        name: 'program matches but cgpa fails',
        programs: ['CSE'],
        branches: [],
        studentProgram: 'CSE',
        expectedEligible: false,
        cgpa: 6.0,
        minCgpa: 7.5,
      );
      expectParity(
        name: 'program matches and cgpa passes',
        programs: ['CSE'],
        branches: ['IT'],
        studentProgram: 'CSE',
        expectedEligible: true,
        cgpa: 8.0,
        minCgpa: 7.5,
      );
    });
  });

  group('deadline + already-applied short circuits', () {
    test('a passed deadline is rejected by both paths', () {
      final placement = buildPlacement(
        programs: ['CSE'],
        branches: [],
        deadline: DateTime.now().subtract(const Duration(days: 1)),
      );
      final profile = buildProfile(program: 'CSE');

      final client = EligibilityEngine.checkEligibility(
        placement: placement,
        profile: profile,
        hasApplied: false,
      );
      expect(client.isEligible, isFalse);
      expect(client.status, EligibilityStatus.deadlinePassed);

      final server = checkMandatoryEligibilityServer(
        isActive: true,
        deadline: placement.deadline,
        alreadyApplied: false,
        minCgpa: null,
        allowedYears: const [],
        programs: const ['CSE'],
        branches: const [],
        studentCgpa: 8.0,
        studentYear: 3,
        studentProgram: 'CSE',
      );
      expect(server.eligible, isFalse);
    });

    test('already-applied is rejected by both paths', () {
      final placement = buildPlacement(programs: ['CSE'], branches: []);
      final profile = buildProfile(program: 'CSE');

      final client = EligibilityEngine.checkEligibility(
        placement: placement,
        profile: profile,
        hasApplied: true,
      );
      expect(client.isEligible, isFalse);
      expect(client.status, EligibilityStatus.alreadyApplied);

      final server = checkMandatoryEligibilityServer(
        isActive: true,
        deadline: placement.deadline,
        alreadyApplied: true,
        minCgpa: null,
        allowedYears: const [],
        programs: const ['CSE'],
        branches: const [],
        studentCgpa: 8.0,
        studentYear: 3,
        studentProgram: 'CSE',
      );
      expect(server.eligible, isFalse);
    });
  });

  group('KNOWN DIVERGENCE (documented, deliberately not "fixed")', () {
    test(
      'the CLIENT compares program/branch case-insensitively while the server '
      'compares exactly — the client is the more permissive superset',
      () {
        // Making the client case-SENSITIVE would start hiding placements whose
        // stored program is "cse" while the placement lists "CSE" — a
        // regression for real (hand-entered) data. Changing the SERVER is
        // outside this release (no recommendation-engine rewrite), so the
        // divergence is recorded here rather than silently changed in either
        // direction. It is noted in docs/eligibility_rules.md and in the
        // v9.2.4 hardening report as a known limitation.
        final placement = buildPlacement(programs: ['cse'], branches: []);
        final profile = buildProfile(program: 'CSE');

        final client = EligibilityEngine.checkEligibility(
          placement: placement,
          profile: profile,
          hasApplied: false,
        );
        expect(client.isEligible, isTrue, reason: 'client is case-insensitive');

        final server = checkMandatoryEligibilityServer(
          isActive: true,
          deadline: placement.deadline,
          alreadyApplied: false,
          minCgpa: null,
          allowedYears: const [],
          programs: const ['cse'],
          branches: const [],
          studentCgpa: 8.0,
          studentYear: 3,
          studentProgram: 'CSE',
        );
        expect(
          server.eligible,
          isFalse,
          reason: 'server compares the raw string exactly',
        );
      },
    );

    test(
      'for UPPER-CASE data (the format the app writes) the two agree exactly',
      () {
        // The divergence above only shows up for mixed-case rows; the stored
        // format the client writes is upper-case, so the badge and the engine
        // agree for all data the application itself produces.
        final placement = buildPlacement(programs: ['CSE'], branches: ['IT']);
        final profile = buildProfile(program: 'CSE');

        final client = EligibilityEngine.checkEligibility(
          placement: placement,
          profile: profile,
          hasApplied: false,
        );
        final server = checkMandatoryEligibilityServer(
          isActive: true,
          deadline: placement.deadline,
          alreadyApplied: false,
          minCgpa: null,
          allowedYears: const [],
          programs: const ['CSE'],
          branches: const ['IT'],
          studentCgpa: 8.0,
          studentYear: 3,
          studentProgram: 'CSE',
        );

        expect(client.isEligible, isTrue);
        expect(server.eligible, isTrue);
      },
    );
  });
}

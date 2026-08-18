import 'package:flutter_test/flutter_test.dart';

/// CampusConnect v8.9 — Career-Role Matching contract tests.
///
/// Mirrors the deterministic role-scoring logic in
/// `functions/recommendations/career_roles.js` (`matchRole`) and
/// `functions/recommendations/engine.js` (`buildRoleRecommendations`) as pure
/// Dart functions so the contract is unit-testable without Firebase or API
/// keys — same pattern as `test/security_rules_mirror_test.dart`.
///
/// Under test:
///   - Weighted role fit: required skills weight 3, nice-to-have 1.5.
///   - Keyword career-intent bonus (≤12) — exact-phrase fast path AND
///     v8.9.3 token-overlap fallback (R1b).
///   - v8.9.3 evidence pool (R1c): demonstrated experience/cert/project
///     tokens satisfy role skills with an ALL-tokens rule.
///   - Role recommendation emits targetRole, explainable score, reason,
///     matched and missing skills.
///   - Missing skills are surfaced (NOT a hard gate) — Skill-Gap reports them.
///   - Partial/weak profiles never exceed their true fit.
///   - v8.9.3 threshold 20 (R2): thin-but-real portfolios surface their best
///     role; intent-only students still gate at the portfolio-first layer.

/// Mirrors `skillTokens` + role skill presence checks in career_roles.js.
Set<String> skillTokens(String skill) {
  return skill
      .toLowerCase()
      .split(RegExp(r'[,\s/]+'))
      .where((token) => token.length > 1)
      .toSet();
}

/// Mirrors `matchRole` from career_roles.js — weighted-coverage fit.
///
/// v8.9.3 (R1c): `evidenceTokens` is the engine's demonstrated-evidence pool
/// (experience description/role/tech + certification titles + project
/// titles/tech). A role skill is satisfied when ANY structured token
/// (skills/projects/certs) hits, OR when ALL of the skill's tokens appear in
/// the free-text evidence pool — so a description casually containing "data"
/// cannot satisfy "Data Visualization".
///
/// v8.9.3 (R1b): keyword matching uses a majority-token-overlap fallback in
/// addition to the exact-phrase fast path.
({String roleId, int score, List<String> matched, List<String> missing})
matchRoleMirror({
  required String roleId,
  required String title,
  required List<String> requiredSkills,
  required List<String> niceToHaveSkills,
  required List<String> keywords,
  required Set<String> skills,
  required Set<String> projectTokens,
  required Set<String> careerSignals,
  required Set<String> careerPhrases,
  required Set<String> certTokens,
  Set<String> evidenceTokens = const {},
}) {
  final matched = <String>[];
  var matchedWeight = 0.0;
  var totalWeight = 0.0;
  final phraseSet = careerPhrases;

  bool hasSkill(String skill) {
    final tokens = skillTokens(skill);
    if (tokens.isEmpty) return false;
    final structuredHit = tokens.any(
      (token) =>
          skills.contains(token) ||
          projectTokens.contains(token) ||
          certTokens.contains(token),
    );
    if (structuredHit) return true;
    // v8.9.3 (R1c): ALL-token rule for free-text evidence.
    return tokens.every((token) => evidenceTokens.contains(token));
  }

  for (final skill in requiredSkills) {
    totalWeight += 3;
    if (hasSkill(skill)) {
      matchedWeight += 3;
      matched.add(skill);
    }
  }
  for (final skill in niceToHaveSkills) {
    totalWeight += 1.5;
    if (hasSkill(skill)) {
      matchedWeight += 1.5;
      if (!matched.contains(skill)) matched.add(skill);
    }
  }

  var keywordBonus = 0;
  for (final keyword in keywords) {
    final key = keyword.toLowerCase();
    // Fast path: the exact phrase is present verbatim in the career phrases
    // ("app development" matches a keyword alias "App Development").
    if (careerSignals.contains(key) || phraseSet.contains(key)) {
      keywordBonus += 2;
      continue;
    }
    // v8.9.3 (R1b): token-overlap fallback. `careerSignals` is TOKENIZED
    // ("App Development" ⇒ {app, development}) while role keywords are
    // multi-word phrases ("App Developer"); exact lookups could never fire.
    // Require a MAJORITY of the keyword's tokens in careerSignals or the
    // evidence pool. Single-token keywords ("Analytics") are skipped — the
    // exact fast path already covers them.
    final kwTokens = skillTokens(key).toList();
    if (kwTokens.length <= 1) continue;
    var overlap = 0;
    for (final token in kwTokens) {
      if (careerSignals.contains(token) || evidenceTokens.contains(token)) {
        overlap++;
      }
    }
    if (overlap >= (kwTokens.length / 2).ceil()) {
      keywordBonus += 2;
    }
  }

  final basePercent = totalWeight > 0
      ? (matchedWeight / totalWeight) * 100
      : 0.0;
  final score =
      ((basePercent + (keywordBonus > 12 ? 12 : keywordBonus)).round())
          .clamp(0, 100)
          .toInt();

  final allRoleSkills = [...requiredSkills, ...niceToHaveSkills];
  final missing = allRoleSkills.where((skill) => !hasSkill(skill)).toList();

  return (roleId: roleId, score: score, matched: matched, missing: missing);
}

/// Mirrors buildRoleRecommendations: score every role, keep ≥20 (v8.9.3 R2 —
/// was 30), sort desc, cap at 2.
List<({String roleId, int score, List<String> matched, List<String> missing})>
rankRoles({
  required List<
    ({
      String roleId,
      String title,
      List<String> requiredSkills,
      List<String> niceToHaveSkills,
      List<String> keywords,
    })
  >
  roles,
  required Set<String> skills,
  required Set<String> projectTokens,
  required Set<String> careerSignals,
  required Set<String> careerPhrases,
  required Set<String> certTokens,
  Set<String> evidenceTokens = const {},
}) {
  final results =
      <
        ({String roleId, int score, List<String> matched, List<String> missing})
      >[];
  for (final role in roles) {
    final match = matchRoleMirror(
      roleId: role.roleId,
      title: role.title,
      requiredSkills: role.requiredSkills,
      niceToHaveSkills: role.niceToHaveSkills,
      keywords: role.keywords,
      skills: skills,
      projectTokens: projectTokens,
      careerSignals: careerSignals,
      careerPhrases: careerPhrases,
      certTokens: certTokens,
      evidenceTokens: evidenceTokens,
    );
    if (match.score >= 20) {
      results.add((
        roleId: match.roleId,
        score: match.score,
        matched: match.matched,
        missing: match.missing,
      ));
    }
  }
  results.sort((a, b) => b.score.compareTo(a.score));
  return results.take(2).toList();
}

/// Mirrors the taxonomy entries in career_roles.js for mobile_developer,
/// data_analyst and cloud_engineer.
///
/// v8.9.3 (R1b): mobile_developer now carries the verbatim profile-setup
/// aliases (App Development / Mobile App Development / App Dev).
const mobileDevRole = (
  roleId: 'mobile_developer',
  title: 'Mobile Developer',
  requiredSkills: ['Flutter', 'Dart', 'Android', 'Kotlin', 'Swift', 'iOS'],
  niceToHaveSkills: [
    'Firebase',
    'React Native',
    'REST',
    'SQLite',
    'Git',
    'UI/UX',
  ],
  keywords: [
    'Mobile Developer',
    'Android Developer',
    'iOS Developer',
    'Flutter Developer',
    'App Developer',
    'App Development',
    'Mobile App Development',
    'App Dev',
  ],
);

const dataAnalystRole = (
  roleId: 'data_analyst',
  title: 'Data Analyst',
  requiredSkills: [
    'SQL',
    'Python',
    'Excel',
    'Statistics',
    'Data Visualization',
  ],
  niceToHaveSkills: [
    'Pandas',
    'Power BI',
    'Tableau',
    'R',
    'NumPy',
    'ETL',
    'Machine Learning',
  ],
  keywords: ['Data Analyst', 'Data Analysis', 'Business Analyst', 'Analytics'],
);

const cloudEngineerRole = (
  roleId: 'cloud_engineer',
  title: 'Cloud Engineer',
  requiredSkills: ['AWS', 'Azure', 'GCP', 'Docker', 'Kubernetes', 'Linux'],
  niceToHaveSkills: [
    'Terraform',
    'CI/CD',
    'Jenkins',
    'Networking',
    'Python',
    'Git',
  ],
  keywords: ['Cloud Engineer', 'Cloud Architect', 'AWS Engineer', 'DevOps'],
);

void main() {
  group('matchRole — weighted fit scoring', () {
    test('a mobile-focused student gets a high mobile-developer score', () {
      final match = matchRoleMirror(
        roleId: mobileDevRole.roleId,
        title: mobileDevRole.title,
        requiredSkills: mobileDevRole.requiredSkills,
        niceToHaveSkills: mobileDevRole.niceToHaveSkills,
        keywords: mobileDevRole.keywords,
        skills: {'flutter', 'dart', 'android', 'firebase', 'git'},
        projectTokens: {'flutter', 'firebase'},
        careerSignals: {},
        careerPhrases: {'mobile developer'},
        certTokens: {},
      );

      // Engine math: 44.4% weighted coverage + 2 keyword bonus (exact phrase
      // "mobile developer") = 46 — unchanged by the v8.9.3 keyword aliases
      // (no token-overlap fired: no evidence pool, careerSignals empty).
      expect(match.score, 46);
      expect(match.matched, contains('Flutter'));
      expect(match.missing, isNot(contains('Flutter')));
    });

    test(
      'data-analyst intent without skills scores via keyword bonus only',
      () {
        final match = matchRoleMirror(
          roleId: dataAnalystRole.roleId,
          title: dataAnalystRole.title,
          requiredSkills: dataAnalystRole.requiredSkills,
          niceToHaveSkills: dataAnalystRole.niceToHaveSkills,
          keywords: dataAnalystRole.keywords,
          skills: {'c', 'java'},
          projectTokens: {},
          careerSignals: {'data', 'analyst'},
          careerPhrases: {'data analyst'},
          certTokens: {},
        );

        // base 0 + bonus (Data Analyst phrase 2, Data Analysis {data} 2,
        // Business Analyst {analyst} 2; "Analytics" is single-token/skipped)
        // = 6 — far below the 20 threshold, and the portfolio-first gate
        // would suppress emission entirely.
        expect(match.score, 6);
        expect(match.missing, containsAll(['SQL', 'Python']));
      },
    );

    test('missing skills are reported, not a hard gate', () {
      final match = matchRoleMirror(
        roleId: cloudEngineerRole.roleId,
        title: cloudEngineerRole.title,
        requiredSkills: cloudEngineerRole.requiredSkills,
        niceToHaveSkills: cloudEngineerRole.niceToHaveSkills,
        keywords: cloudEngineerRole.keywords,
        skills: {'aws', 'docker', 'linux'},
        projectTokens: {},
        careerSignals: {},
        careerPhrases: {},
        certTokens: {},
      );

      // Partial profile → low-but-non-zero fit with clear missing skills.
      expect(match.score, greaterThan(0));
      expect(match.missing, contains('Kubernetes'));
    });

    test('score never exceeds 100 even with perfect overlap + bonus', () {
      final match = matchRoleMirror(
        roleId: mobileDevRole.roleId,
        title: mobileDevRole.title,
        requiredSkills: mobileDevRole.requiredSkills,
        niceToHaveSkills: mobileDevRole.niceToHaveSkills,
        keywords: mobileDevRole.keywords,
        skills: {
          'flutter',
          'dart',
          'android',
          'kotlin',
          'swift',
          'ios',
          'firebase',
          'react',
          'native',
          'rest',
          'sqlite',
          'git',
          'ui',
          'ux',
        },
        projectTokens: {'flutter'},
        careerSignals: {'mobile', 'developer'},
        careerPhrases: {'mobile developer'},
        certTokens: {},
      );

      expect(match.score, 100);
    });

    test('empty profile yields a 0 fit with all skills missing', () {
      final match = matchRoleMirror(
        roleId: dataAnalystRole.roleId,
        title: dataAnalystRole.title,
        requiredSkills: dataAnalystRole.requiredSkills,
        niceToHaveSkills: dataAnalystRole.niceToHaveSkills,
        keywords: dataAnalystRole.keywords,
        skills: {},
        projectTokens: {},
        careerSignals: {},
        careerPhrases: {},
        certTokens: {},
      );

      expect(match.score, 0);
      expect(
        match.missing.length,
        dataAnalystRole.requiredSkills.length +
            dataAnalystRole.niceToHaveSkills.length,
      );
    });
  });

  group('rankRoles — role recommendation ranking (top 2, ≥20 fit)', () {
    test('sorts by score descending and returns at most 2', () {
      final ranked = rankRoles(
        roles: [mobileDevRole, dataAnalystRole, cloudEngineerRole],
        skills: {
          'flutter',
          'dart',
          'android',
          'firebase',
          'git',
          'sql',
          'python',
        },
        projectTokens: {'flutter'},
        careerSignals: {'data', 'analyst', 'mobile'},
        careerPhrases: {'mobile developer', 'data analyst'},
        certTokens: {},
      );

      // mobile 46, data 30, cloud 11 (<20 → filtered).
      expect(ranked.length, lessThanOrEqualTo(2));
      expect(ranked.first.roleId, 'mobile_developer');
      expect(ranked.first.score, greaterThanOrEqualTo(ranked.last.score));
    });

    test('a weak/empty profile receives no role recommendations', () {
      final ranked = rankRoles(
        roles: [mobileDevRole, dataAnalystRole, cloudEngineerRole],
        skills: {},
        projectTokens: {},
        careerSignals: {},
        careerPhrases: {},
        certTokens: {},
      );

      expect(ranked, isEmpty);
    });
  });

  group(
    'v8.9.3 regression — project_info__27 "recommendations show nothing"',
    () {
      test(
        'regressed profile: nested careerInterest "App Development" + Flutter '
        'project + cert + experience surfaces mobile_developer ≥ 20',
        () {
          // Mirrors the ENGINE's extractUserSignals → buildRoleRecommendations
          // for the exact Firestore doc in project_info__27:
          //   - career.careerInterest = "App Development" (R1a: now read)
          //   - skills = ["Flutter"]
          //   - project "Task Management App" (tech: Flutter) → projectTokens
          //   - cert "Mobile App Development Fundamentals" → certTokens
          //   - experience "Mobile App Developer Intern" description naming
          //     Flutter/Dart/REST APIs/Firebase/Git → experience tokens
          //   - evidenceTokens = experience ∪ cert ∪ project (engine R1c)
          const experienceTokens = {
            'worked', 'development', 'testing', 'cross', 'platform',
            'mobile', 'applications', 'using', 'flutter', 'dart',
            'implemented', 'user', 'interfaces', 'integrated', 'rest',
            'apis', 'connected', 'firebase', 'services', 'fixed', 'bugs',
            'git', 'github', 'developer', 'intern', 'apptech', 'solutions',
          };
          const certTokens = {
            'mobile', 'app', 'development', 'fundamentals', 'techskills',
            'academy',
          };
          const projectTokens = {'task', 'management', 'app', 'flutter'};
          final evidenceTokens = <String>{
            ...experienceTokens,
            ...certTokens,
            ...projectTokens,
          };

          final match = matchRoleMirror(
            roleId: mobileDevRole.roleId,
            title: mobileDevRole.title,
            requiredSkills: mobileDevRole.requiredSkills,
            niceToHaveSkills: mobileDevRole.niceToHaveSkills,
            keywords: mobileDevRole.keywords,
            // u.skills = normalizeTokens(userData.skills) ∪ projectTokens
            skills: {'flutter', 'task', 'management', 'app'},
            projectTokens: projectTokens,
            // R1a: nested career.careerInterest feeds careerPhrases/signals.
            careerSignals: {'app', 'development'},
            careerPhrases: {'app development'},
            certTokens: certTokens,
            evidenceTokens: evidenceTokens,
          );

          // Weighted coverage: Flutter(3) + Dart(3 via evidence) + Firebase(1.5)
          // + REST(1.5) + Git(1.5) = 10.5 / 27 ⇒ 38.9% → 39. Keyword bonus:
          // "App Development" phrase (+2) + token overlaps ("App Developer",
          // "Mobile App Development", "App Dev", "Mobile Developer" via
          // evidence, "Flutter Developer", "Android/iOS Developer" via
          // "developer") capped at +12 ⇒ 39 + 12 = 51.
          expect(match.score, 51);
          expect(match.matched, containsAll(['Flutter', 'Dart']));
          expect(match.matched, containsAll(['Firebase', 'REST', 'Git']));
          expect(match.missing, contains('Android'));
          expect(match.score, greaterThanOrEqualTo(20));
        },
      );

      test(
        'thin-but-real portfolio (Flutter + project + App Development intent) '
        'scores between 20 and 30 — surfaces only because R2 lowered the '
        'threshold',
        () {
          final match = matchRoleMirror(
            roleId: mobileDevRole.roleId,
            title: mobileDevRole.title,
            requiredSkills: mobileDevRole.requiredSkills,
            niceToHaveSkills: mobileDevRole.niceToHaveSkills,
            keywords: mobileDevRole.keywords,
            skills: {'flutter', 'task', 'management', 'app'},
            projectTokens: {'task', 'management', 'app', 'flutter'},
            careerSignals: {'app', 'development'},
            careerPhrases: {'app development'},
            certTokens: {},
            evidenceTokens: {'task', 'management', 'app', 'flutter'},
          );

          // Flutter(3)/27 = 11.1% → 11. Keyword bonus: "App Development"
          // phrase, "App Developer" {app}, "Mobile App Development"
          // {app, development}, "App Dev" {app}, "Flutter Developer"
          // {flutter via evidence} = 10 ⇒ 21. 21 ≥ 20 (would have been
          // filtered at the old 30).
          expect(match.score, 21);
          expect(match.score, greaterThanOrEqualTo(20));
          expect(match.score, lessThan(30));
        },
      );

      test(
        'multi-word intent matches via token overlap (R1b) — no evidence '
        'required',
        () {
          final match = matchRoleMirror(
            roleId: mobileDevRole.roleId,
            title: mobileDevRole.title,
            requiredSkills: mobileDevRole.requiredSkills,
            niceToHaveSkills: mobileDevRole.niceToHaveSkills,
            keywords: mobileDevRole.keywords,
            skills: {},
            projectTokens: {},
            careerSignals: {'app', 'development'},
            careerPhrases: {'app development'},
            certTokens: {},
          );

          // base 0. Bonus: "App Development" phrase (+2), "App Developer"
          // {app} (+2), "Mobile App Development" {app, development} (+2),
          // "App Dev" {app} (+2) = 8. ("Analytics"-style single-token
          // keywords are skipped; Android/iOS/Flutter/Mobile Developer have
          // no overlapping tokens.)
          expect(match.score, 8);
          // Same intent expressed with a different-but-equivalent phrase.
          expect(match.missing, containsAll(['Flutter', 'Dart']));
        },
      );

      test(
        'evidence tokens count as skills only when ALL tokens appear (R1c)',
        () {
          final mobile = matchRoleMirror(
            roleId: mobileDevRole.roleId,
            title: mobileDevRole.title,
            requiredSkills: mobileDevRole.requiredSkills,
            niceToHaveSkills: mobileDevRole.niceToHaveSkills,
            keywords: mobileDevRole.keywords,
            skills: {},
            projectTokens: {},
            careerSignals: {},
            careerPhrases: {},
            certTokens: {},
            evidenceTokens: {
              'flutter', 'dart', 'firebase', 'rest', 'git',
            },
          );

          // Experience text naming Flutter/Dart/Firebase/REST/Git proves those
          // skills: Flutter(3) + Dart(3) + Firebase(1.5) + REST(1.5) + Git(1.5)
          // = 10.5 / 27 ⇒ 38.9% base, plus the keyword "Flutter Developer"
          // fires via the evidence token {flutter} (+2) ⇒ 41.
          expect(mobile.score, 41);
          expect(mobile.matched, containsAll(['Flutter', 'Dart']));
          expect(mobile.matched, containsAll(['Firebase', 'REST', 'Git']));

          final analyst = matchRoleMirror(
            roleId: dataAnalystRole.roleId,
            title: dataAnalystRole.title,
            requiredSkills: dataAnalystRole.requiredSkills,
            niceToHaveSkills: dataAnalystRole.niceToHaveSkills,
            keywords: dataAnalystRole.keywords,
            skills: {},
            projectTokens: {},
            careerSignals: {},
            careerPhrases: {},
            certTokens: {},
          // A description casually containing the word "data" must NOT
          // satisfy the multi-token skill "Data Visualization".
          evidenceTokens: {'data'},
        );

          // The ALL-token skill rule keeps "Data Visualization" missing, but
          // the evidence token "data" DOES nudge the keyword bonus (Data
          // Analyst {data, analyst} + "Data Analysis" {data, analysis} =
          // +4). Small intent signal — still far below the 20 threshold and
          // never a role card on its own.
          expect(analyst.score, 4);
          expect(analyst.missing, contains('Data Visualization'));
        },
      );
    },
  );
}

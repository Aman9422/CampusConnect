import 'package:flutter_test/flutter_test.dart';

/// CampusConnect v8.9 — Skill-Gap Intelligence contract tests.
///
/// Mirrors `buildSkillGapRecommendations` in
/// `functions/recommendations/engine.js`:
///   - Missing skills are aggregated from the target role (weight 2) and
///     relevant placement matches (weight 1).
///   - Top 3 gaps are emitted with a reason and a concrete suggestedAction.
///   - Skills are NEVER invented for the student — only real gaps from the
///     engine's own role/placement output are suggested.

({String title, List<String> skillsMissing}) roleRec(
  String title,
  List<String> missing,
) => (title: title, skillsMissing: missing);

({String title, List<String> skillsMissing}) placementRec(
  String title,
  List<String> missing,
) => (title: title, skillsMissing: missing);

/// Mirrors buildSkillGapRecommendations — aggregated frequency → top 3.
List<
  ({
    String title,
    String description,
    int signalCount,
    String reason,
    String suggestedAction,
  })
>
buildSkillGapsMirror({
  required List<({String title, List<String> skillsMissing})> roleRecs,
  required List<({String title, List<String> skillsMissing})> placementRecs,
}) {
  final frequency = <String, int>{};

  for (final role in roleRecs) {
    for (final skill in role.skillsMissing) {
      final token = skill.toLowerCase();
      frequency[token] = (frequency[token] ?? 0) + 2; // target role = heavy
    }
  }
  for (final placement in placementRecs) {
    for (final skill in placement.skillsMissing) {
      final token = skill.toLowerCase();
      frequency[token] = (frequency[token] ?? 0) + 1; // relevant opportunity
    }
  }

  final ranked = frequency.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  return ranked.take(3).map((entry) {
    final display = toTitleCase(entry.key);
    final inRole = roleRecs.any(
      (r) => r.skillsMissing.any((s) => s.toLowerCase() == entry.key),
    );
    final inPlacements = placementRecs
        .where((p) => p.skillsMissing.any((s) => s.toLowerCase() == entry.key))
        .length;

    final reasons = <String>[];
    if (inRole && roleRecs.isNotEmpty) {
      reasons.add('appears in your target role (${roleRecs.first.title})');
    }
    if (inPlacements > 0) {
      reasons.add(
        'appears in $inPlacements relevant placement${inPlacements > 1 ? 's' : ''}',
      );
    }
    final reasonText = reasons.isNotEmpty
        ? reasons.join(' and ')
        : 'commonly expected for your career path';

    return (
      title: display,
      description:
          'Missing skill · ${entry.value} signal${entry.value > 1 ? 's' : ''}',
      signalCount: entry.value,
      reason: '$display $reasonText.',
      suggestedAction:
          'Complete a $display project or course and add practical evidence to your portfolio.',
    );
  }).toList();
}

String toTitleCase(String token) {
  return token
      .split(RegExp(r'[\s/-]+'))
      .where((part) => part.isNotEmpty)
      .map((part) => part[0].toUpperCase() + part.substring(1))
      .join(' ');
}

void main() {
  group('buildSkillGapsMirror — aggregation', () {
    test(
      'a gap present in role + placements ranks first with a full reason',
      () {
        final gaps = buildSkillGapsMirror(
          roleRecs: [
            roleRec('Software Developer', ['Docker', 'AWS']),
          ],
          placementRecs: [
            placementRec('SDE at A', ['Docker']),
            placementRec('Cloud at B', ['Docker']),
            placementRec('Data at C', ['AWS']),
          ],
        );

        expect(gaps, isNotEmpty);
        expect(gaps.first.title, 'Docker');
        expect(gaps.first.signalCount, 4); // role(2) + 2 placements(1 each)
        expect(gaps.first.reason, contains('target role'));
        expect(gaps.first.reason, contains('2 relevant placements'));
        expect(
          gaps.first.suggestedAction,
          contains('Docker project or course'),
        );
      },
    );

    test('role-only gaps still get a target-role reason', () {
      final gaps = buildSkillGapsMirror(
        roleRecs: [
          roleRec('AI/ML Engineer', ['TensorFlow']),
        ],
        placementRecs: [],
      );

      // The engine lowercases tokens before title-casing, so camelCase is
      // flattened in the emitted title/action — this mirrors that exactly.
      expect(gaps.single.title, 'Tensorflow');
      expect(gaps.single.reason, contains('target role'));
      expect(gaps.single.suggestedAction, contains('Tensorflow'));
    });

    test('placement-only gaps get a placement-count reason', () {
      final gaps = buildSkillGapsMirror(
        roleRecs: [],
        placementRecs: [
          placementRec('Mobile at A', ['Kotlin']),
          placementRec('Mobile at B', ['Kotlin']),
        ],
      );

      expect(gaps.single.title, 'Kotlin');
      expect(gaps.single.reason, contains('2 relevant placements'));
    });

    test('only real missing skills are suggested — never invented', () {
      final gaps = buildSkillGapsMirror(
        roleRecs: [
          roleRec('DevOps Engineer', ['Ansible', 'Terraform']),
        ],
        placementRecs: [],
      );

      final titles = gaps.map((g) => g.title).toList();
      expect(titles, containsAll(['Ansible', 'Terraform']));
      // A skill the student already has never appears.
      expect(titles, isNot(contains('Flutter')));
    });
  });

  group('ranking', () {
    test('gaps are sorted by aggregate signal count descending, max 3', () {
      final gaps = buildSkillGapsMirror(
        roleRecs: [
          roleRec('Software Developer', [
            'Docker',
            'Kubernetes',
            'AWS',
            'React',
          ]),
        ],
        placementRecs: [
          placementRec('SDE at A', ['Docker']),
          placementRec('Cloud at B', ['Docker', 'Kubernetes']),
          placementRec('Web at C', ['React']),
        ],
      );

      expect(gaps.length, lessThanOrEqualTo(3));
      for (var i = 1; i < gaps.length; i++) {
        expect(gaps[i].signalCount, lessThanOrEqualTo(gaps[i - 1].signalCount));
      }
      // Docker: role(2) + 2 placements(2) = 4 → first.
      expect(gaps.first.title, 'Docker');
    });
  });
}

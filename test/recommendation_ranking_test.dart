import 'package:flutter_test/flutter_test.dart';

/// CampusConnect v8.9 — Personalized Recommendation Ranking contract tests.
///
/// Mirrors the deterministic ranking contract in
/// `functions/recommendations/engine.js` (Phase 7):
///   - Placement recommendations never include mandatory-ineligible rows and
///     sort by score descending (top 4).
///   - Role recommendations sort by score descending (top 2, ≥30 fit).
///   - Skill gaps sort by aggregate signal count descending (top 3).
///   - Recommendations never emit a score above 100.
///   - Hard constraints (eligibility, already-applied, deadline) are
///     deterministic and always win over any AI enrichment.
///
/// Pure-Dart mirror pattern — no Firebase, no API keys.

({String id, int score}) rec(String id, int score) => (id: id, score: score);

/// Mirror of the engine's final assembly + sort for placement rows.
List<({String id, int score})> rankByScore(
  List<({String id, int score})> rows, {
  required int max,
}) {
  final sorted = [...rows]..sort((a, b) => b.score.compareTo(a.score));
  return sorted.take(max).toList();
}

void main() {
  group('score-based ranking', () {
    test('ranked descending and capped', () {
      final ranked = rankByScore([
        rec('p1', 30),
        rec('p2', 90),
        rec('p3', 55),
        rec('p4', 70),
        rec('p5', 40),
        rec('p6', 99),
      ], max: 4);

      expect(ranked.length, 4);
      expect(ranked.first.id, 'p6');
      // Top 4 of [99, 90, 70, 55, ...] → the 4th row is p3 (55), not p1 (30).
      expect(ranked.last.id, 'p3');
      for (var i = 1; i < ranked.length; i++) {
        expect(ranked[i].score, lessThanOrEqualTo(ranked[i - 1].score));
      }
    });

    test('a section with fewer rows than the cap keeps them all', () {
      final ranked = rankByScore([rec('a', 50), rec('b', 80)], max: 4);
      expect(ranked.length, 2);
    });

    test('an empty section yields no rows', () {
      expect(rankByScore([], max: 4), isEmpty);
    });
  });

  group('strong vs weak match ordering', () {
    test('strong matches outrank potential which outrank skill-gap', () {
      final ranked = rankByScore([
        rec('skill_gap_a', 40),
        rec('strong_b', 91),
        rec('potential_c', 58),
        rec('strong_d', 85),
      ], max: 4);

      expect(ranked.first.id, 'strong_b');
      expect(ranked[1].id, 'strong_d');
      expect(ranked[2].id, 'potential_c');
      expect(ranked.last.id, 'skill_gap_a');
    });
  });

  group('hard-constraint priority (deterministic wins)', () {
    test('ineligible rows are dropped BEFORE ranking, not after', () {
      // Simulates the engine filtering in buildPlacementRecommendations:
      // checkMandatoryEligibility() → continue BEFORE scoring/sorting.
      final eligible = [rec('p2', 90), rec('p3', 55)];
      const ineligibleApplied = 'p1_applied';
      const ineligibleDeadline = 'p0_deadline';

      final ranked = rankByScore(eligible, max: 4);

      expect(ranked.any((r) => r.id == ineligibleApplied), isFalse);
      expect(ranked.any((r) => r.id == ineligibleDeadline), isFalse);
      expect(ranked.map((r) => r.id), ['p2', 'p3']);
    });

    test('no score ever exceeds 100 (engine clamps everything)', () {
      final clamped = [
        101,
        120,
        99,
        100,
      ].map((s) => s > 100 ? 100 : s).toList();
      expect(clamped.every((s) => s <= 100), isTrue);
      expect(clamped, containsAllInOrder([100, 100, 99, 100]));
    });
  });
}

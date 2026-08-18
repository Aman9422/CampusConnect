import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

/// CampusConnect v8.9 — AI Recommendation Output Sanitizer contract tests.
///
/// Mirrors `validateExplanations` + the deterministic-fallback behavior of
/// `enrichRecommendationExplanations` in
/// `functions/recommendations/ai_explanations.js`:
///   - Structured JSON parsing ("explanations" keyed by recommendation id).
///   - Recovery from markdown/extra text around the JSON object.
///   - Malformed AI responses → empty safe map (deterministic reason wins).
///   - Output restricted to ids we asked about; 200-char cap; non-string and
///     empty values dropped.
///   - AI failure NEVER throws and NEVER overrides deterministic eligibility
///     (Phase 7 hard-constraint contract).
///
/// No real API keys are used anywhere in these tests.

/// Mirrors validateExplanations(rawContent, allowedIds).
Map<String, String> validateExplanationsMirror(
  String? rawContent,
  Set<String> allowedIds,
) {
  final safe = <String, String>{};
  if (rawContent == null || rawContent.isEmpty) return safe;

  Map<String, dynamic>? parsed;
  try {
    parsed = jsonDecode(rawContent) as Map<String, dynamic>;
  } catch (_) {
    // Recover a JSON object from markdown/extra text.
    final firstBrace = rawContent.indexOf('{');
    final lastBrace = rawContent.lastIndexOf('}');
    if (firstBrace != -1 && lastBrace > firstBrace) {
      final extracted = rawContent.substring(firstBrace, lastBrace + 1);
      try {
        parsed = jsonDecode(extracted) as Map<String, dynamic>;
      } catch (_) {
        return safe;
      }
    } else {
      return safe;
    }
  }

  final explanations = parsed['explanations'];
  if (explanations is! Map<String, dynamic>) return safe;

  for (final entry in explanations.entries) {
    if (!allowedIds.contains(entry.key)) {
      continue; // never echo ids we didn't ask about
    }
    final value = entry.value;
    if (value is! String) continue;
    final text = value.trim();
    if (text.isEmpty) continue;
    safe[entry.key] = text.length > 200 ? text.substring(0, 200) : text;
  }
  return safe;
}

/// Mirrors enrichRecommendationExplanations' best-effort contract: when AI
/// produces no valid text for a recommendation, the deterministic [reason]
/// stays authoritative.
List<({String id, String reason, String? aiExplanation})>
enrichWithFallbackMirror({
  required List<({String id, String reason})> recommendations,
  required Map<String, String> aiExplanations,
}) {
  return recommendations.map((rec) {
    final ai = aiExplanations[rec.id];
    return (
      id: rec.id,
      reason: rec.reason,
      aiExplanation: (ai == null || ai.isEmpty) ? null : ai,
    );
  }).toList();
}

void main() {
  group('validateExplanationsMirror — structured output parsing', () {
    test('parses a valid explanations object', () {
      const raw =
          '{"explanations": {"role_1": "Your Flutter projects align with this role."}}';
      final safe = validateExplanationsMirror(raw, {'role_1', 'role_2'});

      expect(safe['role_1'], contains('Flutter projects'));
    });

    test('recovers a JSON object wrapped in markdown code fences', () {
      const raw =
          '```json\n{"explanations": {"skill_1": "Docker appears in your target role."}}\n```';
      final safe = validateExplanationsMirror(raw, {'skill_1'});

      expect(safe['skill_1'], contains('Docker'));
    });

    test('ignores explanations for ids we never asked about', () {
      const raw =
          '{"explanations": {"role_1": "Good fit", "role_weird": "Injected"}}';
      final safe = validateExplanationsMirror(raw, {'role_1'});

      expect(safe.keys, ['role_1']);
    });

    test('caps explanation length at 200 characters', () {
      final longText = 'x' * 500;
      final safe = validateExplanationsMirror(
        '{"explanations": {"role_1": "$longText"}}',
        {'role_1'},
      );

      expect(safe['role_1']!.length, 200);
    });
  });

  group('malformed AI responses — deterministic fallback wins', () {
    test('non-JSON text returns an empty safe map', () {
      expect(
        validateExplanationsMirror('I am sorry, I cannot do that.', {'role_1'}),
        isEmpty,
      );
    });

    test('JSON without an explanations key returns empty', () {
      expect(validateExplanationsMirror('{"foo": "bar"}', {'role_1'}), isEmpty);
    });

    test('null/empty input returns empty', () {
      expect(validateExplanationsMirror(null, {'role_1'}), isEmpty);
      expect(validateExplanationsMirror('', {'role_1'}), isEmpty);
    });

    test('non-string explanation values are dropped', () {
      const raw = '{"explanations": {"role_1": {"not": "a string"}}}';
      expect(validateExplanationsMirror(raw, {'role_1'}), isEmpty);
    });

    test('whitespace-only explanations are dropped', () {
      const raw = '{"explanations": {"role_1": "   "}}';
      expect(validateExplanationsMirror(raw, {'role_1'}), isEmpty);
    });
  });

  group('deterministic fallback — AI can never override hard constraints', () {
    test('AI failure keeps the deterministic reason authoritative', () {
      final recs = enrichWithFallbackMirror(
        recommendations: [
          (
            id: 'role_1',
            reason: 'Strong match — your skills align with the role.',
          ),
          (
            id: 'placement_1',
            reason: 'Eligible, but this role highlights missing skills.',
          ),
        ],
        aiExplanations: {}, // AI failed / timed out / returned malformed JSON
      );

      expect(recs.first.aiExplanation, isNull);
      expect(recs.first.reason, contains('Strong match'));
      // The second deterministic reason is untouched too.
      expect(recs.last.reason, contains('missing skills'));
    });

    test('valid AI text enriches only, never replaces the reason field', () {
      final recs = enrichWithFallbackMirror(
        recommendations: [(id: 'role_1', reason: 'Deterministic reason.')],
        aiExplanations: {'role_1': 'AI explains why this fits your profile.'},
      );

      expect(recs.single.aiExplanation, contains('AI explains'));
      expect(recs.single.reason, 'Deterministic reason.');
    });
  });
}

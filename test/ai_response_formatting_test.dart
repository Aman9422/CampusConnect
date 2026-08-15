import 'package:flutter_test/flutter_test.dart';

/// CampusConnect v8.8 — AI response formatting contract tests (Phase 4).
///
/// These tests mirror the SERVER-SIDE `normalizeChatText` function in
/// `functions/ai/aiProvider.js` as a pure Dart implementation so the
/// normalization contract is unit-testable without Firebase, following the
/// existing test pattern.
///
/// Contract (docs/Task.md Phase 4):
///   - `**bold**`, `*italic*`, `__underline__` markers are stripped when they
///     wrap a word phrase.
///   - ATX headings (`### Heading`) become plain lines.
///   - Markdown bullets (`- item`, `* item`) become `• item`.
///   - Fenced code blocks keep their inner content as plain text.
///   - Literal `\n` escape sequences become real newlines.
///   - LEGITIMATE `*` characters (e.g. "C++", "a*b", "5 * 4") are preserved.
///   - Numbered lists keep their numbering normalized to "1. " spacing.
class ChatTextNormalizer {
  const ChatTextNormalizer._();

  static String normalize(String text) {
    if (text.isEmpty) return '';

    var output = text
        // Literal escape sequences.
        .replaceAll(r'\n', '\n')
        .replaceAll(r'\t', '    ')
        // Fenced code blocks — keep inner content as plain text.
        .replaceAllMapped(
          RegExp(r'```(?:[a-zA-Z0-9_+-]*)\s*\n?([\s\S]*?)\n?\s*```'),
          (m) => m.group(1) ?? '',
        )
        // Inline code backticks.
        .replaceAllMapped(RegExp(r'`([^`\n]+)`'), (m) => m.group(1) ?? '');

    // Emphasis: **bold** / __bold__ → content.
    output = output.replaceAllMapped(
      RegExp(r'(\*\*|__)(?=\S)(.+?)(?<=\S)\1'),
      (m) => m.group(2) ?? '',
    );
    // Single * or _ emphasis — only when wrapping a letter word, and only
    // when NOT part of a longer token (protects "C++", "a*b", "5 * 4").
    output = output.replaceAllMapped(
      RegExp(
        r'(?<![A-Za-z0-9*_])(\*|_)(?=\S)([A-Za-z][^*\n]*?)(?<=\S)\1(?![A-Za-z0-9*_])',
      ),
      (m) => m.group(2) ?? '',
    );

    // ATX headings: "### Heading" → "Heading".
    output = output.replaceAllMapped(
      RegExp(r'^\s{0,3}(#{1,6})\s+(.+)$', multiLine: true),
      (m) => m.group(2) ?? '',
    );

    // Bullets: "- item", "* item", "+ item" → "• item".
    output = output.replaceAllMapped(
      RegExp(r'^\s{0,3}[-*+]\s+', multiLine: true),
      (_) => '• ',
    );

    // Numbered lists: normalize to "1. " spacing.
    output = output.replaceAllMapped(
      RegExp(r'^\s{0,3}(\d+)[.)]\s+', multiLine: true),
      (m) => '${m.group(1)}. ',
    );

    // Line cleanup: trim trailing whitespace, collapse 3+ blank lines.
    final lines = output
        .split('\n')
        .map((line) => line.replaceAll(RegExp(r'\s+$'), ''))
        .join('\n');
    return lines.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
  }
}

void main() {
  group('Markdown emphasis cleanup', () {
    test('**bold** becomes plain bold text', () {
      expect(
        ChatTextNormalizer.normalize('This is **very important** advice.'),
        'This is very important advice.',
      );
    });

    test('*italic* becomes plain text', () {
      expect(
        ChatTextNormalizer.normalize('Try *focusing* on projects.'),
        'Try focusing on projects.',
      );
    });

    test('__underline__ becomes plain text', () {
      expect(
        ChatTextNormalizer.normalize('Use __metrics__ in bullets.'),
        'Use metrics in bullets.',
      );
    });
  });

  group('Legitimate characters are preserved', () {
    test('C++ is NOT destroyed', () {
      expect(
        ChatTextNormalizer.normalize('Learn C++ for systems programming.'),
        'Learn C++ for systems programming.',
      );
    });

    test('multiplication expression is preserved', () {
      expect(
        ChatTextNormalizer.normalize('Compute 5 * 4 manually.'),
        'Compute 5 * 4 manually.',
      );
    });

    test('inline a*b token is preserved', () {
      // `a*b` in the middle of a word has non-space on both sides → kept.
      expect(
        ChatTextNormalizer.normalize('The a*b comparison is invalid.'),
        'The a*b comparison is invalid.',
      );
    });
  });

  group('Headings and lists', () {
    test('### Heading becomes a plain line', () {
      expect(
        ChatTextNormalizer.normalize('### Interview Tips\nBe yourself.'),
        'Interview Tips\nBe yourself.',
      );
    });

    test('## and # headings are cleaned too', () {
      expect(
        ChatTextNormalizer.normalize('## Summary\nShort.'),
        'Summary\nShort.',
      );
      expect(
        ChatTextNormalizer.normalize('# Resume Advice\nShort.'),
        'Resume Advice\nShort.',
      );
    });

    test('dash bullets become bullet points', () {
      expect(
        ChatTextNormalizer.normalize('- First\n- Second'),
        '• First\n• Second',
      );
    });

    test('asterisk bullets become bullet points (not stripped)', () {
      expect(
        ChatTextNormalizer.normalize('* Item one\n* Item two'),
        '• Item one\n• Item two',
      );
    });

    test('numbered lists keep numbering with . spacing', () {
      expect(
        ChatTextNormalizer.normalize('1) Do this\n2) Do that'),
        '1. Do this\n2. Do that',
      );
    });
  });

  group('Code and escapes', () {
    test('fenced code blocks keep inner content as plain text', () {
      expect(
        ChatTextNormalizer.normalize(
          'Run this:\n```dart\nprint("hi");\n```\nDone.',
        ),
        'Run this:\nprint("hi");\nDone.',
      );
    });

    test('inline code backticks are stripped, content kept', () {
      expect(
        ChatTextNormalizer.normalize('Use `flutter analyze` first.'),
        'Use flutter analyze first.',
      );
    });

    test('literal \\n sequences become real newlines', () {
      expect(
        ChatTextNormalizer.normalize('Line one\\nLine two'),
        'Line one\nLine two',
      );
    });

    test('excess blank lines collapse', () {
      expect(ChatTextNormalizer.normalize('A\n\n\n\n\nB'), 'A\n\nB');
    });

    test('raw JSON is NOT mangled when intentionally present', () {
      final rawJson = 'Result: {"score": 85, "verdict": "strong"}';
      expect(
        ChatTextNormalizer.normalize(rawJson).contains('"score": 85'),
        isTrue,
      );
    });
  });
}

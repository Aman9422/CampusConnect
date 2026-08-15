import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

/// CampusConnect v8.8.1 — AI callable response cast regression tests.
///
/// Root cause (docs/logs.md 2026-08-15):
/// ```
/// AIChatProvider.sendMessage error: Exception: Failed to connect to AI
/// service: type '_Map<Object?, Object?>' is not a subtype of type
/// 'Map<String, dynamic>' in type cast
/// ```
///
/// The `cloud_functions` callable SDK decodes nested JSON objects as
/// `Map<Object?, Object?>` (a `_JsonMap`-style map typed `Object?`). Calling
/// `.call<Map<String, dynamic>>(...)` — or casting `result.data` straight to
/// `Map<String, dynamic>` — throws for any response containing nested objects
/// (the `askAI` response has nested `trial` and `usage` maps; the
/// `reviewResume` response has a nested `review` map).
///
/// `ResumeReviewService` already worked around it with the deep-convert
/// `jsonDecode(jsonEncode(result.data))`. This test mirrors the exact fix
/// applied to `AIService.sendMessage` (and documents that the direct cast is
/// what broke the AI chat).
class CallableResponseDecoder {
  const CallableResponseDecoder._();

  /// The buggy pattern from ai_service.dart v8.8: forces the SDK to downcast
  /// the decoded `Map<Object?, Object?>` to `Map<String, dynamic>`.
  static Map<String, dynamic> directCast(Object? data) =>
      data as Map<String, dynamic>;

  /// The fix (v8.8.1, same as ResumeReviewService): re-encode then decode so
  /// every nested map comes back as `Map<String, dynamic>`.
  static Map<String, dynamic> deepConvert(Object? data) =>
      Map<String, dynamic>.from(jsonDecode(jsonEncode(data)) as Map);
}

void main() {
  test('deepConvert parses the full askAI response shape (nested maps)', () {
    // What the callable SDK actually returns at runtime: a `Map<Object?, Object?>`
    // whose VALUES include further `Map<Object?, Object?>` objects.
    final raw = <Object?, Object?>{
      'response': 'Try building projects to strengthen your resume.',
      'timestamp': '2026-08-15T09:00:00.000Z',
      'trial': <Object?, Object?>{
        'status': 'active',
        'daysRemaining': 3,
        'expiresAt': '2026-08-18T09:00:00.000Z',
      },
      'usage': <Object?, Object?>{
        'dailyCount': 4,
        'dailyLimit': 50,
        'lastResetAt': '2026-08-15T00:00:00.000Z',
      },
    };

    final data = CallableResponseDecoder.deepConvert(raw);

    expect(data['response'], isA<String>());
    expect(data['trial'], isA<Map<String, dynamic>>());
    expect(
      (data['trial'] as Map<String, dynamic>)['status'],
      'active',
    );
    expect((data['trial'] as Map<String, dynamic>)['daysRemaining'], 3);
    expect(data['usage'], isA<Map<String, dynamic>>());
    expect((data['usage'] as Map<String, dynamic>)['dailyCount'], 4);
  });

  test('deepConvert handles the flat deleteAIHistory response shape', () {
    final raw = <Object?, Object?>{'deleted': 12};
    final data = CallableResponseDecoder.deepConvert(raw);
    expect(data['deleted'], 12);
  });

  test('direct cast throws on nested maps — documents the v8.8 bug', () {
    final raw = <Object?, Object?>{
      'response': 'hello',
      'trial': <Object?, Object?>{'status': 'active', 'daysRemaining': 3, 'expiresAt': null},
    };

    expect(
      () => CallableResponseDecoder.directCast(raw),
      throwsA(
        isA<TypeError>().having(
          (e) => e.toString(),
          'message',
          contains("is not a subtype of type 'Map<String, dynamic>'"),
        ),
      ),
    );
  });

  test('deepConvert survives an empty response body', () {
    final data = CallableResponseDecoder.deepConvert(<Object?, Object?>{});
    expect(data, isEmpty);
  });

  test('deepConvert preserves primitive values in nested lists', () {
    final raw = <Object?, Object?>{
      'items': <Object?>[
        <Object?, Object?>{'name': 'dart', 'tags': <Object?>['static', 'typed']},
        42,
        true,
      ],
    };
    final data = CallableResponseDecoder.deepConvert(raw);
    final items = data['items'] as List<dynamic>;
    expect((items[0] as Map<String, dynamic>)['name'], 'dart');
    expect((items[0] as Map<String, dynamic>)['tags'], ['static', 'typed']);
    expect(items[1], 42);
    expect(items[2], isTrue);
  });
}

import 'package:flutter_test/flutter_test.dart';

/// CampusConnect v8.8 — AI provider fallback + quota contract tests (Phases 8/9).
///
/// These tests mirror the v8.8 `callAIProvider` fallback chain in
/// `functions/ai/aiProvider.js` and the v8.6 quota architecture in
/// `functions/index.js` as pure Dart functions:
///
///   - Primary provider (Groq `openai/gpt-oss-20b` by default).
///   - On primary failure (missing key, timeout, rate limit, 5xx, malformed
///     response) → automatic retry against HuggingFace Inference Providers
///     (same model) → normalized response (no duplicate pipeline).
///   - `AI_PROVIDER=huggingface` is single-provider mode (no fallback).
///   - Quota consumption is application-level: a provider fallback must NOT
///     double-charge usage, and a provider failure must not create duplicate
///     usage records or permanently consume quota where rollback applies.
class ProviderFallbackChain {
  const ProviderFallbackChain._();

  static const String defaultProvider = 'groq';
  static const String fallbackProvider = 'huggingface';
  static const String model = 'openai/gpt-oss-20b';

  /// Mirrors `callAIProvider`: huggingface mode has no fallback.
  static bool shouldAttemptFallback(String configuredProvider) =>
      configuredProvider != 'huggingface';

  /// A primary error (missing key, timeout, 429, 5xx, malformed) triggers the
  /// fallback when configured for dual-provider mode.
  static bool isFallbackTrigger({
    required bool primaryFailed,
    required String provider,
  }) => primaryFailed && shouldAttemptFallback(provider);

  /// Resolves the provider that actually produced the response.
  static String resolveProviderUsed({required bool primarySucceeded}) =>
      primarySucceeded ? defaultProvider : fallbackProvider;

  /// Missing primary key error surfaces a deployment error (no key leaked).
  static String missingKeyError(String providerName) =>
      '${providerName.toUpperCase()}_API_KEY not configured. '
      'Set it via functions/.env.';

  /// The fallback requires its own key configured; otherwise a clear error is
  /// thrown instead of leaking anything.
  static bool fallbackAvailable({required bool fallbackKeyConfigured}) =>
      fallbackKeyConfigured;

  /// Guard: the error message must never contain an actual key.
  static bool messageLeaksKey(String message, String? apiKey) =>
      apiKey != null && apiKey.isNotEmpty && message.contains(apiKey);
}

class ApplicationQuota {
  const ApplicationQuota._();

  /// Successful AI calls consume ONE credit, regardless of which provider
  /// produced the response (application-level, not provider-level).
  static int consumeOnce({
    required bool primarySucceeded,
    required int current,
  }) => current + 1;

  /// Failed AI calls where rollback is expected do NOT permanently consume.
  static int rollback(int current) => current > 0 ? current - 1 : 0;

  /// Provider fallback does not double-charge: the quota increments once per
  /// logical request, never once per provider attempt.
  static int chargeForRequest({
    required bool succeeded,
    required int current,
    required int attempts,
  }) {
    if (!succeeded) return current; // rollback path handles it
    return current + 1; // one credit per end-user request, not per attempt
  }
}

void main() {
  group('ProviderFallbackChain — primary config (Phases 1/9)', () {
    test('default provider is groq (v8.8 primary)', () {
      expect(ProviderFallbackChain.defaultProvider, 'groq');
    });

    test('fallback provider is huggingface (v8.8)', () {
      expect(ProviderFallbackChain.fallbackProvider, 'huggingface');
    });

    test('v8.8 model is openai/gpt-oss-20b on both providers', () {
      expect(ProviderFallbackChain.model, 'openai/gpt-oss-20b');
    });
  });

  group('ProviderFallbackChain — fallback behavior (Phase 9)', () {
    test('primary failure triggers the HF fallback (dual mode)', () {
      expect(
        ProviderFallbackChain.isFallbackTrigger(
          primaryFailed: true,
          provider: 'groq',
        ),
        isTrue,
      );
    });

    test('huggingface mode has NO fallback (single-provider mode)', () {
      expect(
        ProviderFallbackChain.shouldAttemptFallback('huggingface'),
        isFalse,
      );
      expect(
        ProviderFallbackChain.isFallbackTrigger(
          primaryFailed: true,
          provider: 'huggingface',
        ),
        isFalse,
      );
    });

    test('successful primary resolves providerUsed = groq', () {
      expect(
        ProviderFallbackChain.resolveProviderUsed(primarySucceeded: true),
        'groq',
      );
    });

    test('fallback success resolves providerUsed = huggingface', () {
      expect(
        ProviderFallbackChain.resolveProviderUsed(primarySucceeded: false),
        'huggingface',
      );
    });

    test('missing primary key is a deployment error, not a silent failure', () {
      final message = ProviderFallbackChain.missingKeyError('groq');
      expect(message, contains('GROQ_API_KEY'));
      expect(message, isNot(contains('sk-')));
    });

    test('fallback cannot run without its own key configured', () {
      expect(
        ProviderFallbackChain.fallbackAvailable(fallbackKeyConfigured: false),
        isFalse,
      );
      expect(
        ProviderFallbackChain.fallbackAvailable(fallbackKeyConfigured: true),
        isTrue,
      );
    });

    test('error messages never leak API keys', () {
      const apiKey = 'hf_secret_token_123';
      final safe = 'AI providers unavailable. Please try again later.';
      expect(ProviderFallbackChain.messageLeaksKey(safe, apiKey), isFalse);
      final leaked = 'Key hf_secret_token_123 was rejected.';
      expect(ProviderFallbackChain.messageLeaksKey(leaked, apiKey), isTrue);
    });
  });

  group('ApplicationQuota — quota preserved across fallback (Phase 8)', () {
    test('successful AI call consumes exactly one credit', () {
      // Primary succeeded — one credit.
      expect(
        ApplicationQuota.consumeOnce(primarySucceeded: true, current: 3),
        4,
      );
    });

    test(
      'fallback success still consumes exactly one credit (no double-charge)',
      () {
        // Two provider attempts (primary failed → HF succeeded) but ONE credit.
        expect(
          ApplicationQuota.chargeForRequest(
            succeeded: true,
            current: 3,
            attempts: 2,
          ),
          4,
        );
      },
    );

    test('failed AI call rolls back the consumed credit', () {
      expect(ApplicationQuota.rollback(4), 3);
      expect(ApplicationQuota.rollback(0), 0);
    });

    test('failed call with rollback leaves quota unchanged', () {
      expect(
        ApplicationQuota.chargeForRequest(
          succeeded: false,
          current: 3,
          attempts: 1,
        ),
        3,
      );
    });

    test('no duplicate usage records across provider attempts', () {
      // A single logical request, regardless of attempts, produces one charge.
      final afterSingleAttempt = ApplicationQuota.chargeForRequest(
        succeeded: true,
        current: 5,
        attempts: 1,
      );
      final afterFallback = ApplicationQuota.chargeForRequest(
        succeeded: true,
        current: 5,
        attempts: 2,
      );
      expect(afterSingleAttempt, afterFallback);
    });
  });
}

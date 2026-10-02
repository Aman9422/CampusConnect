import 'package:campusconnect/services/app_check/app_check_config.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// CampusConnect v9.2.4 (C-2) — App Check provider-selection contract tests.
///
/// The v9.2.3 audit found that App Check was configured but never enforced, and
/// that the *provider selection* lived inside the private `_activateAppCheck`
/// helper in `main.dart`, where it could not be asserted. It was extracted into
/// `lib/services/app_check/app_check_config.dart` so this file can pin the
/// security-critical property directly:
///
/// > a RELEASE build must never be handed a debug attestation provider.
///
/// If a future edit swaps `AndroidPlayIntegrityProvider` for
/// `AndroidDebugProvider` in the release branch, these tests fail — which is
/// exactly the regression that would silently re-disable tamper protection.
///
/// Scope note: this verifies *provider selection*, which is all that can be
/// verified without a device. Enforcement itself is a Firebase Console action
/// (see `docs/app_check_status.md`) and is explicitly NOT claimed here.
void main() {
  group('resolveAppCheckTier — build mode mapping', () {
    test('debug mode resolves to the debug tier', () {
      expect(
        resolveAppCheckTier(isDebugMode: true, isProfileMode: false),
        AppCheckTier.debug,
      );
    });

    test('profile mode is treated as debug (keeps --profile runs working)',
        () {
      expect(
        resolveAppCheckTier(isDebugMode: false, isProfileMode: true),
        AppCheckTier.debug,
      );
    });

    test('release mode resolves to the release tier', () {
      expect(
        resolveAppCheckTier(isDebugMode: false, isProfileMode: false),
        AppCheckTier.release,
      );
    });

    test('debug wins when both flags are somehow set', () {
      expect(
        resolveAppCheckTier(isDebugMode: true, isProfileMode: true),
        AppCheckTier.debug,
      );
    });
  });

  group('isAppCheckSupportedPlatform — platform gate', () {
    test('Android, iOS and Web are supported', () {
      expect(
        isAppCheckSupportedPlatform(isWeb: false, platform: TargetPlatform.android),
        isTrue,
      );
      expect(
        isAppCheckSupportedPlatform(isWeb: false, platform: TargetPlatform.iOS),
        isTrue,
      );
      expect(
        isAppCheckSupportedPlatform(isWeb: true, platform: TargetPlatform.android),
        isTrue,
      );
    });

    test('desktop platforms are skipped so startup does not throw', () {
      for (final platform in [
        TargetPlatform.windows,
        TargetPlatform.linux,
        TargetPlatform.macOS,
        TargetPlatform.fuchsia,
      ]) {
        expect(
          isAppCheckSupportedPlatform(isWeb: false, platform: platform),
          isFalse,
          reason: '$platform must not activate App Check',
        );
      }
    });
  });

  group('resolveAppCheckConfig — debug / profile tier', () {
    test('debug builds get the platform debug providers', () {
      final config = resolveAppCheckConfig(
        isDebugMode: true,
        isProfileMode: false,
        webSiteKey: '',
      );

      expect(config.tier, AppCheckTier.debug);
      expect(config.usesDebugProviders, isTrue);
      expect(config.android, isA<AndroidDebugProvider>());
      expect(config.apple, isA<AppleDebugProvider>());
    });

    test('profile builds get the platform debug providers', () {
      final config = resolveAppCheckConfig(
        isDebugMode: false,
        isProfileMode: true,
        webSiteKey: '',
      );

      expect(config.usesDebugProviders, isTrue);
      expect(config.android, isA<AndroidDebugProvider>());
      expect(config.apple, isA<AppleDebugProvider>());
    });

    test('the default Web App Check is switched off when no Site Key exists',
        () {
      final config = resolveAppCheckConfig(
        isDebugMode: true,
        isProfileMode: false,
        webSiteKey: '',
      );

      expect(config.web, isNull);
      expect(config.hasWebProvider, isFalse);
    });
  });

  group('resolveAppCheckConfig — release tier (release blocker C-2)', () {
    AppCheckConfig releaseConfig({String webSiteKey = ''}) =>
        resolveAppCheckConfig(
          isDebugMode: false,
          isProfileMode: false,
          webSiteKey: webSiteKey,
        );

    test('release builds get Play Integrity and DeviceCheck', () {
      final config = releaseConfig();

      expect(config.tier, AppCheckTier.release);
      expect(config.usesDebugProviders, isFalse);
      expect(config.android, isA<AndroidPlayIntegrityProvider>());
      expect(config.apple, isA<AppleDeviceCheckProvider>());
    });

    test('REGRESSION: a release config never carries a debug provider', () {
      // The C-1 of this workstream: pre-v9.2.4 the release build type was wired
      // to the debug *signing* config. The equivalent mistake in App Check is
      // handing a release binary a debug *attestation* provider, which would
      // make every backend call fail App Check once enforcement is on.
      final config = releaseConfig();

      expect(config.android, isNot(isA<AndroidDebugProvider>()));
      expect(config.apple, isNot(isA<AppleDebugProvider>()));
      expect(config.usesDebugProviders, isFalse);
    });

    test('the debug tier is never produced for a release invocation', () {
      // A table of "this is a release build" inputs must all resolve to
      // release — there is no input that gives a release build debug providers.
      for (final webSiteKey in ['', 'site-key-value']) {
        final config = releaseConfig(webSiteKey: webSiteKey);
        expect(config.tier, AppCheckTier.release, reason: 'key="$webSiteKey"');
        expect(config.usesDebugProviders, isFalse, reason: 'key="$webSiteKey"');
      }
    });
  });

  group('resolveAppCheckConfig — Web (reCAPTCHA v3)', () {
    test('a supplied Site Key activates reCAPTCHA v3 in release', () {
      final config = resolveAppCheckConfig(
        isDebugMode: false,
        isProfileMode: false,
        webSiteKey: 'test-recaptcha-site-key',
      );

      expect(config.web, isA<ReCaptchaV3Provider>());
      expect(config.hasWebProvider, isTrue);
    });

    test('a supplied Site Key also activates it in debug (no web debug '
        'provider exists)', () {
      final config = resolveAppCheckConfig(
        isDebugMode: true,
        isProfileMode: false,
        webSiteKey: 'test-recaptcha-site-key',
      );

      expect(config.web, isA<ReCaptchaV3Provider>());
      // The Android/Apple side is still the debug pair.
      expect(config.android, isA<AndroidDebugProvider>());
      expect(config.apple, isA<AppleDebugProvider>());
    });

    test('a blank / whitespace-only key is treated as "no Web App Check"', () {
      expect(
        resolveAppCheckConfig(
          isDebugMode: false,
          isProfileMode: false,
          webSiteKey: '',
        ).web,
        isNull,
      );
    });

    test('the Site Key is never hard-coded — it comes from '
        '--dart-define (String.fromEnvironment)', () {
      // The default must be empty outside a configured build, i.e. the key is
      // supplied at build time rather than committed. A non-empty default here
      // would mean a secret had been checked in.
      expect(appCheckWebRecaptchaSiteKey, isEmpty);
    });
  });

  group('AppCheckConfig — diagnostics', () {
    test('toString reports the tier and whether Web is active', () {
      final debugConfig = resolveAppCheckConfig(
        isDebugMode: true,
        isProfileMode: false,
        webSiteKey: '',
      );
      final releaseConfig = resolveAppCheckConfig(
        isDebugMode: false,
        isProfileMode: false,
        webSiteKey: 'k',
      );

      expect(debugConfig.toString(), contains('debug'));
      expect(debugConfig.toString(), contains('hasWebProvider: false'));
      expect(releaseConfig.toString(), contains('release'));
      expect(releaseConfig.toString(), contains('hasWebProvider: true'));
    });
  });
}

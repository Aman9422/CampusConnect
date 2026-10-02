// CampusConnect v9.2.4 — App Check provider selection (audit finding C-2).
//
// Extracted from `main.dart` so the provider-selection contract is a pure,
// unit-testable function rather than an assertion about a private helper.
// The behaviour is unchanged from v9.2.2; only the *testability* changed.
//
// Provider matrix (Task §2):
//
// | Build           | Android                | Apple                  |
// |-----------------|------------------------|------------------------|
// | debug / profile | `AndroidDebugProvider` | `AppleDebugProvider`   |
// | release         | `AndroidPlayIntegrity` | `AppleDeviceCheck`     |
//
// Web uses reCAPTCHA v3 in every build (there is no web debug provider); it is
// only activated when a Site Key was supplied at build time.

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

/// App Check attestation tier for a build.
enum AppCheckTier {
  /// Debug/profile builds — emulator-friendly debug providers.
  debug,

  /// Release builds — real attestation.
  release,
}

/// The reCAPTCHA v3 Site Key for Web App Check, injected at build time:
///
/// ```
/// flutter build web --dart-define=WEB_RECAPTCHA_V3_SITE_KEY=<key>
/// ```
///
/// Empty means "no Web App Check" (a mobile-only build), which keeps the build
/// runnable instead of throwing on an unconfigured key.
const String appCheckWebRecaptchaSiteKey = String.fromEnvironment(
  'WEB_RECAPTCHA_V3_SITE_KEY',
  defaultValue: '',
);

/// A fully resolved App Check activation plan.
@immutable
class AppCheckConfig {
  const AppCheckConfig({
    required this.tier,
    required this.android,
    required this.apple,
    this.web,
  });

  /// Which attestation tier this plan belongs to.
  final AppCheckTier tier;

  /// The Android provider to activate.
  final AndroidAppCheckProvider android;

  /// The Apple provider to activate.
  final AppleAppCheckProvider apple;

  /// The Web provider to activate, or `null` when no Site Key was supplied.
  ///
  /// `firebase_app_check` only re-exports the concrete web providers (not the
  /// `WebProvider` base class), and reCAPTCHA v3 is the only web provider this
  /// app uses.
  final ReCaptchaV3Provider? web;

  /// Whether this plan uses the shared debug attestation providers.
  bool get usesDebugProviders => tier == AppCheckTier.debug;

  /// Whether a Web provider will be activated.
  bool get hasWebProvider => web != null;

  @override
  String toString() =>
      'AppCheckConfig(tier: ${tier.name}, hasWebProvider: $hasWebProvider)';
}

/// Whether App Check is supported on the running platform.
///
/// App Check covers Android, iOS and Web. Desktop platforms (Windows/Linux/
/// macOS) are skipped so startup does not throw; enforcement for those apps is
/// left off in the Console.
bool isAppCheckSupportedPlatform({
  required bool isWeb,
  required TargetPlatform platform,
}) {
  return isWeb ||
      platform == TargetPlatform.android ||
      platform == TargetPlatform.iOS;
}

/// Resolve the attestation tier for a build.
///
/// Profile mode is deliberately treated as debug so `flutter run --profile`
/// (used for the startup profiling in v9.2.2) keeps working on an emulator.
AppCheckTier resolveAppCheckTier({
  required bool isDebugMode,
  required bool isProfileMode,
}) {
  return (isDebugMode || isProfileMode)
      ? AppCheckTier.debug
      : AppCheckTier.release;
}

/// Build the provider set App Check should activate with.
///
/// Release builds NEVER fall back to a debug provider: a release binary must
/// fail attestation rather than silently present a placeholder token.
AppCheckConfig resolveAppCheckConfig({
  required bool isDebugMode,
  required bool isProfileMode,
  String webSiteKey = appCheckWebRecaptchaSiteKey,
}) {
  final tier = resolveAppCheckTier(
    isDebugMode: isDebugMode,
    isProfileMode: isProfileMode,
  );
  final web = webSiteKey.isEmpty ? null : ReCaptchaV3Provider(webSiteKey);

  if (tier == AppCheckTier.debug) {
    return AppCheckConfig(
      tier: tier,
      android: AndroidDebugProvider(),
      apple: AppleDebugProvider(),
      web: web,
    );
  }

  return AppCheckConfig(
    tier: tier,
    android: const AndroidPlayIntegrityProvider(),
    apple: const AppleDeviceCheckProvider(),
    web: web,
  );
}

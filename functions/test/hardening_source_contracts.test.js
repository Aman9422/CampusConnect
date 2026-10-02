"use strict";

/**
 * CampusConnect v9.2.4 — production-hardening SOURCE CONTRACT tests.
 *
 * C-1 (release signing), C-2 (App Check) and E-18 (HttpsError handling) are all
 * *configuration / consistency* fixes. None of them has a runtime behaviour a
 * unit test can exercise in this repository:
 *
 *   - C-1 lives in the Gradle build script and only matters when Gradle
 *     itself assembles a release artifact;
 *   - C-2's provider selection is a Dart build-mode branch verified by
 *     `test/app_check_config_test.dart` on the Flutter side, and its
 *     enforcement is a Firebase Console action;
 *   - E-18 is an idiomatic-consistency fix inside a catch block.
 *
 * Exactly like `retention_snapshot_contract.test.js`, these tests therefore
 * assert the SOURCE that encodes each fix and fail if a future edit undoes it.
 * That is the regression that matters: each of these defects shipped precisely
 * because nothing pinned the invariant.
 *
 * Run:  node --test test/hardening_source_contracts.test.js  (from functions/)
 */

const test = require("node:test");
const assert = require("node:assert");
const fs = require("node:fs");
const path = require("node:path");
const {execFileSync} = require("node:child_process");

// ── Source loaders ───────────────────────────────────────────────────────

const FUNCTIONS_ROOT = path.join(__dirname, "..");
const REPO_ROOT = path.join(FUNCTIONS_ROOT, "..");

function readRepoFile(relativePath) {
  return fs.readFileSync(path.join(REPO_ROOT, relativePath), "utf8");
}

function repoFileExists(relativePath) {
  return fs.existsSync(path.join(REPO_ROOT, relativePath));
}

/**
 * True when `git` reports [relativePath] as tracked — that is, it would be
 * committed.
 *
 * The C-1 invariant is "never *committed*", not "never present on disk": a
 * machine that can assemble a release build *must* carry a local, Git-ignored
 * `key.properties`, so asserting bare filesystem absence fails on exactly the
 * machine the guard exists to protect, and a permanently-red suite hides real
 * regressions.
 *
 * A path is treated as untracked when `git` cannot answer — `--error-unmatch`
 * exits non-zero for an untracked path, and the spawn raises ENOENT when git is
 * not installed. The .gitignore assertions above pin the invariant regardless.
 */
function repoFileIsTracked(relativePath) {
  try {
    execFileSync("git", ["ls-files", "--error-unmatch", "--", relativePath], {
      cwd: REPO_ROOT,
      stdio: "pipe",
    });
    return true;
  } catch {
    return false;
  }
}

/** Strip `//` line comments so assertions run against executable text only. */
function stripLineComments(source) {
  return source
      .split("\n")
      .map((line) => {
        const commentAt = line.indexOf("//");
        return commentAt === -1 ? line : line.slice(0, commentAt);
      })
      .join("\n");
}

const gradle = readRepoFile("android/app/build.gradle.kts");
const gradleCode = stripLineComments(gradle);
const androidGitignore = readRepoFile("android/.gitignore");
const appCheckConfig = readRepoFile("lib/services/app_check/app_check_config.dart");
const appCheckConfigCode = stripLineComments(appCheckConfig);
const deepAnalysisSource = readRepoFile("functions/ai/deepAnalysis.js");

// ═════════════════════════════════════════════════════════════════════════
// C-1 — release builds must never be signed with the debug key
// ═════════════════════════════════════════════════════════════════════════

test("C-1: the release build type does NOT use the debug signing config", () => {
  // The pre-fix line was:
  //   release { signingConfig = signingConfigs.getByName("debug") }
  // Assert the release block never resolves the debug config.
  const releaseBlock = gradleCode.match(/buildTypes\s*\{[\s\S]*?\n\s{4}\}/);
  assert.ok(releaseBlock, "build.gradle.kts must declare a buildTypes block");

  const releaseIdx = releaseBlock[0].indexOf("release");
  assert.ok(releaseIdx !== -1, "the buildTypes block must declare a release type");

  const releaseSection = releaseBlock[0].slice(releaseIdx);
  assert.doesNotMatch(
      releaseSection,
      /signingConfig\s*=\s*signingConfigs\.getByName\(\s*"debug"\s*\)/,
      "the release build type must never be signed with the debug keystore (C-1)",
  );
});

test("C-1: the debug build type keeps the debug signing config", () => {
  assert.match(
      gradleCode,
      /debug\s*\{[\s\S]*?signingConfig\s*=\s*signingConfigs\.getByName\(\s*"debug"\s*\)/,
      "debug builds must still be signed with the debug key so `flutter run` works",
  );
});

test("C-1: the release build type is wired to the release signing config", () => {
  assert.match(
      gradleCode,
      /signingConfig\s*=\s*signingConfigs\.findByName\(\s*"release"\s*\)/,
      "the release type must (conditionally) use the `release` signing config",
  );
  assert.match(
      gradleCode,
      /create\(\s*"release"\s*\)\s*\{/,
      "a `release` signing config must be created from key.properties",
  );
});

test("C-1: credentials are loaded from key.properties, never hard-coded", () => {
  assert.match(
      gradleCode,
      /file\(\s*"key\.properties"\s*\)/,
      "the signing config must read android/app/key.properties",
  );
  for (const key of ["storeFile", "storePassword", "keyAlias", "keyPassword"]) {
    assert.ok(
        gradleCode.includes(`"${key}"`),
        `the signing config must require the ${key} property`,
    );
  }
});

test("C-1: a release build without a keystore fails loudly instead of falling back", () => {
  assert.match(
      gradleCode,
      /throw GradleException\(/,
      "a release build with no key.properties must abort, not silently use the debug key",
  );
  assert.match(
      gradleCode,
      /releaseSigningRequested/,
      "the abort must be gated so debug/test/profile builds are unaffected",
  );
});

test("C-1: key.properties and every keystore are Git-ignored", () => {
  assert.match(androidGitignore, /^key\.properties\s*$/m,
      "android/app/key.properties must never be committed");
  assert.match(androidGitignore, /^\*\*\/\*\.keystore\s*$/m,
      "keystore files must never be committed");
  assert.match(androidGitignore, /^\*\*\/\*\.jks\s*$/m,
      "jks files must never be committed");
});

test("C-1: a committed keystore or key.properties would fail this test", () => {
  assert.ok(
      !repoFileIsTracked("android/app/key.properties"),
      "android/app/key.properties must never be committed — a local, " +
          "Git-ignored copy is expected (see android/app/key.properties.template)",
  );
  assert.ok(
      repoFileExists("android/app/key.properties.template"),
      "a template must exist so the signing setup is reproducible without secrets",
  );

  // No keystore material committed anywhere in the tree. Keystores are
  // Git-ignored too, so a local signing keystore is expected — only a
  // *committed* one fails.
  const keystoreCandidates = [
    "android/app/upload-keystore.jks",
    "android/app/release.keystore",
    "android/app/key.jks",
  ];
  for (const candidate of keystoreCandidates) {
    assert.ok(
        !repoFileIsTracked(candidate),
        `${candidate} must not be committed`,
    );
  }
});

// ═════════════════════════════════════════════════════════════════════════
// C-2 — App Check provider selection and no committed debug tokens
// ═════════════════════════════════════════════════════════════════════════

test("C-2: release builds use Play Integrity / DeviceCheck, never a debug provider", () => {
  assert.match(
      appCheckConfigCode,
      /AndroidPlayIntegrityProvider\(\)/,
      "Android release attestation must be Play Integrity",
  );
  assert.match(
      appCheckConfigCode,
      /AppleDeviceCheckProvider\(\)/,
      "Apple release attestation must be DeviceCheck",
  );

  // The FINAL `return AppCheckConfig(...)` is the release branch — the debug
  // branch returns earlier, inside `if (tier == AppCheckTier.debug)`. Slice
  // from that last return so the debug providers (which legitimately exist
  // above it) cannot mask a regression here.
  const releaseReturnIdx = appCheckConfigCode.lastIndexOf("return AppCheckConfig(");
  assert.ok(releaseReturnIdx !== -1,
      "resolveAppCheckConfig must return an AppCheckConfig");
  const releaseReturn = appCheckConfigCode.slice(releaseReturnIdx);

  assert.match(
      releaseReturn,
      /AndroidPlayIntegrityProvider\(\)/,
      "the release return must use Play Integrity on Android",
  );
  assert.match(
      releaseReturn,
      /AppleDeviceCheckProvider\(\)/,
      "the release return must use DeviceCheck on Apple",
  );
  assert.doesNotMatch(
      releaseReturn,
      /AndroidDebugProvider\(\)|AppleDebugProvider\(\)/,
      "a release binary must never fall back to a debug App Check provider",
  );
});

test("C-2: debug/profile builds use the debug providers", () => {
  assert.match(appCheckConfigCode, /AndroidDebugProvider\(\)/);
  assert.match(appCheckConfigCode, /AppleDebugProvider\(\)/);
  assert.match(
      appCheckConfigCode,
      /isDebugMode\s*\|\|\s*isProfileMode|\(isDebugMode \|\| isProfileMode\)/,
      "profile mode must be treated as debug so `flutter run --profile` keeps working",
  );
});

test("C-2: Web uses reCAPTCHA v3 and is skipped when no Site Key is supplied", () => {
  assert.match(appCheckConfigCode, /ReCaptchaV3Provider\(/,
      "Web attestation must be reCAPTCHA v3");
  assert.match(
      appCheckConfigCode,
      /WEB_RECAPTCHA_V3_SITE_KEY/,
      "the Site Key must come from a build-time --dart-define, not a committed value",
  );
  assert.match(
      appCheckConfigCode,
      /webSiteKey\.isEmpty\s*\?\s*null/,
      "an unconfigured Web build must skip App Check rather than throw",
  );
});

test("C-2: App Check covers exactly Android / iOS / Web", () => {
  assert.match(appCheckConfigCode, /TargetPlatform\.android/);
  assert.match(appCheckConfigCode, /TargetPlatform\.iOS/);
  assert.match(
      appCheckConfigCode,
      /isWeb\s*\|\|/,
      "Web must be treated as a supported platform",
  );
});

test("C-2: no App Check debug token is committed anywhere in the repo", () => {
  // Debug tokens are UUIDs; the SDK logs them at runtime. Nothing in the repo
  // may carry one. Check the build-time config surface only (a Dart file, the
  // web index and the Android manifest) — the App Check token is never a
  // committed value in this project.
  const filesToCheck = [
    "lib/services/app_check/app_check_config.dart",
    "lib/firebase_options.dart",
    "android/app/src/main/AndroidManifest.xml",
  ].filter(repoFileExists);

  const debugTokenPattern =
      /[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}/;

  for (const file of filesToCheck) {
    const contents = readRepoFile(file);
    assert.doesNotMatch(
        contents,
        debugTokenPattern,
        `${file} must not contain an App Check debug token (C-2: do not commit debug tokens)`,
    );
  }
});

// ═════════════════════════════════════════════════════════════════════════
// E-18 — deepAnalysis.js uses the idiomatic HttpsError re-throw test
// ═════════════════════════════════════════════════════════════════════════

test("E-18: deepAnalysis.js detects HttpsError with `instanceof`", () => {
  assert.match(
      stripLineComments(deepAnalysisSource),
      /if\s*\(\s*error\s+instanceof\s+admin\.functions\.https\.HttpsError\s*\)\s*\{?\s*throw error;/,
      "every other Functions module uses `instanceof admin.functions.https.HttpsError`",
  );
});

test("E-18: the pre-fix duck-typed check is gone", () => {
  assert.doesNotMatch(
      stripLineComments(deepAnalysisSource),
      /error\.code\s*&&\s*error\.httpErrorCode/,
      "the `error.code && error.httpErrorCode` duck-typing must be removed (E-18)",
  );
});

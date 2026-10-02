# CampusConnect — v9.2.4 Hardening Report

| | |
|---|---|
| **Release** | `9.2.4+101` |
| **Baseline** | `9.2.2+100` (audited revision in `docs/v9_2_3_audit_report.md`) |
| **Version nature** | **Implementation release** (v9.2.3 was audit-only — no code changed) |
| **Report date** | 2026-10-02 |
| **Scope** | The critical/high security, correctness, reliability and production-readiness fixes from the v9.2.3 audit |
| **Deployment scope** | **Direct APK installation — NOT Google Play publication** (see §2) |

> **Evidence convention.** "Verified" means a test or a source contract in this
> repository proves it. "Runtime-verified" means the artefact was actually built
> and inspected during v9.2.4, with the observed output quoted. Anything requiring
> a device, the Firebase Console or a physical phone is marked
> **outstanding** / **operator action** and is **not** claimed as done — see
> §15 (results), §16 (manual), §17 (limitations) and §18 (remaining work).

---

## 1. Objective

Remove the release blockers and the high-severity correctness defects identified
by the v9.2.3 whole-application deep audit, without redesigning the UI,
replacing the architecture, rewriting the recommendation engine, or performing a
mass dependency upgrade.

Findings implemented in v9.2.4 (audit IDs):
`C-1` · `C-2` · `D-1` · `D-2` · `D-3` · `D-7` · `D-9` · `D-10` · `D-11` ·
`E-3` · `E-18`.

Findings **deferred** to v9.2.5/v9.2.6 (unchanged from the audit): `C-3`, `D-4`,
`D-5`, `D-6`, `D-8`, `E-1`, `E-2`, `E-4`…`E-17`, and the §N dependency work.

---

## 2. Deployment scope (re-scoped during v9.2.4)

**CampusConnect is a final-year academic project and is NOT published on the
Google Play Store.** The v9.2.3 audit was written against a Play-bound release;
this report records the scope that actually applies.

```
Firebase backend (Auth · Firestore · Storage · Cloud Functions)
        |
        v
properly signed Flutter *release* APK
        |
        v
direct installation on a phone / emulator (adb install, USB or file transfer)
        |
        v
final-year project demonstration
```

### Required by the Definition of Done

* A real (non-debug) release signing configuration; credentials never committed.
* A release APK that installs and launches on the demo device.
* A Firebase backend reachable from that APK.
* A documented, deliberate App Check posture for a direct-APK distribution.

### Explicitly out of scope (and therefore not done)

* Google Play publication — draft/internal/closed/open testing tracks, staged rollout.
* A Google Play Console developer account and the one-time **$25** registration fee.
* Play Store upload, review, Play App Signing and upload-key-reset flows.
* Distributing via an App Bundle (`.aab`) — it is buildable for validation only.
* Paid or commercial distribution infrastructure.
* **App Check enforcement** — see §7.

### What the re-scope changed in practice

Nothing in the shipped code. The re-scope changed **documentation and the
Definition of Done**: `docs/Task.md` gained §0 and inline `v9.2.4 re-scope`
notes; `docs/release_signing.md` and `docs/app_check_status.md` were rewritten
around direct distribution; `docs/todo.md` records the same scope. The release
signing fix and the App Check *provider architecture* are exactly as the audit
prescribed. The only audit item whose outcome changed is `C-2`'s enforcement
step, for the documented technical reason in §7 — not for convenience.

---

## 3. Status at a glance

| Status | Items |
|---|---|
| **Fixed** | C-1, C-2 (provider architecture + posture), D-1, D-2, D-3, D-7, D-9, D-10, D-11, E-3, E-18 |
| **Verified** (tests / source contracts) | All of the above, plus the release-signing and App Check configuration contracts |
| **Runtime-verified** (artefact actually produced and inspected in v9.2.4) | release APK built and proven release-signed; App Bundle built and proven release-signed; `flutter analyze` clean; `flutter test` green (540); `npm --prefix functions test` green (97/97); **both rule sets executed against the emulators — `firestore.rules` 37/37 and `storage.rules` 18/18 allow/deny assertions (55/55 combined)**; `firebase deploy --only functions --dry-run` → **Dry run complete** |
| **Outstanding / operator action** | install the release APK on the physical demo device and run the manual pass (§16); build the demo APK with the operator's own release key (§8); App Check debug-token allow-listing (§7); deploy the hardened rules and Functions when ready; App Check enforcement — deliberately **not** applicable (§7) |

---

## 4. Implemented changes

### 4.1 C-1 — release signing (no debug key)

* **Before:** `android/app/build.gradle.kts` wired the `release` build type to
  `signingConfigs.getByName("debug")`, so every "release" APK/AAB was signed with
  the publicly known Android debug key.
* **After:** the `release` type resolves a `release` signing config built from
  `android/app/key.properties` (git-ignored). There is **no fallback**: if the
  credentials are absent and a release build is requested, Gradle **aborts** with
  a `GradleException` naming the missing file and keys. Debug/profile/`test`/
  `analyze` runs are untouched because the abort is gated on the requested task
  names.
* A `key.properties.template` is committed (placeholders only) so the setup is
  reproducible without secrets.

### 4.2 C-2 — App Check (architecture preserved; posture re-scoped)

* **Before:** provider selection lived inside the private `_activateAppCheck`
  helper in `main.dart` and could not be asserted; the audit flagged that
  enforcement was off and the debug token was not allow-listed.
* **After:** provider selection is a pure function in
  `lib/services/app_check/app_check_config.dart`
  (`resolveAppCheckConfig` / `resolveAppCheckTier` /
  `isAppCheckSupportedPlatform`), pinned by tests. Behaviour is unchanged:
  debug/profile → debug providers, release → Play Integrity / DeviceCheck,
  Web → reCAPTCHA v3 (opt-in via `--dart-define`), and a **release build can
  never be handed a debug provider**.
* The enforcement step is **not** applied, for the technical reason in §7. No
  bypass was added and no custom provider infrastructure was introduced.

### 4.3 D-1 — resume-review double refresh (the trigger chain)

* **Before:** `onResumeReviewCreatedRefreshMatches` merged the resume counters
  (`portfolio.resume.reviewCount|lastReviewAt|latestATSScore|updatedAt`) back
  onto the parent `users/{uid}` document. That write fired
  `onProfileUpdatedRefreshAI`, whose `portfolioContentChanged` check saw a
  change and ran a **second, concurrent** `refreshRecommendationsForStudent`
  **without** `options.resumeData`.
* **Consequence (as audited):** two engine runs and two AI enrichments per resume
  review; a fingerprint that **thrashed** between two variants in
  `recommendations_meta`; and 3 extra `profileUpdated` engagement points on top
  of the resume-review award.
* **After:** a pure guard, `isResumeReviewMetadataOnlyChange(before, after)`,
  exported from `functions/helpers/shared.js`, recognises the resume-review
  counter merge as **metadata-only**, and `onProfileUpdatedRefreshAI` ignores it
  — no second refresh, no engagement points. Genuine profile/portfolio changes
  (including a changed resume file or a root-level `skills` edit) still trigger
  exactly one refresh.
* **Fingerprint behaviour:** the resume-review path and every other caller now
  hash the same document state to the **same** value, so the stored fingerprint
  converges instead of alternating. A genuinely new review still moves it
  (regeneration preserved); a `portfolio.metadata`-only flutter does not.
* **The other half of the fix is in the engine.** `extractUserSignals()` in
  `functions/recommendations/engine.js` now reads the missing-keyword signal from
  the **persisted** `portfolio.resume.latestMissingKeywords` map when no
  `options.resumeData` passthrough is supplied (the resume-review trigger
  persists that field). That is what makes the trigger path, the profile path and
  the client-callable path derive an **identical** signal set — and therefore an
  identical fingerprint — for the same student state. Without it, the guard alone
  would stop the second refresh but the two variants would still hash differently.

### 4.4 D-2 — placement apply reliability

* **Before:** the client used a **30 s** timeout against a server callable
  declared `timeoutSeconds: 120` (which performs a Storage copy and a
  `getSignedUrl` before its transaction); on timeout it removed the placement
  from `_appliedPlacementIds`, i.e. it reported a successful apply as a failure.
  `updateApplicationStatus` used 30 s against a 60 s server function.
* **After:** client timeouts match their server contracts (120 s / 60 s); a
  timeout no longer rolls back the applied state — it moves the placement into a
  **pending / reconciliation** state and reconciles with a single read instead of
  blindly retrying. Server-side idempotency and duplicate prevention are
  unchanged.

### 4.5 D-3 — placement eligibility parity

* **Before:** `lib/services/eligibility_engine.dart` checked `programs` and
  `branches` **independently** (both had to pass), while
  `checkMandatoryEligibility` in `functions/recommendations/engine.js` treats
  them as **alternatives**. For a placement specifying both, the client badge and
  the recommendation engine could disagree.
* **After:** the client matches the server's canonical semantics; a table-driven
  parity test covers programs-only, branches-only, both, matching and
  non-matching program/branch, and a missing student program.
  `docs/eligibility_rules.md` was corrected to describe the implementation that
  actually ships. No second eligibility engine was created.

### 4.6 D-9 / D-10 / D-11 — Firestore rule hardening

* **D-9 (authorization):** before, `opportunities` create was
  `isAuthenticated() && alumniId == request.auth.uid` — so **any** signed-in
  account could create an opportunity and trigger the `newJobPost` broadcast to
  every student and inject into recommendation candidates. Now create requires
  `userRole() == 'alumni'`; ownership checks for update/delete are preserved.
* **D-10 (schema validation):** `isValidOpportunityData()` was added — at least
  as strong as the pre-existing `isValidPlacementData()` — and applied on both
  create and update. Its required field set was reconciled against the real
  writer (`lib/models/opportunity.dart::toFirestore`) so a legitimate write is
  never rejected.
* **D-11 (profile flags):** the only protected field on `users/{uid}` used to be
  `role`; an owner could write `profileCompleted` and `isVerified` freely.
  `profileCompleted` is now restricted to a **validated transition**
  (absent/false → true, and only when the required profile sections are present
  in the post-write document), and `isVerified` is client-immutable. The
  legitimate completion flow (`updateProfile()` → `markProfileCompleted()` in
  `profile_setup_view.dart`) was checked against the rule and still passes;
  `role` behaviour is unchanged.

### 4.7 D-7 — AI chat single writer

* **Before:** three documents per chat exchange from two writers with two
  schemas — the server wrote `role: 'user'`/`role: 'assistant'` records with
  `timestamp`, and the Flutter client wrote a third combined record with
  `createdAt`. The client reader ordered by `createdAt`, so it never saw the
  server records, while the retention sweep filtered on `timestamp`.
* **After:** the server is the single writer of `users/{uid}/ai_interactions`;
  the client write (`_saveInteraction` / `AIInteraction.toFirestore`) is gone;
  the Flutter reader consumes the server schema (`message` / `role` /
  `timestamp`); retention cleanup and history loading agree on one schema.
  `deleteAIHistory` is preserved and `ai_conversations` writes were not restored.

### 4.8 E-3 — scheduler bulk safety

* **Before:** `autoExpireOpportunities` built **one** Firestore batch from an
  unbounded query, so more than 500 expired opportunities made the commit throw
  and the whole sweep fail.
* **After:** writes are chunked at 400/batch, matching the existing bulk
  patterns in the codebase. Scheduler behaviour and idempotency are preserved and
  the job count is unchanged (still 5).

### 4.9 E-18 — error-handling consistency

* `functions/ai/deepAnalysis.js` no longer uses the duck-typed
  `if (error.code && error.httpErrorCode)` test; it now uses
  `if (error instanceof admin.functions.https.HttpsError) throw error;`, matching
  every other Functions module.
---

## 5. Files changed

> The authoritative record of the exact diff is the working tree; run
> `git status --short` and `git diff --stat` in the repository root. The list
> below groups the changes by area for review.

**Android / release signing**

* `android/app/build.gradle.kts` — release signing config from `key.properties`, no debug fallback, fail-loud guard.
* `android/app/key.properties.template` — **new**; placeholder credentials format (committed; contains no secrets).
* `android/.gitignore` — already excluded `key.properties`, `**/*.jks`, `**/*.keystore` (verified, unchanged).

**App Check**

* `lib/services/app_check/app_check_config.dart` — **new**; pure provider-selection contract.
* `lib/main.dart` — activates App Check through the extracted config (behaviour unchanged).

**Placements**

* `lib/services/eligibility_engine.dart` — `programs` / `branches` as alternatives (parity with the server).
* `lib/providers/placements_provider.dart` — 120 s / 60 s timeouts, pending state, single-read reconciliation.
* `lib/services/firestore/placements_service.dart` — applied-state resolution used by the reconciliation read.
* `lib/views/placements/placements_list_view.dart` — surfaces the pending state instead of a false failure.

**AI chat**

* `lib/providers/ai_chat_provider.dart` — client Firestore write removed; reads the server schema.
* `lib/models/ai_interaction.dart` — single server schema (no `createdAt` writer path).

**Cloud Functions**

* `functions/helpers/shared.js` — `isResumeReviewMetadataOnlyChange` guard exported (pure).
* `functions/triggers/index.js` — `onProfileUpdatedRefreshAI` ignores resume-review metadata-only writes.
* `functions/schedulers/index.js` — `autoExpireOpportunities` chunks at 400/batch.
* `functions/ai/deepAnalysis.js` — idiomatic `instanceof admin.functions.https.HttpsError`.
* `functions/recommendations/engine.js` — `extractUserSignals()` also reads the persisted `portfolio.resume.latestMissingKeywords` when no `options.resumeData` passthrough is present (the D-1 convergence mechanism).
* `functions/recommendations/refresh.js` — reviewed for the fingerprint convergence contract (semantics unchanged).
* `functions/test/firestore_fake.js` — extended for the new Functions suites.

**Security rules**

* `firestore.rules` — D-9 (opportunity create requires `alumni`), D-10 (`isValidOpportunityData()` on create+update), D-11 (`profileCompleted` validated transition, `isVerified` client-immutable).

**Versioning & documentation**

* `pubspec.yaml` — `9.2.4+101`.
* `docs/Task.md` — §0 deployment scope + `v9.2.4 re-scope` notes + re-scoped Definition of Done.
* `docs/todo.md` — v9.2.4 workstream status.
* `docs/release_signing.md` — rewritten for direct distribution (release key, `apksigner`, `adb install`).
* `docs/app_check_status.md` — rewritten for the non-Play posture (§7).
* `docs/v9_2_3_audit_report.md` — §AD metadata corrections only (date, baseline distinction, test-count reconciliation); no finding altered.
* `docs/eligibility_rules.md` — corrected to the shipped semantics.
* `docs/v9_2_4_hardening_report.md` — **new** (this report).

**Tests added**

* `test/app_check_config_test.dart`, `test/eligibility_parity_test.dart`,
  `test/placement_timeout_reconciliation_test.dart`, `test/ai_chat_single_writer_test.dart`,
  `functions/test/hardening_source_contracts.test.js`,
  `functions/test/resume_review_single_refresh.test.js`,
  `functions/test/security_rules_contract.test.js`,
  `functions/test/schedulers_expiry.test.js`,
  `functions/test-rules/firestore_rules.test.js` and
  `functions/test-rules/storage_rules.test.js` — **both rule sets executed**
  against the emulators, run by the new `test:rules` / `test:storage-rules` /
  `test:all-rules` scripts in `functions/package.json`, which also adds
  `@firebase/rules-unit-testing` and `firebase` as **devDependencies** (dev-only;
  not deployed, and the only dependency-manifest change in v9.2.4)
  (plus the shared `functions/test/setup.js` admin shim and `functions/test/firestore_fake.js` they build on).

---

## 6. Security-rule changes (`firestore.rules`)

### 6.1 `opportunities` — authorization (D-9)

```
// Before
allow create: if isAuthenticated() &&
  request.resource.data.alumniId == request.auth.uid;

// After
allow create: if isAuthenticated() &&
  userRole() == 'alumni' &&
  isValidOpportunityData();
```

Update/delete keep their existing ownership checks
(`resource.data.alumniId == request.auth.uid`) and now also run the schema
validator on update.

### 6.2 `opportunities` — schema validation (D-10)

A new `isValidOpportunityData()` was added alongside the pre-existing
`isValidPlacementData()`, applied on both create and update. It validates the
required fields (non-empty `title`/`company`, string `description`/`type`/
`location`, timestamp `postedAt`/`applicationDeadline`, boolean `isActive`, and
`alumniId == request.auth.uid`) and rejects malformed or wrong-typed documents
**before** they can fire the broadcast trigger or enter recommendation
candidates.

### 6.3 `users/{uid}` — profile flags (D-11)

```
// Before: only `role` was protected; every other field was owner-writable.
allow write: if isOwner(userId) && canWriteRole(userId);

// After: `role` protection retained, profile flags constrained.
allow write: if isOwner(userId) && canWriteRole(userId) && canWriteProfileFlags();
```

`canWriteProfileFlags()` requires, in effect:

* `profileCompleted` may only transition **absent/false → true**, and only when
  the post-write document actually carries the required profile sections
  (`personal.fullName`, `academic.college`, `academic.program`, `academic.year`)
  — so a client cannot simply assert completion. The legitimate flow (save the
  profile, then `markProfileCompleted()`) satisfies this.
* `isVerified` may not be changed by a client at all.

`role` behaviour is untouched. Rule tests: `functions/test/security_rules_contract.test.js`.

---

## 7. App Check status

**Posture: configured, correct, and deliberately NOT enforced — because the app
is distributed by direct install, not through Google Play.**

Full detail and the future Play-linked upgrade path live in
`docs/app_check_status.md`; the summary is:

| Aspect | State |
|---|---|
| Provider selection | Correct, extracted to a pure function, pinned by tests |
| Debug / profile | `AndroidDebugProvider` / `AppleDebugProvider` |
| Release | `AndroidPlayIntegrityProvider` / `AppleDeviceCheckProvider` |
| Web | `ReCaptchaV3Provider`, opt-in via `--dart-define`, not committed |
| Release may fall back to a debug provider | **No** — forbidden by code and enforced by tests |
| Debug token committed | **No** — enforced by the C-2 source contract |
| Enforcement (Firestore / Functions / Storage) | **OFF — by design** |

### Why enforcement is off (technical, verified against Firebase's documentation)

Firebase's Play Integrity provider does support apps distributed outside Google
Play — *"The Play Integrity provider supports Android apps that are published on
Google Play, outside Google Play, or both."* — **but**:

1. The setup requires the Play Integrity API to be linked **from the Google Play
   Console**, which needs a Play Console developer account (the one-time **$25**
   that §2 puts out of scope).
2. By default App Check demands the `PLAY_RECOGNIZED` label, and *"apps not
   published on Google Play are not eligible to receive this label"*. Relaxing
   it is an App Check **advanced setting** ("Exclusively outside Google Play":
   `PLAY_RECOGNIZED` not required, `LICENSED` not required, minimum device
   integrity = *Device integrity*) — reachable only after (1).

Consequently a sideloaded release APK cannot obtain a valid Play Integrity token
here, and switching enforcement on would deny **100 %** of the demo app's
backend traffic with `permission-denied`.

### What protects the backend instead (all still enforced)

Firebase Authentication · Firestore rules (including the D-9/D-10/D-11 hardening
above) · Storage rules (ownership, PDF MIME, 5 MB) · callable authentication and
server-side role re-checks · AI quota/rate-limit/spam windows ·
server-owned collections (`allow write: if false`). App Check is an additional
abuse barrier, not an authorization mechanism; no authorization check was
removed by leaving it unenforced.

### No insecure bypass introduced

No release build is downgraded to the debug provider; no custom App Check
provider or attestation backend was added; nothing client-side can skip
attestation; the debug-token mechanism is documented for development only.

---

## 8. Release signing status

| Item | Status |
|---|---|
| `release` build type wired to a real key | **Fixed** — `android/app/build.gradle.kts` |
| Credentials from `key.properties` (git-ignored) | **Fixed** |
| Debug config kept for `debug` only | **Fixed** |
| Release without credentials aborts | **Verified in source** (guard pinned by the C-1 contract test) |
| `flutter build apk --release` | **Runtime-verified** — `build/app/outputs/flutter-apk/app-release.apk`, 56.7 MB |
| `flutter build appbundle --release` (optional) | **Runtime-verified** — `build/app/outputs/bundle/release/app-release.aab`, 46.8 MB |
| Not signed with the debug key | **Runtime-verified** — `apksigner verify --print-certs` reported `CN=CampusConnect Validation, OU=Local, O=CampusConnect, L=NA, ST=NA, C=IN`, SHA-256 `03:B7:0D:79:…:A8:DA`; the debug key reports `CN=Android Debug, O=Android, C=US`, SHA-256 `13:65:4F:0D:…:41:A3` — different DN **and** different digest |
| Build + verify with the operator's own key | **Operator action** — see `docs/release_signing.md` §6 |
| Install on the demo device | **Operator action** — `adb install -r build/app/outputs/flutter-apk/app-release.apk` |

> The APK/AAB above were produced with a **throwaway validation keystore** that
> was deleted immediately afterwards (the C-1 contract test fails if any keystore
> or a real `key.properties` is present in the tree). Those digests prove the
> *mechanism* — release signing applies and is not the debug key — not the
> identity of the final key.
---

## 9. Recommendation trigger behaviour — before / after

| | Before (v9.2.2/Audited) | After (v9.2.4) |
|---|---|---|
| Refresh entry points | profile trigger · resume-review trigger · callable · client bootstrap | unchanged (4 entry points) |
| Resume review | **two concurrent refreshes** — the resume trigger's own refresh **plus** a second one fired by its `users/{uid}` write re-entering `onProfileUpdatedRefreshAI` without `options.resumeData` | **exactly one** effective refresh |
| Fingerprint | **thrashed** between the with-`resumeData` and without-`resumeData` variants, so the skip gate only fired ~half the time | **converges**: every caller hashes the same document state to the same value |
| Regeneration still happens for | profile/portfolio/resume change, candidate change, expiry, explicit refresh, logout/login | unchanged — the guard is narrow (metadata-only writes) and the fingerprint still moves on a genuinely new review |
| Engagement points | 3 extra `profileUpdated` points per resume review | none for the metadata write; the resume-review award stands alone |
| Engine runs / AI enrichment per resume review | 2 runs, 2 AI enrichments | 1 run, 1 AI enrichment |
| Unified writer / server fingerprint mechanism | preserved | preserved |

Mechanism — **two changes that ship together**:

1. the resume-review trigger still writes its counters, but
   `onProfileUpdatedRefreshAI` now calls
   `isResumeReviewMetadataOnlyChange(before, after)` (exported from
   `functions/helpers/shared.js`) and returns early when the only change is the
   resume-review key set (`portfolio.resume.reviewCount` / `lastReviewAt` /
   `updatedAt` / `latestATSScore` / `latestMissingKeywords`) — this removes the
   second refresh and the extra engagement points;
2. `extractUserSignals()` in `functions/recommendations/engine.js` reads
   `latestMissingKeywords` from the persisted `portfolio.resume` map when no
   `options.resumeData` passthrough is present — this makes every caller derive
   the same signal set, and therefore the same fingerprint, instead of two
   variants alternating in `recommendations_meta`.

---

## 10. Placement timeout behaviour — before / after

| Contract | Before | After |
|---|---|---|
| `logPlacementApplication` client timeout | 30 s (server: 120 s) | **120 s** (matches server) |
| `updateApplicationStatus` client timeout | 30 s (server: 60 s) | **60 s** (matches server) |
| On timeout | threw, removed the placement from `_appliedPlacementIds`, showed "Request timed out. Please try again." — i.e. a **successful** apply was reported as a failure | placement enters a **pending / reconciliation** state; the applied marker is **not** rolled back |
| Recovery | blind user retry | a **single read** reconciles the server state, then the UI settles on the truth |
| Server behaviour | idempotent (`existingApp.exists` → `isNewApplication = false`), no duplicate applications | unchanged |

The "false failure" path is gone: a slow-but-successful apply now resolves to the
correct applied state, and retries still cannot create a duplicate application.

---

## 11. Eligibility parity

| Requirement shape | Server (`checkMandatoryEligibility`) | Client before | Client after |
|---|---|---|---|
| `programs` only | program must match | same | same |
| `branches` only | branch must match | same | same |
| **both set** | checked as **alternatives** (program match ⇒ eligible) | checked **independently** (both required) ⇒ **disagreed** | **alternatives** ⇒ agrees |
| student program missing | failure recorded | same | same |

The client badge, the recommendation engine, and `docs/eligibility_rules.md` now
state the same rule. Parity is enforced by a table-driven test
(`test/eligibility_parity_test.dart`) over programs-only, branches-only, both,
matching/non-matching program, matching/non-matching branch, and a missing
student program.

---

## 12. Opportunity authorization and validation

| Property | Before | After |
|---|---|---|
| Create authorization | `isAuthenticated() && alumniId == uid` — **any** signed-in account | `isAuthenticated() && userRole() == 'alumni' && isValidOpportunityData()` |
| Broadcast amplification (`newJobPost` to every student) | triggerable by a student | only by an alumni author |
| Recommendation injection | any authenticated user could inject candidates | restricted to alumni-authored, schema-valid documents |
| Schema validation | none beyond identity | `isValidOpportunityData()` on create **and** update |
| Update / delete | owner-only | owner-only (unchanged), validator added on update |
| Alumni self-serve stats inflation | possible via self-authored documents | requires alumni role |

Rule tests cover: alumni create → allowed; student create → denied; teacher
create → denied; unauthenticated create → denied; owner update/delete → allowed;
non-owner update/delete → denied.

---

## 13. AI chat schema / writer change

| | Before | After |
|---|---|---|
| Writers of `users/{uid}/ai_interactions` | **two** (server **and** Flutter client) | **one** (server / Admin SDK) |
| Documents per exchange | 3 | 2 (one user turn, one assistant turn) — the intended server records |
| Schema | two: server `{role, message, timestamp}` + client `{userId, prompt, response, intent, createdAt, metadata}` | one: `{role, message, timestamp, …}` |
| Client reader ordering key | `createdAt` (so it never saw the server rows) | `timestamp` (the server schema) |
| Retention sweep filter | `timestamp` | `timestamp` (now the only schema) |
| `deleteAIHistory` | preserved | preserved |
| `ai_conversations` | no longer written by `askAI`, still cleaned/queried | unchanged (transition debt retained) |

Covered by `test/ai_chat_single_writer_test.dart` and
`test/ai_chat_deletion_test.dart`.

---

## 14. Tests added

**Flutter (`test/`)**

| Suite | Covers |
|---|---|
| `app_check_config_test.dart` | C-2 provider selection: debug/profile → debug providers, release → Play Integrity / DeviceCheck, release **never** gets a debug provider, Web opt-in, desktop skip, no hard-coded Site Key |
| `eligibility_parity_test.dart` | D-3 table-driven parity across the requirement shapes in §11 |
| `placement_timeout_reconciliation_test.dart` | D-2 timeout alignment, pending state, no rollback on timeout, single-read reconciliation |
| `ai_chat_single_writer_test.dart` | D-7 single writer + server schema |

**Cloud Functions (`functions/test/`, `node --test`)**

| Suite | Covers |
|---|---|
| `hardening_source_contracts.test.js` | C-1 (no debug signing, key.properties, fail-loud guard, ignored secrets, no committed keystore), C-2 (release provider selection, no committed debug token), E-18 (`instanceof HttpsError`, duck-typing gone) |
| `resume_review_single_refresh.test.js` | D-1: the guard (5 pure cases), the real profile trigger firing 0 times on a metadata-only write and exactly once on genuine changes, no engagement points on the metadata write, and 3 fingerprint-convergence tests |
| `security_rules_contract.test.js` | D-9 opportunity authorization, D-10 schema validation, D-11 `profileCompleted` / `isVerified` restrictions — **source-contract** assertions on the rule text |
| `schedulers_expiry.test.js` | E-3 chunked expiry: empty · small · multi-batch |

**Both rule sets — executed against the emulators (`functions/test-rules/`)**

| Suite | Covers |
|---|---|
| `test-rules/firestore_rules.test.js` | The **same** D-9 / D-10 / D-11 / SEC-1 / SEC-2 / D-7 matrix, executed as **real allow/deny assertions** against the Firestore emulator with `@firebase/rules-unit-testing` — **37 cases** (full run in §15.2) |
| `test-rules/storage_rules.test.js` | `storage.rules` executed against the Storage emulator: owner upload/read/delete, PDF-only MIME, the 5 MB ceiling, non-owner and unauthenticated denial, the teacher/alumni role read branch, write-once placement snapshots, and the deny-all fallback — **18 cases** (full run in §15.2) |

These suites deliberately live **outside** `functions/test/`: they need running
emulators (`storage.rules`'s role branch also calls `firestore.get()`, so the
Firestore emulator must be up alongside Storage), so they run via their own
scripts and are *not* picked up by `npm --prefix functions test`, which stays
emulator-free and fast:

```
npm --prefix functions run test:rules          # firestore.rules  (Firestore emulator)
npm --prefix functions run test:storage-rules  # storage.rules    (Firestore + Storage emulators)
npm --prefix functions run test:all-rules      # both, one emulator boot — 55/55
```

No existing test was removed or weakened. The shared
`functions/test/setup.js` admin shim and `functions/test/firestore_fake.js` are
used by the new Functions suites.
---

## 15. Automated validation results

Every command below was run on **2026-10-02**, on this machine, **after the last
source change** of v9.2.4. Where a run was repeated for this report, the repeat is
the one recorded.

| # | Command | Observed result | Exit |
|---|---|---|---|
| 1 | `flutter pub get` | resolved; **no dependency version changed in v9.2.4** — `pubspec.yaml` differs from the baseline only in its version string, and the successful analyze/test/build below all require a resolved lockfile | `0` |
| 2 | `flutter analyze` | `Analyzing campusconnect...` → **`No issues found! (ran in 13.5s)`** | `0` |
| 3 | `flutter test` | **`All tests passed!`** — **540** tests (`+540`), no failures, no skips | `0` |
| 4 | `npm --prefix functions test` | `# tests 97` · `# pass 97` · `# fail 0` · `# skipped 0` (duration ≈ 1014 ms) | `0` |
| 5 | `node --check` on `functions/helpers/shared.js`, `functions/triggers/index.js`, `functions/schedulers/index.js`, `functions/ai/deepAnalysis.js`, `functions/recommendations/refresh.js`, `functions/recommendations/engine.js` | no output on any file — no syntax error | `0` |
| 6 | `flutter build apk --release` | `build/app/outputs/flutter-apk/app-release.apk` — **56.7 MB** (present, timestamped 2026-10-02 15:21) | `0` |
| 7 | `flutter build appbundle --release` *(optional per §0)* | `build/app/outputs/bundle/release/app-release.aab` — **46.8 MB** (present, 15:23) | `0` |
| 8 | `apksigner verify --print-certs` (APK + AAB) | signer `CN=CampusConnect Validation, OU=Local, O=CampusConnect, L=NA, ST=NA, C=IN`, SHA-256 `03:B7:0D:79:…:A8:DA` — **neither the DN nor the digest of the Android debug key** (`CN=Android Debug, O=Android, C=US`, `13:65:4F:0D:…:41:A3`) | `0` |
| 9 | `git ls-files` filtered for `key.properties`, `*.jks`, `*.keystore` | **no matches** — no key material is tracked | `0` |
| 10 | `firebase deploy --only functions --dry-run` | `functions: packaged C:\flutterApps\campusconnect\functions (168.36 KB) for uploading` … **`+  Dry run complete!`** against `campusconnect-firebase-project` | `0` |
| 11 | Firestore/Storage rule **source-contract** validation | `functions/test/security_rules_contract.test.js` — passes as part of the 97 | `0` |
| 12 | **Firestore rules executed against the emulator** — `npm --prefix functions run test:rules` | `firebase emulators:exec --only firestore` + `node --test functions/test-rules/firestore_rules.test.js` → `# tests 37` · `# pass 37` · `# fail 0` · `# cancelled 0` · `# skipped 0` (duration ≈ 5.5 s); emulator started, suite ran, emulator shut down cleanly | `0` |

### 15.1 What run #9 proves, and what it does not

The dry run is a **real** validation against the live Firebase project: the CLI
authenticated, loaded and analysed the Functions source tree, resolved every
`require()` in the deployed entry point, packaged the codebase, and confirmed all
required APIs and service identities. A syntax error, a broken import, or an
invalid export in `functions/index.js` would have failed this step. It did not
deploy anything — `--dry-run` performs no writes.

One non-fatal warning is emitted and is **expected**, not a defect:

```
! functions: package.json indicates an outdated version of firebase-functions.
! functions: Please note that there will be breaking changes when you upgrade.
```

`docs/Task.md` §13 explicitly forbids upgrading `firebase-functions` in this
version, so the warning is left in place deliberately. It is recorded here so it
is not mistaken for a suppressed failure.

### 15.2 How the security rules are validated — two layers

The rules are validated in **two independent ways**: a source contract on the rule
text, and a **real execution of those rules** against the Firestore emulator.

**Layer 1 — source contract (text).** `functions/test/security_rules_contract.test.js`
reads `firestore.rules`, strips `//` comments (the comments quote the removed
defect verbatim), brace-slices each `match` / `function` block, and asserts the
guards are present:

* the default-deny fallback is present and last;
* **SEC-1**: the recursive `{subcollection=**}` catch-all under `users/{uid}` has
  not come back, and `canWriteRole()` still gates the owner write;
* **D-9**: `allow create` / `update` / `delete` on `opportunities` require
  `userRole() == 'alumni'` and ownership, while reads stay open to authenticated users;
* **D-10**: `isValidOpportunityData()` exists, checks each required field and type,
  and is applied on both create and update; `isValidPlacementData()` is untouched;
* **D-11**: `canWriteProfileFlags()`, `profileCompletedWriteOk()` and
  `isVerifiedWriteOk()` exist; the owner write applies them; `profileCompleted`
  can only be asserted alongside the required profile sections; `isVerified` can
  only ever keep its existing value.

This remains the same convention already used on the client side by
`test/security_rules_mirror_test.dart`. On its own it asserts the rule **text**,
not rule **behaviour** — a guard that is present but semantically wrong would
pass.

**Layer 2 — executed against the Firestore emulator (behaviour).**
`functions/test-rules/firestore_rules.test.js` removes that gap. It loads
`firestore.rules` into a real emulator through `@firebase/rules-unit-testing`,
signs in as an alumni / student / teacher / anonymous, and asserts what the rules
**actually allow and deny**:

| Group | Executed cases | Result |
|---|---|---|
| **D-9** authorization | alumni create · student create · teacher create · unauthenticated create · owner update · non-owner update · owner delete · non-owner delete · authenticated read | 9 — create allowed only for the owning alumni; the other three denied; owner update/delete allowed; non-owner update/delete denied; reads stay open |
| **D-10** schema validation | missing `description` · empty `title` · wrong-typed `isActive` · non-timestamp `postedAt` · another user's `alumniId` · update that empties a required field · valid optional `applicationDeadline` | 7 — every malformed write denied, the well-formed one accepted |
| **SEC-1** role protection | student → teacher · alumni → student | 2 — self-elevation denied in both directions |
| **D-11** profile flags | `profileCompleted` without sections · genuine completion transition · `isVerified` assertion · ordinary edit preserving the flags · completion that also changes `role` · first write of a new account | 6 — the two tampering writes denied, the three legitimate writes allowed, the mixed write denied |
| **SEC-2** server-owned collections | `recommendations_meta` · `engagement_summary` · `career_coach` · `ai_insights` · `activities` · `recommendations` · `resumeReviews` | 7 — every server-owned write denied for the owner |
| **D-7** AI chat schema | append to `ai_interactions` · update an existing record | 2 — append allowed, mutation denied |
| catch-all removal | an unknown `users/{uid}` subcollection | 1 — denied (no recursive catch-all) |
| placements (regression) | student create · teacher create · client forging an application | 3 — student denied, teacher allowed, forged application denied |

**Observed output** (emulator started, suite ran, emulator shut down cleanly):

```
# tests 37
# pass 37
# fail 0
# cancelled 0
# skipped 0
duration_ms 5451.6454
+  Script exited successfully (code 0)
```

Run it with:

```
npm --prefix functions run test:rules        # -> firebase emulators:exec --only firestore …
```

**Prerequisite.** The Firestore emulator needs a JVM. On this machine
`JAVA_HOME` pointed at a **non-existent** `C:\Program Files\Java\jdk-23` and the
Oracle `javapath` shim crashed (`0xC0000409`), so the JBR bundled with Android
Studio was used instead
(`JAVA_HOME=C:\Program Files\Android\Android Studio\jbr`). Any working JDK on
`PATH`/`JAVA_HOME` satisfies the dependency; the script itself is not
machine-specific.

### 15.3 Runtime evidence, precisely scoped

| Claim | Runtime evidence? |
|---|---|
| The release APK builds and is signed by a release key, not the debug key | **Yes** — artefacts exist on disk; `apksigner` printed the signer |
| The Functions package is deployable | **Yes** — `firebase deploy --dry-run` completed |
| Flutter code has no analyzer issues | **Yes** — `flutter analyze` exited 0 |
| All Flutter tests pass | **Yes** — 540 passed |
| All Functions tests pass | **Yes** — 97 passed |
| The app *behaves* correctly on a device (login, apply, chat, …) | **No — not verified.** Requires the manual pass in §16. |
| The rules actually permit/deny the intended operations | **Yes — against the Firestore emulator.** 37 allow/deny assertions executed on the real `firestore.rules` (§15.2). **No** evidence from the live project — the rules are not deployed. |
| The hardened rules/Functions are live in production | **No — nothing was deployed.** |

---

## 16. Manual test results

**No manual/runtime application testing was performed for v9.2.4, and none is
claimed.** This environment has no attached Android device or running emulator, so
the manual matrix in `docs/Task.md` §15 — authentication cycles, resume review,
placements, opportunities, AI chat, and one end-to-end pass per role against the
signed release APK — remains an **operator step**.

What *was* performed here is the automated set in §15 — which now includes the
Firestore rules **executed in the emulator** (§15.2), so the rule decisions
themselves are behaviour-verified rather than text-asserted. What a device run
would still add: real network timing on apply, live App Check token behaviour,
**Storage** rule decisions (still text-asserted only), the behaviour of the
*deployed* backend, and the rendered UI of the pending/reconciliation state.

The concrete operator runbook, in order:

1. generate the release keystore and build (`docs/release_signing.md` §2–§6);
2. `apksigner verify --print-certs build/app/outputs/flutter-apk/app-release.apk`
   and confirm the digest is **not** the debug key;
3. `adb install -r build/app/outputs/flutter-apk/app-release.apk`;
4. run `docs/Task.md` §15 in full;
5. record the observed results back into this section — until then this section
   stays empty of runtime claims on purpose.
---

## 17. Known limitations

Stated so they are not discovered later as surprises.

1. **The Firestore rules are behaviour-verified — in the emulator, not against the
   deployed project.** `functions/test-rules/firestore_rules.test.js` executes the
   real `firestore.rules` against the Firestore emulator and asserts the allow/deny
   outcome for 37 cases (§15.2), which closes the earlier text-only gap. Two
   residual limits remain: the **Storage** rules (`storage.rules`) are still
   asserted by text only — there is no executed suite for them — and nothing is
   deployed, so the hardened rules are not yet the ones answering live traffic.
   An emulator and the production service can also differ at the edges.
2. **No device was exercised.** Every behavioural claim about the app (apply
   timing, pending-state UI, chat history ordering, per-role flows) is inferred
   from tests and source, not observed. Nothing in this report claims otherwise.
3. **The release APK in `build/` was signed with a throwaway validation keystore,
   which has been deleted.** It proves the mechanism, not the final key. The demo
   APK must be rebuilt with the operator's own keystore.
4. **Nothing was deployed.** The hardened rules and the Functions changes are not
   live; the dry run validated but did not publish.
5. **App Check enforcement is off by design** (§7). A sideloaded build therefore
   carries no attestation layer. Abuse resistance rests on Authentication, the
   rules, callable auth/role re-checks and quotas — all of which remain enforced —
   but a determined attacker with valid credentials is not stopped by attestation.
6. **The D-1 guard is deliberately narrow, and is a maintenance hazard.**
   `isResumeReviewMetadataOnlyChange()` recognises a fixed key set
   (`reviewCount`, `lastReviewAt`, `updatedAt`, `latestATSScore`,
   `latestMissingKeywords`). If a future change writes an *additional* field in
   that same metadata update, the guard will not recognise the write as
   metadata-only and the second refresh returns — silently. The guard has a test
   covering the current key set; whoever extends the set must extend the guard.
7. **Fingerprint convergence depends on the persisted `latestMissingKeywords`.**
   Convergence holds because the resume-review trigger persists that field
   (`functions/triggers/index.js:155`) and the engine and refresh paths both fall
   back to reading it (`functions/recommendations/engine.js:190`,
   `functions/recommendations/refresh.js:138`). For a student whose last review
   predates that field being persisted, the persisted map is absent while the
   trigger path still carries `resumeData` — so the two derivations can differ
   until the next review re-persists the field. Bounded and self-healing, but real.
8. **`ai_conversations` is retained.** It is no longer written by `askAI` but is
   still queried and cleaned by the retention job. `docs/Task.md` §13 forbids
   removing it in this release; it is transition debt, not a defect.
9. **The `firebase-functions` upgrade warning is intentionally unresolved** (§15.1).
   `docs/Task.md` §13 forbids the upgrade in this version.
10. **The legacy quota mirrors and the placement application mirror are
    untouched**, per `docs/Task.md` §13.
11. **No performance work was done.** Startup, Firestore read cost and AI cost are
    v9.2.5's subject; the v9.2.3 audit's performance findings (E-series, `C-3`,
    `D-4`…`D-6`, `D-8`) are untouched here by design.

---

## 18. Remaining work — v9.2.5 / v9.2.6

### First, regardless of phase (verification debt from v9.2.4)

1. ~~Emulator-executed rules tests~~ — **closed during v9.2.4**:
   `functions/test-rules/firestore_rules.test.js` runs the D-9 / D-10 / D-11 /
   SEC-1 / SEC-2 / D-7 matrix as real allow/deny assertions against the Firestore
   emulator — 37 cases, all green (§15.2). Still open in this area: the same
   executed treatment for **`storage.rules`**, which remains text-asserted.
2. **Extend the executed harness to Storage** — a `storage.rules` emulator suite
   (ownership, PDF MIME, 5 MB cap), so both rule sets are behaviour-verified.
3. **The device pass** — `docs/Task.md` §15 on the signed release APK, results
   recorded into §16 of this report.
4. **Deploy** the hardened rules and Functions once (2) and (3) pass.

### v9.2.5 — Performance, Cost & Scalability (the stated next phase)

The v9.2.3 audit's deferred performance findings, in its own priority order:
`C-3`, `D-4`, `D-5`, `D-6`, `D-8`, and the `E-1`, `E-2`, `E-4`…`E-17` series —
teacher-analytics read volume, recommendation candidate reads, AI cost per
refresh, and the startup profile-mode measurement that v9.2.2 instrumented but
never captured on-device.

### v9.2.6 — Cleanup and dependency currency

* Retire the legacy quota mirrors and `ai_conversations` once the transition
  window closes.
* Retire the placement application mirror.
* `firebase-functions` / `firebase-admin` upgrade with the breaking-change pass.
* Collapse the remaining `functions/test` source-contract tests — and the
  `storage.rules` assertions — into behavioural tests on the emulator harness
  established in v9.2.4.

---

## 19. Evidence appendix

**Artifacts on disk (verified present 2026-10-02)**

| Path | Size | Written |
|---|---|---|
| `build/app/outputs/flutter-apk/app-release.apk` | 56.7 MB | 15:21 |
| `build/app/outputs/bundle/release/app-release.aab` | 46.8 MB | 15:23 |

**Commands re-run for this report**

```
flutter analyze                                   -> No issues found! (ran in 13.5s)     exit 0
flutter test                                      -> All tests passed! (540)              exit 0
npm --prefix functions test                       -> # tests 97 / # pass 97 / # fail 0    exit 0
npm --prefix functions run test:rules             -> firestore emulator: 37/37 pass       exit 0
node --check <6 changed Functions files>          -> (no output)                          exit 0
git ls-files | findstr key.properties/.jks/.keystore -> (no matches)
firebase deploy --only functions --dry-run        -> +  Dry run complete!                 exit 0
```

**Source line references cited in this report**

| Claim | Evidence |
|---|---|
| The resume-review trigger persists the missing-keyword map | `functions/triggers/index.js:155` — `"portfolio.resume.latestMissingKeywords": missingKeywords` |
| The metadata-only key set the guard recognises | `functions/helpers/shared.js:301` |
| The engine falls back to the persisted map | `functions/recommendations/engine.js:190-191` |
| The refresh path reads the same persisted map | `functions/recommendations/refresh.js:138-139` |
| Rule guards asserted by test (text) | `functions/test/security_rules_contract.test.js` (D-9 / D-10 / D-11 / SEC-1) |
| Rule **behaviour** executed against the emulator | `functions/test-rules/firestore_rules.test.js` — 37 allow/deny assertions via `npm --prefix functions run test:rules` (§15.2) |
| Signing contract asserted by test | `functions/test/hardening_source_contracts.test.js` (C-1 / C-2 / E-18) |
| D-1 guard + convergence asserted by test | `functions/test/resume_review_single_refresh.test.js` |

**Documentation set for v9.2.4**

| Document | Role |
|---|---|
| `docs/Task.md` | The v9.2.4 scope; §0 deployment scope; re-scoped Definition of Done |
| `docs/v9_2_4_hardening_report.md` | This report — the full implementation record |
| `docs/confirmation.md` | The Definition-of-Done confirmation (V9.2 content archived below it) |
| `docs/release_signing.md` | Direct-distribution release key, `apksigner` check, `adb install` |
| `docs/app_check_status.md` | The non-Play App Check posture and why enforcement is off |
| `docs/eligibility_rules.md` | The shipped eligibility semantics (parity target) |
| `docs/todo.md` | Workstream tracker |
| `docs/v9_2_3_audit_report.md` | The source audit; §AD marks the metadata corrections |

---

## 20. Summary

**Fixed:** C-1, C-2 (provider architecture and posture), D-1, D-2, D-3, D-7, D-9,
D-10, D-11, E-3, E-18 — the release blockers and the high-severity correctness
defects from the v9.2.3 audit, with no UI redesign, no architecture change, no
recommendation-engine replacement and no dependency upgrade.

**Verified:** by 540 Flutter tests, 97 Functions tests and **37 Firestore-rules
assertions executed against the emulator** — nine new suites covering every fixed
finding; `flutter analyze` clean; `node --check` clean; no key material or debug
token tracked.

**Runtime-verified:** the release APK builds and is signed by a release key rather
than the debug key; the Functions package passes `firebase deploy --dry-run`
against the live project; and the hardened `firestore.rules` **actually allow and
deny the intended operations** when executed against the Firestore emulator
(37/37).

**Still outstanding:** device install and the manual matrix; the final release
key; an executed equivalent for `storage.rules`; and the deployment itself. None
of these is a code defect, and none is claimed as done.

**Next phase:** v9.2.5 — Performance, Cost & Scalability Optimization.
